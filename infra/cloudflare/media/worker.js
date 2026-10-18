/**
 * The media CDN: https://media.myotherapp.in/<key> is the picture at <key>
 * in the bucket, kept at the edge near whoever asks.
 *
 * Public pictures (event posters, club logos and covers, speakers', team
 * members' and partners' photos, posts' images, stock avatars, store photos)
 * used to reach browsers only as presigned S3 links from us-east-1: ~280 ms
 * a hop from India, a different address every few days, S3 egress on every
 * view. With APP_MEDIA_CDN_URL set, the backend hands out addresses here
 * instead (app/core/storage/media.py), and this Worker:
 *
 *   - answers GET and HEAD only;
 *   - serves only a picture in one of the public folders (media.js); any
 *     other path is a 404 that never reaches S3;
 *   - reads the object from the private bucket with a signed GetObject
 *     (sigv4.js), using a key that can read those folders and nothing else
 *     (the S3_* secrets, README.md);
 *   - keeps it in this data centre's cache (the Cache API) under its path
 *     alone -- a query string never makes a new copy, so it cannot be used
 *     to send every request to S3;
 *   - says how long it may be kept: a versioned key (`v-<32 hex>`, written
 *     once by the backend) for a year, `immutable`; an older key an hour in
 *     the browser and a day here; a missing one a minute;
 *   - sends the type its extension names, S3's ETag and Last-Modified, and
 *     answers a matching If-None-Match / If-Modified-Since with a 304;
 *   - limits the misses one address can cause (MISS_LIMITER, wrangler.toml):
 *     hits cost nothing, so only what reaches S3 is counted.
 *
 * Pictures are meant to be shown anywhere -- the app, emails, WhatsApp
 * previews, other sites -- so there is no Referer check: requests without
 * one (the app, mail clients) are most of them. Abuse is bounded by the
 * cache key and the miss limit instead.
 */

import { MISSING, cacheControl, notModified, objectKey, pictureAt } from "./media.js";
import { getObject } from "./sigv4.js";

/** S3 errors that mean our signing or key is wrong, not that the picture is missing. */
const OUR_FAULT = /<Code>(SignatureDoesNotMatch|InvalidAccessKeyId|ExpiredToken|RequestTimeTooSkewed|AuthorizationHeaderMalformed|InvalidToken)<\/Code>/;

const COMMON = {
  "access-control-allow-origin": "*",
  "cross-origin-resource-policy": "cross-origin",
  "x-content-type-options": "nosniff",
};

function plain(status, text, cache, extra = {}) {
  return new Response(text, { status, headers: { "content-type": "text/plain; charset=utf-8", "cache-control": cache, ...COMMON, ...extra } });
}

const notFound = () => plain(404, "Not found\n", MISSING);
/** The same answer without its body, for a HEAD. */
const bodiless = (r) => new Response(null, { status: r.status, headers: r.headers });
const failed = () => plain(502, "The picture could not be read just now\n", "no-store");

function configured(env) {
  return Boolean(env && env.S3_BUCKET && env.S3_REGION && env.S3_ACCESS_KEY_ID && env.S3_SECRET_ACCESS_KEY);
}

/** The cache's key for a picture: its path on our host, nothing else (no query, no headers). */
function cacheKey(url, picture) {
  return new Request(`${url.origin}/${picture.path}`, { method: "GET" });
}

function stash(ctx, cache, key, response) {
  if (!cache) return;
  const stored = cache.put(key, response.clone());
  if (ctx && typeof ctx.waitUntil === "function") ctx.waitUntil(stored);
}

/**
 * The picture from S3, as the response to keep: a 200 with our headers, a
 * 404 (no such key -- or AccessDenied, which is what S3 says about a
 * missing key to a reader without ListBucket), or null when S3 could not be
 * asked or refused us (never kept).
 */
async function fromBucket(env, picture) {
  let upstream;
  try {
    const signed = await getObject({
      bucket: env.S3_BUCKET,
      region: env.S3_REGION,
      key: objectKey(picture.path, env.S3_BASE_PATH),
      accessKeyId: env.S3_ACCESS_KEY_ID,
      secretAccessKey: env.S3_SECRET_ACCESS_KEY,
    });
    upstream = await fetch(signed.url, { method: "GET", headers: signed.headers });
  } catch (err) {
    console.error("media: S3 unreachable", picture.path, String(err));
    return null;
  }
  if (upstream.status === 404) return notFound();
  if (upstream.status === 403) {
    const body = await upstream.text().catch(() => "");
    if (OUR_FAULT.test(body)) {
      console.error("media: S3 refused our signature", picture.path, body.slice(0, 300));
      return null;
    }
    return notFound();
  }
  if (upstream.status !== 200) {
    console.error("media: S3 answered", upstream.status, picture.path);
    return null;
  }
  const headers = { "content-type": picture.contentType, "cache-control": cacheControl(picture), ...COMMON };
  for (const name of ["etag", "last-modified", "content-length"]) {
    const value = upstream.headers.get(name);
    if (value) headers[name] = value;
  }
  return new Response(upstream.body, { status: 200, headers });
}

/** What the visitor gets from a kept 200: a 304 when they hold it already, else it (no body for HEAD). */
function answer(request, kept, how) {
  const etag = kept.headers.get("etag");
  const modified = kept.headers.get("last-modified");
  if (notModified(request.headers, etag, modified)) {
    const headers = { "cache-control": kept.headers.get("cache-control"), ...COMMON, "x-cache": how };
    if (etag) headers.etag = etag;
    if (modified) headers["last-modified"] = modified;
    return new Response(null, { status: 304, headers });
  }
  const headers = new Headers(kept.headers);
  headers.set("x-cache", how);
  return new Response(request.method === "HEAD" ? null : kept.body, { status: kept.status, headers });
}

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return plain(405, "Method not allowed\n", "no-store", { allow: "GET, HEAD" });
    }
    const url = new URL(request.url);
    if (url.pathname === "/robots.txt") {
      // Posters and logos in image search are welcome; nothing else is here.
      return plain(200, "User-agent: *\nAllow: /\n", "public, max-age=86400");
    }
    const picture = pictureAt(url.pathname);
    if (!picture) return request.method === "HEAD" ? bodiless(notFound()) : notFound();
    if (!configured(env)) {
      console.error("media: S3_BUCKET, S3_REGION, S3_ACCESS_KEY_ID or S3_SECRET_ACCESS_KEY is not set");
      return plain(503, "Not configured\n", "no-store");
    }

    const cache = typeof caches !== "undefined" ? caches.default : null;
    const key = cacheKey(url, picture);
    let kept = cache ? await cache.match(key) : undefined;
    let how = "HIT";
    if (!kept) {
      how = "MISS";
      if (env.MISS_LIMITER) {
        const who = request.headers.get("cf-connecting-ip") || "unknown";
        const { success } = await env.MISS_LIMITER.limit({ key: who });
        if (!success) return plain(429, "Too many requests\n", "no-store", { "retry-after": "60" });
      }
      kept = await fromBucket(env, picture);
      if (!kept) return failed();
      stash(ctx, cache, key, kept);
    }
    if (kept.status !== 200) {
      return request.method === "HEAD" ? bodiless(kept) : kept;
    }
    return answer(request, kept, how);
  },
};
