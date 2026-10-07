# Admin & Club dashboards — product requirements

**For whoever is designing or generating these screens.** Every field name,
filter and figure below is one the API actually returns today; where something
is missing or awkward it says so rather than describing an ideal. Build against
this and the result will connect to real data without rework.

Two separate web apps, one shared component library:

| App | Who signs in | Live at |
|---|---|---|
| **Admin** | Platform staff | `admin-next.myotherapp.in` |
| **Clubs** | One login per club (often shared by a committee) | `clubs-next.myotherapp.in` |

---

## 1. The product in a paragraph

Clubs publish events. People follow clubs, register for events, attend them,
pay when there's a fee, and rate them afterwards. Certificates and winner
awards are issued from attendance. Platform staff approve clubs, moderate
content, handle refunds and watch the whole thing. The Admin dashboard governs
the platform; the Clubs dashboard is the tool a club runs its events with.

Scale today: ~670 users, ~42 events, a few hundred followers per active club.
Design for hundreds-to-thousands, not millions — density matters more than
virtualised infinite lists.

---

## 2. Shared foundations

### Brand

- **Accent:** teal `#17a58f`. It is the product's signature colour and is
  hard-coded as the default in ticket and certificate rendering, so it is the
  brand, not a preference.
- **Structure:** charcoal `#2c333d` — the sidebar, primary buttons.
- **Display type:** Bebas Neue, uppercase, used for page titles.
- **Body type:** DM Sans.
- Light and dark themes both required; theme follows a class on `<html>`.

### Currency and locale

Indian Rupees, `en-IN` formatting (lakh/crore grouping). Dates read naturally
(`20 Sep 2026`), times 12-hour.

### Every screen needs four states

Design all four, not just the happy one:

1. **Loading** — skeletons matching the final layout's shape, not spinners.
2. **Empty** — distinguish "nothing yet" from "nothing matched your filter".
   They need different wording and different actions.
3. **Error** — the API returns a message; show it, with a retry.
4. **Forbidden** — admin only; see roles below.

### Destructive actions

Deletes are soft almost everywhere and recoverable from Trash. Say so in the
confirmation, because an admin who believes a delete is permanent behaves
differently. Where something is genuinely unrecoverable (badge definitions,
interests, snapshots), say that instead.

---

## 3. Admin roles — this changes what is on screen

Three roles. The UI must **hide** controls a role cannot use, not disable them:
a greyed-out button implies the action is yours and merely needs something.

| Role | Can |
|---|---|
| **Viewer** | Read everything. Change nothing. |
| **Support** | Everything Viewer can, plus moderate: approve a club, suspend a user, award or revoke a badge, block an organisation, send an announcement, restore a deleted item. |
| **Owner** | Everything, including refunds, deletion, impersonation, editing the catalogue, resetting passwords, granting roles and taking database snapshots. |

The session payload (`GET /auth/me`) carries `admin_role`. **An absent role
means owner** — accounts predate roles. An *unrecognised* role means viewer.

Capabilities, if you need the granularity: `view`, `moderate`, `manage_money`,
`destroy`, `impersonate`, `manage_admins`, `manage_content`,
`reset_credentials`, `export_data`.

**The Clubs app has no roles at all.** Any club login can do anything,
including delete events and announce to every follower. Worth designing as if
roles will arrive, but do not show controls for them yet.

---

## 4. Admin dashboard

Thirteen sections. Sidebar navigation, labelled.

### 4.1 Overview

**The question:** is the platform healthy, and is anything waiting on me?

A reporting period control (7 / 30 / 90 days) governs every panel on the page —
one control, so no two figures describe different windows.

**Headline figures** (`GET /admin/analytics`): total users, verified clubs,
events hosted, platform revenue. Each carries a change against the previous
window from `GET /admin/analytics/trends?days=`, which returns `series[]` (one
point per day: `date, users, events, registrations, revenue`), `totals` and
`previous_totals`.

Direction must be coloured by **good/bad, not up/down**. Refunds rising is not
a success. Growth from a zero baseline is "new", not "+100%". A sub-1% move is
"flat".

**Activity chart** — the four totals double as the chart's series selector, so
the number being read and the line being looked at cannot drift apart.

**Needs attention** (`GET /admin/moderation-queue`): `pending_clubs[]` (id,
name, created_at) and `events_without_attendance[]` (id, name, event_datetime,
registration_count). Age each item — a queue is only useful if it says what is
going stale. Oldest first.

**Platform composition** — proportions, not counts: verified vs awaiting clubs,
upcoming vs past events. Assembled from the admin list endpoints, each asked
for one row to read its `total`.

**Revenue retained** (`GET /payments/admin/totals`): `captured_total`,
`refunded_total`, `net_total`, `failed_count`. Net as a share of captured is
the signal; gross alone overstates what the platform kept.

### 4.2 Users

List with `search`, `user_type` (app_user / club / admin / guest), `provider`
(google / apple / email), `sort` (joined / name / email / username), `order`.
Paginated, CSV export, saved views.

**Detail** (`GET /user/admin/{id}`) shows the profile plus the clubs they
follow and events they attended — both separate calls. Actions, by role:

- Suspend / reinstate with a reason (`moderate`) — reversible; make it the
  obvious choice over deletion.
- Edit name, email, phone (`manage_admins`). Username is fixed; it appears in
  links and exports that already exist.
- Set a password (`reset_credentials`) — generated in-browser, shown once.
- Grant an admin role (`manage_admins`).
- Impersonate (`impersonate`).
- Delete (`manage_admins`) — signs them out everywhere.

### 4.3 Clubs

List with `search`, `org_id`, `is_verified`, `sort` (created / name /
followers), `order`. Bulk-approve selection, where only unverified rows are
selectable.

**Detail**: profile, followers, events, pending state. Approve / reject
(`moderate`), edit (`manage_content`), delete (`destroy`).

**Create a club** (`manage_content`) — takes name and email only. The service
generates a random password and **deliberately does not return it**, so a club
created this way cannot sign in until someone sets one. Creating must therefore
hand straight to the password step; stopping at "created" leaves an unusable
account.

### 4.4 Events

List with `search`, `club_id`, `org_id`, `category_id`, `is_ended`, `has_fee`,
`sort` (created / date / name / views), `order`.

Detail: registrations, attendance, winners (placings), edit (multipart form),
delete and restore.

### 4.5 Organisations

List and detail. A detail page must show **which clubs and events belong to the
organisation** — this was a reported gap. Block / unblock (`moderate`), edit
(`manage_content`), delete (`destroy`), restore.

### 4.6 Badges

Definitions (create, edit, delete) and awards. Two distinct things share the
word "award" in this product: **badge awards** and **event winners** — keep
them visibly separate. Recipients list and stats per badge.

### 4.7 Payments

Every payment taken. Filters: `status` (captured / authorized / refunded /
failed / disputed / pending / created), `search` (payment, order or receipt
id), `user_id`. Totals above the table.

Refund is **owner-only, full-amount only** — partial refunds are unsupported,
so the UI must not imply an amount can be entered. Only captured payments are
refundable; a row that is not should say so rather than offering a button that
errors.

### 4.8 Interests, 4.9 Avatars

Reference data shown on every club, event and user profile. Interests are
grouped into categories. Create / rename (`manage_content`), delete
(`destroy`) — deletion detaches the interest from every record that used it and
reports how many. Seeded rows contain the literal word "string"; treat
non-emoji icons as absent.

### 4.10 Announcements

Compose and send to real phones. Includes the notification log — what was sent,
when, by whom.

### 4.11 Activity

The audit log: every moderation action, refund, role change, impersonation,
password reset and snapshot, with actor, target, time and address. Append-only.

### 4.12 Trash

Soft-deleted clubs, events and organisations, each restorable. Badges are
absent on purpose — badge definitions hard-delete, and an empty tab would imply
otherwise.

### 4.13 Security

The admin's own account: two-factor (TOTP with recovery codes), active sessions
with the ability to revoke one or all, and database snapshots (`export_data`,
owner-only).

Snapshots are explicitly **not a backup regime** — they are written to the same
host as the database. The UI must say so rather than letting a tidy list imply
the problem is solved.

---

## 5. Clubs dashboard

Six sections. The audience is a volunteer running a student club, often on a
phone, often the night before an event.

### 5.1 Overview

**The question:** what is next, is it filling, and is anything waiting on me?

- **Club identity** — logo, name, location, about, link to edit.
- **Headline figures** — followers, upcoming events, registrations ahead,
  rating (`rating` / `total_ratings`, from `GET /clubs/info`).
- **Next event, given real prominence** — countdown, registrations, page views
  and the sign-up rate between them, with Manage and Announce actions. This is
  the single most-read thing on the page.
- **Coming up** — remaining events with a registration bar. *There is no
  capacity field in the API.* Compare each event against the club's own
  best-performing upcoming event and label it as such; do not imply a target
  nobody set.
- **Needs attention** — finished events with registrations where nobody was
  marked present. Certificates and winners are issued from attendance, so each
  row is a group of people who turned up and have nothing to show for it.
- **Reach** — view-to-sign-up and turnout. Page views are recorded on every
  event; without them a club cannot tell whether a quiet event was *unseen* or
  *unappealing*.

### 5.2 Events

`GET /clubs/events/list` with `search`, `is_ended`, `offset`, `limit`. Each row
carries: `name`, `event_datetime`, `location_name`, `is_online`, `has_fee`,
`reg_fee`, `has_prize`, `reg_startdate`, `reg_enddate`, `page_views`,
`registration_count`, `attended_count`.

Scope is a binary choice (live / past) — one segmented control, not two
buttons. Row actions: edit, delete, share.

### 5.3 Event workspace — the most important screen in this app

Everything about one event. `GET /events/registration/{id}/analytics` returns
**ten fields**, and a design should use them all:

| Field | |
|---|---|
| `total_registrations` | |
| `total_revenue` | what this event earned |
| `attendance_rate` | |
| `conversion_rate` | views → registrations |
| `payment_status` | `{paid, unpaid}` |
| `attendance_status` | `{attended, absent}` |
| `top_institutions` | `[{name, value}]`, capped at 5 server-side |
| `total_institutions` | distinct count — **not** the length of the list above |
| `registration_time` | `{morning, afternoon, evening, night}` |
| `attendance_over_time` | `[{time, count}]` |

Also on this screen:

- **Registrations table** with search and Excel export.
- **Attendance marking** — one tap per attendee. This is used standing at a
  door, on a phone, under time pressure. It deserves to be fast and large;
  consider a dedicated check-in mode.
- **Volunteers** — add and remove.
- **Announcements** to registered attendees.
- **Reviews** (`GET /events/ratings/{id}`) — rating, text, who left it, when.
  Note: this endpoint returns `total: null` and `next: null` *always*, so the
  only signal that more exist is a full page coming back. Design for "load
  more", not numbered pages.

### 5.4 Followers

`GET /clubs/followers/{club_id}` — each row has the user and `created_at`, so
growth over time is derivable. **The endpoint has no search parameter**; any
filter is client-side over the loaded page and must be labelled honestly.

### 5.5 Announcements

Compose and send; history of what was sent. These reach real phones — the
confirmation should carry that weight.

### 5.6 Templates — ticket and certificate designers

Two modes, and both must remain:

**Styled mode** — restyle the built-in layout: colours (accent, background,
text, secondary text, border), font, border style, ticket type label, toggles
(show prizes, guidelines link, QR, certificate ID), custom header/body/footer
text, logos, signatures, orientation, date format.

**Layer mode** — the club uploads its own artwork and places content on it.
Each layer has: `type` (text | qr), `text` (may contain tokens), `x`, `y`,
`width`, `font_size`, `color`, `align`, `bold`, `max_lines`, `line_spacing`.

Requirements for layer mode:

- A canvas showing the artwork with layers positioned on it, draggable, with a
  live X/Y readout.
- **Coordinates are in the artwork's own pixels**, never display pixels, so a
  position chosen at 25% zoom is the position the PDF uses.
- A zoom control, a layers list (add text / add QR, select, delete), and an
  inspector for precise numeric editing — dragging gets a layer roughly right,
  the inspector reproduces a designer's spec exactly.
- A **sample preview** mode that swaps tokens for placeholder values, so the
  result can be checked before anyone receives one.
- One QR per template. The renderer encodes a single ticket; a second would be
  a duplicate.
- A transparency checkerboard behind the stage — artwork is usually a PNG with
  transparency, and a white backdrop hides exactly the mistakes a club needs to
  see.

**Ticket tokens:** `name`, `ticket_code`, `event_name`, `event_title`,
`event_date`, `event_time`, `event_start_time`, `event_end_time`, `venue`,
`club_name`, `team_name`.

**Certificate tokens:** `name`, `event_name`, `event_title`, `event_date`,
`club_name`, `certificate_id`, `placing`.

An unknown token renders as literal `{{even_name}}` rather than blank — a typo
that disappears is the version nobody catches before it is emailed out.

### 5.7 Club profile

Name, about, location, logo, interests, organisation, social links
(instagram, youtube, linkedin, website), change password.

---

## 6. Constraints that will shape the design

Not wishes — these are how the API behaves today.

1. **No event capacity field.** Nothing can show "80 of 100 seats". Compare
   against the club's own events instead.
2. **Ratings pagination reports nothing.** `total` and `next` are always null.
3. **Followers cannot be searched server-side.**
4. **Partial refunds do not exist.**
5. **Admin-created clubs have an unknown password.** Creation must flow into
   setting one.
6. **There is no unauthenticated forgot-password flow anywhere.** The admin
   password-reset screen is the only route back in for a locked-out account,
   and it requires a working admin.
7. **Soft deletes everywhere** — lists filter `is_deleted`, so any count that
   does not will disagree with the table it links to.
8. **Announcements have no delivery data** — sent, with no open or read signal.

---

## 7. What is missing today, and worth designing for

These have no UI and would be new endpoints, or endpoints that exist and are
unused:

- **Club roles.** A committee shares one login; everyone can delete everything.
- **Club-side security** — no 2FA, no view of active sessions. Admin has both.
- **Duplicate an event.** Clubs run the same event monthly and retype it each
  time.
- **Draft events.** Everything published goes live to followers immediately.
- **A fast check-in mode** for attendance at the door.
- **Follower growth over time** as a first-class view.
- **Notes** (`/clubs/notes`) and **attendee networking**
  (`/events/{id}/networking`) — both built, both unreachable.
- **Delivery/read signal on announcements.**

---

## 8. Non-goals

- The public-facing events website. It does not exist yet and is a separate
  product.
- The Flutter mobile app.
- Anything requiring per-seat ticketing, assigned seating or partial refunds.
