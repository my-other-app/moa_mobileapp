# Club websites at `{name}.myotherapp.in`

A Cloudflare Worker that serves each club's published website at its own subdomain.

## How it fits together

- **DNS:** one proxied wildcard record, `*.myotherapp.in AAAA 100::`. The named records (`api`, `events`, `www`, `club-dashboard`, `main-portal`, the old `clubs-next` and `admin-next` that redirect to them, the mail records) are DNS-only, so their traffic never reaches Cloudflare's proxy or this Worker.
- **Route:** `*.myotherapp.in/*` → `club-sites`.
- **Page:** the backend stores each club's published site as one HTML page at `GET /api/v1/sites/{name}`. The Worker fetches it, caches it for 5 minutes, and serves it with a strict Content-Security-Policy.
- **Analytics:** on its own address the page counts its own visits (`POST /api/v1/sites/{name}/visit`), so nothing extra is needed here.
- **Unknown names** get a small "No club site here" page (404). Reserved names (`www`, `api`, `mail`, ...) pass straight through to their origin if they are ever proxied.
- **A club's own domain** (`www.theirclub.org`, Growth and up) is a Cloudflare for SaaS custom hostname that CNAMEs to `sites.myotherapp.in`. A `*/*` route brings it here, and `GET /api/v1/sites/resolve?host=` (edge-cached for 5 minutes) says whose site it is: active serves the site, paused redirects (302) to the club's subdomain, unknown gets the 404 page. A subdomain whose club has an active domain redirects (301) to it. The one-time setup, how to verify it and how to roll it back are in [CUSTOM_DOMAINS.md](CUSTOM_DOMAINS.md).
- **Code:** `worker.js` is the handler; `routing.js` is the pure part (which host is what, checking the resolver's answer). Both are uploaded as modules.

Auth cookies are host-only (no `Domain` attribute), so club subdomains never receive them.

## Deploy

```
./deploy.sh
```

The token needs **Account › Workers Scripts › Edit** and **Zone › Workers Routes › Edit**.

## Test locally

```
node --test test/*.test.js     # or: npm test
```

`test/worker.test.js` runs the Worker under Node 18+ with the API (`fetch`) and the edge cache (`caches.default`) stubbed: subdomains, clubs' own domains (active, paused, unknown, API down), our own hosts passing through.
