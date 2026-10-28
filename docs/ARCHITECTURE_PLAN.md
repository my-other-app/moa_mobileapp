# Ecosystem architecture assessment & restack plan

Assessed 2026-10-01 against the stated target: **web on Next.js**, **Flutter on clean architecture + Riverpod + go_router**.
Every claim below was verified against the code; file:line references are given so each can be re-checked.

## 0. Decisions taken (2026-10-01)

- **Repo layout: one Turborepo.** The three web apps collapse into a new `moa_web` repo, with `moa-ui` moved in as
  `packages/ui`. End state is 3 repos: `moa_mobileapp` (Flutter), `moa_backend`, `moa_web`.
- **Auth: BFF proxy per Next app.** A route handler in each app forwards to the backend, so cookies are always
  first-party, preview deployments work, CORS disappears, and there is one place to add CSRF.
- **Starting point: phases 0 and 1** — unblock the repo, then fix the live bugs.

### Progress

| Item | Status |
|---|---|
| `.gitmodules` written, submodules registered, pinned commits verified pushed | **done** |
| `moa-ui` protected from accidental commit into the Flutter repo (`.gitignore`) | **done** |
| envied codegen repaired — `@EnviedField` moved from getters to fields | **done**, obfuscated values decoded and checked against `.env` |
| Mobile CI now generates `env.g.dart` before analyze/test | **done**, full CI recipe run locally end-to-end |
| `flutter test` un-broken — scaffold widget test no longer needs a Firebase app | **done**, 7/7 pass |
| `.env.example` pointed at `api.myotherapp.in` | **done** |
| `moa_clubs` dead-token bugs (4 files) | **done** — `tsc --noEmit` clean, 5/5 tests, production build passes, no new lint findings |
| Backend hardcoded `@finnet.app` senders removed | **done** — ruff clean, 31/31 tests pass |
| Phase 2: moa_web Turborepo + packages/{ui,api,auth,app-kit} | **done** |
| Phase 3: @moa/api generated from OpenAPI + drift gate | **done** |
| Phase 4: BFF gateway + cookie session helpers | **done** |
| Phase 5: apps/events (public site) | not started |
| Phase 6: apps/admin | **done** — all six resource features |
| Phase 7: apps/clubs | **done** — events, workspace, templates, announcements, profile |
| Phase 8-10: Flutter restack | not started |
| Phase 12: backend service splitting | not started (two outage fixes landed instead) |

Phase 0 and 1 are complete and verified. Both CI gates that were structurally incapable of passing — mobile
(`flutter analyze`/`test`) — now pass locally through the exact CI steps. Nothing is committed; all changes sit in
the working trees of the root, `moa_clubs` and `moa_backend` repos.

**Correction logged**: an earlier draft of this document claimed `moa_clubs` had no middleware and therefore only
client-side auth guarding. That was wrong — Next 16 renames `middleware.ts` to **`proxy.ts`**, and `src/proxy.ts`
does guard `/dashboard/:path*` server-side. See §4.1.

---

## 1. Verdict

Stability is in better shape than architecture. Tests and CI now exist in all six repos, the backend has been
security-hardened, and `flutter analyze` is clean (8 info-level lints). The problems that remain are **structural**:

- The Flutter app is **two architectures in one codebase** — a clean-architecture path that works, and a legacy
  `APIService` path that 22 presentation files still use. Three of its abstraction layers are dead code.
- `moa_clubs` is Next.js **in name only**: 36 of 55 files are `"use client"`, zero server components fetch data,
  zero route handlers, no `middleware.ts`.
- The two Vite SPAs (`moa_admin_dashboard`, `moa_eventwebsite`) are the stated migration targets.
- A shared UI package (`moa-ui`) exists, is fully built, and has **zero consumers**.
- Three hand-maintained API type sets for one OpenAPI schema; two different auth models against one backend.
- The repo wiring is broken: four gitlinks with **no `.gitmodules` and no submodule URLs** — a fresh clone cannot build.

The target is reachable without a rewrite. The ordering below front-loads the work that removes duplication, because
every day the three web apps stay separate is another day of triplicated types, clients and components.

---

## 2. Current state

| Repo | Stack | Size | Tests | Gap to target |
|---|---|---|---|---|
| root (Flutter) | Riverpod + go_router, Dart 3.6 | 151 files / 28.2k LOC | 4 files | Partial clean arch, dead layers, 2 network stacks |
| `moa_backend` | FastAPI + SQLModel + Alembic | 104 files / 15.6k LOC | 12 files | Not in restack; fat services, dual auth, no CSRF |
| `moa_clubs` | Next.js 16 App Router, React 19 | 55 files / 8.2k LOC | 2 files | Next.js shell over a CSR SPA |
| `moa_admin_dashboard` | Vite 8 + React 18 SPA | ~4.1k LOC src | 2 files | → Next.js |
| `moa_eventwebsite` | Vite 6 + React 19 SPA | 19 files / 1.35k LOC | 2 files | → Next.js (highest value) |
| `moa-ui` | tsup lib, GitHub Packages | 1.8k LOC | 3 files | Built, published, **unused** |

---

## 3. Flutter app — findings

The target stack is already chosen correctly. The problem is that the old stack was never removed, so both run
side by side and new code picks whichever is nearest.

### 3.1 Two networking stacks, and the UI uses the wrong one
- `lib/core/network/` is the real stack: `dio_client.dart` + 3 interceptors (auth/refresh, error, logging); the no-op cert-pinning one was removed in Phase 0.
- `lib/core/api/api_helper.dart` wraps it as an `APIService` singleton — and **this is the one in use**:
  **28 files** import `core/api/`, with **54 `APIService.instance` call sites**.
- **22 of those files are in `presentation/` or `shared/widgets/`** — UI widgets issuing HTTP directly, with no
  repository, no datasource, no error mapping. Examples:
  `lib/features/events/presentation/pages/individual_event_page.dart`,
  `lib/features/clubs/presentation/pages/clubs_page.dart`,
  `lib/shared/widgets/custom_search_delegate.dart`,
  `lib/shared/widgets/explore_more_club_card.dart`.
- `lib/core/services/notification_service.dart` additionally uses `package:http` directly — a third client.

### 3.2 Three layers of dead abstraction
| Abstraction | Where | Actual usage |
|---|---|---|
| Use cases | 4 files under `features/*/domain/usecases/` + `core/usecases/usecase.dart` | **0 imports from presentation** |
| `Either` / `Failure` | `core/error/either.dart` (77 LOC), `failures.dart` (65 LOC) | `Either<` appears **only in its own definition file** |
| Secure storage #2 | `core/secure_storage/secure_storage.dart` (47 LOC) | **0 consumers** (the live one is `core/storage/secure_storage_service.dart`, 7 consumers) |

### 3.3 Riverpod is used, but not the version that's installed
- 11 hand-written `StateNotifier` subclasses, each with a bespoke `XState` class + `copyWith` — **~2.0k LOC of providers**
  that is mostly boilerplate.
- `riverpod_annotation` and `riverpod_generator` are declared in `pubspec.yaml` with **0 `@riverpod` annotations**
  (the only `.g.dart` in `lib/` is the envied output). The codegen dependency is paid for and unused.
- Two callback-"Cubit" classes survive outside Riverpod entirely and are constructed in `initState`:
  `lib/features/auth/presentation/pages/profile_check_page.dart:33` → `ProfileCubit(profileService: ProfileService())`.

### 3.4 go_router is correct but not exclusive
- One router with an auth `redirect` and an analytics observer — good: `lib/app/router/app_router.dart`.
- **11 `Navigator.push` / `MaterialPageRoute` sites across 5 files** bypass it, so those screens have no route
  identity and cannot be deep-linked: `club_profile_page.dart`, `reg_successfull_page.dart`, `settings_page.dart`,
  `profile_page.dart`, `individual_event_page.dart`.
- Params are passed untyped: `state.extra as Map<String, dynamic>?` with `extra?['accessToken'] ?? ''` — a silent
  empty-string fallback on a credential.

### 3.5 Layer coverage is uneven
| Feature | Layers present | LOC |
|---|---|---|
| auth, clubs, events, profile | data + domain + presentation | 4.9k / 4.6k / 6.2k / 3.2k |
| volunteer | **presentation only** | 1.65k |
| notifications | data + presentation (no domain) | 0.48k |
| home, main, common | presentation only | 0.6k / 0.15k / 0.08k |

`volunteer` is 1,654 LOC of check-in/scanner logic — the most correctness-sensitive feature in the app — with no
data or domain layer at all.

### 3.6 Three parallel model families
`lib/common/models/` (274 LOC) · `features/*/data/models/` (~1.4k) · `features/*/domain/entities/` (631).
Events alone: `common/models/events/event_model.dart` (248) + `events/data/models/event_models.dart` (335) +
`events/domain/entities/event_entity.dart` (223).

### 3.7 God widgets (and they are the same files that call `APIService` directly)
`individual_event_page.dart` 1,572 · `ticket_view_page.dart` 1,086 · `club_profile_page.dart` 908 ·
`event_form_page.dart` 866 · `volunteer_scanner_page.dart` 721.

### 3.8 Other
- The envied setup was broken such that **a fresh clone could not compile the app at all**, and mobile CI could never
  pass. Full diagnosis and fix in §8.3 — the short version is that `@EnviedField` was on getters, which the generator
  does not scan, so codegen produced an empty `_Env`.
- Lints are stock `flutter_lints` only — nothing enforces any of the boundaries above.
- Directory typo: `features/auth/presentation/pages/widgest/`.

---

## 4. Web — findings

### 4.1 `moa_clubs` — Next.js shell, CSR internals
- **36 / 55 files** are `"use client"`. Verified: **every `page.tsx` in the app is a client component**, there are
  **0 route handlers** (no `route.ts` anywhere), **0 server actions** (no `"use server"`), and **0 async server
  components**. `src/app/api/` contains axios modules (`jsonAPI.ts`, `formAPI.ts`, `axiosGlobalSetup.ts`) — not
  `route.ts` files — so the name is actively misleading.
- Server-side route guarding **does** exist, via `src/proxy.ts` — Next 16's renamed `middleware.ts`. It matches
  `/dashboard/:path*` and redirects when the `access_token` cookie is absent. It is deliberately a presence check
  only (no signature/expiry validation), documented in the file as a UX-layer guard with real enforcement on the API.
  So the cookie migration did land properly here; this is the pattern the other two apps should copy.
- **Three API access patterns coexist**: `jsonAPI`/`formAPI` instances (11 files), bare global `axios` configured
  through `axiosGlobalSetup.ts` (8 app files), and per-file `axios.create`.
- **Live breakage from the cookie migration** — 4 files still read `localStorage.getItem("accessToken")`, and
  **nothing writes that key any more**:
  - `src/app/dashboard/clubEdit/page.tsx:91` — `if (!API_BASE_URL || !token) return;` → the club edit page never loads.
  - `src/app/dashboard/clubProfile/page.tsx:99` — same shape.
  - `src/app/components/dashboard/volunteer.tsx:42,84,111` — sends `Authorization: Bearer null`.
  - `src/app/utils/socialsRegistration.ts:28` — throws `"Authentication error: Access token missing"`.
- `src/app/dashboard/dashScreen/page.tsx` is 1,159 LOC.
- Registration is a 5-page wizard passing state through `sessionStorage`.
- Good precedent worth copying: event create/edit **was** consolidated into `dashboard/event/_shared/` with 7–11 LOC
  page shims. That is the pattern the rest of the app should follow.

### 4.2 `moa_eventwebsite` — the strongest case for Next.js
It is the public, link-shared, SEO-relevant surface, and it is 100% client-rendered:
- `index.html` has a static `<title>Myotherapp</title>` and **no OG/Twitter/description meta at all**;
  no component sets `document.title`. Every shared event link produces an identical, preview-less card.
- `vercel.json` rewrites `/(.*)` → `/` (SPA fallback), so crawlers get an empty shell.
- 19 files, 1.35k LOC, plain per-component CSS, no state library, no UI kit → the cheapest migration and the
  biggest external payoff.

### 4.3 `moa_admin_dashboard`
- Cleanest source layout of the three: `api/` + `hooks/` (TanStack Query) + `pages/` + `store/` (Zustand) +
  `components/ui` (shadcn). This ports to Next almost mechanically.
- **JWT in `localStorage`** via `zustand/persist` — XSS-exposed, and inconsistent with `moa_clubs`' httpOnly cookies,
  even though the backend supports both (`app/core/auth/dependencies.py:24`).
- `src/api/client.ts:4` hardcodes a production fallback: `|| "https://api.myotherapp.in"`.
- `App.tsx` wraps **every** route in `<DashboardLayout>` by hand — precisely what Next nested layouts remove.
- React 18 while the other two web apps are on React 19.

### 4.4 `moa-ui` — built, published, unused
Exports 16 components, `./hooks`, `./api` (`create-api-client.ts`) and `./preset.css`; publishes to GitHub Packages
via `.github/workflows/publish.yml`. **No app depends on it.** It also sits **untracked** inside the parent repo's
working tree (`?? moa-ui/` in `git status`), one careless `git add -A` away from being committed into the Flutter repo.

---

## 5. Backend — findings

Not part of the restack (it stays Python), and it is the healthiest repo. Architecture notes that affect the restack:

- Layout is consistent: `app/api/<domain>/{router,service,schemas,models}.py`, with `events/registration` and
  `events/volunteer` already demonstrating sub-domain splitting.
- **Fat services** carry the complexity: `events/service.py` 912 · `clubs/service.py` 839 ·
  `events/registration/service.py` 790 · `users/service.py` 559 · `badges/service.py` 540 · `events/router.py` 582.
- **Dual auth, no CSRF.** `get_current_user` accepts a Bearer header *or* an `access_token` cookie
  (`app/core/auth/dependencies.py:24`); cookies are `httponly`, `samesite="lax"`, host-only, no CSRF token anywhere
  in the codebase. **This is the binding constraint on web deployment** — see §6.3.
- Debug scripts still sit at the repo root (`backend_test_*.py`, `test_*.py`, `verify_fix.py`, `add_volunteer.py`,
  `remote_test_attendance.py`, `token.txt`), alongside `service-account.json` and `wallet_certs/`.
- `/openapi.json` is the one authoritative API contract in the ecosystem and nothing consumes it yet.

### Rebrand stragglers (the product moved finnet.app → myotherapp.in)
- `app/api/payments/background_tasks.py:29` → `sender="payments@finnet.app"`, display name `"Finnet Payments"`
- `app/api/events/registration/background_tasks.py:29` → `sender="events@finnet.app"`

Both **bypass `SES_DEFAULT_SENDER`** and hardcode the old domain. Whether payment receipts and registration
confirmations are currently failing depends on which domain identity is verified in production SES — the local
`.env` only has a placeholder, so this needs checking against the real SES config.
(The app's Apple **bundle ID** in `lib/firebase_options.dart` and the backend's `APPLE_CLIENT_ID` is an identifier,
not a domain, so the rebrand leaves it alone. It is `app.myotherapp.in` since 2026-10-28, when the app moved to the
Firebase project `myotherapp-in` for its first store release; it was `app.myotherapp.com`.)

---

## 6. Target architecture

### 6.1 Flutter: one path, three layers, no ceremony

```
presentation/   Riverpod Notifier/AsyncNotifier (@riverpod codegen) + widgets
      ↓ depends on
domain/         entities + repository interfaces          ← the only types presentation sees
      ↑ implemented by
data/           repository impl → remote datasource → ApiClient (core/network)
```

Decisions to make explicit, because the current code hedges on all three:

1. **Delete the use-case layer.** It has zero call sites today. At this size, notifiers calling repositories is the
   pragmatic clean-architecture variant; keeping 4 unused use-case files and a `UseCase` base class is pure cost.
   Repository *interfaces* stay — they are what makes the layers real.
2. **Delete `Either`/`Failure`.** `AsyncValue` already is the Either, and Riverpod gives error/loading for free.
   Standardize on datasources throwing typed `ApiException` and notifiers exposing `AsyncValue`.
3. **Delete `core/api/APIService`.** Fold `requestTyped`'s ergonomics into a datasource base class, then migrate the
   54 call sites. This is the single largest piece of the Flutter work and the one that actually buys architecture.

Plus: one model family (`domain/entities` crosses layers, `data/models` are DTOs, delete `lib/common/models/`);
delete the dead `core/secure_storage/`; `StateNotifier` → `@riverpod` codegen; all navigation through named go_router
routes with typed params; give `volunteer` and `notifications` real data/domain layers; split the five god widgets.

**Enforce it in CI**, or it regresses: add `custom_lint` + `riverpod_lint`, and an import-boundary check that fails
the build when `presentation/` imports `data/` or when anything outside `data/` imports `core/network/`.

### 6.2 Web: one Turborepo, three Next apps, four shared packages

```
moa_web/
  apps/events      public event pages — server components + ISR + generateMetadata (fixes OG/SEO)
  apps/clubs       organizer dashboard — in-place conversion of moa_clubs
  apps/admin       platform admin — port of moa_admin_dashboard
  packages/ui      moa-ui moved in (ends the zero-consumer problem)
  packages/api     generated from /openapi.json — types + typed client, one source for all three apps
  packages/auth    cookie session helpers + shared middleware guard
  packages/config  eslint / tsconfig / tailwind presets
```

`packages/api` is the highest-leverage piece: it replaces three hand-maintained type sets with one generated from the
backend's own schema (`openapi-typescript` + a thin fetch wrapper), and a CI check that fails when the committed
client drifts from the live schema turns every breaking API change into a red build instead of a runtime 422.

Rendering rules per app: server components for reads, route handlers / server actions for writes, `"use client"` only
on genuinely interactive leaves. `middleware.ts` guards every protected segment server-side.

### 6.3 Auth and the deployment constraint (decide before migrating anything)

Standardize all three web apps on **httpOnly cookies** — the backend already supports it, and it is what lets
middleware guard routes. Drop the admin app's `localStorage` JWT.

But the current cookie is `SameSite=Lax` and host-only, set by the API host. That works **only** while every web app
is served from a subdomain of the same registrable domain as the API (`clubs.myotherapp.in` → `api.myotherapp.in` is
same-site; `something.vercel.app` → `api.myotherapp.in` is **cross-site and the cookie is silently dropped**).

Two ways out, pick one:
- **Subdomain-only deployment.** Cheapest. Preview deployments on `*.vercel.app` will not be able to authenticate.
- **BFF proxy (recommended).** A Next route handler `app/api/[...path]/route.ts` per app forwards to the backend.
  The browser only ever talks to its own origin, so cookies are first-party everywhere, previews work, and **CORS
  disappears entirely**. It also gives one place to add CSRF protection, which the backend currently has none of.

### 6.4 Repo layout — fix this first, it is cheap and currently broken

Four directories are recorded as gitlinks (mode `160000`) with **no `.gitmodules` and no `submodule.*.url` in
`.git/config`**. A fresh `git clone --recurse-submodules` produces four empty directories. Remotes exist and are
known (`github.com/my-other-app/{moa_backend, moa_admin_dashboard, moa_clubs, moa_events, moa_ui}`), so this is
recoverable right now — and will not be, once someone's laptop is gone.

End state: **three repos** — `moa_mobileapp` (Flutter), `moa_backend`, `moa_web` (the Turborepo, absorbing
`moa_clubs` + `moa_admin_dashboard` + `moa_eventwebsite` + `moa-ui`). Either commit a real `.gitmodules` in the
interim, or drop the gitlinks entirely and clone the siblings independently.

---

## 7. Plan, in dependency order

Rationale for the ordering: unblock the repo, stop the bleeding, then build the shared foundation **before** porting
apps onto it — porting first means porting twice.

| # | Phase | Why here | Rough size |
|---|---|---|---|
| 0 | Repo wiring: `.gitmodules` (or collapse), commit/remove `moa-ui`, `env.g.dart` regen | A clone must build before anything else matters | ~0.5 day |
| 1 | Live bug fixes (§8) | Known-broken pages and possibly-failing emails, today | ~1 day |
| 2 | `moa_web` Turborepo skeleton + `packages/config` + `packages/ui` (move `moa-ui` in) | Foundation; nothing else can share code until it exists | ~2 days |
| 3 | `packages/api` generated from `/openapi.json` + CI drift gate | Kills 3 duplicate type sets; every later port consumes it | ~2 days |
| 4 | Auth decision + `packages/auth` + BFF proxy pattern | Must precede app ports — it changes every data-fetch call | ~2–3 days |
| 5 | `apps/events` (port `moa_eventwebsite`) | Smallest, validates the whole pattern, fixes OG/SEO immediately | ~3 days |
| 6 | `apps/admin` (port `moa_admin_dashboard`) | Mechanical: layouts → nested layouts, hooks → server components | ~4–5 days |
| 7 | `apps/clubs` (convert `moa_clubs` in place, then move in) | Largest; split `dashScreen` (1,159 LOC), unify 3 API patterns | ~6–8 days |
| 8 | Flutter: delete `APIService`, migrate 54 call sites to repositories | The core of the Flutter restack | ~5–6 days |
| 9 | Flutter: delete dead layers, `@riverpod` codegen, one model family, go_router-only nav | Mostly deletion once step 8 lands | ~4–5 days |
| 10 | Flutter: data/domain for `volunteer` + `notifications`, split god widgets | Highest-risk feature gets a real architecture | ~4 days |
| 11 | Guardrails: import-boundary lints, `riverpod_lint`, coverage floors in CI | Without these, 8–10 regress | ~1–2 days |
| 12 | Backend: split the 4 fat services, move debug scripts out, add CSRF | Independent of the above; can run in parallel | ~3–4 days |

Phases 8–12 are independent of 2–7 and can run in parallel if more than one person is working.
Sizes are estimates for one person familiar with the code, excluding QA.

---

## 8. Live bugs found during this assessment

Not architecture — things that are broken right now.

1. **`moa_clubs`: four files read a `localStorage` key nothing writes.** The club edit and club profile pages return
   early and never load their data; the volunteer component sends `Bearer null`; social registration throws.
   `clubEdit/page.tsx:91`, `clubProfile/page.tsx:99`, `components/dashboard/volunteer.tsx:42,84,111`,
   `utils/socialsRegistration.ts:28`. Fix: delete the token plumbing, let the cookie do its job (requests already
   send `withCredentials`).
2. **Backend: two transactional emails hardcode `@finnet.app` senders** and bypass `SES_DEFAULT_SENDER`
   (`payments/background_tasks.py:29`, `events/registration/background_tasks.py:29`). Needs checking against the
   verified SES identity in production; if the identity moved to `myotherapp.in`, payment receipts and registration
   confirmations are failing silently in a background task.
3. **Flutter: the envied setup was broken, and the app only built on one machine.** [FIXED]
   `env.dart` put `@EnviedField` on **getters**, but envied's generator scans *fields* — so a clean codegen run
   emitted `final class _Env {}` with no members at all. The only reason the app compiled was a stale, **gitignored**
   `env.g.dart` (`*.g.dart` is in `.gitignore`) sitting on one developer's disk. Consequences, all verified:
   - A fresh clone could not compile the Flutter app — 4 hard analyzer errors (`uri_has_not_been_generated`,
     3× `undefined_identifier: _Env`), reproduced by hiding the local artifact.
   - **Mobile CI could never pass.** `.github/workflows/ci.yml` ran `flutter analyze` with no codegen step, so the
     gate was decorative.
   - `obfuscate: true` was never taking effect — the values were plain string constants in the build.
   Fixed by converting the getters to `static final` fields (obfuscated values are computed at runtime, so they
   cannot be `const`), and by adding a codegen step to CI that sources `.env` from `.env.example` — which also means
   adding an `@EnviedField` without updating `.env.example` now fails CI loudly instead of breaking the next clone.
4. **No `.gitmodules` and no submodule URLs** — a fresh clone of the umbrella repo is unbuildable. [FIXED: written,
   `git submodule init` registered all four, and each pinned commit confirmed present on its remote]
5. **`moa-ui` is untracked inside the Flutter repo's working tree** — at risk of being committed into the wrong repo.
   [FIXED: `/moa-ui/` ignored in the parent; its sole commit is confirmed pushed to `origin/main`, so nothing is at
   risk of being lost]
6. **The dev machine's disk is 100% full** — 157 MB free of 228 GB. This is what crashed the Dart compiler
   (`No space left on device`). Largest reclaimable items measured: `~/.pub-cache` 2.3 GB,
   `~/Library/Developer/CoreSimulator/Devices` 2.0 GB, `moa_backend/backend/.venv_test` 497 MB, `.dart_tool` 194 MB,
   `build` 72 MB. Note that ~45 GB of the volume is unaccounted for by `du` — likely APFS local snapshots or
   purgeable space, which is worth checking separately.

---

## 9. What this plan deliberately does not do

- **Does not rewrite the backend.** It is the healthiest repo; it gets service splitting and CSRF, not a restack.
- **Does not put the admin dashboard on Next.js for SEO reasons** — it is an internal tool behind a login and gains
  nothing there. The reasons are shared packages, nested layouts, server-side auth guarding and one stack to maintain.
  If that trade does not feel worth it, keeping admin on Vite while it consumes `packages/ui` + `packages/api` is a
  defensible alternative.
- **Does not introduce a state library to `apps/events`.** Server components plus URL state cover it.
- **Does not change the Apple/Firebase bundle IDs** as part of the domain move — those are identifiers, not domains.
  (They moved separately, to `app.myotherapp.in` with the Firebase project `myotherapp-in`, on 2026-10-28.)
