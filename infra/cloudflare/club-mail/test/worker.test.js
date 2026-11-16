// node --test: the Worker against a fake Email Routing message and a fake API.
import assert from "node:assert/strict";
import { test } from "node:test";

import worker, { deliver, forwardTarget, MAX_DEFAULT, sha256Hex, signedHeaders, TOO_LARGE } from "../worker.js";

const SECRET = "k".repeat(64);
const RAW = "From: Ananya <ananya@example.org>\r\nTo: yukthi@myotherapp.in\r\nSubject: Parking\r\nMessage-ID: <p@example.org>\r\n\r\nIs parking free?\r\n";

function message({ to = "yukthi@myotherapp.in", raw = RAW, size, auth = "mx.cloudflare.net; dmarc=pass" } = {}) {
  const bytes = new TextEncoder().encode(raw);
  const m = {
    from: "ananya@example.org",
    to,
    rawSize: size ?? bytes.byteLength,
    raw: new Response(bytes).body,
    headers: new Headers(auth ? { "authentication-results": auth } : {}),
    rejected: null,
    forwarded: null,
    setReject(reason) { this.rejected = reason; },
    async forward(to) { this.forwarded = to; },
  };
  return m;
}

function api(...answers) {
  const calls = [];
  const fetchFn = async (url, init) => {
    calls.push({ url, init });
    const next = answers.length > 1 ? answers.shift() : answers[0];
    if (next instanceof Error) throw next;
    return new Response(next.body === undefined ? null : JSON.stringify(next.body), { status: next.status ?? 200 });
  };
  return { calls, fetchFn };
}

const env = { MAILBOX_HOOK_SECRET: SECRET, API_URL: "https://api.test/api/v1/hooks/mailbox/cloudflare" };
const fast = { sleep: async () => {}, now: () => 1_700_000_000_000 };

test("signs exactly as the API checks (the backend's own vector)", async () => {
  // backend: hmac(sha256, key, "v1\n1700000000\n<to>\n<from>\n1234\n<auth>"), each value encodeURIComponent'd
  const h = await signedHeaders(SECRET, { to: "Yukthi+Events@myotherapp.in", from: "ananya@example.org", size: 1234, auth: "mx.cloudflare.net; dmarc=pass", now: 1_700_000_000_000 });
  assert.equal(h["X-Moa-Envelope-To"], "Yukthi%2BEvents%40myotherapp.in");
  assert.equal(h["X-Moa-Auth-Results"], "mx.cloudflare.net%3B%20dmarc%3Dpass");
  assert.equal(h["X-Moa-Signature"], "a56d9288597c17eed940afd1c06f08f13113a0785a9592fed6d1f9798aa677aa");
});

test("signs the body too (v2), exactly as the API checks (the backend's own vector)", async () => {
  // backend: hmac(sha256, key, "v1\n...\n<auth>\n<sha256 of the body>") with "v2" first
  const body = await sha256Hex(new TextEncoder().encode("hello"));
  assert.equal(body, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824");
  const h = await signedHeaders(SECRET, { to: "Yukthi+Events@myotherapp.in", from: "ananya@example.org", size: 1234, auth: "mx.cloudflare.net; dmarc=pass", now: 1_700_000_000_000, bodySha256: body });
  assert.equal(h["X-Moa-Signature"], "a56d9288597c17eed940afd1c06f08f13113a0785a9592fed6d1f9798aa677aa");
  assert.equal(h["X-Moa-Body-Sha256"], body);
  assert.equal(h["X-Moa-Signature-V2"], "4a917b041982b97a02e938d1083a7a1ef94e304665a01d9993126dcfe9dc62cb");
  // Without the body's hash, v1 alone, as before.
  const old = await signedHeaders(SECRET, { to: "a@myotherapp.in", from: "b@example.org", size: 1, auth: "", now: 1_700_000_000_000 });
  assert.ok(old["X-Moa-Signature"] && !("X-Moa-Signature-V2" in old) && !("X-Moa-Body-Sha256" in old));
});

test("every try carries both signatures and the hash of the bytes it posts", async () => {
  const { calls, fetchFn } = api({ status: 502, body: null }, { body: { action: "accept" } });
  assert.equal(await deliver(message(), env, { fetchFn, ...fast }), "accepted");
  assert.equal(calls.length, 2);
  const expected = await sha256Hex(new TextEncoder().encode(RAW));
  for (const { init } of calls) {
    assert.equal(init.headers["X-Moa-Body-Sha256"], expected);
    assert.equal(await sha256Hex(init.body), expected);
    assert.match(init.headers["X-Moa-Signature"], /^[0-9a-f]{64}$/);
    assert.match(init.headers["X-Moa-Signature-V2"], /^[0-9a-f]{64}$/);
  }
});

test("BODY_SIGNATURE=off sends the older signature alone", async () => {
  const { calls, fetchFn } = api({ body: { action: "accept" } });
  assert.equal(await deliver(message(), { ...env, BODY_SIGNATURE: "OFF" }, { fetchFn, ...fast }), "accepted");
  const { headers } = calls[0].init;
  assert.ok(headers["X-Moa-Signature"] && !("X-Moa-Signature-V2" in headers) && !("X-Moa-Body-Sha256" in headers));
});

test("posts the raw mail, signed, and is done when the API keeps it", async () => {
  const { calls, fetchFn } = api({ body: { ok: true, action: "accept", kept: 1 } });
  const m = message();
  assert.equal(await deliver(m, env, { fetchFn, ...fast }), "accepted");
  assert.equal(calls.length, 1);
  const { url, init } = calls[0];
  assert.equal(url, env.API_URL);
  assert.equal(new TextDecoder().decode(init.body), RAW);
  assert.equal(init.headers["X-Moa-Size"], String(new TextEncoder().encode(RAW).byteLength));
  assert.equal(init.headers["X-Moa-Envelope-From"], "ananya%40example.org");
  assert.equal(m.rejected, null);
});

test("rejects in the session with the API's words", async () => {
  const { fetchFn } = api({ body: { ok: true, action: "reject", reason: "unknown", text: "No mailbox here by that name" } });
  const m = message({ to: "nobody@myotherapp.in" });
  assert.equal(await deliver(m, env, { fetchFn, ...fast }), "rejected:unknown");
  assert.equal(m.rejected, "No mailbox here by that name");
});

test("tries again while the API restarts, then takes the answer", async () => {
  const { calls, fetchFn } = api({ status: 502, body: null }, new TypeError("fetch failed"), { body: { action: "accept" } });
  const waits = [];
  const outcome = await deliver(message(), env, { fetchFn, sleep: async (ms) => waits.push(ms), now: fast.now });
  assert.equal(outcome, "accepted");
  assert.equal(calls.length, 3);
  assert.deepEqual(waits, [2000, 6000]);
});

test("throws (a temporary error for the sender) when the API never takes it", async () => {
  const { calls, fetchFn } = api({ status: 503, body: { ok: false, reason: "retry" } });
  const m = message();
  await assert.rejects(deliver(m, env, { fetchFn, ...fast }), /did not take the mail \(HTTP 503\)/);
  assert.equal(calls.length, 3);
  assert.equal(m.rejected, null);
});

test("a refused key is not hammered, and still not lost", async () => {
  const { calls, fetchFn } = api({ status: 401, body: { ok: false, reason: "signature" } });
  await assert.rejects(deliver(message(), env, { fetchFn, ...fast }), /HTTP 401/);
  assert.equal(calls.length, 1);
});

test("without the secret nothing is sent, and the mail comes again", async () => {
  const { calls, fetchFn } = api({ body: { action: "accept" } });
  await assert.rejects(deliver(message(), {}, { fetchFn, ...fast }), /MAILBOX_HOOK_SECRET/);
  assert.equal(calls.length, 0);
});

test("too large is rejected before anything is read or sent", async () => {
  const { calls, fetchFn } = api({ body: { action: "accept" } });
  assert.equal(MAX_DEFAULT, 15 * 1024 * 1024);
  const m = message({ size: 15 * 1024 * 1024 + 1 });
  assert.equal(await deliver(m, env, { fetchFn, ...fast }), "rejected:too_large");
  assert.equal(m.rejected, TOO_LARGE);
  assert.equal(calls.length, 0);
  // Up to the limit it goes to the API; MAX_BYTES can raise or lower it.
  assert.equal(await deliver(message({ size: 15 * 1024 * 1024 }), env, { fetchFn, ...fast }), "accepted");
  assert.equal(calls.length, 1);
  const small = message({ size: 2 * 1024 * 1024 });
  assert.equal(await deliver(small, { ...env, MAX_BYTES: String(1024 * 1024) }, { fetchFn, ...fast }), "rejected:too_large");
  assert.equal(calls.length, 1);
  const big = api({ status: 413, body: null });
  const m2 = message();
  assert.equal(await deliver(m2, env, { fetchFn: big.fetchFn, ...fast }), "rejected:too_large");
});

test("FORWARD sends a staff address on without asking the API", async () => {
  const { calls, fetchFn } = api({ body: { action: "accept" } });
  const fwd = { ...env, FORWARD: JSON.stringify({ info: "owner@example.com" }) };
  const m = message({ to: "Info+press@myotherapp.in" });
  assert.equal(await deliver(m, fwd, { fetchFn, ...fast }), "forwarded");
  assert.equal(m.forwarded, "owner@example.com");
  assert.equal(calls.length, 0);
  assert.equal(forwardTarget({ FORWARD: "not json" }, "info@x"), null);
  assert.equal(forwardTarget({ FORWARD: '{"info": "nope"}' }, "info@x"), null);
});

test("the handler logs the outcome and no address", async (t) => {
  const logs = [];
  t.mock.method(console, "log", (line) => logs.push(line));
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify({ action: "accept" }), { status: 200 });
  try {
    await worker.email(message(), env);
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.equal(logs.length, 1);
  assert.ok(!logs[0].includes("@"));
  assert.equal(JSON.parse(logs[0]).outcome, "accepted");
});
