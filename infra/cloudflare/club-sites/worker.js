/**
 * Club websites at {name}.myotherapp.in, and at a club's own domain.
 *
 * DNS has a proxied wildcard (*.myotherapp.in, AAAA 100::) and this Worker is
 * routed on *.myotherapp.in/*. Named records (api, events, www, clubs-next,
 * admin-next, mail...) are DNS-only, so their traffic never reaches Cloudflare's
 * proxy or this Worker; only names that exist nowhere else arrive here.
 *
 * A club's own domain (www.theirclub.org) is a Cloudflare for SaaS custom
 * hostname: the club CNAMEs it to sites.myotherapp.in (the fallback origin)
 * and a catch-all Worker route brings its traffic here (CUSTOM_DOMAINS.md).
 * Whose site it is comes from the API's GET /api/v1/sites/resolve?host=,
 * kept in the edge cache for five minutes:
 *
 *   - active: the club's site, exactly as at its subdomain;
 *   - paused (the club's plan no longer includes its own domain): 302 to
 *     https://{slug}.myotherapp.in, same path and query;
 *   - unknown: the "No club site here" page.
 *
 * A club's subdomain whose club has an active domain of its own answers 301
 * to that domain, same path and query. If the API cannot be asked, the
 * subdomain is served as before; a custom domain gets "Back in a moment".
 *
 * The page is the one the club published from its dashboard: the backend
 * stores it as a single HTML file and serves it at /api/v1/sites/{name}.
 * This Worker only fetches it and hands it out at the club's own address,
 * with a cache and a strict Content-Security-Policy. The page counts its own
 * visits (it is the whole tab here) and its buttons open the events site.
 *
 * The zone's Email Obfuscation is OFF (2026-10-16): it rewrote the club's
 * contact address into a link needing Cloudflare's decoder script, which the
 * CSP below refuses, and it ignores <!--email_off--> on Worker responses.
 */

import { ZONE, classify, readResolved, sameUrlOn } from "./routing.js";

const API = "https://api.myotherapp.in";
const EVENTS = "https://events.myotherapp.in";
// The resolver's answers live in the edge cache under keys on our own zone.
const RESOLVE_CACHE = `https://sites.${ZONE}/__resolve/`;
const RESOLVE_TTL = 300;
const UNKNOWN_TTL = 60;
const UNREACHABLE = Symbol("unreachable");

const CSP = [
  "default-src 'none'",
  "script-src 'unsafe-inline'",
  "style-src 'unsafe-inline' https://fonts.googleapis.com",
  "font-src https://fonts.gstatic.com",
  "img-src https: data:",
  `connect-src ${API}`,
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
].join("; ");

function esc(value) {
  return String(value).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

function page(status, title, body) {
  const html =
    `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="robots" content="noindex"><title>${title}</title><style>` +
    `body{margin:0;min-height:100vh;display:grid;place-items:center;font:16px/1.5 system-ui,-apple-system,Segoe UI,sans-serif;background:#f3f4f1;color:#141614}` +
    `@media(prefers-color-scheme:dark){body{background:#0b0e0d;color:#e9ece9}a{color:#4cc8ae}}` +
    `main{max-width:440px;padding:24px}h1{font-size:22px;margin:0 0 8px}p{margin:0 0 16px;color:#6b716c}a{color:#17a58f;font-weight:600}` +
    `</style></head><body><main>${body}</main></body></html>`;
  return new Response(html, {
    status,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=60", "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'" },
  });
}

/** `host` is the address shown (`circuit.myotherapp.in`, `www.theirclub.org`); null for "this address". */
function notFound(host) {
  const what = host ? esc(host) : "this address";
  return page(
    404,
    "No club site here",
    `<h1>No club site at ${what}</h1><p>The club may not have published its website yet, or the address has changed.</p>` +
      `<a href="${EVENTS}">Find events on MyOtherApp →</a>`,
  );
}

function unavailable() {
  return page(503, "Back in a moment", `<h1>Back in a moment</h1><p>This club's site could not be loaded just now. Try again shortly.</p>`);
}

function redirect(location, status) {
  return new Response(null, { status, headers: { location, "cache-control": status === 301 ? "public, max-age=300" : "no-store" } });
}

/**
 * Whose site `host` is: {slug, status, canonical}, null when the API does not
 * know it, or UNREACHABLE. Answers, "unknown" included, are kept in the edge
 * cache (the Cache API) so the API sees one question per host per five minutes.
 */
async function resolve(host, ctx) {
  const key = new Request(RESOLVE_CACHE + encodeURIComponent(host), { method: "GET" });
  const cache = typeof caches !== "undefined" ? caches.default : null;
  let answer = cache ? await cache.match(key) : undefined;
  if (!answer) {
    let upstream;
    try {
      upstream = await fetch(`${API}/api/v1/sites/resolve?host=${encodeURIComponent(host)}`, { headers: { accept: "application/json" } });
    } catch {
      return UNREACHABLE;
    }
    if (upstream.status !== 200 && upstream.status !== 404) return UNREACHABLE;
    const ttl = upstream.status === 200 ? RESOLVE_TTL : UNKNOWN_TTL;
    answer = new Response(await upstream.text(), {
      status: upstream.status,
      headers: { "content-type": "application/json", "cache-control": `public, max-age=${ttl}` },
    });
    if (cache) {
      const stored = cache.put(key, answer.clone());
      if (ctx && typeof ctx.waitUntil === "function") ctx.waitUntil(stored);
      else await stored;
    }
  }
  if (answer.status === 404) return null;
  try {
    return readResolved(await answer.json()) || UNREACHABLE;
  } catch {
    return UNREACHABLE;
  }
}

/** The club's published page, served at `host` (its subdomain or its own domain). */
async function serveSite(request, url, slug, host) {
  if (url.pathname === "/robots.txt") {
    return new Response("User-agent: *\nAllow: /\n", { headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "public, max-age=3600" } });
  }
  // The site is one page; any other path lands on it, keeping the query (ref, utm tags).
  if (url.pathname !== "/") return Response.redirect(`https://${host}/${url.search}`, 302);

  let upstream;
  try {
    upstream = await fetch(`${API}/api/v1/sites/${encodeURIComponent(slug)}`, {
      headers: { accept: "text/html" },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
  } catch {
    upstream = null;
  }
  if (upstream && upstream.status === 404) return notFound(host);
  if (!upstream || !upstream.ok) return unavailable();
  return new Response(request.method === "HEAD" ? null : upstream.body, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=300",
      "content-security-policy": CSP,
      "x-content-type-options": "nosniff",
      "referrer-policy": "strict-origin-when-cross-origin",
    },
  });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const target = classify(url.hostname);

    // Ours (the apex, www, api, the dashboards...): passed straight through, never served from here.
    if (target.kind === "own") return fetch(request);
    if (target.kind === "fallback" || target.kind === "invalid") return notFound(null);
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", { status: 405, headers: { allow: "GET, HEAD" } });
    }

    if (target.kind === "club") {
      // A club with an active domain of its own is seen there. If the API
      // cannot be asked, the subdomain is served as it always was.
      const found = await resolve(target.host, ctx);
      if (found && found !== UNREACHABLE && found.status === "active" && found.canonical !== target.host) {
        return redirect(sameUrlOn(found.canonical, url), 301);
      }
      return serveSite(request, url, target.name, target.host);
    }

    // A club's own domain.
    const found = await resolve(target.host, ctx);
    if (found === UNREACHABLE) return unavailable();
    if (!found) return notFound(target.host);
    if (found.status === "paused") {
      // Never a redirect to the same host: that would loop.
      return found.canonical === target.host ? notFound(target.host) : redirect(sameUrlOn(found.canonical, url), 302);
    }
    return serveSite(request, url, found.slug, target.host);
  },
};
