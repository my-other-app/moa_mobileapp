// The media Worker, run under Node (18+) with S3 (`fetch`), the edge cache
// (`caches.default`) and the rate limiter stubbed:
//   node --test infra/cloudflare/media/test/*.test.js   (or `npm test` in infra/cloudflare/media)
import assert from "node:assert/strict";
import { beforeEach, describe, test } from "node:test";

import { IMMUTABLE, LEGACY, MISSING, PUBLIC_FOLDERS, notModified, objectKey, pictureAt } from "../media.js";
import { EMPTY_SHA256, authorization, getObject } from "../sigv4.js";
import worker from "../worker.js";

const HOST = "https://media.myotherapp.in";
const HEX = "0123456789abcdef0123456789abcdef";
const LEGACY_NAME = "0b6f2d6e-4a51-4b0e-9a2b-1f7c4b9d2e11";
const S3 = "https://moa-media.s3.us-east-1.amazonaws.com/";
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3, 4]);

/** The edge cache, by URL, honouring nothing but presence (and checking what is put). */
class FakeCache {
  constructor() {
    this.store = new Map();
  }
  async match(request) {
    const hit = this.store.get(typeof request === "string" ? request : request.url);
    return hit ? hit.clone() : undefined;
  }
  async put(request, response) {
    assert.equal(request.method, "GET");
    assert.equal(new URL(request.url).search, "", "a query never reaches the cache key");
    assert.match(response.headers.get("cache-control"), /max-age=\d+/);
    assert.ok(!response.headers.has("set-cookie"));
    this.store.set(request.url, response.clone());
  }
}

/** The Workers rate limiter: `limit` calls per key, then refusals. */
class FakeLimiter {
  constructor(limit) {
    this.limit_ = limit;
    this.seen = new Map();
  }
  async limit({ key }) {
    const n = (this.seen.get(key) || 0) + 1;
    this.seen.set(key, n);
    return { success: n <= this.limit_ };
  }
}

let objects; // S3 key -> {body, etag, modified, type} | "denied" | "badsig" | "down" | status number
let calls; // every request that reached S3: {url, headers}
let ctx;
let env;

beforeEach(() => {
  objects = {
    [`clubs/logos/v-${HEX}.png`]: { body: PNG, etag: '"9b2cf535f27731c974343645a3985328"', modified: "Sat, 17 Oct 2026 10:00:00 GMT", type: "image/png" },
    [`clubs/logos/v-${HEX}.thumbnail.png`]: { body: PNG, etag: '"aa"', modified: "Sat, 17 Oct 2026 10:00:00 GMT", type: "image/png" },
    [`clubs/covers/${LEGACY_NAME}.jpg`]: { body: PNG, etag: '"bb"', modified: "Mon, 03 Mar 2025 08:00:00 GMT", type: "binary/octet-stream" },
    [`events/42/merch/v-${HEX}.webp`]: { body: PNG, etag: '"cc"', modified: "Sat, 17 Oct 2026 10:00:00 GMT", type: "image/webp" },
  };
  calls = [];
  ctx = { pending: [], waitUntil(p) { this.pending.push(p); } };
  env = { S3_BUCKET: "moa-media", S3_REGION: "us-east-1", S3_BASE_PATH: "", S3_ACCESS_KEY_ID: "AKIDMEDIA", S3_SECRET_ACCESS_KEY: "secret" };
  globalThis.caches = { default: new FakeCache() };
  globalThis.fetch = async (input, init = {}) => {
    const url = typeof input === "string" ? input : input.url;
    const headers = Object.fromEntries(new Headers(init.headers || (typeof input === "string" ? {} : input.headers)).entries());
    calls.push({ url, headers, method: init.method || "GET" });
    assert.ok(url.startsWith(S3) || url.startsWith("https://s3.us-east-1.amazonaws.com/"), `only S3 is ever asked: ${url}`);
    const key = decodeURIComponent(new URL(url).pathname.slice(1).replace(/^moa\.media\//, ""));
    const found = objects[key];
    if (found === "down") throw new TypeError("fetch failed");
    if (found === "denied" || found === undefined) {
      // What S3 says about a key that is not there, to a reader without ListBucket.
      return new Response("<Error><Code>AccessDenied</Code><Message>Access Denied</Message></Error>", { status: 403 });
    }
    if (found === "missing") return new Response("<Error><Code>NoSuchKey</Code></Error>", { status: 404 });
    if (found === "badsig") return new Response("<Error><Code>SignatureDoesNotMatch</Code></Error>", { status: 403 });
    if (typeof found === "number") return new Response("<Error/>", { status: found });
    return new Response(found.body, {
      status: 200,
      headers: { etag: found.etag, "last-modified": found.modified, "content-type": found.type, "content-length": String(found.body.length), "x-amz-request-id": "R1" },
    });
  };
});

const get = (path, init = {}) => worker.fetch(new Request(HOST + path, init), env, ctx);
const settle = () => Promise.all(ctx.pending);

describe("which paths are pictures", () => {
  test("one file in a public folder, with an image extension", () => {
    assert.deepEqual(pictureAt(`/clubs/logos/v-${HEX}.png`), { path: `clubs/logos/v-${HEX}.png`, versioned: true, contentType: "image/png" });
    assert.deepEqual(pictureAt(`/clubs/logos/v-${HEX}.thumbnail.png`), { path: `clubs/logos/v-${HEX}.thumbnail.png`, versioned: true, contentType: "image/png" });
    assert.equal(pictureAt(`/clubs/covers/${LEGACY_NAME}.medium.jpg`).versioned, false);
    assert.equal(pictureAt(`/events/42/merch/${HEX}.jpeg`).contentType, "image/jpeg");
    for (const folder of PUBLIC_FOLDERS) {
      const path = `/${folder.replace("{id}", "7")}v-${HEX}.gif`;
      assert.ok(pictureAt(path), path);
    }
  });

  test("the same folders as the backend's app/core/storage/media.py PUBLIC_FOLDERS", () => {
    assert.deepEqual(PUBLIC_FOLDERS, [
      "clubs/logos/", "clubs/covers/", "clubs/team/", "clubs/partners/", "clubs/threads/", "events/speakers/", "avatars/", "events/{id}/merch/",
    ]);
  });

  test("anything private or odd is not a picture", () => {
    for (const path of [
      "/", "", "/robots", "/clubs/logos/", "/clubs/logos",
      `/docs/ticket/1b2c/3-${HEX.slice(0, 24)}.pdf`, `/docs/certificate/1b2c/0-${HEX.slice(0, 24)}.png`,
      `/templates/certificates/signatures/v-${HEX}.png`, `/templates/tickets/backgrounds/${LEGACY_NAME}.png`,
      `/events/7/layout/template-${HEX}.png`, `/events/7/layout/speaker-${HEX}.png`, `/clubs/3/layout/image-${HEX}.png`,
      `/clubs/3/email/email-${HEX}.png`, `/events/7/closeout/${HEX}.pdf`, `/events/files/${LEGACY_NAME}.png`,
      `/users/profile_pic/v-${HEX}.png`, `/organizations/logos/v-${HEX}.png`,
      `/clubs/logos/../../docs/ticket/1/0-a.png`, `/clubs/logos/%2e%2e/%2e%2e/docs/a.png`, `/clubs/logos%2fv-${HEX}.png`,
      `/clubs/logos/nested/v-${HEX}.png`, `/clubs/logos/v-${HEX}.svg`, `/clubs/logos/v-${HEX}.html`, `/clubs/logos/v-${HEX}.PNG`,
      `/clubs/logos/v-${HEX}.png.pdf`, `/Clubs/logos/v-${HEX}.png`, `/events/seven/merch/v-${HEX}.png`, `/events/7/merch/x/v-${HEX}.png`,
      `/clubs/logos/.hidden.png`, `/clubs/logos/%E0%A4%A.png`, `//clubs/logos/v-${HEX}.png`,
    ]) {
      assert.equal(pictureAt(path), null, path);
    }
  });

  test("the key is under the bucket's base path", () => {
    assert.equal(objectKey("clubs/logos/a.png", ""), "clubs/logos/a.png");
    assert.equal(objectKey("clubs/logos/a.png", "media/"), "media/clubs/logos/a.png");
    assert.equal(objectKey("clubs/logos/a.png", undefined), "clubs/logos/a.png");
  });
});

describe("signing", () => {
  test("AWS's own worked example (GetObject with a Range header)", async () => {
    const auth = await authorization({
      method: "GET", host: "examplebucket.s3.amazonaws.com", path: "/test.txt",
      headers: { range: "bytes=0-9", "x-amz-content-sha256": EMPTY_SHA256, "x-amz-date": "20130524T000000Z" },
      region: "us-east-1", accessKeyId: "AKIAIOSFODNN7EXAMPLE", secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    });
    assert.equal(auth, "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41");
  });

  test("the same signature botocore makes, virtual-hosted and path style", async () => {
    // From botocore's S3SigV4Auth with the same key, time and object.
    const at = new Date(Date.UTC(2026, 9, 18, 9, 30, 0));
    const key = `media/clubs/logos/v-${HEX}.thumbnail.png`;
    const creds = { accessKeyId: "AKIDMEDIAREADONLY", secretAccessKey: "s3cr3t/Key+For/Media" };
    let r = await getObject({ bucket: "moa-media", region: "us-east-1", key, now: at, ...creds });
    assert.equal(r.url, `https://moa-media.s3.us-east-1.amazonaws.com/${key}`);
    assert.equal(r.headers["x-amz-date"], "20261018T093000Z");
    assert.match(r.headers.authorization, /Signature=e0b05b32f4a8ea814afa77765c21645f6744a0b293520c3c1c11b9c71be6e69e$/);
    r = await getObject({ bucket: "moa.media", region: "us-east-1", key, now: at, ...creds });
    assert.equal(r.url, `https://s3.us-east-1.amazonaws.com/moa.media/${key}`);
    assert.match(r.headers.authorization, /Signature=20e0f35d8f10773647c17594decf3d7d5d50a4004cb4a1d959c17b83c28e7185$/);
  });
});

describe("a picture", () => {
  test("a versioned key: from S3 once, signed, then from the cache, kept a year as immutable", async () => {
    let r = await get(`/clubs/logos/v-${HEX}.png`);
    assert.equal(r.status, 200);
    assert.deepEqual(new Uint8Array(await r.arrayBuffer()), PNG);
    assert.equal(r.headers.get("content-type"), "image/png");
    assert.equal(r.headers.get("cache-control"), IMMUTABLE);
    assert.equal(r.headers.get("etag"), '"9b2cf535f27731c974343645a3985328"');
    assert.equal(r.headers.get("last-modified"), "Sat, 17 Oct 2026 10:00:00 GMT");
    assert.equal(r.headers.get("access-control-allow-origin"), "*");
    assert.equal(r.headers.get("x-content-type-options"), "nosniff");
    assert.equal(r.headers.get("x-cache"), "MISS");
    assert.ok(!r.headers.has("x-amz-request-id"), "S3's own headers stay behind");
    assert.equal(calls.length, 1);
    assert.equal(calls[0].url, `${S3}clubs/logos/v-${HEX}.png`);
    assert.match(calls[0].headers.authorization, /^AWS4-HMAC-SHA256 Credential=AKIDMEDIA\/\d{8}\/us-east-1\/s3\/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=[0-9a-f]{64}$/);
    assert.equal(calls[0].headers["x-amz-content-sha256"], EMPTY_SHA256);

    await settle();
    r = await get(`/clubs/logos/v-${HEX}.png`);
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("x-cache"), "HIT");
    assert.deepEqual(new Uint8Array(await r.arrayBuffer()), PNG);
    assert.equal(calls.length, 1, "the second view never reaches S3");
  });

  test("a key from before versioning: an hour in the browser, a day at the edge, its type from the extension", async () => {
    const r = await get(`/clubs/covers/${LEGACY_NAME}.jpg`);
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("cache-control"), LEGACY);
    assert.equal(r.headers.get("content-type"), "image/jpeg", "S3's binary/octet-stream is not believed");
    const merch = await get(`/events/42/merch/v-${HEX}.webp`);
    assert.equal(merch.headers.get("content-type"), "image/webp");
    assert.equal(merch.headers.get("cache-control"), IMMUTABLE);
  });

  test("a query string is not part of the picture: one copy, one S3 read", async () => {
    await get(`/clubs/logos/v-${HEX}.png?v=1`);
    await settle();
    const r = await get(`/clubs/logos/v-${HEX}.png?cachebust=${Math.random()}`);
    assert.equal(r.headers.get("x-cache"), "HIT");
    assert.equal(calls.length, 1);
    assert.deepEqual([...globalThis.caches.default.store.keys()], [`${HOST}/clubs/logos/v-${HEX}.png`]);
  });

  test("HEAD: the headers, no body, and the cache warmed", async () => {
    const r = await get(`/clubs/logos/v-${HEX}.thumbnail.png`, { method: "HEAD" });
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("content-type"), "image/png");
    assert.equal(r.headers.get("etag"), '"aa"');
    assert.equal((await r.arrayBuffer()).byteLength, 0);
    await settle();
    assert.equal((await get(`/clubs/logos/v-${HEX}.thumbnail.png`)).headers.get("x-cache"), "HIT");
    assert.equal(calls.length, 1);
  });

  test("under the bucket's base path", async () => {
    env.S3_BASE_PATH = "media/";
    objects[`media/clubs/logos/v-${HEX}.png`] = objects[`clubs/logos/v-${HEX}.png`];
    const r = await get(`/clubs/logos/v-${HEX}.png`);
    assert.equal(r.status, 200);
    assert.equal(calls[0].url, `${S3}media/clubs/logos/v-${HEX}.png`);
  });
});

describe("conditional requests", () => {
  const etag = '"9b2cf535f27731c974343645a3985328"';

  test("If-None-Match: 304 with the validators and the caching rule, no body -- on a miss and on a hit", async () => {
    for (const how of ["MISS", "HIT"]) {
      const r = await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-none-match": etag } });
      assert.equal(r.status, 304, how);
      assert.equal(r.headers.get("etag"), etag);
      assert.equal(r.headers.get("cache-control"), IMMUTABLE);
      assert.equal(r.headers.get("x-cache"), how);
      assert.equal(await r.text(), "");
      await settle();
    }
    assert.equal(calls.length, 1);
  });

  test("a weak tag, a list and * match; another tag does not", async () => {
    assert.equal((await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-none-match": `W/${etag}` } })).status, 304);
    assert.equal((await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-none-match": `"zz", ${etag}` } })).status, 304);
    assert.equal((await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-none-match": "*" } })).status, 304);
    assert.equal((await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-none-match": '"zz"' } })).status, 200);
  });

  test("If-Modified-Since, unless If-None-Match is sent", async () => {
    assert.equal((await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-modified-since": "Sun, 18 Oct 2026 00:00:00 GMT" } })).status, 304);
    assert.equal((await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-modified-since": "Fri, 16 Oct 2026 00:00:00 GMT" } })).status, 200);
    assert.equal((await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-modified-since": "nonsense" } })).status, 200);
    const both = await get(`/clubs/logos/v-${HEX}.png`, { headers: { "if-modified-since": "Sun, 18 Oct 2026 00:00:00 GMT", "if-none-match": '"zz"' } });
    assert.equal(both.status, 200);
  });

  test("notModified on its own", () => {
    const h = (o) => new Headers(o);
    assert.equal(notModified(h({}), '"a"', "Sat, 17 Oct 2026 10:00:00 GMT"), false);
    assert.equal(notModified(h({ "if-none-match": '"a"' }), null, null), false);
    assert.equal(notModified(h({ "if-none-match": '"a"' }), 'W/"a"', null), true);
  });
});

describe("what is not served", () => {
  test("private and odd paths: 404, and S3 is never asked", async () => {
    for (const path of [
      `/docs/ticket/1b2c/3-${HEX.slice(0, 24)}.pdf`, `/templates/certificates/signatures/v-${HEX}.png`, `/events/7/layout/template-${HEX}.png`,
      `/clubs/3/email/email-${HEX}.png`, `/events/7/closeout/${HEX}.pdf`, `/users/profile_pic/v-${HEX}.png`, `/clubs/logos/%2e%2e/%2e%2e/docs/a.png`,
      `/clubs/logos/v-${HEX}.svg`, "/", "/favicon.ico",
    ]) {
      const r = await get(path);
      assert.equal(r.status, 404, path);
      assert.equal(r.headers.get("cache-control"), MISSING);
      const head = await get(path, { method: "HEAD" });
      assert.equal(head.status, 404, path);
      assert.equal(await head.text(), "");
    }
    assert.equal(calls.length, 0);
  });

  test("only GET and HEAD", async () => {
    for (const method of ["POST", "PUT", "DELETE", "PATCH", "OPTIONS"]) {
      const r = await get(`/clubs/logos/v-${HEX}.png`, { method });
      assert.equal(r.status, 405, method);
      assert.equal(r.headers.get("allow"), "GET, HEAD");
    }
    assert.equal(calls.length, 0);
  });

  test("robots.txt welcomes image search", async () => {
    const r = await get("/robots.txt");
    assert.equal(r.status, 200);
    assert.match(await r.text(), /Allow: \//);
    assert.equal(calls.length, 0);
  });
});

describe("when S3 says no", () => {
  test("no such key (404, or AccessDenied without ListBucket): a 404 kept a minute", async () => {
    objects[`clubs/team/v-${HEX}.png`] = "missing";
    for (const path of [`/clubs/team/v-${HEX}.png`, `/clubs/partners/v-${HEX}.png`]) {
      const r = await get(path);
      assert.equal(r.status, 404, path);
      assert.equal(r.headers.get("cache-control"), MISSING);
      await settle();
      assert.equal((await get(path)).status, 404);
    }
    assert.equal(calls.length, 2, "each missing key asked of S3 once");
  });

  test("our signature or key refused, S3 failing or unreachable: 502, never kept", async () => {
    for (const answer of ["badsig", 500, 503, "down"]) {
      objects[`clubs/logos/v-${HEX}.png`] = answer;
      globalThis.caches = { default: new FakeCache() };
      const r = await get(`/clubs/logos/v-${HEX}.png`);
      assert.equal(r.status, 502, String(answer));
      assert.equal(r.headers.get("cache-control"), "no-store");
      await settle();
      assert.equal(globalThis.caches.default.store.size, 0, String(answer));
    }
  });

  test("not configured: 503, nothing asked, nothing kept", async () => {
    delete env.S3_SECRET_ACCESS_KEY;
    const r = await get(`/clubs/logos/v-${HEX}.png`);
    assert.equal(r.status, 503);
    assert.equal(r.headers.get("cache-control"), "no-store");
    assert.equal(calls.length, 0);
  });
});

describe("the miss limit", () => {
  test("counts only what reaches S3, per address", async () => {
    env.MISS_LIMITER = new FakeLimiter(2);
    const from = (ip) => ({ headers: { "cf-connecting-ip": ip } });
    assert.equal((await get(`/clubs/logos/v-${HEX}.png`, from("203.0.113.9"))).status, 200);
    await settle();
    // Hits are free, however many.
    for (let i = 0; i < 5; i++) assert.equal((await get(`/clubs/logos/v-${HEX}.png`, from("203.0.113.9"))).status, 200);
    assert.equal((await get(`/clubs/logos/v-${HEX}.thumbnail.png`, from("203.0.113.9"))).status, 200);
    const refused = await get(`/clubs/covers/${LEGACY_NAME}.jpg`, from("203.0.113.9"));
    assert.equal(refused.status, 429);
    assert.equal(refused.headers.get("retry-after"), "60");
    assert.equal(refused.headers.get("cache-control"), "no-store");
    // Someone else is not held to that address's count.
    assert.equal((await get(`/clubs/covers/${LEGACY_NAME}.jpg`, from("198.51.100.4"))).status, 200);
    assert.equal(calls.length, 3);
  });

  test("without the binding (wrangler dev, a test) nothing is limited", async () => {
    for (let i = 0; i < 3; i++) {
      globalThis.caches = { default: new FakeCache() };
      assert.equal((await get(`/clubs/logos/v-${HEX}.png`)).status, 200);
    }
  });
});
