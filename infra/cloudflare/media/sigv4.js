/**
 * AWS Signature Version 4 for one S3 GetObject, with the runtime's own
 * WebCrypto (crypto.subtle) -- no SDK, nothing to bundle. The bucket is
 * private (the backend has only ever handed out presigned links), so the
 * Worker signs its own reads with a key that can read the public folders and
 * nothing else (README.md).
 *
 * Header signing, the empty payload's hash in x-amz-content-sha256:
 * https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
 * test/worker.test.js checks it against AWS's own worked example.
 */

const enc = new TextEncoder();

/** sha256("") -- a GET has no body. */
export const EMPTY_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

async function sha256Hex(text) {
  return hex(await crypto.subtle.digest("SHA-256", enc.encode(text)));
}

async function hmac(key, text) {
  const k = await crypto.subtle.importKey("raw", typeof key === "string" ? enc.encode(key) : key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return crypto.subtle.sign("HMAC", k, enc.encode(text));
}

/** RFC 3986 encoding of one path segment, as S3 expects: only A-Z a-z 0-9 - _ . ~ stay. */
export function encodeSegment(segment) {
  return encodeURIComponent(segment).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

/** The key as a URL path: each segment encoded, the slashes kept (S3 does not normalise them). */
export function encodeKey(key) {
  return key.split("/").map(encodeSegment).join("/");
}

/** 20130524T000000Z */
export function amzDate(now) {
  return now.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

/**
 * The Authorization header for a request.
 *
 *   method, host, path    path already encoded (encodeKey), starting with "/"
 *   headers               lower-case name → value; must hold x-amz-date and
 *                         x-amz-content-sha256; `host` is added
 *   region, accessKeyId, secretAccessKey
 */
export async function authorization({ method, host, path, headers, region, accessKeyId, secretAccessKey, service = "s3" }) {
  const all = { ...headers, host };
  const names = Object.keys(all).map((n) => n.toLowerCase()).sort();
  const lower = Object.fromEntries(Object.entries(all).map(([k, v]) => [k.toLowerCase(), String(v).trim().replace(/\s+/g, " ")]));
  const signedHeaders = names.join(";");
  const canonical = [
    method,
    path,
    "", // no query
    names.map((n) => `${n}:${lower[n]}\n`).join(""),
    signedHeaders,
    lower["x-amz-content-sha256"],
  ].join("\n");
  const stamp = lower["x-amz-date"];
  const day = stamp.slice(0, 8);
  const scope = `${day}/${region}/${service}/aws4_request`;
  const toSign = ["AWS4-HMAC-SHA256", stamp, scope, await sha256Hex(canonical)].join("\n");
  let key = await hmac(`AWS4${secretAccessKey}`, day);
  key = await hmac(key, region);
  key = await hmac(key, service);
  key = await hmac(key, "aws4_request");
  const signature = hex(await hmac(key, toSign));
  return `AWS4-HMAC-SHA256 Credential=${accessKeyId}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;
}

/**
 * A signed GetObject for `key`: {url, headers}. Virtual-hosted addressing
 * (`{bucket}.s3.{region}.amazonaws.com/{key}`), or path style for a bucket
 * whose name has a dot, which the wildcard certificate does not cover.
 */
export async function getObject({ bucket, region, key, accessKeyId, secretAccessKey, now = new Date() }) {
  const dotted = bucket.includes(".");
  const host = dotted ? `s3.${region}.amazonaws.com` : `${bucket}.s3.${region}.amazonaws.com`;
  const path = `${dotted ? `/${encodeSegment(bucket)}` : ""}/${encodeKey(key)}`;
  const headers = { "x-amz-content-sha256": EMPTY_SHA256, "x-amz-date": amzDate(now) };
  headers.authorization = await authorization({ method: "GET", host, path, headers, region, accessKeyId, secretAccessKey });
  return { url: `https://${host}${path}`, headers };
}
