# MyOtherApp: app vs website parity, and store readiness

Audited 2026-10-19. Read-only: nothing in any repo was changed.

| Source | Revision |
| --- | --- |
| App | `/Users/muhammedr/development/projects/moa_app_wt/stability`, branch `app/stability` @ `2dbdd2d` (PR #49) |
| Website | `moa_eventwebsite` `origin/main` @ `cc50a00` (snapshot exported to `scratchpad/app-parity/site/`) |
| Backend | `moa_backend` `origin/master` @ `6a15a9e` (snapshot in `scratchpad/app-parity/backend/`) |
| Live checks | `https://myotherapp.in/.well-known/apple-app-site-association`, `/apple-app-site-association` and `/.well-known/assetlinks.json` all return **404** today. `myotherapp.in` has **no MX record**. |

App paths below are relative to `lib/` unless they start with `ios/` or `android/`. Site paths are relative to `src/`. Backend paths are relative to `backend/app/api/`.

Values: **H** = high, **M** = medium, **L** = low. Effort: **S** ≈ a day or two, **M** ≈ up to a week, **L** = more than a week.

---

## 0. The earlier findings (2026-10-18), re-checked

| Earlier finding | Status today |
| --- | --- |
| Discover home and near-you | **Still missing.** The app never calls `/discover/*` (`features/topics/domain/topic_filter.dart:12` says so). |
| Filters and calendar | **Still missing.** The app filters by search and topic only. |
| Full event page (speakers, team, map, similar) | **Still missing.** `/events/info` already returns `speakers` and `event_guidelines`, but nothing in `lib/` reads them. Team, similar and more-from-club come only from `/discover/events/{ref}`. |
| Club team | **Still missing.** `/clubs/info/{id}` already returns `team`, `partners`, `cover` and `tagline` (`clubs/schemas.py:326-360`); the app ignores them. |
| Forgot password | **Still missing.** No "forgot" anywhere in `lib/`. The backend has `/auth/password/forgot` and `/reset`. |
| Deep links (no AASA or assetlinks) | **Still missing**, on all three sides: the site (404), iOS (no Associated Domains) and Android (no VIEW intent filter). |
| Native live room | **Partly addressed.** The app now opens the website's room inside the app (SFSafariViewController or a Custom Tab), and "join now" pushes route there. There is still no native room. |

---

## 1. Parity: what a person can do on the website vs in the app

### 1.1 Discover, search and topics

| # | Feature | Site route / component | API | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Home: hero search, category chips, the "coming up" fan | `/` → `components/discover/homepage.jsx`, `hero.jsx` | `GET /discover/home` | **Partial.** Home has two tabs, FOR YOU (`/events/for-you`) and FOLLOWING, plus a "Browse by topic" row (`features/home/presentation/pages/home_page.dart:20-27`, `home_page_tabs/for_you_events_page.dart:23`, `features/topics/presentation/widgets/browse_by_topic_row.dart:15`). | H | M |
| 2 | Events near you, and Clubs near you | `homeislands.jsx` (`NearYou`, `NearEvents`, `NearClubs`), `locationpill.jsx`, `app/api/near/route.js` | `GET /discover/home?lat&lng`. Without a point, the server places the caller by IP (`discover/geo.py:996-1015`), so no location permission is needed. | **No.** There is no location code, no geolocator, and no `NSLocationWhenInUseUsageDescription`. | H | S (by IP); M (with GPS) |
| 3 | This week, Online and Popular rails | `homepage.jsx:54-72` | `GET /discover/home` | **No** | M | S (once #1 is in) |
| 4 | "From the clubs": the newest posts from every club | `homepage.jsx:74`; `/threads` → `threadspage.jsx` | `GET /discover/threads`. The backend also has `GET /threads/feed` (clubs you follow), which nothing uses. | **No.** Only a club's own THREADS tab (`features/clubs/presentation/pages/club_individual_page.dart:18-31`). | M | S |
| 5 | Clubs directory: words, topic, interest, sort (popular, nearby, newest), radius | `/clubs` → `clubspage.jsx`, `finderislands.jsx` | `GET /discover/clubs` | **Partial.** Explore clubs offers search and topic/interest (`explore_more_clubs_page.dart:165-173` via `/clubs/list`; `shared/widgets/custom_search_delegate.dart:35`). No sort and no distance. | M | S |
| 6 | Search events by words | `header.jsx:36`, `/events?q=` | `GET /discover/events?q=` | **Yes.** `custom_search_delegate.dart:19` and `explore_events_page.dart:21-33`, both on `/events/list?search=`. | — | — |
| 7 | When: today, tomorrow, this week, this weekend, next week, this month, or a custom range | `eventspage.jsx`, `datepicker.jsx`, `api/parse.js:41-48` | `/discover/events?when=` or `from=&to=` | **No** | H | S |
| 8 | Price (free or paid) and type (online or in person) | `api/parse.js:50-58` | `/discover/events?price=&type=` | **No** | M | S |
| 9 | Category chips with counts | `eventspage.jsx` `CategoryChips` | `/discover/events` facets, `/discover/categories` | **No.** `eventCategoriesProvider` exists (`features/events/presentation/providers/events_provider.dart:256`) but nothing shows it. | L | S |
| 10 | Topic and interest filter | `eventspage.jsx` `InterestChips` | `/discover/events?topic=&interest=` | **Yes.** Topics go to `/events/list` as their interests' `interest_ids` (`features/topics/domain/topic_filter.dart`, `topic_filter_bar.dart`). | — | — |
| 11 | Sort (date, distance, popular, relevance) and radius (10–100 km) | `api/parse.js:60-87` | `/discover/events?sort=&radius_km=&near=` | **No** | M | S (after #2) |
| 12 | Calendar view: a month with a count per day | `/events?view=calendar` → `calendarview.jsx` | `GET /discover/calendar`; `/discover/events?from&to` | **No** | L–M | M |
| 13 | Topics index | `/topics` → `topicspage.jsx` `TopicsView` | `GET /interests/topics` | **Partial.** Only the "Browse by topic" row on Home. | M | S |
| 14 | A topic's page: its events, interest chips with counts, its clubs, more topics | `/topics/[slug]` → `TopicView` | `GET /interests/topics/{slug}`; `/discover/events?topic`; `/discover/clubs?topic` | **Partial.** A topic opens Explore events, filtered (`browse_by_topic_row.dart:174`). No clubs section and no counts. | M | S |

### 1.2 The event page

Site: `/events/[slug]` → `components/discover/eventpage.jsx` and `eventparts.jsx`, from `GET /discover/events/{ref}`.

App: `features/events/presentation/pages/individual_event_page.dart`, from `GET /events/info/{id}`.

| # | Feature | Site | API | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| 15 | Header facts: category and topic chips, hosting club, date, venue, price | `Facts`, `ClubRow` | both | **Yes**: topic strip, plus date, fee, location and duration tiles (~838–1100). | — | — |
| 16 | Going count and seats-left meter | `RegisterCard` (`eventparts.jsx:96-138`) | `/discover/events/{ref}` (`going`, `capacity`) | **No** | M | S |
| 17 | About and interests | `EpSection#about` | both | **Yes** (`:1751`) | — | — |
| 18 | Prizes | `Prizes` | both | **Yes**: the prize-worth tile (`:980-1011`). | — | — |
| 19 | **Speakers** with photo, bio and links | `Speakers` (`eventparts.jsx:156-190`) | `/discover/events/{ref}.speakers`. Also already in `/events/info` (`events/schemas.py:640`). | **No.** `speakers` is never read in `lib/`. | H | S |
| 20 | Agenda: by day, with parallel tracks | `discover/agenda.jsx` | `GET /events/{id}/agenda` | **Yes** (`:462-470`, `:604-730`) | — | — |
| 21 | Venue: embedded map and "Get directions" | `Venue` (`eventparts.jsx:255-305`) | `lat`/`lng` from `/discover/events` | **Partial.** An OPEN MAPS button (`location_link`, or a Google Maps search) (`:942-964`). No map, no directions from coordinates. | L | S |
| 22 | Guidelines | `eventpage.jsx` `#guidelines` | `event_guidelines` (both) | **No** | M | S |
| 23 | **Organising team**, or the club's team | `Team` (`eventparts.jsx:195-236`) | `/discover/events/{ref}.team`, `.team_source` | **No** | M | S |
| 24 | Contact: name, email, phone | `Contact` (`eventparts.jsx:307`) | both | **Partial.** A call button only (`:1835`). The email is parsed but not shown. | L | S |
| 25 | **More from this club** and **Similar events** | `eventpage.jsx:216-240` | `/discover/events/{ref}.more_from_club`, `.similar` | **No** | H | S |
| 26 | Share | `ShareButton` | — | **Yes**: links to `https://myotherapp.in/events/{slug}` (`:449-456`; `features/events/presentation/utils/event_feed.dart:53`). | — | — |
| 27 | Add to calendar from the event page | `CalendarButton` (`utils/calendar.js`) | — | **Partial.** Only on the ticket, after registering (`ticket_view_page.dart:217`). | M | S |
| 28 | LIVE NOW strip | `LiveStrips` (`eventislands.jsx`) | `GET /events/{id}/live` and `/live/stream` | **Yes** (`:478-546`; `features/events/data/live/live_stream_client.dart`) | — | — |
| 29 | Store and merch sold with the ticket | `register/merchpicker.jsx` | `GET /events/{id}/store/catalog` | **Yes** (`:559-600`; `widgets/merch_picker.dart`; `event_form_page.dart:1202`) | — | — |
| 30 | Ratings and reviews | not on the site | `POST /events/rate/{id}`, `GET /events/ratings/{id}` | **App only**: a rate-and-review sheet (`:1147-1330`). Neither side shows anyone's reviews. | L | — |
| 31 | FAQ | none | none | n/a | — | — |
| 32 | People Like You (attendee networking) | not on the site | `GET /events/{id}/networking` | **App only** (`networking_page.dart`) | — | — |

### 1.3 Registration

| # | Feature | Site | API | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| 33 | Custom questions: text, email, url, tel, number, date, time, datetime, select, radio, checkbox | `register/register.jsx`, `fields.jsx`, `utils/register.js:25-55` | `POST /events/registration/{id}/register` | **Yes** (`event_form_page.dart:216`, `:429`; `utils/question_answers.dart:31-50`) | — | — |
| 34 | Guest registration (no account) | `register.jsx` (guest token) | same, signed out | **No, by design.** Every screen needs sign-in (`app/router/app_router.dart:67-80`). See store risk iOS-14. | M | M (signed-out browsing) |
| 35 | Paid registration through Razorpay, and finishing payment later | `register/finishpayment.jsx`, `api/payments.js` | `POST /payments/orders?checkout=2`, `/payments/verify` | **Yes** (`features/payments/checkout.dart`; `features/events/presentation/finish_payment.dart`) | — | — |
| 36 | Waitlist | none | **none in the backend** | n/a everywhere | — | — |
| 37 | **Team competitions**: make or join a team, look for teammates, pick a track, submit links, book mentor slots, see the leaderboard | `/events/[slug]/compete` → `components/compete.jsx`, linked from the ticket (`ticket.jsx:132`) | `/events/{id}/competition/me`, `/me/team`, `/me/team/join/{id}`, `/me/team/leave`, `/me/seeking`, `/me/submission`, `/me/slots/{id}`, `/competition/leaderboard` | **No** | M (hackathons only) | M–L |

### 1.4 Tickets and certificates

| # | Feature | Site | API | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| 38 | My tickets: upcoming and past, with Finish payment | `/me/tickets` → `me/mepages.jsx` | `/events/list?is_registered=true` | **Yes** (`upcoming_events_page.dart:27`, `past_events_page.dart:24`) | — | — |
| 39 | A ticket: QR code and PDF | `/tickets/[ticketid]` → `ticket.jsx` | `/events/tickets/{id}` (+`/pdf`) | **Yes, and more.** Offline saved tickets (`/tickets/:code`), PDF, Apple Wallet, add to calendar, share (`ticket_view_page.dart`, `saved_ticket_page.dart`). | — | — |
| 40 | From the ticket to "Your team and submission" | `ticket.jsx:132` | — | **No** (see #37) | M | with #37 |
| 41 | Certificates: list, view, PDF | `/certificates/[ticketid]` → `certificate.jsx` | `/events/certificates/{id}/style`, `/pdf` | **Yes** (`features/profile/presentation/pages/certificates/*`; `certificate_detail_page.dart:34`). There is no way to share the public certificate page. | L | S |
| 42 | Certificate verification (the QR holds `certificate:{ticket_id}`, `events/certificates.py:48`) | **none on the site** | `GET /verify/certificates/{code}` | **No.** The endpoint exists, but no page anywhere uses it. | L | S (the app already has a scanner) |
| 43 | Ticket transfer | none | none | n/a everywhere | — | — |

### 1.5 Live room and feedback

| # | Feature | Site | API | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| 44 | Live room: updates banner, polls (incl. word cloud), Q&A (ask and upvote), quiz (join with a code, then play) | `/events/[slug]/live` → `components/live.jsx`; `/play/[eventId]` → `play.jsx` | `GET /events/{id}/live` (+`/stream`), `POST …/questions`, `…/questions/{id}/vote`, `…/polls/{id}/respond`, `/live/quiz/join`, `…/quiz/play`, `…/quiz/answer` | **Partial.** The app opens the site's room inside the app (`shared/utils/external_links.dart:31-33`, `:45-62`; `individual_event_page.dart:493-498`). The "join now" push opens it (`core/services/notification_service.dart:385-400`). It uses the old `/{id}/live` address, which redirects with a 308. There is no native room. | M | S (keep the web room); L (native) |
| 45 | The feedback survey (linked from the email) | `/feedback/[eventId]/[registrationId]?k=` → `feedback.jsx` | `GET`/`POST /events/{id}/feedback/{registration_id}` | **No.** The email link opens the browser. No push or in-app entry: the backend sends no survey push type, only `event_live_join`, `event_live_update`, `event_reminder`, `event_started` and `event_checkin`. | M | S (app) + S (backend) |

### 1.6 Clubs

| # | Feature | Site | API | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| 46 | About, location, contact | `/clubs/[slug]` → `clubpage.jsx` | `/discover/clubs/{slug}` or `/clubs/info/{id}` | **Yes** (`club_profile_page.dart`) | — | — |
| 47 | Cover banner and tagline | `clubpage.jsx:138-146` | `/clubs/info/{id}` `.cover`, `.tagline` | **No** | M | S |
| 48 | **Team** | `clubpage.jsx:250-258` | `/clubs/info/{id}.team` | **No** | M | S |
| 49 | **Partners and sponsors** | `clubpage.jsx:260-268` | `/clubs/info/{id}.partners` | **No** | M | S |
| 50 | Upcoming and past events | `clubpage.jsx:185-248`, `MoreEvents` | `/discover/clubs/{slug}/events` | **Yes** (`club_events_page.dart:97-113` via `/clubs/{id}/events`) | — | — |
| 51 | Threads | `clubpage.jsx:235` | `/clubs/{id}/threads` | **Yes** (`features/threads/presentation/pages/club_threads_page.dart`) | — | — |
| 52 | Follow and unfollow, with tracking-link credit (`?follow=`/`ref`) | `clubislands.jsx` `ClubFollow` | `POST /clubs/follow/{id}?ref=` | **Yes** for follow (`club_profile_page.dart:66-67`). **No** for the `ref` credit, which needs deep links. | L | S |
| 53 | Website and social links | `clubpage.jsx:117-170` | `socials` | **Yes** (`club_profile_page.dart:335-347`) | — | — |
| 54 | Share | — | — | **Yes** (`shared/widgets/club_tab_header.dart:95-103`) | — | — |
| 55 | Mute, pin, hide | none | `/notifications/mutes/clubs/{id}`, `/clubs/pin`, `/clubs/hide` | **App only** (`shared/widgets/clubs_option_screen.dart:50-166`) | — | — |

### 1.7 Threads

| # | Feature | Site | API | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| 56 | Threads index (every club) | `/threads` → `threadspage.jsx` | `/discover/threads` | **No** (see #4) | M | S |
| 57 | Like, and vote in a poll | `/threads/[id]` → `threadislands.jsx` | `POST /threads/{id}/like`, `/vote` | **Yes** (`threads_provider.dart:47-85`) | — | — |
| 58 | Comments: read, write, delete your own | The site only reads them ("comment in the app") | `GET`/`POST`/`DELETE /threads/{id}/comments` | **Yes** (`thread_detail_page.dart:223`, `:319`) | — | — |
| 59 | Report a post or comment, block its author, list of blocked people | none on the site | `POST /reports`, `/user/blocks` | **App only** (`widgets/moderation_actions.dart:43-104`, `report_sheet.dart`, `settings/blocked_users_page.dart`) | — | — |
| 60 | Share a post | thread pages have URLs | — | **No** | L | S |

### 1.8 Profile, settings and auth

| # | Feature | Site | API | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- | --- |
| 61 | Notification switches | none | `GET`/`PATCH /notifications/settings` | **App only** (`push_switches_section.dart`; `settings_page.dart:109`) | — | — |
| 62 | Delete your account | `/privacy#delete-account` (by email) | `DELETE /user/delete` | **Yes** (`settings_page.dart:176-250`) | — | — |
| 63 | Export your data | none | none | n/a | — | — |
| 64 | Clubs you follow | `/me/following` | `/user/following` | **Yes** (`clubs_page.dart:45-46`) | — | — |
| 65 | Notification inbox; badges | none | `/notifications/*`, `/badges/me` | **App only** | — | — |
| 66 | Sign in with Google | `auth/google.js`, `signinsheet.jsx` | `POST /auth/google` | **Yes** (`onboarding_initial_page.dart:112`) | — | — |
| 67 | Sign in with Apple | not on the web | `POST /auth/apple` | **Yes**, on iOS (`onboarding_initial_page.dart:154`) | — | — |
| 68 | Email and password: sign in, sign up, verify the address | `auth/emailforms.jsx`, `verifyemail.jsx` | `/auth/token`, `/user/register`, `/auth/email/*` | **Yes** (`authentication_service.dart:19-37`; `verify_email_page.dart`) | — | — |
| 69 | **Forgot and reset password** | `ForgotForm`, `ResetForm` (`signinsheet.jsx:192`) | `POST /auth/password/forgot`, `POST /auth/password/reset` (reset signs you in) | **No** | H | S |
| 70 | Two-step code (TOTP) at sign-in | `TotpForm` | `/auth/token` with `totp_code` | **No.** The app says two-factor is needed and stops (`features/auth/presentation/sign_in_errors.dart:41-44`). | L | S |
| 71 | Guest tickets merged into the account | `AuthProvider`, the verify result | server side | **Yes** (`email_verification_service.dart:169-183`) | — | — |
| 72 | Privacy and Terms | `/privacy`, `/terms` | — | **Yes**: links to the site (`external_links.dart:9-10`; `widgets/terms_consent.dart`) | — | — |
| 73 | About page | `/about` | — | **No.** Settings has a Website row only. | L | S |

### 1.9 Deep links and universal links

| # | Feature | Evidence | App? | Value | Effort |
| --- | --- | --- | --- | --- | --- |
| 74 | Event, club, thread, ticket, certificate, topic and live-room URLs opening the app | **Site:** AASA and `assetlinks.json` both 404, and the site's `public/` has no `.well-known`. **iOS:** no `com.apple.developer.associated-domains` in `ios/Runner/Runner.entitlements` or `Runner.Release.entitlements`. **Android:** only MAIN/LAUNCHER (`android/app/src/main/AndroidManifest.xml:80-83`), with no VIEW intent filter and no `autoVerify`. **Router:** `/events/:eventId` and `/clubs/:clubId` parse an int, so a slug becomes id 0 (`app_router.dart`). The two sides also disagree on what `/events` and `/clubs` mean: on the site they are the directories, in the app "my registrations" and "my clubs". **Resolvable today:** `/events/info/{slug}` accepts slugs (`events/service.py:451-487`), `/discover/clubs/{slug}` returns the club's id, thread ids are UUIDs, and the site's `/tickets/{id}` matches the app's `/tickets/:code`. | **No** | H | M |

**Out of scope (clubs and admins):** `/for-clubs`, `/pricing` (`api/plans.js`), the clubs and admin dashboards, OG images (`/og/*`), sitemaps and RSS, `/api/revalidate`, `/api/share`, `/media/*`, and the club sites at `{slug}.myotherapp.in`.

**Where the app is already ahead of the site:**
- offline tickets, Apple Wallet, the ticket PDF;
- writing comments; report and block;
- mute, pin and hide a club; push switches; a notification inbox;
- badges, ratings, People Like You, the volunteer scanner;
- Sign in with Apple.

---

## 2. Store readiness

Severity: **Blocker** means it can stop an upload or get the app rejected. **Risk** means it could get the app rejected. **Low** means fix it, but it won't block a release.

### 2.1 iOS

| # | Item | Status | Evidence | Fix |
| --- | --- | --- | --- | --- |
| iOS-1 | Privacy manifest and required-reason APIs | **OK** | `ios/Runner/PrivacyInfo.xcprivacy` is in the Runner target (`project.pbxproj:21`, `:285`). Tracking is false; 12 data types; required-reason APIs UserDefaults `CA92.1`, FileTimestamp `C617.1`, SystemBootTime `35F9.1`, DiskSpace `E174.1`. | Add a Location type, and the purpose string, if precise near-you is built. |
| iOS-2 | Usage descriptions | **Risk: one missing** | Camera (`Info.plist:83`) and Calendars (`:81`) are present. **`NSContactsUsageDescription` is missing.** add_2_calendar 3.0.1's README says Apple's event editor offers contact-based location autocomplete and "might crash otherwise". Photos aren't needed (avatars are presets; only a PDF is shared, `ticket_view_page.dart:266`). Location isn't needed today. Notifications are asked for after sign-in (`notification_service.dart:134`). | Add `NSContactsUsageDescription`. Add `NSLocationWhenInUseUsageDescription` only with GPS near-you. |
| iOS-3 | Sign in with Apple alongside Google | **OK** | `Runner.Release.entitlements:7`; `onboarding_initial_page.dart:66-70`, `:154-200`; shown when available. | — |
| iOS-4 | In-app account deletion (5.1.1(v)) | **OK in the app; Risk in the backend** | Settings → Delete Account (`settings_page.dart:176-250`) calls `DELETE /user/delete`, which scrubs name, email, phone and password and ends every session (`users/service.py:1121-1160`). **But Sign in with Apple tokens are never revoked:** the backend only verifies the identity token (`auth/service.py:185-240`), never exchanges the `authorization_code`, and never calls `appleid.apple.com/auth/revoke`. Apple's account-deletion rules require revoking them. | Backend: at Apple sign-in, exchange the code for a refresh token (this needs a client secret signed with the `.p8` key) and store it; on deletion, call `/auth/revoke`. |
| iOS-5 | User-generated content (1.2) | **OK, with two gaps** | Report on posts and comments (`thread_detail_page.dart:98`, `:183`; `club_threads_page.dart:119`), block (`moderation_actions.dart:104`), Blocked Users. Terms are agreed to before an account exists (`terms_consent.dart`; `onboarding_initial_page.dart:234`, `:555`). The terms promise zero tolerance and action within 24 hours (site `content/legal.js:340`, `:399`). The admin app has a report queue (`moa_web apps/admin/src/app/(dashboard)/reports`). **Gap 1:** People Like You lists other attendees' names and photos with no Report or Block (`networking_page.dart`). **Gap 2:** `support@myotherapp.in` bounces, because there is no MX record; it is the contact in the suspension notice and the privacy policy. | Add Report and Block to networking cards. Turn on email routing for support@ before submitting. |
| iOS-6 | App Transport Security | **OK** | No `NSAppTransportSecurity` exceptions; `API_BASE_URL` is https. | — |
| iOS-7 | Push entitlement and background modes | **OK / Low** | `aps-environment` is `production` in Release (`Runner.Release.entitlements:5`) and `development` in Debug and Profile. **`UIBackgroundModes` lists `fetch`**, which nothing uses (`Info.plist:76-80`); see guideline 2.5.4. | Remove `fetch`. Check the APNs `.p8` is in Firebase. |
| iOS-8 | UPI and other query schemes for Razorpay | **OK** | `Info.plist:38-63`: tez, phonepe, paytmmp, credpay, bhim, amazonpay, … whatsapp. | — |
| iOS-9 | iPhone only | **OK** | `TARGETED_DEVICE_FAMILY = 1` (`project.pbxproj:481`, `505`, `613`, `666`, `691`, `715`); portrait only (`Info.plist:72`). | Untick Mac and Vision Pro availability in App Store Connect. |
| iOS-10 | Version and build | **Check** | `pubspec.yaml:19` is `1.1.0+3` → `FLUTTER_BUILD_NAME`/`NUMBER`. | The build number must be higher than any earlier upload (owner to confirm). |
| iOS-11 | App icon set | **Blocker (likely)** | The set is complete, including `1024.png` `ios-marketing`. **But `1024.png` is RGBA** (it has an alpha channel, though every pixel is opaque, alpha 255/255). App Store Connect refuses a marketing icon with an alpha channel (ITMS-90717). The same goes for the other PNGs. | Re-export the icons as RGB with no alpha. |
| iOS-12 | Export compliance | **OK** | `ITSAppUsesNonExemptEncryption` is false (`Info.plist:85`). | — |
| iOS-13 | Paid online events and in-app purchase (3.1.3(d)) | **Risk** | Razorpay sells every paid event (`features/payments/checkout.dart`), with no check for `is_online`. Apple: "one-to-few and one-to-many real-time services must use in-app purchase". A paid webinar or workshop bought in the iOS app is exactly that. | On iOS, for `has_fee && is_online`, don't open Razorpay; send the person to the website. Keep the review demo to in-person events. |
| iOS-14 | Sign-in wall before any browsing (5.1.1(v)) | **Risk** (higher on a first submission; the site has no App Store link yet, `config.js:17`) | `authRedirect` sends every signed-out route to sign-in (`app_router.dart:67-80`). Yet events, clubs and posts are public on the website. Apple rejects apps that require an account for content that isn't account-based. | A signed-out browse mode built on the public `/discover/*` endpoints, with sign-in asked for at Register, Follow and Comment. |
| iOS-15 | UIScene lifecycle (TN3187) | **Low now, future blocker** | `Info.plist` has no `UIApplicationSceneManifest`, and `AppDelegate.swift` is pre-scene. Built with the iOS 27 SDK, an app without UIScene will not launch. Xcode 26 builds are fine. | Do Flutter's UIScene migration before moving to Xcode 27. |
| iOS-16 | Xcode and SDK | **Check** | The release notes say the iOS 26.2 platform was missing locally (`docs/RELEASE_1.1.0.md`). | Build with Xcode 26 and the iOS 26 SDK. |

### 2.2 Android

| # | Item | Status | Evidence | Fix |
| --- | --- | --- | --- | --- |
| AND-1 | Target and compile SDK; toolchain | **OK, but fragile** | `compileSdk`, `targetSdk` and `minSdk` come from `flutter.*` (`android/app/build.gradle:34`, `:49-50`). On the installed Flutter 3.44.6 those are 36, 36 and 24 (`FlutterExtension.kt:23-34`). Play has required target 36 for updates since 31 Aug 2026 (an extension to 1 Nov 2026 is possible). An older Flutter on the build machine would silently produce 35. AGP is **8.6.0** (`android/settings.gradle:21`) and Gradle **8.7** (`gradle-wrapper.properties:5`), exactly at Flutter 3.44's error floor; it warns below AGP 8.11.1 and Gradle 8.14 (`DependencyVersionChecker.kt:94-105`). AGP 8.6 predates API 36. | Pin `compileSdk = 36` and `targetSdk = 36`. Move to AGP 8.11.1+ and Gradle 8.14+. |
| AND-2 | 16 KB page size | **Probably OK, not verified** | Flutter 3.44 engine; NDK 28.2 (`flutter.ndkVersion`) builds 16 KB-aligned; AGP 8.5.1+ aligns uncompressed libraries. Two libraries are unverified: **ML Kit barcode** (`mobile_scanner 7.1.4` bundles `com.google.mlkit:barcode-scanning:17.3.0`, native `libbarhopper_v3.so`) and **Razorpay** `checkout:1.6.+`. | Build the AAB and check it in Play's App bundle explorer, or with `zipalign -c -P 16 -v 4`. If ML Kit fails, set `dev.steenbakker.mobile_scanner.useUnbundled=true`. |
| AND-3 | `AD_ID` permission | **Decision needed** | Firebase Analytics merges `com.google.android.gms.permission.AD_ID`, and the manifest does not remove it. The app shows no ads. | Either answer "Yes, analytics" on Play's Advertising ID form and in Data safety, or remove it (`tools:node="remove"` plus the `google_analytics_adid_collection_enabled=false` meta-data). Removing it is recommended. |
| AND-4 | `POST_NOTIFICATIONS` | **OK** | Merged from the firebase_messaging and flutter_local_notifications manifests; asked for at runtime after sign-in (`notification_service.dart:134-140`). | — |
| AND-5 | Exact alarms | **OK** | No `zonedSchedule` and no `SCHEDULE_EXACT_ALARM`. | — |
| AND-6 | Data safety | **OK (draft exists)** | `docs/RELEASE_1.1.0.md` §10 still matches the code: no location, no photos. The deletion URL `https://myotherapp.in/privacy#delete-account` exists (`content/legal.js:12`, `:155`). | Update it if AD_ID is removed or GPS is added. |
| AND-7 | R8 and ProGuard (Razorpay, Firebase) | **OK** | `minifyEnabled` and `shrinkResources` are on (`build.gradle:78-80`). `proguard-rules.pro` keeps `com.razorpay.**` and `onPayment*`, Firebase and Crashlytics, and the local-notifications Gson rules. `res/raw/keep.xml` keeps `@mipmap/ic_launcher`. | — |
| AND-8 | Release signing | **OK by design / Check** | A release uses `key.properties` or the debug key with a warning; CI refuses the debug key (`build.gradle:77`, `:96-107`). `key.properties` exists in the main checkout (`moa_mobileapp/android/`) but **not in this worktree**, so a release built here is debug-signed. `google-services.json` lists 3 Android SHA-1 clients. | Build releases from a checkout that has `key.properties`. |
| AND-9 | Adaptive icon; notification icon and channel | **Low (cosmetic)** | There are only legacy `mipmap-*/ic_launcher.png` files: no `mipmap-anydpi-v26`, no monochrome (themed) icon. The notification small icon is `@mipmap/ic_launcher` (`notification_service.dart:275`, `:458`), a full-colour icon that shows as a white blob. No `default_notification_icon` or `default_notification_channel_id` meta-data, and the backend sets no `channel_id`, so background pushes land in "Miscellaneous". | Add an adaptive and monochrome icon, a white-on-transparent `ic_stat_*` icon, and both meta-data entries pointing at `high_importance_channel`. |
| AND-10 | Deep-link intent filters with `autoVerify` | **Missing** | `AndroidManifest.xml:80-83` has only MAIN/LAUNCHER. | Add VIEW + BROWSABLE + DEFAULT for `https://myotherapp.in` with `android:autoVerify="true"` and path prefixes, plus `assetlinks.json` on the site (§3, batch D). |
| AND-11 | Backup of the encrypted session | **Low** | `allowBackup` is on by default, and the session is in EncryptedSharedPreferences (`core/storage/secure_storage_service.dart:22`). Restored on a new phone, it cannot be decrypted. The read failures are caught (`auth_provider.dart:116-137`). | `android:allowBackup="false"`, or backup rules that leave out FlutterSecureStorage. |
| AND-12 | Edge-to-edge and predictive back (target 36) | **Check** | — | Run QA on an Android 15 or 16 phone. |

### 2.3 Both platforms

| # | Item | Status | Evidence | Fix |
| --- | --- | --- | --- | --- |
| BOTH-1 | Consent for crash reports and analytics | **Gap (compliance, not a store blocker)** | Crashlytics is on in release builds (`core/services/analytics_service.dart:36`), and Analytics collects by default. The `ENABLE_ANALYTICS` env flag (`core/config/app_config.dart`) is read by nothing. There is no opt-out. `setUserId` is never called, which is good. | Add a Settings switch that calls `setAnalyticsCollectionEnabled` and `setCrashlyticsCollectionEnabled`, for DPDP notice and consent. |
| BOTH-2 | Errors never show raw exceptions | **OK, three nits** | `extractErrorMessage` never returns class names or status codes (`core/utils/error_utils.dart:13-45`). The nits: (a) the router's error page prints `Page not found: <path>` (`app_router.dart:422-427`), which deep links will start to reach; (b) the scanner uses mobile_scanner's default error widget, which shows the platform's error text and offers no "Open Settings" when the camera is refused (`volunteer_scanner_page.dart:167`, no `errorBuilder`); (c) `apple_auth_service.dart:61` would show the raw response body, but `signIn()` is dead code. | A friendly not-found page that offers "Open in browser"; an `errorBuilder` on the scanner; delete the dead code. |
| BOTH-3 | An expired session goes to sign-in | **OK** | The auth interceptor reports the revoked session; `_onRevoked` clears the tokens and caches; the router redirects; `sessionEndNotice` says why (`auth_provider.dart:244-275`; `app_router.dart:67-80`). | — |
| BOTH-4 | Logout clears the server session and the FCM token | **OK** | `DELETE /user/fcm-token`, then `DELETE /auth/sessions/{sid}`, both under a timeout; then the tokens and caches are cleared (`auth_provider.dart:198-240`; `notification_service.dart:569`; `session_services.dart:89`). | — |
| BOTH-5 | A working support contact | **Blocker** | `host -t mx myotherapp.in` → no MX record. | Cloudflare Email Routing, or a mailbox, for support@. |

---

## 3. Proposed build plan

Four batches, each owning its own folders, so parallel builders don't collide.

**One rule, in a short first commit (call it Batch 0):** `lib/app/router/app_router.dart` belongs to batch D. Batches A, B and C each put their new routes in their own `lib/features/<x>/presentation/routes.dart` (a `List<RouteBase>`), and D wires them in with one line each. Shared widgets in `lib/shared/` are read-only for A to C; anything new goes in the batch's own feature folder.

### Batch A: Discover

**Folders:** new `lib/features/discover/**`; `lib/features/home/**`; `lib/features/topics/presentation/**`

- A discover data layer (datasource, repository, models, cached through the existing `ApiCache` policies):
  - `/discover/home`, `/discover/events`, `/discover/calendar`, `/discover/clubs`, `/discover/threads`, `/discover/categories`, `/discover/locate`;
  - `/interests/topics/{slug}`.
- Home sections:
  - Events near you, by IP first, with no permission (#2);
  - This week, Online and Popular rails (#3);
  - Popular clubs, or clubs near you (#5);
  - From the clubs (#4).

  Keep FOR YOU and FOLLOWING as they are.
- A **Find events** screen with filters (#7–#11):
  - when, or a date range;
  - type and price;
  - category chips;
  - topic and interest;
  - sort and radius.

  Plus a **calendar** month view (#12).
- A topics index and a topic page with its clubs (#13, #14); clubs directory sort and distance (#5); a threads index for every club (#56).
- **Backend:** nothing required; every endpoint exists and is public. **Recommended:** `/discover/*` is limited to 120/minute **per IP** (`discover/router.py:25-30`). App users behind Indian carrier NAT share IPs, so key the limit by account when a token is present (`account_or_address` already exists).
- Optional later: precise "Use my location" (geolocator, a location purpose string, a Location row in the privacy manifest and Data safety).

### Batch B: Event page, registration and payments

**Folders:** `lib/features/events/**`, `lib/features/payments/**`, `lib/common/models/events/**`

- The event page also reads `/discover/events/{id}`. It returns 404 for non-public events; then show what `/events/info` has, as today. That adds:
  - speakers with bios and links (#19);
  - the organising team (#23);
  - guidelines (#22);
  - the contact's name and email (#24);
  - the going count and seats-left meter (#16);
  - a map and directions from `lat`/`lng` (#21);
  - More from this club and Similar events (#25);
  - Add to calendar on the page (#27).
- `IndividualEventPage` accepts a slug as well as an id, since `/events/info/{slug}` already works. Batch D needs this for deep links. Point the live room at `/events/{slug}/live`.
- Competitions (#37, #40): a "Your team" screen, reached from the ticket and the event page, on `/events/{id}/competition/me*`.
- A feedback entry after an attended event (#45), opening the survey in the in-app browser.
- The **iOS guard for paid online events** (iOS-13), in `payments/`.
- Report and Block on People Like You cards (iOS-5).
- **Backend:** nothing required for the page or competitions. For feedback, either put the person's survey link (with `k`) on `/events/info` for an attended registration, or add an `event_feedback` push type that carries it.

### Batch C: Clubs, threads, auth and profile

**Folders:** `lib/features/clubs/**`, `lib/features/threads/**`, `lib/features/auth/**`, `lib/features/profile/**`, `lib/core/services/analytics_service.dart`

- The club page: cover and tagline, team, and partners and sponsors from `/clubs/info` (#47–#49), and a prominent website button.
- Threads: a following feed on `/threads/feed` (or the every-club feed from A, if the owner prefers), and share a post (#60).
- Auth:
  - **forgot and reset password** (#69): `/auth/password/forgot`, then `/reset`, which returns tokens, so it signs the person in;
  - the TOTP code step (#70).
- Profile: share the public certificate page (#41); optionally, scan to verify a certificate on `/verify/certificates/{code}` (#42); and the analytics and crash-reporting opt-out (BOTH-1).
- **Backend:** nothing for these features. Store readiness needs separate backend work: **revoke Sign in with Apple tokens on account deletion** (iOS-4).

### Batch D: Platform (deep links and store fixes)

**Folders:** `lib/app/**`, `ios/**`, `android/**`, `lib/core/services/notification_service.dart`, plus the **website repo**

- **Router** (it owns `app_router.dart`):
  - wire in A, B and C's route files;
  - add a layer that maps web URLs to app routes:

    | Website URL | Opens in the app |
    | --- | --- |
    | `/events/{slug\|id}` | the event page (by slug or id) |
    | `/events/{slug}/live` | the event page with `?live=room` |
    | `/events/{slug}/register` | registration |
    | `/clubs/{slug}` | the club, its id looked up through `/discover/clubs/{slug}` |
    | `/threads/{id}` | the post |
    | `/tickets/{id}` | the saved ticket |
    | `/certificates/{id}` | the certificate |
    | `/topics/{slug}` | the topic page (batch A) |
    | `/events?…` | Find events (batch A) |

  - anything else opens in the browser;
  - replace "Page not found: path" with a friendly page.
- **Signed-out browsing** (iOS-14): open up `authRedirect` for the discover, event, club, topic and thread routes, and prompt for sign-in at Register, Follow, Like, Vote and Comment. Do this last, once A and B have merged.
- **iOS:**
  - Associated Domains `applinks:myotherapp.in`;
  - add `NSContactsUsageDescription`;
  - remove the `fetch` background mode;
  - re-export the icons without alpha;
  - plan the UIScene migration.
- **Android:**
  - intent filters with `autoVerify`;
  - the AD_ID decision;
  - an adaptive icon, a monochrome icon and a status-bar icon, plus the default channel meta-data;
  - pin SDK 36; bump to AGP 8.11+ and Gradle 8.14+;
  - `allowBackup`;
  - check 16 KB alignment on the built AAB.
- **Website (`moa_eventwebsite`):** serve `/.well-known/apple-app-site-association` (JSON, no redirect) for app ID `PX6QV826X4.app.myotherapp.com`.
  - **Claim:** `/events/*`, `/clubs/*`, `/threads/*`, `/tickets/*`, `/certificates/*`, `/topics/*`.
  - **Exclude:** `/feedback/*`, `/play/*`, `/for-clubs`, `/pricing`, `/api/*`, `/og/*`, `/media/*`.

  Also serve `/.well-known/assetlinks.json` for `app.myotherapp.com` with the **Play App Signing SHA-256**. `www` and `events.` redirect to the apex, so claim only `myotherapp.in`, and send email links to the apex.
- **Backend:** nothing for links. Optional: set `android.notification.channel_id` on FCM sends.

**Order:**
1. A, B and C in parallel.
2. D's platform files, plus the site's `.well-known` files, in parallel with them.
3. D's router mapping once B's slug support lands.
4. Signed-out browsing last.
5. The backend's Apple revocation alongside, before the iOS submission.

---

## 4. Questions for the owner

1. **Browsing without an account** in the app, as on the website? It removes the main 5.1.1(v) risk for the first iOS review.
2. **Are there, or will there be, paid online events?** If yes, on iOS: send the person to the website to pay, use in-app purchase, or accept the 3.1.3(d) risk?
3. **Is the iOS app on the App Store yet?** The site has no App Store URL. What are the latest build numbers on both stores? 1.1.0 (3) must be higher.
4. **Who owns the Apple developer keys?** The backend needs a Sign in with Apple `.p8` key to revoke tokens when an account is deleted.
5. **support@myotherapp.in:** who sets up MX or email routing? It is a blocker.
6. **AD_ID:** keep it and declare it, or remove it? There are no ads.
7. **Near you:** city by IP only, which needs no permission, or also precise location, which needs a permission prompt and privacy-label changes?
8. **The live room:** keep the website room in the in-app browser, as today and recommended, or build a native one (L)?
9. **Competitions in the app:** worth an M–L effort, or keep them on the web, linked from the ticket?
10. **Threads feed:** every club's posts (as on the website), only followed clubs (`/threads/feed`), or both as tabs?
11. **Deep-link scope:** the claim and exclude lists in batch D look right? And what is the **Play App Signing SHA-256** for `assetlinks.json`?
12. **The feedback survey:** a push, or an in-app link? It needs a small backend change to hand the app the signed survey link.
13. **Certificate verification:** should there be a public verify page on the site, a verify scanner in the app, or neither? The backend endpoint exists, but nothing uses it.
14. **An analytics and crash-reporting opt-out** in Settings, for DPDP?
15. **Ratings:** reviews are collected in the app but shown nowhere. Show them on event or club pages, or drop the review text?
