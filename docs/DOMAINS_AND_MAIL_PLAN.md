# Domains, club sites and mail — plan

Written 2026-10-16. Nothing here is built yet. Each phase below is one integration step, shipped and verified before the next.

**Decided 2026-10-16**: DNS moves to Cloudflare — done the same day. No mail server of our own and no mail subscription (section 3.2): staff mail on a free hosted mailbox; club mail built into MyOtherApp, received and sent through SES.

**Interim sender, 2026-10-16**: platform mail goes out through Resend's free plan From `info@myotherapp.in`, with SES taking over on any refusal. Resend's free plan stops at 100 mails a day and 3,000 a month, sent and received together, so receiving stays off there; after a quota refusal the backend leaves Resend alone until the next UTC day. Set on the server's `.env` as `APP_MAIL_PROVIDER=resend`, `APP_RESEND_API_KEY` and `APP_RESEND_WEBHOOK_SECRET` (settings carry the `APP_` prefix). Compose hands `.env` to a container only when it is created, so after editing it recreate the backend alone (`up -d --no-deps --force-recreate backend`; postgres reads the same file), then reinstall requirements. Never use the workflow's "Sync environment variables" for this: the `PROD_ENV_VARIABLES` secret dates from 2025-03-13 and replaces the whole file. Delivery, open, bounce and complaint events come back through `POST /api/v1/hooks/resend`.

## 1. Target map

| Host | What it is | Served by |
|---|---|---|
| `myotherapp.in` | The public portal: what MyOtherApp is, every club, every upcoming event, sign-in for attendees | New Next app `apps/www` in `moa_web` (needs SEO, so server-rendered) |
| `www.myotherapp.in` | 308 to the apex | Vercel domain redirect |
| `event.myotherapp.in` | Event pages, registration, tickets, certificates, live room, competition | Today's `moa-events` project, renamed |
| `club.myotherapp.in` | The clubs dashboard | `moa-clubs-next` |
| `admin.myotherapp.in` | The admin dashboard | `moa-admin-next` |
| `api.myotherapp.in` | The API, for the app and the dashboards' gateways | EC2, unchanged |
| `r.myotherapp.in` | Short links: `r.myotherapp.in/x7k2m9pq` | Edge worker that forwards to the API |
| `{handle}.myotherapp.in` | A club's website | Edge worker that serves the published page from cache |
| `www.theirclub.org` | A club's own domain for its website | Same worker, via custom hostnames |
| `info@myotherapp.in` | The official address: a real mailbox for staff, and the sender of platform mail | Zoho Mail free plan for the mailbox; SES sends platform mail |
| `hello@{handle}.myotherapp.in` | A club's address, read in the club's dashboard | SES receives, our API stores, SES sends |
| `events@theirclub.org` | A club's own domain for mail | SES identity per club |

**Old names keep working forever** as permanent 308 redirects that keep the path and query. They are printed on posters, inside sent emails, inside shipped app builds, and on gate and kiosk devices:

| Old | Redirects to |
|---|---|
| `events.myotherapp.in/*` | `event.myotherapp.in/*` |
| `clubs-next.myotherapp.in/*` | `club.myotherapp.in/*` |
| `admin-next`, `admin-dashboard`, `admin-official` | `admin.myotherapp.in/*` |
| `api.myotherapp.in/l/{code}` | Keeps answering itself; new links are minted on `r.` |
| `event.myotherapp.in/clubs/{slug}` | `{handle}.myotherapp.in` |

## 2. What is there today

Checked live on 2026-10-16.

- **DNS is on Hostinger** (`byte`/`pixel.dns-parking.com`). Records cannot be listed from outside, so the move below starts with a full zone export from the Hostinger panel.
- **No MX, no SPF, no DMARC** on `myotherapp.in`. Nothing can receive mail at the domain, and platform mail goes out with no published policy. Gmail and Yahoo now expect SPF or DKIM plus DMARC from senders; this is the most urgent gap.
- **SES sends the mail.** The From name still defaults to "Finnet" (`app/core/email/email.py:94` and `:213`, `payments/background_tasks.py:28`, the TOTP issuer `auth/totp.py:17`). The bounce hook from SES is still not wired.
- **Vercel** holds `myotherapp.in` and `www` (project `my-other-app-dashboard`), `events`, `clubs-next`, `admin-next` and `admin-dashboard`, `admin-official` (old admin). **`club.myotherapp.in` is already attached to the old `moa-clubs` project** with no DNS record; it must be detached there first.
- **The API is one shared EC2 box** in us-east-1 (3.8 GB, no swap, three products on it). Right after today's deploy it answered 502, then timed out intermittently while serving 200s. Public club sites must never send their traffic to it directly.
- **Hosts are hardcoded** in 18 places: backend `config.py:67-74`, `events/service.py:487-489`, `events/router.py:373-375`; the clubs app `event-row-menu.tsx:38`, `event-row-actions.tsx:58`; the admin app `impersonate-button.tsx:36`; the event site `App.jsx:17`; the Flutter app `ticket_view_page.dart:77,80`, `individual_event_page.dart:229,1776,1779`, `event_card.dart:141`.
- **Dashboard cookies are host-only** with SameSite=Lax (`auth/router.py:58-72`). A club site on a sibling subdomain cannot read them. It is still "same-site" with the dashboards, which matters for the rule in section 5.
- **Club slugs carry a random suffix** (`circuit-society-a3a168`) and cannot be edited. They cannot be the subdomain.

## 3. The decisions that shape everything

**3.1 Move DNS to Cloudflare.** Decided.

- It gives, free, in one place: a proxied wildcard `*.myotherapp.in` with a certificate, edge workers for `r.` and club sites, edge caching so club pages never load the EC2 box, and custom hostnames with certificates for clubs' own domains (100 free, then about $0.10 a month each).
- The Vercel apps stay on Vercel as DNS-only records; nothing about them changes.
- Vercel DNS would also host the wildcard, but a wildcard there needs Vercel nameservers and custom domains count against the plan's domain limits. Verify the Vercel plan either way: a commercial product on Hobby breaks its terms.

**3.2 No mail server of our own; two kinds of mail, each on the cheapest thing that works.** Decided.

A self-run mail server (Postfix, Mailcow, Stalwart) has no subscription but costs more in practice: AWS blocks outbound port 25 on EC2 until a removal request is approved; a fresh EC2 address has no sending reputation, so Gmail files its mail as spam; spam and virus filtering needs one to two gigabytes the shared 3.8 GB box does not have; and every attack lands on the machine that runs the API.

- **Staff mail, `info@` and `support@`: Zoho Mail's free plan.** Up to five mailboxes of 5 GB on one domain, in the browser and Zoho's phone app; no IMAP on the free plan. Its MX sits on the apex. The fallback, also free, is Cloudflare Email Routing forwarding to a personal Gmail with Gmail's send-as over SES.
- **Club mail, `hello@{handle}.myotherapp.in`: built into MyOtherApp.** A wildcard MX for every club subdomain points at SES receiving; one SES receipt rule for `.myotherapp.in` stores each message in the bucket and notifies our API, which already takes SES notifications. Messages, threads and mailboxes live in our database; each club reads and replies in an Inbox in its dashboard; replies go out through SES with proper threading headers. Cost is SES's per-use price, about $0.10 per thousand messages each way.
- **Platform mail**, tickets and reminders: SES, as today, From `info@myotherapp.in`.

Cloudflare Email Routing is not used for clubs: it allows at most 30 mail domains per zone, apex included.

**3.3 Give every club a handle.** A new `clubs.handle`: 3–30 characters, `a-z 0-9 -`, no leading, trailing or double hyphen, unique, not reserved. Backfilled from the name with the random suffix dropped, de-duplicated with a number. The club may change it; an old handle stays reserved and redirects for a year, because it is in emails and on posters.

Reserved: `www api r event events club clubs admin app mail smtp imap pop mx bounce email info support help docs status blog cdn static assets img media files auth login account id sso dev staging test beta demo preview site sites dashboard my go link links pay payments billing careers jobs press legal about terms privacy security abuse postmaster hostmaster webmaster noreply no-reply root ns1 ns2 myotherapp finnet official`, every host in section 1, and every `xn--` name.

**3.4 Club mail lives on the club's subdomain.** `hello@circuit.myotherapp.in`, not `circuit@myotherapp.in`. Each club's reputation stays apart from `info@`, the address matches the website, and staff names on the apex never collide with clubs. With `myotherapp.in` verified in SES, every subdomain can send without its own verification, and DKIM passes DMARC by relaxed alignment.

## 4. DNS records after the move

| Name | Type | Value | Proxy |
|---|---|---|---|
| `@` | CNAME (flattened) | `cname.vercel-dns.com` | off |
| `www` | CNAME | `cname.vercel-dns.com` | off |
| `event`, `events` | CNAME | `cname.vercel-dns.com` | off |
| `club`, `clubs-next` | CNAME | `cname.vercel-dns.com` | off |
| `admin`, `admin-next`, `admin-dashboard`, `admin-official` | CNAME | `cname.vercel-dns.com` | off |
| `api` | A | `44.208.217.219` | off, until nginx trusts Cloudflare's client-IP header |
| `r` | AAAA | `100::` (worker only) | on |
| `sites` | AAAA | `100::` (fallback origin for clubs' own domains) | on |
| `*` | AAAA | `100::` (club sites) | on |
| `@` | MX | Zoho Mail (the records it gives) | — |
| `*` | MX | `10 inbound-smtp.us-east-1.amazonaws.com` (club subdomains) | — |
| `@` | TXT | `v=spf1 include:zoho.in include:amazonses.com ~all` | — |
| `zmail._domainkey` | TXT | Zoho's DKIM key | — |
| `*` | TXT | `v=spf1 include:amazonses.com ~all` (club subdomains) | — |
| three `…._domainkey` | CNAME | the SES Easy DKIM tokens | off |
| `bounce` | MX | `feedback-smtp.us-east-1.amazonses.com` | — |
| `bounce` | TXT | `v=spf1 include:amazonses.com ~all` | — |
| `_dmarc` | TXT | `v=DMARC1; p=none; rua=mailto:dmarc@myotherapp.in; adkim=r; aspf=r` | — |

Exact names win over the wildcard, so every named host above is untouched by `*`. Cloudflare's free certificate covers the apex and one level of wildcard, which is exactly what club sites need.

`p=none` for two to four weeks while the reports show only our own mail passing, then `p=quarantine`, then `p=reject`.

## 5. The rules that keep it safe

1. **No club-written JavaScript or HTML on `*.myotherapp.in`, ever.** Club sites are generated by us and every string is escaped. They share a site with `club.` and `admin.`, so a script there could ride a dashboard session on top-level navigations. If clubs ever get custom code, their sites move to a separate domain on the Public Suffix List, the way GitHub uses `github.io`.
2. **Dashboard cookies stay host-only.** Nothing sets `Domain=.myotherapp.in`.
3. **Old links never break.** Every rename in section 1 is a permanent redirect, kept indefinitely.
4. **Club pages never hit the EC2 box per visit.** The worker caches the published page at the edge and is purged on publish.
5. **Club mail goes only to the club's own registrants and followers**, which is how the emails module already works, with per-club rate limits and bounce and complaint suppression from the SES hook before club senders are switched on.
6. **Custom domains are verified before they are served**, with an ownership record the club adds.

## 6. Phases

Each phase is one set of PRs and one deploy, verified live before the next starts. **You** marks steps that need your accounts.

### Phase 1 — Move DNS to Cloudflare, with no visible change
- **You**: export the full zone from Hostinger; create the Cloudflare account and add `myotherapp.in`.
- Recreate every record from the export, DNS-only; diff it against the export.
- **You**: switch nameservers at Hostinger. Watch every host from section 2 answer as before.
- Done when every existing host answers exactly as it did, and Cloudflare shows the zone active.

### Phase 2 — Mail foundation
- **You**: sign up for Zoho Mail's free plan with `myotherapp.in`; create `info@` and `support@`. This step can happen before the Cloudflare move, at Hostinger.
- **You**: in SES (us-east-1), verify `myotherapp.in` as a domain with Easy DKIM and MAIL FROM `bounce.myotherapp.in`; confirm production access.
- Add Zoho's MX, SPF and DKIM; SES's DKIM and MAIL FROM; one SPF covering both; DMARC at `p=none`.
- Backend: one sender setting for platform mail, `MyOtherApp <info@myotherapp.in>`; every "Finnet" default gone; wire the SES bounce and complaint hook, which already has its endpoint, to suppress bad addresses.
- Done when a test mail to Gmail shows SPF, DKIM and DMARC all "pass", and mail to `info@` arrives in Zoho.

### Phase 3 — The new hostnames
- Backend: `PUBLIC_SITE_URL=https://event.myotherapp.in`, `PUBLIC_WEB_URL=https://club.myotherapp.in`, new `PUBLIC_PORTAL_URL`; the four hardcoded ticket and certificate URLs read the setting; `CORS_ORIGINS` gains the new hosts.
- Web: the three hardcoded hosts become environment variables.
- Flutter: one constants file for the three hosts; old builds keep working through the redirects.
- Vercel: detach `club.` from the old `moa-clubs`; attach `event.`, `club.`, `admin.`; old names become 308 redirects.
- Done when every old URL in section 1 redirects with its path, and the dashboards work on the new names. Everyone signs in once more, because cookies are host-only.

### Phase 4 — `r.` short links
- A worker on `r.myotherapp.in/*` forwards `/{code}` to the API's `/l/{code}` with the visitor's IP, browser and referrer, so click counting is unchanged.
- Backend: a `PUBLIC_SHORT_URL` setting; new links are minted on `r.`. Old `api.…/l/` links keep working.
- Done when a new link and a two-week-old poster link both redirect and both count the click.

### Phase 5 — Club websites at `{handle}.myotherapp.in`
- Backend: `clubs.handle` with the rules and reserved list, backfill, handle history; `/sites/{handle}` alongside the slug; purge the edge cache on publish.
- Worker on `*.myotherapp.in/*`: the published page from cache, images through the site's image route, a branded "no club here" page that links to the club directory.
- Clubs app: the handle on the Website page with an availability check; the site address becomes `circuit.myotherapp.in`.
- Event site: `/clubs/{slug}` redirects to the handle's subdomain.
- Done when a club picks a handle, publishes, and its subdomain serves the page, with the API seeing one request per publish, not per visit.

### Phase 6 — Club mail, built in
- SES: one receipt rule for `.myotherapp.in` that stores each message in the bucket and notifies our API; the wildcard MX and SPF from section 4.
- Backend: mailboxes, threads, messages and attachments as tables; the SES notification parses and files each message under its club, and drops mail to a handle that does not exist or has mail off. Club emails send From `Circuit Society <hello@circuit.myotherapp.in>`; per-club daily limits; a club with high bounces is paused and told why.
- Clubs app: an Inbox — read, reply in thread, mark done, search — and an optional forward to the club's contact address.
- Done when a club email passes SPF, DKIM and DMARC at Gmail, and a reply from Gmail lands in the club's Inbox and is answered from there in the same thread.

### Phase 7 — Clubs' own domains
- Backend: a `club_domains` table (host, kind web or mail, status, the records to add, provider ids, verified time); a Cloudflare client for custom hostnames; an SES client for per-club domain identities.
- Web domain: the club enters `www.theirclub.org`; we show a CNAME to `sites.myotherapp.in` and an ownership TXT; we poll until active and then serve it. The bare `theirclub.org` is redirected to `www` at their registrar, because apex custom hostnames need an enterprise plan.
- Mail domain: the club enters `theirclub.org`; we show the three DKIM CNAMEs from SES; once verified, their mail can go From `events@theirclub.org`.
- Clubs app: a Domain card on the Website page and a Sending domain card on the Emails page, each with the records, a copy button and live status.
- Done when a test domain goes from "add these records" to serving the site and sending signed mail without anyone touching a console.

### Phase 8 — The portal at `myotherapp.in`
- `apps/www` in `moa_web`: what MyOtherApp is, a searchable club directory linking to each club's subdomain, upcoming events linking to `event.`, attendee sign-in, app store links, sitemap and structured data.
- Retire `my-other-app-dashboard` once it is replaced.

## 7. What I need from you

| When | What |
|---|---|
| Before phase 1 | The Cloudflare account with `myotherapp.in` added; a scoped API token; the record list from Hostinger |
| Before phase 2 | A Zoho Mail free account on `myotherapp.in`; SES console access or a scoped IAM user |
| Before phase 3 | Whether the Vercel team is on Pro |
| Before phase 7 | Whether clubs' own domains are free or a paid feature |

## 8. Open questions I did not settle

- **"Users seen individually."** Read here as the attendee-facing portal with the club list. If it also means public profiles for attendees, that is a privacy decision and a phase of its own.
- **`api.finnet.app` and `api.staging.*`** still point at production. They stay until no app build in use calls them; `api.staging.*` should be retired now, since it is production under another name.
