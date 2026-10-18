/**
 * What a media address may name, and how long it may be kept. Pure, so it
 * can be tested without a Worker runtime (test/worker.test.js).
 *
 * An address is https://media.myotherapp.in/<path>, and <path> is the
 * object's key under the bucket's base path. Only a picture in one of
 * PUBLIC_FOLDERS is ever served: one file, directly inside the folder, with
 * an image extension. Everything else -- tickets and certificates (docs/),
 * template art and signatures (templates/), designer uploads (layout/),
 * email pictures, event files, close-out reports, profile pictures -- is a
 * 404 here, and the key this Worker signs with cannot read it either
 * (README.md, the IAM policy).
 *
 * The same list lives in the backend (app/core/storage/media.py,
 * PUBLIC_FOLDERS): the backend only ever hands out addresses inside it.
 * Change both together.
 */

export const PUBLIC_FOLDERS = [
  "clubs/logos/", // club logos, and event posters (stored here since the start)
  "clubs/covers/",
  "clubs/team/",
  "clubs/partners/",
  "clubs/threads/", // a post's image
  "events/speakers/",
  "avatars/", // the stock avatars people pick from
  "events/{id}/merch/", // store and merch photos
];

/** Extension → Content-Type. Never SVG: a picture from our host must not carry a script. */
export const CONTENT_TYPES = {
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  webp: "image/webp",
  gif: "image/gif",
};

/** A versioned key (written once by the backend, never again): kept for a year, by browsers too. */
export const IMMUTABLE = "public, max-age=31536000, immutable";
/** A key from before versioning: an hour in the browser, a day at the edge. */
export const LEGACY = "public, max-age=3600, s-maxage=86400";
/** No such picture: a minute, so a missing key is not asked of S3 on every view. */
export const MISSING = "public, max-age=60";

const reEscape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const FOLDERS = PUBLIC_FOLDERS.map((f) => reEscape(f.replace(/\/$/, "")).replace(reEscape("{id}"), "[0-9]{1,12}")).join("|");
const EXTS = Object.keys(CONTENT_TYPES).join("|");
// One file directly inside a public folder; the backend's pattern exactly.
const PUBLIC = new RegExp(`^(?:${FOLDERS})/[A-Za-z0-9][A-Za-z0-9_.-]{0,199}\\.(?:${EXTS})$`);
// `v-` and a uuid4's 32 hex digits, then the size (thumbnail, medium...) if it is one.
const VERSIONED = new RegExp(`^v-[0-9a-f]{32}(?:\\.[a-z0-9_]{1,24})?\\.(?:${EXTS})$`);

/**
 * The picture a URL path names: {path, versioned, contentType}, or null for
 * anything this Worker does not serve. `pathname` is as the URL holds it
 * (percent-encoded); a path that only decodes to a public one (%2e%2e, %2f)
 * is refused, as is anything that does not decode.
 */
export function pictureAt(pathname) {
  if (typeof pathname !== "string" || !pathname.startsWith("/") || pathname.length > 600) return null;
  let path;
  try {
    path = decodeURIComponent(pathname.slice(1));
  } catch {
    return null;
  }
  // Decoding must not have changed what the path says: no encoded slashes or dots.
  if (path !== pathname.slice(1)) return null;
  if (path.includes("..") || !PUBLIC.test(path)) return null;
  const name = path.slice(path.lastIndexOf("/") + 1);
  const ext = name.slice(name.lastIndexOf(".") + 1);
  return { path, versioned: VERSIONED.test(name), contentType: CONTENT_TYPES[ext] };
}

/** The S3 key for a picture's path: under the bucket's base path (the backend's APP_S3_BASE_PATH). */
export function objectKey(path, basePath = "") {
  const base = String(basePath || "").replace(/\/+$/, "");
  return base ? `${base}/${path}` : path;
}

export function cacheControl(picture) {
  return picture.versioned ? IMMUTABLE : LEGACY;
}

/** The entity tags an If-None-Match lists, without W/ (weak comparison, as for a GET). */
function tags(header) {
  return String(header || "")
    .split(",")
    .map((t) => t.trim().replace(/^W\//, ""))
    .filter(Boolean);
}

/**
 * Whether a conditional GET can be answered 304 from what we hold: the
 * entity tag first (RFC 9110: If-Modified-Since is ignored when
 * If-None-Match is sent), else the modification date.
 */
export function notModified(headers, etag, lastModified) {
  const inm = headers.get("if-none-match");
  if (inm) {
    if (!etag) return false;
    const mine = etag.replace(/^W\//, "");
    return tags(inm).some((t) => t === "*" || t === mine);
  }
  const ims = headers.get("if-modified-since");
  if (ims && lastModified) {
    const since = Date.parse(ims);
    const modified = Date.parse(lastModified);
    return !Number.isNaN(since) && !Number.isNaN(modified) && modified <= since;
  }
  return false;
}
