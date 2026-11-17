// The club-mail Worker: Cloudflare Email Routing's catch-all for myotherapp.in.
//
// Every mail to an address on the domain comes here, once per envelope
// recipient. The Worker posts the raw MIME, signed, to the API
// (POST /api/v1/hooks/mailbox/cloudflare; backend app/api/club_mailbox/
// cloudflare.py), which keeps it for the club whose address it is (or for the
// team's desk: support@, sales@) and says what to do:
//
//   accept                 -> done
//   reject (with words)    -> setReject(words): the sending server tells its
//                             sender ("No mailbox here by that name"), so a
//                             forged sender gets no bounce from us
//   anything else          -> tried again (about 10 s), then thrown: Cloudflare
//                             gives the sending server a temporary error and
//                             it delivers again later. Never lost.
//
// FORWARD (JSON, optional): {"info": "someone@gmail.com"} sends a local part
// straight to an address verified in Email Routing, without asking the API.
//
// Signed twice, with MAILBOX_HOOK_SECRET (HMAC-SHA256; backend
// app/api/club_mailbox/cloudflare.py), over the values as sent:
//   X-Moa-Signature     v1, time, to, from, size, Authentication-Results
//   X-Moa-Signature-V2  v2, the same, and the body's SHA-256 (X-Moa-Body-Sha256)
// An API from before v2 checks v1 and ignores the rest; one with v2 checks v2,
// so the body is covered. Once this Worker is deployed the API may require v2
// (APP_MAILBOX_HOOK_REQUIRE_BODY_SIGNATURE).
//
// Bindings: MAILBOX_HOOK_SECRET (secret; the API's APP_MAILBOX_HOOK_SECRET),
// API_URL and FORWARD (plain text, set by deploy.sh), MAX_BYTES (optional:
// default 15 MiB, the API's APP_MAILBOX_INBOUND_MAX_MB), BODY_SIGNATURE
// (optional: "off" sends v1 alone, as before; only while the API doesn't
// require v2).
//
// Nothing a mail says, and no address, is logged: only the outcome.

export const VERSION = "v1";
export const VERSION_2 = "v2";
export const DEFAULT_URL = "https://api.myotherapp.in/api/v1/hooks/mailbox/cloudflare";
export const TOO_LARGE = "Message too large for this mailbox";
// Waits (ms) before each try: now, then 2 s, then 6 s.
export const WAITS = [0, 2000, 6000];
// A larger mail is refused in the SMTP session, by its size alone, before
// anything is read or sent on: the API keeps nothing past 15 MiB either.
export const MAX_DEFAULT = 15 * 1024 * 1024;

const enc = (value) => encodeURIComponent(value || "");

const hex = (bytes) => Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");

export async function hmacHex(key, text) {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(key), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(new Uint8Array(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(text))));
}

/** The body's SHA-256, hex: what v2 signs of it. */
export async function sha256Hex(bytes) {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)));
}

/**
 * The headers for one try: each value percent-encoded, then signed (v1; and
 * v2, with the body's hash, when `bodySha256` is given).
 */
export async function signedHeaders(secret, { to, from, size, auth, now, bodySha256 }) {
  const ts = String(Math.floor(now / 1000));
  const fields = [enc(to), enc(from), String(size), enc(auth)];
  const headers = {
    "Content-Type": "message/rfc822",
    "X-Moa-Timestamp": ts,
    "X-Moa-Envelope-To": fields[0],
    "X-Moa-Envelope-From": fields[1],
    "X-Moa-Size": fields[2],
    "X-Moa-Auth-Results": fields[3],
    "X-Moa-Signature": await hmacHex(secret, [VERSION, ts, ...fields].join("\n")),
  };
  if (bodySha256) {
    headers["X-Moa-Body-Sha256"] = bodySha256;
    headers["X-Moa-Signature-V2"] = await hmacHex(secret, [VERSION_2, ts, ...fields, bodySha256].join("\n"));
  }
  return headers;
}

/** The verified address FORWARD names for this recipient's local part, if any. */
export function forwardTarget(env, to) {
  let map;
  try {
    map = JSON.parse(env.FORWARD || "{}");
  } catch {
    return null;
  }
  const local = String(to || "").toLowerCase().split("@")[0].split("+")[0];
  const target = map && typeof map === "object" ? map[local] : null;
  return typeof target === "string" && target.includes("@") ? target : null;
}

/** Hand one mail to the API, and do what it says. Returns the outcome; throws to have it sent again. */
export async function deliver(message, env, { fetchFn = fetch, sleep = (ms) => new Promise((r) => setTimeout(r, ms)), now = () => Date.now() } = {}) {
  const max = Number(env.MAX_BYTES) || MAX_DEFAULT;
  if (message.rawSize > max) {
    message.setReject(TOO_LARGE);
    return "rejected:too_large";
  }
  const target = forwardTarget(env, message.to);
  if (target) {
    await message.forward(target);
    return "forwarded";
  }
  if (!env.MAILBOX_HOOK_SECRET) throw new Error("club-mail: MAILBOX_HOOK_SECRET is not set; the sender will try again");
  const raw = new Uint8Array(await new Response(message.raw).arrayBuffer());
  // Cloudflare's own result is the first; the API reads that one alone.
  const auth = message.headers.get("authentication-results") || "";
  // Hashed once: the same bytes go on every try.
  const bodySha256 = String(env.BODY_SIGNATURE || "").toLowerCase() === "off" ? null : await sha256Hex(raw);
  let last = "no try";
  for (const wait of WAITS) {
    if (wait) await sleep(wait);
    const headers = await signedHeaders(env.MAILBOX_HOOK_SECRET, { to: message.to, from: message.from, size: raw.byteLength, auth, now: now(), bodySha256 });
    let res;
    try {
      res = await fetchFn(env.API_URL || DEFAULT_URL, { method: "POST", body: raw, headers });
    } catch (err) {
      last = `network: ${(err && err.name) || "error"}`;
      continue;
    }
    if (res.status === 200) {
      let body = {};
      try {
        body = await res.json();
      } catch {
        // an answer that isn't ours: try again
      }
      if (body.action === "accept") return "accepted";
      if (body.action === "reject") {
        message.setReject(body.text || "No mailbox here by that name");
        return `rejected:${body.reason || "unknown"}`;
      }
      last = "200 without an action";
      continue;
    }
    if (res.status === 413) {
      message.setReject(TOO_LARGE);
      return "rejected:too_large";
    }
    last = `HTTP ${res.status}`;
    // A key or a body the API refuses won't change by trying again now.
    if (res.status === 400 || res.status === 401 || res.status === 403) break;
  }
  throw new Error(`club-mail: the API did not take the mail (${last}); the sender will try again`);
}

export default {
  async email(message, env) {
    try {
      const outcome = await deliver(message, env);
      console.log(JSON.stringify({ outcome, size: message.rawSize }));
    } catch (err) {
      console.error(JSON.stringify({ outcome: "temporary_failure", error: String((err && err.message) || err) }));
      throw err;
    }
  },
};
