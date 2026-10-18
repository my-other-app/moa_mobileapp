/**
 * Which kind of request this is, from its host alone. Pure, so it can be
 * tested without a Worker runtime (test/worker.test.js).
 *
 *   own       myotherapp.in itself, or one of our reserved names (www, api,
 *             club, admin, events...): passed straight through to its origin,
 *             never touched. They are DNS-only today, so they never get here.
 *   fallback  sites.myotherapp.in, the fallback origin clubs' own domains
 *             CNAME to. Opened directly, it is no club's site.
 *   club      {name}.myotherapp.in: a club's site at its subdomain.
 *   custom    any other host: a club's own domain (a Cloudflare for SaaS
 *             custom hostname), resolved through the API.
 *   invalid   a deeper name under the zone (a.b.myotherapp.in), or junk.
 */

export const ZONE = "myotherapp.in";
export const FALLBACK = "sites";

// Names that are ours, not a club's. If one of them is ever proxied through
// Cloudflare, it passes straight through to its origin instead of being taken.
export const RESERVED = new Set([
  "www", "api", "admin", "admin-next", "club", "clubs", "clubs-next", "event", "events", "r",
  "mail", "email", "send", "rsend", "smtp", "imap", "pop", "mx", "app", "apps", "staging",
  "api-staging", "dev", "status", "help", "support", "docs", "blog", "static", "cdn", "assets",
  "m", "go", "link", "links", "auth", "login", "account", "accounts", "dashboard",
]);

// One DNS label: letters, digits, inner hyphens. A dot means a deeper name, which is never a club.
export const LABEL = /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/;

// A whole host name, in the punycode form URL parsing gives.
const HOST = /^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,61}[a-z0-9]$/;

export function classify(hostname) {
  const host = String(hostname || "").toLowerCase().replace(/\.$/, "");
  if (host === ZONE) return { kind: "own", host };
  if (host.endsWith(`.${ZONE}`)) {
    const name = host.slice(0, -(ZONE.length + 1));
    if (RESERVED.has(name)) return { kind: "own", host };
    if (name === FALLBACK) return { kind: "fallback", host };
    if (!LABEL.test(name)) return { kind: "invalid", host };
    return { kind: "club", host, name };
  }
  if (!isHost(host)) return { kind: "invalid", host };
  return { kind: "custom", host };
}

export function isHost(value) {
  return typeof value === "string" && HOST.test(value);
}

/** The resolver's answer, checked: {club_slug, status, canonical_host}, or null if it is not one. */
export function readResolved(data) {
  if (!data || typeof data !== "object") return null;
  const { club_slug: slug, status, canonical_host: canonical } = data;
  if (typeof slug !== "string" || !slug || slug.length > 200 || /[/?#\s]/.test(slug)) return null;
  if (status !== "active" && status !== "paused") return null;
  if (!isHost(canonical)) return null;
  return { slug, status, canonical };
}

/** The same path and query on another host. */
export function sameUrlOn(host, url) {
  return `https://${host}${url.pathname}${url.search}`;
}
