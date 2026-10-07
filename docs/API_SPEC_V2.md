# API specification for the v2 dashboards

**For the engineers building this backend.** It answers one question per
section: what does the v2 design need that the API cannot do today, and what
should the endpoint look like.

Companion to `DASHBOARD_PRD.md` (what the screens do) and the v2 design handoff
(what they look like). Where the three disagree, the design handoff wins on
layout, the PRD wins on existing behaviour, and this document wins on contracts.

---

## 1. Where we actually are

The v2 design covers **17 screens across two apps**. Counting by domain:

| | Domains | Status |
|---|---|---|
| Already built | 12 | users, clubs, events, orgs, badges, interests, avatars, payments, announcements, audit, trash, admin security |
| Built this cycle | 2 | admin roles/capabilities, template layers, admin overview aggregate |
| **Not built at all** | **17** | everything in §4 below |

So: **roughly half the backend the design assumes does not exist.** The honest
framing is that v2 is not a reskin — it is a product expansion with a new
interface on top.

Nothing in §4 is required to ship the admin shell or the Overview screen. They
are required for the screens that come after.

---

## 2. Conventions every new endpoint follows

Decided once here so twenty new domains do not each invent their own.

**Paths.** `/api/v1/<domain>` for member-facing, `/api/v1/<domain>/admin/...`
for staff. Club-scoped resources are nested under the thing that owns them
(`/events/{event_id}/ticket-types`), never under the club — a club id in the
path invites the bug where one club reads another's data.

**Ownership.** Every club-scoped endpoint resolves the club from the session
and checks it owns the parent, through the existing `ensure_event_access`.
Never trust a club id from the client.

**Pagination.** `offset` / `limit`, response `{items, total, limit, offset,
next}`. `total` is mandatory on new endpoints — the ratings endpoint returning
`null` is a defect we are not repeating.

**Filtering and sorting.** `search`, domain filters, `sort` + `order` against a
server-side whitelist. An unrecognised sort key falls back to the default
rather than 422ing a stale bookmark.

**Soft delete.** `is_deleted` on everything, filtered from every list and every
count. A count that does not filter it disagrees with the table beside it.

**Money.** Integer paise or `Numeric(10,2)` — never float. Sums come from
`payment_logs`, which is the record of money that actually moved; a
registration's `paid_amount` is what was charged, not what cleared.

**Capability gating.** Admin endpoints declare a capability
(`requires(MANAGE_MONEY)`), never a role name.

**Plan gating.** Club endpoints for paid features check the club's plan
entitlement and return `402` with `{feature, plan_required}` so the UI can show
the Pro banner rather than a generic error.

**Aggregates.** A screen needing many figures gets one aggregate endpoint, not
many list calls. `/admin/overview` is the pattern: every figure a `GROUP BY`,
nothing counted by walking rows in Python.

---

## 3. Built this cycle

### 3.1 `GET /admin/overview` — the Overview screen ✅

One response for ~15 aggregates: totals, today, running events, nine averages,
four monthly growth series, three breakdowns, funnel, top clubs, money split.
Params `days` (1–365), `top_by` (followers | registrations | revenue).

Two keys the design asks for are **absent on purpose**:

- `users_by_city` — `Users` has no city column. Needs a migration plus a
  backfill nobody can source. Decide before promising the chart.
- `mrr` — no subscription domain yet. Lands with §4.1.

---

## 4. What has to be built

Ordered by what unblocks the most screens.

### 4.1 Subscriptions and plans — **the largest new domain**

*Needed by: Admin → Subscriptions (3 tabs), Clubs → Plan & billing, and every
Pro-gated feature in the Clubs app.*

This is the keystone. Plan **limits and feature flags drive gating across the
entire Clubs app**, so until it exists every "NEW API" feature below is
ungated.

**Models**

- `plans` — `id, key, name, tagline, price_monthly, price_yearly, trial_days,
  visibility (public|hidden|legacy), is_deleted`
- `plan_limits` — 10 keys, `NULL` meaning unlimited: `events_per_month,
  registrations_per_month, registrations_per_event, ticket_types_per_event,
  coupons_per_event, merch_items_per_event, committee_seats, storage_gb,
  announcements_per_month, website_templates`
- `plan_features` — ~30 boolean keys in 4 groups: *every event*
  (tickets, certificates, checkin, reviews, threads, regform, waitlist);
  *grow* (coupons, links, merch, swag, quiz, qa, polls, networking);
  *competitions* (teams, judging, rounds, badges, sessions, report);
  *club* (website, domain, nobadge, finance, roles, tfa, payouts, sso, api)
- `club_subscriptions` — `club_id, plan_id, cycle (monthly|yearly),
  status (active|past_due|trial|cancelled), current_period_end, mrr_paise`

**Endpoints**

```
GET    /admin/plans                      list with subscriber counts
POST   /admin/plans                      create                 manage_money
GET    /admin/plans/{id}
PUT    /admin/plans/{id}                 limits + features      manage_money
POST   /admin/plans/{id}/duplicate       creates hidden copy    manage_money
DELETE /admin/plans/{id}                 only when 0 subscribers
POST   /admin/plans/{id}/archive         → legacy when it has subscribers
GET    /admin/subscriptions              filters, MRR totals
PUT    /admin/subscriptions/{id}/plan    move a club            manage_money
POST   /admin/subscriptions/{id}/retry   retry a failed charge  manage_money
GET    /clubs/subscription               the club's own plan + usage
GET    /clubs/entitlements               resolved limits + features
```

**Rules the UI depends on**

- A plan with subscribers **archives** (→ legacy); only an unsubscribed plan
  deletes. The UI already branches on this.
- Lowering a limit never deletes existing records. It applies at next renewal.
- Yearly price above 12× monthly is rejected.
- `GET /clubs/entitlements` is the single source the Clubs app gates on. Cache
  it per session; invalidate on plan change.

### 4.2 Threads — posts, comments, moderation

*Clubs → Threads; event workspace → Threads; Admin → club Threads tab.*

```
GET/POST    /clubs/threads                posts with photos and polls
POST        /threads/{id}/like
GET/POST    /threads/{id}/comments
POST        /threads/{id}/pin                                    club
POST        /admin/threads/{id}/hide      moderation             moderate
GET         /admin/threads/reported       the moderation queue
```

Needs a report/flag model. The Admin shell already shows "2 thread posts
reported as spam" in its notification list.

### 4.3 Ticket types — **blocks merchandise, coupons and finance**

*Event workspace → Ticket types; referenced by registrations, payments and
templates.*

```
GET/POST/PUT/DELETE  /events/{id}/ticket-types
```

`name, price, quantity, sale_window, per_person_limit, visibility,
description`. Registrations gain `ticket_type_id`; payments gain the type in
their "For" column. Template layers gain per-type overrides.

This is a schema change to a hot table — plan the migration carefully. Existing
registrations map to a synthesised default type per event.

### 4.4 Coupons and tracking links

```
GET/POST/PUT/DELETE  /events/{id}/coupons      code, type, value, cap, window
GET                  /events/{id}/coupons/{id}/analytics
GET/POST             /events/{id}/links        UTM builder
GET/POST             /clubs/links              club-level
GET                  /links/{id}/analytics     clicks → signups
```

Click attribution needs a redirect endpoint that records and forwards.

### 4.5 Merchandise and swag

```
GET/POST/PUT/DELETE  /events/{id}/merch     per ticket type, stock, variants
GET/POST             /events/{id}/swag      handed-out tracking
POST                 /events/{id}/swag/{id}/hand-out
```

Merch sales join payments; swag is fulfilment, not revenue. Keep them separate
or the money figures double-count.

### 4.6 Finance and expenses

```
GET/POST/PUT/DELETE  /events/{id}/expenses
GET                  /events/{id}/finance       income vs expense, surplus
GET                  /clubs/finance             club-wide, per event
GET                  /clubs/payouts
GET                  /clubs/finance/statement   CSV
```

Income is derived from payments; expenses are club-entered. Surplus is the
difference. Payouts need a real payment-provider integration — scope separately.

### 4.7 Live event tools

*Event workspace → Live. Needs realtime; everything else here is request/response.*

```
GET/POST  /events/{id}/quiz              questions, host control, leaderboard
GET/POST  /events/{id}/qa                submit, upvote, moderate, answer
GET/POST  /events/{id}/polls             incl. word clouds
GET/POST  /events/{id}/feedback          survey definition + responses
GET/POST  /events/{id}/updates           live announcements
WS        /events/{id}/live              push for all of the above
```

**Decide the realtime transport before building any of it.** WebSocket, SSE or
polling changes every one of these endpoints. On a single throttled instance,
SSE or short polling is the pragmatic choice; WebSockets need a process model
this deployment does not have today.

### 4.8 Competitions

```
GET/POST  /events/{id}/tracks
GET/POST  /events/{id}/teams             members, invites
GET/POST  /events/{id}/submissions       files, links, per round
GET/POST  /events/{id}/rubrics           criteria, weights
GET/POST  /events/{id}/rounds            brackets, advancement
POST      /events/{id}/judging/scores    per judge, per criterion
GET       /events/{id}/leaderboard       computed, tie-break rules
GET/POST  /events/{id}/office-hours      slots and bookings
```

Shown only for Hackathon/Competition event types. Judging needs a judge role —
see §4.11.

### 4.9 Running the day

```
GET/POST  /events/{id}/run-of-show        timed schedule
GET/POST  /events/{id}/tasks              assignee, due, status
GET/POST  /events/{id}/sessions           + session check-in
GET/POST  /events/{id}/waitlist           auto-promote on cancellation
GET/PUT   /events/{id}/registration-form  custom field definitions
GET/POST  /events/{id}/badges             printable attendee badges
```

The custom registration form is the sharp one: field definitions must version,
or an edit retroactively invalidates existing submissions.

### 4.10 ID cards and self check-in

```
GET/PUT   /events/{id}/id-card            designer config, reuses layer model
POST      /events/{id}/id-cards/generate  bulk
GET/POST  /events/{id}/checkin-links      kiosk, rotating QR
POST      /checkin/{token}                self check-in, public, rate-limited
```

The rotating QR is a security control, not decoration: it must expire, or a
photographed poster becomes a permanent skeleton key.

### 4.11 Club roles — committee seats

*Needed by: everything. Today one shared login per club can do everything,
including delete every event and announce to every follower.*

```
GET/POST/DELETE  /clubs/members           invite, remove
PUT              /clubs/members/{id}/role
```

Roles: owner, organiser, volunteer, judge. Mirror the admin capability pattern —
capabilities at the call site, never role names. `committee_seats` is a plan
limit, so this depends on §4.1.

### 4.12 Club security

```
GET     /clubs/sessions          active sessions and devices
DELETE  /clubs/sessions/{id}
GET     /clubs/sign-in-history   with places
POST    /clubs/2fa/*             mirrors the admin flow
```

The admin side already has all of this. Reuse it rather than writing it twice —
`app/api/auth/sessions.py` and `totp.py` are not admin-specific.

### 4.13 Website builder

```
GET/PUT   /clubs/website          template, sections, theme
POST      /clubs/website/publish
GET/POST  /clubs/website/domain   custom domain, Pro-gated
GET       /public/c/{slug}        the rendered public site
```

Custom domains need DNS verification and certificate provisioning. That is
infrastructure work, not an endpoint.

### 4.14 Notifications

```
GET   /notifications              in-app feed for the bell menu
POST  /notifications/{id}/read
POST  /notifications/read-all
```

Both shells have a bell with an unread dot. Distinct from announcements, which
are push to attendees.

### 4.15 Club overview aggregate

The Clubs Overview shows four KPIs, a revenue line chart against the previous
period, next event, coming up, needs attention, reach, busiest weekday, repeat
attendees and new followers. Same reasoning as §3.1 — **one endpoint**.

```
GET /clubs/overview?days=30
```

### 4.16 Smaller gaps already identified

- `POST /events/{id}/duplicate` — clubs retype monthly events today.
- Draft events — `status` on events; everything published goes live immediately.
- Follower growth series — derivable, but belongs server-side.
- Announcement delivery data — sent/delivered/read. Needs provider callbacks.
- `/clubs/notes` and `/events/{id}/networking` — **built, unreachable**. Wire or
  delete.

### 4.17 The assistant

The Clubs Overview shows a "club assistant" chat; the prototype has canned
answers. Treat as a research spike, not a spec'd endpoint.

---

## 5. Suggested order

1. **§4.1 Subscriptions and plans** — gates everything else; the admin screen
   is self-contained and shippable on its own.
2. **§4.11 Club roles** and **§4.12 club security** — the biggest live risk, and
   §4.12 is mostly reuse.
3. **§4.3 Ticket types** — blocks merch, coupons and finance; the schema change
   wants doing before those depend on it.
4. **§4.15 Club overview**, **§4.2 Threads**, **§4.4 Coupons and links**.
5. **§4.6 Finance**, **§4.5 Merch and swag**, **§4.9 Running the day**.
6. **§4.7 Live** — only after the realtime decision.
7. **§4.8 Competitions**, **§4.10 ID cards**, **§4.13 Website**.

---

## 6. Decisions needed before building

1. **Realtime transport** for §4.7 — changes those endpoints fundamentally.
2. **Payments provider for subscriptions.** Razorpay handles one-off payments
   today. Recurring billing, proration and dunning are a different integration.
3. **`users.city`** — migrate and backfill, or drop the chart.
4. **Custom domains** — who provisions certificates.
5. **Storage limits** are a plan limit with no enforcement point today; uploads
   go to S3 unmetered.

---

## 7. Capacity note

This doubles the API surface. The deployment is one instance of one container
on a shared `t2.medium` at ~78% CPU steal, with no error tracking, no backups
and the database on the public internet. §4.7 alone adds persistent connections
to a process model that has never been load tested.

The infrastructure work in `PRODUCTION_READINESS.md` is not a parallel track to
this — it is a prerequisite for it.
