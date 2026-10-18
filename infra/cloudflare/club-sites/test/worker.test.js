// The club-sites Worker's routing, run under Node (18+) with the API and the
// edge cache stubbed:  node --test infra/cloudflare/club-sites/test/*.test.js
// (or `npm test` in infra/cloudflare/club-sites).
import assert from "node:assert/strict";
import { beforeEach, describe, test } from "node:test";

import { classify, readResolved, sameUrlOn } from "../routing.js";
import worker from "../worker.js";

const API = "https://api.myotherapp.in";
const PAGE = "<!doctype html><title>Circuit Society</title>";

/** The edge cache, by URL, honouring nothing but presence. */
class FakeCache {
  constructor() {
    this.store = new Map();
  }
  async match(request) {
    const hit = this.store.get(request.url);
    return hit ? hit.clone() : undefined;
  }
  async put(request, response) {
    assert.equal(request.method, "GET");
    assert.match(response.headers.get("cache-control"), /max-age=\d+/);
    this.store.set(request.url, response.clone());
  }
}

let calls;
let answers;
let pages;
let ctx;

beforeEach(() => {
  calls = [];
  // host -> resolver answer: an object (200), undefined (404), "down" (network error) or a status number.
  answers = {
    "www.theirclub.org": { club_slug: "circuit-a1b2c3", status: "active", canonical_host: "www.theirclub.org" },
    "circuit-a1b2c3.myotherapp.in": { club_slug: "circuit-a1b2c3", status: "active", canonical_host: "www.theirclub.org" },
    "events.paused.org": { club_slug: "paused-d4e5f6", status: "paused", canonical_host: "paused-d4e5f6.myotherapp.in" },
    "plain-x9y8z7.myotherapp.in": { club_slug: "plain-x9y8z7", status: "active", canonical_host: "plain-x9y8z7.myotherapp.in" },
  };
  pages = { "circuit-a1b2c3": PAGE, "plain-x9y8z7": PAGE };
  ctx = { pending: [], waitUntil(p) { this.pending.push(p); } };
  globalThis.caches = { default: new FakeCache() };
  globalThis.fetch = async (input, init) => {
    const url = typeof input === "string" ? input : input.url;
    calls.push(url);
    if (url.startsWith(`${API}/api/v1/sites/resolve?host=`)) {
      const host = decodeURIComponent(url.slice(`${API}/api/v1/sites/resolve?host=`.length));
      const answer = answers[host];
      if (answer === "down") throw new TypeError("fetch failed");
      if (typeof answer === "number") return new Response("upstream error", { status: answer });
      if (answer === undefined) return Response.json({ message: "No club site at this host" }, { status: 404 });
      return Response.json(answer);
    }
    const site = url.match(/^https:\/\/api\.myotherapp\.in\/api\/v1\/sites\/([^/?]+)$/);
    if (site) {
      assert.equal(init?.headers?.accept, "text/html");
      const html = pages[decodeURIComponent(site[1])];
      return html ? new Response(html, { status: 200 }) : new Response("Not found", { status: 404 });
    }
    // Anything else is a pass-through to an origin.
    return new Response(`origin for ${url}`, { status: 200, headers: { "x-origin": "yes" } });
  };
});

const get = (url, method = "GET") => worker.fetch(new Request(url, { method }), {}, ctx);
const resolves = () => calls.filter((u) => u.includes("/sites/resolve?"));

describe("classify", () => {
  test("our own names pass through; clubs, the fallback and custom domains are told apart", () => {
    assert.deepEqual(classify("myotherapp.in"), { kind: "own", host: "myotherapp.in" });
    for (const name of ["www", "api", "admin-next", "clubs-next", "events", "club", "r", "mail"]) {
      assert.equal(classify(`${name}.myotherapp.in`).kind, "own", name);
    }
    assert.deepEqual(classify("Circuit-A1B2C3.myotherapp.in"), { kind: "club", host: "circuit-a1b2c3.myotherapp.in", name: "circuit-a1b2c3" });
    assert.equal(classify("sites.myotherapp.in").kind, "fallback");
    assert.equal(classify("a.b.myotherapp.in").kind, "invalid");
    assert.equal(classify("-bad.myotherapp.in").kind, "invalid");
    assert.deepEqual(classify("WWW.TheirClub.org."), { kind: "custom", host: "www.theirclub.org" });
    assert.equal(classify("www.xn--bcherclub-t9a.de").kind, "custom");
    assert.equal(classify("localhost").kind, "invalid");
    assert.equal(classify("203.0.113.9").kind, "invalid");
    assert.equal(classify("myotherapp.in.evil.org").kind, "custom");
  });

  test("only a well-formed resolver answer is believed", () => {
    assert.deepEqual(readResolved({ club_slug: "c", status: "paused", canonical_host: "c.myotherapp.in" }), { slug: "c", status: "paused", canonical: "c.myotherapp.in" });
    assert.equal(readResolved({ club_slug: "c", status: "gone", canonical_host: "c.myotherapp.in" }), null);
    assert.equal(readResolved({ club_slug: "c", status: "active", canonical_host: "evil.org/phish" }), null);
    assert.equal(readResolved({ club_slug: "../x", status: "active", canonical_host: "a.org" }), null);
    assert.equal(readResolved(null), null);
    assert.equal(sameUrlOn("www.theirclub.org", new URL("https://x.myotherapp.in/a/b?ref=k")), "https://www.theirclub.org/a/b?ref=k");
  });
});

describe("a club's subdomain", () => {
  test("is served as before when the club has no active domain of its own, asking the API once per five minutes", async () => {
    const r = await get("https://plain-x9y8z7.myotherapp.in/");
    assert.equal(r.status, 200);
    assert.equal(await r.text(), PAGE);
    assert.match(r.headers.get("content-security-policy"), /default-src 'none'/);
    assert.equal(r.headers.get("cache-control"), "public, max-age=300");
    await Promise.all(ctx.pending);
    await get("https://plain-x9y8z7.myotherapp.in/");
    assert.equal(resolves().length, 1);
  });

  test("redirects for good to the club's own domain, keeping the path and query", async () => {
    let r = await get("https://circuit-a1b2c3.myotherapp.in/?ref=k7&utm_source=ig");
    assert.equal(r.status, 301);
    assert.equal(r.headers.get("location"), "https://www.theirclub.org/?ref=k7&utm_source=ig");
    assert.equal(r.headers.get("cache-control"), "public, max-age=300");
    r = await get("https://circuit-a1b2c3.myotherapp.in/events?x=1");
    assert.equal(r.headers.get("location"), "https://www.theirclub.org/events?x=1");
    assert.ok(!calls.some((u) => u.endsWith("/api/v1/sites/circuit-a1b2c3")), "the page is not fetched for a redirect");
  });

  test("is served as before when the API cannot be asked", async () => {
    answers["circuit-a1b2c3.myotherapp.in"] = "down";
    let r = await get("https://circuit-a1b2c3.myotherapp.in/");
    assert.equal(r.status, 200);
    answers["circuit-a1b2c3.myotherapp.in"] = 502;
    globalThis.caches = { default: new FakeCache() };
    r = await get("https://circuit-a1b2c3.myotherapp.in/");
    assert.equal(r.status, 200);
  });

  test("an unknown club still gets the no-site page", async () => {
    const r = await get("https://nobody-000000.myotherapp.in/");
    assert.equal(r.status, 404);
    assert.match(await r.text(), /No club site at nobody-000000\.myotherapp\.in/);
  });
});

describe("a club's own domain", () => {
  test("active: the club's site, exactly as at its subdomain", async () => {
    const r = await get("https://www.theirclub.org/?ref=k7");
    assert.equal(r.status, 200);
    assert.equal(await r.text(), PAGE);
    assert.match(r.headers.get("content-security-policy"), /connect-src https:\/\/api\.myotherapp\.in/);
    assert.equal(r.headers.get("x-content-type-options"), "nosniff");
    assert.ok(calls.includes(`${API}/api/v1/sites/circuit-a1b2c3`));
    const head = await get("https://www.theirclub.org/", "HEAD");
    assert.equal(head.status, 200);
    assert.equal(await head.text(), "");
  });

  test("active: other paths land on the page, robots.txt is answered", async () => {
    let r = await get("https://www.theirclub.org/about?utm_source=x");
    assert.equal(r.status, 302);
    assert.equal(r.headers.get("location"), "https://www.theirclub.org/?utm_source=x");
    r = await get("https://www.theirclub.org/robots.txt");
    assert.equal(r.status, 200);
    assert.match(await r.text(), /User-agent/);
  });

  test("paused: 302 to the club's subdomain, same path and query", async () => {
    const r = await get("https://events.paused.org/talks?ref=k7");
    assert.equal(r.status, 302);
    assert.equal(r.headers.get("location"), "https://paused-d4e5f6.myotherapp.in/talks?ref=k7");
    assert.equal(r.headers.get("cache-control"), "no-store");
  });

  test("paused, pointing at itself: the no-site page, never a redirect loop", async () => {
    answers["www.loop.org"] = { club_slug: "loop", status: "paused", canonical_host: "www.loop.org" };
    assert.equal((await get("https://www.loop.org/")).status, 404);
  });

  test("unknown: the no-site page, naming the address, and the answer is cached", async () => {
    const r = await get("https://www.evil.org/");
    assert.equal(r.status, 404);
    assert.match(await r.text(), /No club site at www\.evil\.org/);
    await Promise.all(ctx.pending);
    await get("https://www.evil.org/");
    assert.equal(resolves().length, 1);
  });

  test("the API down, or answering nonsense: back in a moment", async () => {
    answers["www.theirclub.org"] = "down";
    assert.equal((await get("https://www.theirclub.org/")).status, 503);
    answers["www.theirclub.org"] = 500;
    assert.equal((await get("https://www.theirclub.org/")).status, 503);
    answers["www.theirclub.org"] = { club_slug: "circuit-a1b2c3", status: "active", canonical_host: "evil.org/phish" };
    assert.equal((await get("https://www.theirclub.org/")).status, 503);
  });

  test("only GET and HEAD", async () => {
    const r = await get("https://www.theirclub.org/", "POST");
    assert.equal(r.status, 405);
    assert.equal(resolves().length, 0);
  });
});

describe("our own hosts", () => {
  test("pass straight through and never ask the resolver", async () => {
    for (const url of ["https://api.myotherapp.in/api/v1/ping", "https://myotherapp.in/", "https://clubs-next.myotherapp.in/login", "https://admin-next.myotherapp.in/"]) {
      const r = await get(url);
      assert.equal(r.headers.get("x-origin"), "yes", url);
    }
    assert.equal(resolves().length, 0);
  });

  test("the fallback origin and deeper names are nobody's site", async () => {
    assert.equal((await get("https://sites.myotherapp.in/")).status, 404);
    assert.equal((await get("https://a.b.myotherapp.in/")).status, 404);
    assert.equal(resolves().length, 0);
  });
});
