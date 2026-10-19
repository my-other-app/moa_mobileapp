# Clubs' own domains (Cloudflare for SaaS)

A club on Growth or above connects a domain it owns, such as `www.theirclub.org`, to its website. This file is the one-time setup on the `myotherapp.in` zone. It is done by hand with the owner. Nothing in it has been done yet.

## How it works

1. The club types `www.theirclub.org` on the Website page. The backend creates a **custom hostname** for it on the `myotherapp.in` zone (`POST /zones/{zone}/custom_hostnames`, TXT validation), and shows three records to add at the club's DNS provider:

   | Type | Name | Value | Purpose |
   |---|---|---|---|
   | CNAME | `www.theirclub.org` | `sites.myotherapp.in` | Brings the traffic to us |
   | TXT | `_cf-custom-hostname.www.theirclub.org` | a UUID from Cloudflare | Proves the domain is theirs |
   | TXT | `_acme-challenge.www.theirclub.org` | a token from Cloudflare | Validates the certificate |

2. The backend checks Cloudflare every 5 minutes. When both the hostname and its certificate are `active`, the domain is active: the club gets an email, the admins get an alert, and the site is published again with the new address as its canonical URL.
3. Traffic for `www.theirclub.org` reaches the zone through the **fallback origin** `sites.myotherapp.in`. A **`*/*` Worker route** then sends it to `club-sites`. The Worker asks `GET https://api.myotherapp.in/api/v1/sites/resolve?host=www.theirclub.org` whose site it is, and caches the answer for 5 minutes:
   - **active**: the Worker serves the club's page.
   - **paused** (the plan no longer includes the feature): a 302 to `https://{slug}.myotherapp.in`.
   - **unknown**: the "No club site here" page.
4. `{slug}.myotherapp.in` for a club with an active domain answers 301 to that domain.

**A bare domain (`theirclub.org`) is not supported.** It cannot carry a CNAME at most registrars, and proxying an apex is Enterprise-only. The backend refuses it with `APEX_NOT_SUPPORTED` and tells the club to use `www.` and forward the bare domain to it at their registrar.

## What is there today

Checked on 2026-10-18 with read-only GETs, using the token in `~/.config/moa/cloudflare.authheader`.

- **Zone:** `myotherapp.in`, Free plan, active.
- **Proxied DNS records** (`dns_records?proxied=true`): exactly one.

  | Type | Name |
  |---|---|
  | AAAA | `*.myotherapp.in` |

- **DNS-only records** (A, AAAA, CNAME): these never reach Cloudflare's proxy, so no Worker route can touch them.

  | Type | Name |
  |---|---|
  | A | `myotherapp.in` |
  | A | `api.myotherapp.in` |
  | A | `api.staging.myotherapp.in` |
  | A | `main-portal.myotherapp.in` (admin; `admin-next` redirects here) |
  | A | `club-dashboard.myotherapp.in` (clubs; `clubs-next` redirects here) |
  | CNAME | `events.myotherapp.in` |
  | CNAME | `www.myotherapp.in` |
  | CNAME | `rsend.myotherapp.in` |

- **Worker routes:** one, `*.myotherapp.in/*` → `club-sites`.
- **Cloudflare for SaaS: not enabled.**
  - `GET /custom_hostnames/fallback_origin` answers error 1456: "Access to configure this resource has not been granted for this zone. This feature is available with SSL for SaaS."
  - `GET /custom_hostnames` answers error 1404: "No quota has been allocated for this zone".

## Setup, in order

Each step is safe on its own. Until step 5, no club can add a domain: the backend says "unavailable".

### 0. Deploy the code first

- **Backend:** run the deploy with `migrate=true`. The migration `club_domains` adds the table, renames `plan_features.domain` to `custom_domain`, and turns it on for Growth, Pro, Campus and Enterprise. Without the Cloudflare settings, the feature only reports itself as unavailable.
- **Worker:** run `./deploy.sh`. It now uploads `worker.js` and `routing.js`. The new Worker serves `{slug}.myotherapp.in` exactly as before. If the API is down, or does not know `/sites/resolve` yet, it serves the subdomain as it always did.

### 1. Enable Cloudflare for SaaS (owner, in the dashboard)

1. Open the `myotherapp.in` zone, then **SSL/TLS → Custom Hostnames**.
2. Select **Enable**.
3. Enter a payment method. The Free zone plan includes **100 custom hostnames**; each one after that costs **$0.10 a month**.

### 2. Add the fallback origin's DNS record

Under **DNS → Records**, select **Add record**:

| Type | Name | IPv6 address | Proxy status | TTL |
|---|---|---|---|---|
| AAAA | `sites` | `100::` | **Proxied** | Auto |

`100::` is the "originless" address Cloudflare documents for a Worker acting as the origin. Nothing behind it is ever contacted: the Worker answers every request.

The wildcard already covers `sites`, but the fallback origin needs a record of its own. An exact name wins over the wildcard, so nothing else changes.

### 3. Set the fallback origin

1. Go to **SSL/TLS → Custom Hostnames → Fallback Origin**.
2. Enter `sites.myotherapp.in` and select **Add Fallback Origin**.
3. Wait until its status is **Active**.

The same through the API (needs SSL and Certificates Edit):

```
curl -sS -H @$HOME/.config/moa/cloudflare.authheader -X PUT \
  "https://api.cloudflare.com/client/v4/zones/$(cat ~/.config/moa/cloudflare.zone)/custom_hostnames/fallback_origin" \
  -H "Content-Type: application/json" --data '{"origin":"sites.myotherapp.in"}'
```

### 4. Worker routes

Custom-hostname traffic only reaches a Worker through a route that matches its host. `*.myotherapp.in/*` does not match `www.theirclub.org`, so a catch-all route is needed.

Go to **Workers Routes → Add route**. The most specific pattern wins, so each "None" route below beats both `*/*` and `*.myotherapp.in/*`.

| Route | Worker | Why |
|---|---|---|
| `*/*` | `club-sites` | **New.** Clubs' own domains. |
| `*.myotherapp.in/*` | `club-sites` | **Keep.** Club subdomains (already there). |
| `myotherapp.in/*` | None | The portal (Vercel) |
| `www.myotherapp.in/*` | None | Redirects to the apex (Vercel) |
| `api.myotherapp.in/*` | None | The API |
| `api.staging.myotherapp.in/*` | None | Production under another name |
| `events.myotherapp.in/*` | None | Old event site name (Vercel) |
| `club-dashboard.myotherapp.in/*` | None | Clubs dashboard (Vercel) |
| `main-portal.myotherapp.in/*` | None | Admin dashboard (Vercel) |
| `rsend.myotherapp.in/*` | None | Resend's sending subdomain |
| `event.myotherapp.in/*` | None | Planned (phase 3) |
| `club.myotherapp.in/*` | None | Planned (phase 3) |
| `admin.myotherapp.in/*` | None | Planned (phase 3) |

**Which "None" routes are required today: none.** The only proxied record is the wildcard, and that traffic is meant for this Worker. Every other host is DNS-only and never reaches a route.

The "None" routes are cheap insurance:

- **One of these hosts is proxied later.** The plan is to proxy `api` once nginx trusts Cloudflare's client-IP header. Without a "None" route, every API request would run through `club-sites`. The Worker would pass it straight through, but it would spend the Workers free plan's 100,000 requests a day.
- **The Worker never serves club pages on these hosts.** It already passes them through, because they are in its reserved list.

Do not add a "None" route for:

- **`r.myotherapp.in`:** phase 4 gives it its own Worker route, which is more specific anyway.
- **`sites.myotherapp.in`:** the Worker answers it with a 404.

Through the API (needs Zone › Workers Routes › Edit, which the deploy token has):

```
Z=$(cat ~/.config/moa/cloudflare.zone)
curl -sS -H @$HOME/.config/moa/cloudflare.authheader -X POST "https://api.cloudflare.com/client/v4/zones/$Z/workers/routes" \
  -H "Content-Type: application/json" --data '{"pattern":"*/*","script":"club-sites"}'
for host in myotherapp.in www.myotherapp.in api.myotherapp.in api.staging.myotherapp.in events.myotherapp.in \
            club-dashboard.myotherapp.in main-portal.myotherapp.in rsend.myotherapp.in event.myotherapp.in \
            club.myotherapp.in admin.myotherapp.in; do
  curl -sS -H @$HOME/.config/moa/cloudflare.authheader -X POST "https://api.cloudflare.com/client/v4/zones/$Z/workers/routes" \
    -H "Content-Type: application/json" --data "{\"pattern\":\"$host/*\"}"
done
```

A route with no `script` is a "None" route.

### 5. The backend's token and settings

1. Create an API token under **My Profile → API Tokens → Create Token → Custom token**:
   - **Name:** `moa-backend-custom-hostnames`
   - **Permissions:** **Zone › SSL and Certificates › Edit**, and nothing else. It covers creating, reading, refreshing (PATCH), listing and deleting custom hostnames.
   - **Zone Resources:** Include › Specific zone › `myotherapp.in`.
   - **Client IP Address Filtering (recommended):** Is in › `44.208.217.219`, the API server.
   - **TTL:** none.
2. Add it to the server's `.env`:

   ```
   APP_CLOUDFLARE_API_TOKEN=<the token>
   APP_CLOUDFLARE_ZONE_ID=<the id in ~/.config/moa/cloudflare.zone>
   # Optional; this is the default:
   APP_SITES_CNAME_TARGET=sites.myotherapp.in
   ```

3. Apply it by rebuilding the backend: `sudo docker-compose -f docker-compose.prod.yml up -d --build backend`.
   - A plain `up -d` recreates the container from a stale image.
   - Never use the workflow's "Sync environment variables". It replaces the whole `.env` with the 2025-03 secret.

The domains sweep starts with the process and runs every 5 minutes, holding a Postgres advisory lock (773120) so only one worker runs it.

## Verify

Use a domain the owner controls, for example `www.<a test domain>`, and a test club on Growth.

1. **SaaS is on:**
   - `GET /zones/$Z/custom_hostnames/fallback_origin` shows `"origin":"sites.myotherapp.in","status":"active"`.
   - `GET /zones/$Z/workers/routes` lists `*/*` and `*.myotherapp.in/*` → `club-sites`, plus the "None" routes.
2. **Nothing else moved:** these answer exactly as before (same status and server headers, no `content-security-policy` from the Worker):
   - `curl -sI https://api.myotherapp.in/ping`
   - `curl -sI https://myotherapp.in/`
   - `curl -sI https://club-dashboard.myotherapp.in/`
   - `curl -sI https://main-portal.myotherapp.in/`
   - `curl -sI https://events.myotherapp.in/`
3. **Subdomains still work:** `curl -sI https://<slug>.myotherapp.in/` returns 200 with the Worker's `content-security-policy`.
4. **Connect:** on the club's Website page, add `www.<test domain>`.
   - It shows the CNAME and the two TXT records.
   - `GET /zones/$Z/custom_hostnames?hostname=www.<test domain>` shows it `pending`.
5. **Add the three records** at the test domain's DNS provider. Within minutes, **Check** (or the 5-minute sweep) turns it **active**:
   - the club gets "Your site is live at …";
   - the admin bell gets `club_domain_active`.
6. **Served:**
   - `curl -sI https://www.<test domain>/` returns 200, the Worker's CSP, and a valid certificate (`curl -v` shows it was issued for that name).
   - The page source has `<link rel="canonical" href="https://www.<test domain>">`.
   - `curl -sI https://<slug>.myotherapp.in/?ref=x` returns 301, with `location: https://www.<test domain>/?ref=x`.
7. **Paused:** move the test club to Starter in Admin → Subscriptions. Within 5 minutes plus the 5-minute edge cache, `curl -sI https://www.<test domain>/a?b=1` returns 302 to `https://<slug>.myotherapp.in/a?b=1`. Move it back and it serves again.
8. **Clean up:** remove the domain on the Website page, or with DELETE in Admin → Club domains. Then confirm `GET …/custom_hostnames?hostname=…` is empty.

## Roll back

Each step undoes on its own. Use the smallest one that is enough.

- **Stop serving clubs' own domains, keep everything else:**
  - delete the `*/*` route; subdomains keep working through `*.myotherapp.in/*`;
  - the "None" routes can stay; they change nothing.
- **Stop new domains:**
  - remove `APP_CLOUDFLARE_API_TOKEN` from `.env` and rebuild;
  - the feature says "unavailable", and the sweep stops polling Cloudflare;
  - pausing on downgrade and removal after 30 days still run, but Cloudflare is not called.
- **Worker:** `git checkout <previous commit> -- infra/cloudflare/club-sites/worker.js`, delete the `routing.js` part from `deploy.sh`, and run `./deploy.sh`. The previous Worker answers every custom domain with its 404 page.
- **Remove all clubs' domains:**
  - delete each in Admin → Club domains; this removes it at Cloudflare too;
  - or `DELETE /zones/$Z/custom_hostnames/{id}` for each id in `GET /zones/$Z/custom_hostnames`.
- **Turn Cloudflare for SaaS off:** remove every custom hostname first, then the fallback origin, then the `sites` AAAA record.
- **Backend:** `alembic downgrade admin_revenue` drops `club_domains` and renames the flag back to `plan_features.domain`. Do this only after the domains are removed at Cloudflare, or they are left there with nothing tracking them.

## Notes

- **Renewal:** certificates renew over HTTP on their own while the CNAME points to us and traffic is proxied. The backend rechecks active domains daily. If one needs new TXT records, the dashboard shows them and the reason.
- **Unverified domains:** Cloudflare deletes a custom hostname whose validation has not passed after 7 days. The backend fails the domain at the same point, says why, and deletes it at Cloudflare itself.
- **Club domains already on Cloudflare** ("orange-to-orange"): Cloudflare does not accept the TXT ownership record for these. The hostname validates once the CNAME is in place and traffic arrives, so the club must add the CNAME, which it does anyway.
- **Workers free plan:** 100,000 requests a day, shared by club subdomains and clubs' own domains. Every page view is one request. A 301 from a subdomain to a club's domain is two.
