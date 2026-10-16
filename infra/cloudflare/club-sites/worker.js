/**
 * Club websites at {name}.myotherapp.in.
 *
 * DNS has a proxied wildcard (*.myotherapp.in, AAAA 100::) and this Worker is
 * routed on *.myotherapp.in/*. Named records (api, events, www, clubs-next,
 * admin-next, mail...) are DNS-only, so their traffic never reaches Cloudflare's
 * proxy or this Worker; only names that exist nowhere else arrive here.
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

const ZONE = "myotherapp.in";
const API = "https://api.myotherapp.in";
const EVENTS = "https://events.myotherapp.in";

// Names that are ours, not a club's. If one of them is ever proxied through
// Cloudflare, it passes straight through to its origin instead of being taken.
const RESERVED = new Set([
  "www", "api", "admin", "admin-next", "club", "clubs", "clubs-next", "event", "events", "r",
  "mail", "email", "send", "rsend", "smtp", "imap", "pop", "mx", "app", "apps", "staging",
  "api-staging", "dev", "status", "help", "support", "docs", "blog", "static", "cdn", "assets",
  "m", "go", "link", "links", "auth", "login", "account", "accounts", "dashboard",
]);

// One DNS label: letters, digits, inner hyphens. A dot means a deeper name, which is never a club.
const LABEL = /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/;

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

function notFound(name) {
  const what = name ? `${name}.${ZONE}` : "this address";
  return page(
    404,
    "No club site here",
    `<h1>No club site at ${what}</h1><p>The club may not have published its website yet, or the address has changed.</p>` +
      `<a href="${EVENTS}">Find events on MyOtherApp →</a>`,
  );
}

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const host = url.hostname.toLowerCase();
    if (!host.endsWith(`.${ZONE}`)) return notFound(null);
    const name = host.slice(0, -(ZONE.length + 1));

    if (RESERVED.has(name)) return fetch(request);
    if (!LABEL.test(name)) return notFound(null);
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", { status: 405, headers: { allow: "GET, HEAD" } });
    }
    if (url.pathname === "/robots.txt") {
      return new Response("User-agent: *\nAllow: /\n", { headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "public, max-age=3600" } });
    }
    // The site is one page; any other path lands on it, keeping the query (ref, utm tags).
    if (url.pathname !== "/") return Response.redirect(`https://${host}/${url.search}`, 302);

    let upstream;
    try {
      upstream = await fetch(`${API}/api/v1/sites/${encodeURIComponent(name)}`, {
        headers: { accept: "text/html" },
        cf: { cacheTtl: 300, cacheEverything: true },
      });
    } catch {
      upstream = null;
    }
    if (upstream && upstream.status === 404) return notFound(name);
    if (!upstream || !upstream.ok) {
      return page(503, "Back in a moment", `<h1>Back in a moment</h1><p>This club's site could not be loaded just now. Try again shortly.</p>`);
    }
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
  },
};
