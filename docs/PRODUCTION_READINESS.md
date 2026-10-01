# Production readiness assessment

Assessed 2026-10-01. Every claim here was checked against the deploy workflows, `docker-compose.prod.yml`,
`main.py`, `app/config.py` and the repos' CI — not inferred.

## Verdict

**The system is production-*running*, not production-*ready*.** The code is in reasonable shape: auth has been
hardened, there are 31 backend tests, every repo has a CI gate, and the mobile gate actually works now. The weak
half is **operations**. Specifically, three things would each be a bad day:

1. **There are no database backups at all.** Postgres runs in a Docker volume on one host. A disk failure or a bad
   migration loses every user, club, event, ticket and payment record, with no recovery path.
2. **Nothing is watching.** No health endpoint, no error tracking on the backend, no uptime monitoring. If the API
   starts 500ing at 2am you find out from a user.
3. **Migrations are a separate manual checkbox from deploys**, so code can ship without the schema change it needs.

None of these are hard to fix, and none require the architecture work in `ARCHITECTURE_PLAN.md`. They are also the
difference between "it works" and "it keeps working".

---

## Area by area

| Area | State | Verdict |
|---|---|---|
| Correctness / tests | 31 backend, 7 mobile, 5 clubs, 2 admin, 2 events tests; CI in all 6 repos | **good**, coverage thin |
| Security (app-level) | IDOR fixes, token revocation, bcrypt, security headers, auth rate limits, cert pinning | **good**, gaps below |
| Dependencies | GitHub reports **7 vulns on backend default branch — 1 critical, 4 high, 2 moderate** | **needs work** |
| Deploy / release | Manual `workflow_dispatch`, 10 independent toggles, `rsync --delete` | **weak** |
| Data safety | **No backups. No tested restore.** | **critical gap** |
| Observability | No `/health`, no Sentry, no uptime check, no log shipping | **critical gap** |
| Capacity / resilience | 1 uvicorn worker, single container, single DB, in-memory rate limiter | **fragile** |
| Environments | dev-deploy workflow + `nginx_staging.conf` exist | **ok**, verify parity |

### 1. Deploy and release — weak

`live-deploy.yml` is `workflow_dispatch` only, with ten independent booleans (`sync_code`, `migrate`,
`install_requirements`, `restart_all`, …). Concretely:

- **Deploy is `rsync -avz --delete` of a git checkout**, then a container restart. There is no versioned artifact, so
  **there is no rollback** — reverting means re-running the workflow from an older commit and hoping.
- **`migrate` is a toggle an operator must remember.** Code and schema can diverge in production. This is the most
  dangerous property of the current pipeline.
- **`install_requirements` pip-installs inside the running container.** That is not baked into the image, so it
  silently vanishes on the next `up --build` — guaranteed prod drift between restarts.
- **Nothing deploys on merge, and no deploy is tied to a green CI run.** The gates exist but don't gate releases.
- The web apps' CI never deploys, so those releases happen manually / on Vercel's side, outside this pipeline.

**Fix**: build a tagged image in CI → push to a registry → deploy by tag. Run `alembic upgrade head` as a mandatory
release step, not a checkbox. Keep the previous tag so rollback is one command.

### 2. Data safety — critical gap

- **No `pg_dump`, no WAL archiving, no snapshot schedule anywhere in the repos.**
- `restart: on-failure` on both services means **they do not come back after a host reboot** (use `unless-stopped`).
- Postgres publishes **`6432:5432` on the host** — reachable from anywhere the host firewall permits.
- `backend` has no healthcheck, and `depends_on: postgres` has no `condition: service_healthy`, so the API can start
  against a DB that isn't accepting connections yet.

**Fix, in order**: nightly `pg_dump` to off-host storage (S3/R2) with retention → **perform a real restore into a
scratch DB and confirm row counts** (an untested backup is not a backup) → `restart: unless-stopped` → stop
publishing 6432 publicly → add a backend healthcheck and gate startup on Postgres being healthy.

### 3. Observability — critical gap

- **No health endpoint** (`grep -rn "health" app` → nothing).
- **No Sentry / error tracking / tracing** in the backend (`grep -rniE "sentry|rollbar|opentelemetry"` → nothing).
- No uptime monitoring and no log shipping; logs stay in the container.
- Mobile is the exception and is done properly: Crashlytics + Analytics, with `runZonedGuarded` catching async errors.

**Fix**: `/health` returning liveness + a DB ping, wired into the compose healthcheck and an external uptime check;
Sentry in the backend and all three web apps; decide who gets notified and how.

### 4. Capacity and resilience — fragile

- `WORKERS: int = 1` — the API is a single process. Fine for current load, but one slow request blocks others.
- `uvicorn.run(..., workers=settings.WORKERS, reload=settings.DEBUG)`: **`reload` and `workers` are mutually
  exclusive in uvicorn**, so if `DEBUG` is ever true in production you silently get the dev reloader and lose
  multi-worker behaviour. `DEBUG` defaults to `False`, so this is a latent trap, not a current bug.
- `slowapi` rate limiting uses an **in-memory store** — correct at 1 worker, silently wrong the moment you scale to
  multiple workers or instances, because each process keeps its own counters.
- Single DB container, no replica, no connection pooler beyond SQLAlchemy's pool.

**Fix**: raise workers once there's a healthcheck to prove readiness; move rate limiting to Redis **before** scaling,
not after; keep `DEBUG=False` enforced in prod config.

### 5. Security — good, with specific outstanding items

Already done (earlier hardening passes): volunteer/ticket IDOR fixes, webhook idempotency, order/payment
confusion check, soft-deleted users blocked from login, token revocation on password change, advisory lock against
double-charge, money as `Numeric(10,2)`, security headers, auth endpoint rate limits, JS disabled in PDF rendering.

Outstanding:

- **7 dependabot alerts on the backend's default branch (1 critical, 4 high)** — new since the July CVE sweep.
  Triage these; `gh auth` is currently expired on this machine so I could not read the details.
- **No CSRF protection**, and cookie auth is now a first-class path. `SameSite=Lax` blocks the classic cross-site
  form POST, so this is not urgent — but any XSS on a sibling subdomain can forge authenticated requests. The BFF
  proxy in `ARCHITECTURE_PLAN.md` phase 4 is where this gets solved properly.
- **The Apple Wallet private key is still in git history and has never been rotated** (needs your Apple Developer
  account). Carried over from the July audit and still open.
- Admin dashboard keeps its JWT in `localStorage`, so any XSS there reads an admin token. Resolved by moving admin
  onto cookie auth in the restack.
- Certificate endpoints have no auth — a deliberate, documented decision, because the mobile app opens them in an
  external browser with no way to attach a token. Revisit if that flow changes.

---

## How to manage it — operating rhythm

**Per change**
1. Branch → PR → CI green → merge. No direct pushes to default branches.
2. Deploy by image tag, with migrations as part of the release, not a toggle.
3. Smoke-check the money path (register → pay → ticket) and watch errors for 15 minutes.

**Weekly** — triage dependabot alerts; skim error-tracker volume for new recurring failures.

**Monthly** — restore a backup into a scratch database and verify it. Review who has prod SSH and GitHub access.

**Per release of the mobile app** — confirm `env.g.dart` regenerates in CI (it does now) and that the store build
points at the right API host.

---

## Priority order — the next two weeks

| # | Task | Why first | Size |
|---|---|---|---|
| 1 | Nightly `pg_dump` off-host **+ a tested restore** | Nothing else matters if the data is gone | ~0.5 day |
| 2 | `/health` + uptime monitor + Sentry (backend + web) | You currently cannot tell if prod is broken | ~1 day |
| 3 | Triage the 1 critical + 4 high dependabot alerts | Known, published, exploitable | ~0.5 day |
| 4 | Make `alembic upgrade head` part of deploy, not a toggle | Removes the schema/code divergence risk | ~0.5 day |
| 5 | `restart: unless-stopped`, unpublish 6432, backend healthcheck | Survives a reboot; shrinks attack surface | ~0.5 day |
| 6 | Image-tag deploys + documented rollback | Makes releases reversible | ~1–2 days |
| 7 | Rotate the Apple Wallet key | Needs your Apple account | ~1 hour |

Items 1–5 are roughly three days of work and move this from "production-running" to "production-ready". The
architecture restack is worth doing, but **none of it is a prerequisite for any of the above** — and if you only ever
do one thing from this document, do item 1.
