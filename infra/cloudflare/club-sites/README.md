# Club websites at `{name}.myotherapp.in`

A Cloudflare Worker that serves each club's published website at its own subdomain.

## How it fits together

- **DNS:** one proxied wildcard record, `*.myotherapp.in AAAA 100::`. The named records (`api`, `events`, `www`, `clubs-next`, `admin-next`, the mail records) are DNS-only, so their traffic never reaches Cloudflare's proxy or this Worker.
- **Route:** `*.myotherapp.in/*` → `club-sites`.
- **Page:** the backend stores each club's published site as one HTML page at `GET /api/v1/sites/{name}`. The Worker fetches it, caches it for 5 minutes, and serves it with a strict Content-Security-Policy.
- **Analytics:** on its own address the page counts its own visits (`POST /api/v1/sites/{name}/visit`), so nothing extra is needed here.
- **Unknown names** get a small "No club site here" page (404). Reserved names (`www`, `api`, `mail`, ...) pass straight through to their origin if they are ever proxied.

Auth cookies are host-only (no `Domain` attribute), so club subdomains never receive them.

## Deploy

```
./deploy.sh
```

The token needs **Account › Workers Scripts › Edit** and **Zone › Workers Routes › Edit**.

## Test locally

`worker.js` runs under Node 18+ with `fetch` stubbed; see the checks used before the first deploy in the PR that added it.
