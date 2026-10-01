# Production readiness assessment

Assessed 2026-10-01, then **verified against the live server on 2026-10-02** (`ubuntu@44.208.217.219`,
`/var/www/myotherapp-production`). Everything below is observed, not inferred. Where the first pass was wrong —
because it reasoned from the repo instead of production — the correction is called out explicitly.

## Verdict

**Production-*running*, not production-*ready*.** The application code is in good shape, and the live server confirms
the July security hardening is actually deployed (cookie auth, token revocation, refund flow all present).
The gaps are operational, and the live server turned out to be in worse shape than the repo suggested.

The five things that matter, in order:

1. **The production Postgres is reachable from the public internet.** `doth-postgres` publishes `0.0.0.0:5432`, the
   host firewall is **inactive** (`ufw status` → inactive), and the AWS security group permits it — confirmed by
   connecting to `44.208.217.219:5432` from outside. It is password-protected (`pg_hba.conf` ends with
   `host all all all scram-sha-256`), so this is serious but not instantly fatal: it exposes the DB to brute force
   and means any credential leak is a full data breach. **MongoDB on `0.0.0.0:27017` is also publicly open** (the
   `bcards` project on the same box).
2. **There are still no real backups.** The whole database is **11 MB** (669 users, 42 events) — a `pg_dump` takes
   seconds. What exists: a cron backup for a *different* project (`/var/www/pulsetap-live/backup.sh` → Google Drive)
   and two one-off dumps sitting on the same disk as the database, `myotherapp_dump.sql` from **Oct 2025** and
   `doth_backup_pre_migration_...dump` from **Jul 2026**. One disk failure loses everything.
3. **Releases are untraceable from the server.** Deploys are `rsync` with no `.git` directory, so nothing on the box
   records which commit is running — you have to checksum the tree against the repo to find out (which is what was
   done here; see the corrections table). The code itself *is* current.
4. **The host has not been rebooted in 587 days**, `/var/run/reboot-required` is present, and **100 packages are
   upgradable**. The running kernel is `6.8.0-1021-aws`.
5. **Nothing is watching.** No health endpoint, no backend error tracking, no uptime monitoring.

---

## Corrections to the first pass

| First pass said | Production reality |
|---|---|
| "1 uvicorn worker" (from `config.py`'s default) | **`APP_WORKERS=3`.** So `slowapi`'s in-memory rate limiter is **already wrong today** — three processes keep three independent counters, making `/auth/token`'s 5/min effectively up to 15/min. Not a future scaling problem. |
| Hardcoded `@finnet.app` senders meant emails were failing silently | **Wrong.** `APP_SES_DEFAULT_SENDER` is itself on `finnet.app`, and nginx still serves `api.finnet.app` beside `api.myotherapp.in`. The hardcoded addresses matched the verified identity; **no emails were broken.** The change on `fix/email-sender-domain` is therefore config hygiene, not a bug fix, and it *does* change the From address — see that branch's commit message. |
| "The deployed code is over two months old — ~2 months of merged work unreleased" | **Wrong, and the most important correction here.** Inferred from file mtimes (newest `2026-07-25`), which `rsync -a` preserves from the source and which therefore say nothing about the deployed version. Checksumming the real thing: all **104** `app/**/*.py` files are byte-identical to `origin/master` (`14badec`), as are all 33 migration/template/config files (only `__pycache__/*.pyc` differ). Production carries `14badec`'s change (`subject=f"Ticket: ... - Finnet"`). Alembic is at head. Every installed package matches `requirements.txt` exactly, including the July CVE bumps (fastapi 0.139.2, starlette 1.3.1, pillow 12.3.0, cryptography 49.0.0). **Production is fully up to date.** |
| "Postgres publishes 6432 on the host" | **The repo's `docker-compose.prod.yml` is not what runs.** It defines `doth-live-postgres`/`6432:5432` and `doth-live-backend`/`8001:8000`. The live stack is from the plain `docker-compose.yml`: `doth-postgres`/**`5432:5432`** and `doth-backend`/`8000:8000`. The prod compose file is misleading dead config. |
| `restart: on-failure` means services won't survive reboot | Still true in both compose files, and with 587 days of uptime **this has never been tested**. |

---

## Live server inventory

**Host**: Ubuntu 24.04.2 LTS, kernel 6.8.0-1021-aws, 3.8 GiB RAM, 29 GB disk (70% used, 8.7 GB free),
**no swap**, load ~1.1–1.5, uptime 587 days.

**Memory is the tight constraint**: 2.8 GiB used, **1.0 GiB available, zero swap** — an OOM kill is plausible under
load, and with no swap there is no cushion.

**This is a shared box running four unrelated projects**, which multiplies the blast radius of any one of them:

| Container | Status | Published |
|---|---|---|
| `doth-backend` | Up 2 months | `0.0.0.0:8000` |
| `doth-postgres` | Up 2 months (healthy) | **`0.0.0.0:5432`** |
| `letmego-backend-prod` | Up 7 months (healthy) | `0.0.0.0:6002` |
| `letmego-postgres-prod` | Up 7 months (healthy) | `0.0.0.0:7433` |
| `bcards-backend` | Up 3 months (**unhealthy**) | — |
| `bcards-nginx` | Up 7 months (**unhealthy**) | `0.0.0.0:7001` |
| `bcards-mongo` | Up 7 months (**unhealthy**) | **`0.0.0.0:27017`** |

Externally reachable (tested from off-host): **5432 open, 27017 open**; 6432/8000/7433/6002 filtered. So the AWS
security group is doing the firewalling, inconsistently, and `ufw` is off entirely.

**What is healthy**: Alembic is at `add_order_status_refunded (head)`, matching the repo — **no pending migrations**.
The deployed backend does contain `_set_auth_cookies`, the cookie fallback in `dependencies.py`, `token_version`
revocation and the refund endpoint. `APP_DEBUG=False`. nginx terminates TLS for `api.finnet.app`,
`api.myotherapp.in` and both staging equivalents, and certbot is in `/etc/cron.d`.

---

## Server inventory — what else is on this box

**Three separate products share this one 3.8 GiB host**, each with a production and a dev/staging directory:

| Product | Directories | Running containers | Live upstream | Disk |
|---|---|---|---|---|
| **myotherapp / finnet** (this one) | `myotherapp-production`, `myotherapp-dev` | `doth-backend`, `doth-postgres` | `:8000` | 5.3 MB + 1.7 MB |
| **letmegoo** | `letmego-production`, `letmego-dev` | `letmego-backend-prod`, `letmego-postgres-prod` (postgis) | `:6002` | 48 MB + 33 MB |
| **pulsetap** | `pulsetap-live`, `pulsetap-dev` | `bcards-backend`, `bcards-nginx`, `bcards-mongo` — **all three unhealthy for months** | `:7001` | 2.8 MB + 2.5 MB |

The `bcards-*` containers are built from `pulsetap-live-*` images, so despite the name they are the pulsetap
project, not a fourth product. Only production stacks run; every dev stack is stopped, though their data volumes
remain (65 MB + 64 MB + 412 MB).

### Your "staging" API is production

Verified by request, not by reading config:

| Hostname | Result | Routes to |
|---|---|---|
| `api.myotherapp.in` | HTTP 200 | `:8000` — production |
| **`api.staging.myotherapp.in`** | **HTTP 200** | **`:8000` — the same production backend** |
| `api.finnet.app` | HTTP 200 | `:8000` — production (old domain still live) |
| `api.staging.finnet.app` | connection failure | `:8000`, but no usable cert |
| `api.myotherapp.com` | HTTP 403 | `:8001` — **nothing listens there** |

**Every staging hostname resolves to the production backend and production database.** There is no running staging
environment, even though `myotherapp-dev` and its `myotherapp-dev_postgres_data` volume exist. Anyone who believes
they are testing against staging is reading and writing live user, event and payment data. This supersedes the
earlier note that "a staging path exists — verify parity": there is no parity to verify, because there is no staging.

### Dead nginx vhosts

Four vhosts proxy to ports where nothing listens: `api.myotherapp.com` → 8001, `dev-api.letmegoo.com` and
`dev-location.letmegoo.com` → 6001, and the four `*.dev.pulsetap.in` names → 7002.

### Reclaimable space

Disk is 70% full with 8.7 GB free. `docker system df` reports **4.18 GB reclaimable images** (47% of 8.88 GB) and
585 MB reclaimable volumes, plus the 541 MB of stopped-dev volumes above — roughly 5 GB recoverable without
touching anything live.


---

## Server spec, and why it is the bottleneck

**AWS EC2 `t2.medium`** — `i-09ee9bd54aec1788d`, **us-east-1b** (N. Virginia), AMI `ami-04b4f1a9cf54c11d0`.

| | |
|---|---|
| vCPU | 2 (Intel Xeon E5-2686 v4 @ 2.30 GHz, Broadwell) |
| Hypervisor | **Xen** — pre-Nitro generation |
| RAM | 3.8 GiB usable, **no swap** |
| Disk | 30 GB EBS root (`xvda`), 29 GB usable, 70% used, 8.7 GB free |
| OS | Ubuntu 24.04.2 LTS, kernel 6.8.0-1021-aws, uptime 587 days |

### It is being CPU-throttled right now

`vmstat` over four samples shows **steal time of 37%, 71%, 71%, 76%**, with idle at 0–11% and a run queue of 7–17
on 2 cores. Load average 2.82 and rising.

Steal time that high means the hypervisor is withholding the CPU: **the t2.medium has burned through its CPU credits
and is pinned near its 40% baseline.** The instance is effectively running on well under one vCPU. This is not a
future capacity concern — it is the current state, and it is the most likely explanation for any slowness users
report. A `journalctl` scan during this assessment was slow enough that the SSH connection was reset.

Top CPU consumers are three `containerd-shim` processes (32.8%, 32.6%, 22.1%) and — notably —
**`bcards-mongo` at 20.15%**, an *unhealthy container belonging to a different product*, which is burning the CPU
credits that the myotherapp API needs.

### Memory

| Container | Memory | % of host |
|---|---|---|
| `doth-backend` (3 workers) | 692 MiB | 17.7% |
| `letmego-backend-prod` | 577 MiB | 14.8% |
| `bcards-backend` | 242 MiB | 6.2% |
| `bcards-mongo` | 137 MiB | 3.5% |
| `letmego-postgres-prod` | 62 MiB | 1.6% |
| `doth-postgres` | 40 MiB | 1.0% |

~1.75 GiB in containers, 2.8 GiB used overall, **1.0 GiB available with zero swap**. No OOM events in the current
`dmesg` buffer, but there is no cushion — and `APP_WORKERS=3` on 2 throttled vCPUs is itself part of the problem.

### Wrong region for the user base

The server is in **us-east-1 (Virginia)** while the product is Indian: the domain is `myotherapp.in`, payments go
through Razorpay, and the application's own SES client is hard-coded to **`ap-south-1` (Mumbai)**. So every API call
from a user in India crosses to Virginia and back (~200 ms+ RTT before any processing), and the backend's outbound
email hops back to Mumbai. Moving to `ap-south-1` would cut a large constant off every request.

### Sizing recommendation

Cheap, immediate (no migration):
1. **Stop the unhealthy pulsetap/`bcards` stack** — it is consuming ~20% CPU and ~380 MiB for a product whose
   containers have been unhealthy for months. Biggest single win available.
2. **Add swap** (2–4 GB) — removes the OOM cliff on a no-swap box.
3. **Reclaim ~5 GB** of docker images and stopped-dev volumes.
4. **Reconsider `APP_WORKERS=3`** on 2 throttled vCPUs; it also makes the rate limiter inaccurate.

Then, properly:
5. **Move off `t2`.** `t3.medium` is Nitro-based, cheaper than `t2.medium`, and supports `unlimited` mode so credit
   exhaustion degrades cost instead of performance. Given current memory pressure, **`t3.large` (2 vCPU / 8 GiB)**
   is the more honest size for three production stacks.
6. **Separate the databases** from the app host — managed RDS, or at minimum their own instance. This also solves the
   public-5432 problem structurally rather than by firewall rule.
7. **Relocate to `ap-south-1`** when you next have a maintenance window, for latency.


---

## Security

Already done (earlier hardening, confirmed deployed): IDOR fixes, webhook idempotency, order/payment confusion
check, soft-deleted users blocked from login, token revocation, advisory lock against double-charge, money as
`Numeric(10,2)`, security headers, auth rate limits, JS disabled in PDF rendering.

Outstanding:

- **Public Postgres (5432) and public MongoDB (27017)**, with `ufw` inactive. Highest-priority item.
- **Dependabot: 9 alerts on the backend's default branch — 1 critical, 5 high, 3 moderate.** This was 7 earlier the
  same day, so it is growing. `gh auth` is expired locally, so the details need reading in the GitHub UI.
- **587 days without a reboot, 100 upgradable packages, reboot flagged as required.** Unpatched kernel and libraries.
- **No CSRF protection** while cookie auth is a first-class path. `SameSite=Lax` blocks the classic cross-site POST;
  an XSS on any sibling subdomain can still forge requests. Solved properly by the BFF proxy in the restack plan.
- **Rate limiting is per-process with 3 workers** — the documented limits are not the effective limits.
- **The Apple Wallet private key is still in git history and has never been rotated** (needs the Apple Developer
  account). Carried over from the July audit, still open.
- Admin dashboard keeps its JWT in `localStorage`; resolved by moving it to cookie auth in the restack.
- Certificate endpoints have no auth — a deliberate, documented trade-off for the mobile external-browser flow.

---

## Priority order

Revised after seeing production. Items 1–4 are about a day of work in total.

| # | Task | Why | Size |
|---|---|---|---|
| 1 | Close 5432 and 27017 to the internet (security group + enable `ufw`); bind DB ports to `127.0.0.1` in compose | An authenticated-but-exposed production database is the single largest risk | ~1 hr |
| 2 | Nightly `pg_dump` to off-host storage **+ one tested restore** | 11 MB database; this is minutes of work and currently a total-loss risk | ~2 hrs |
| 3 | `/health` + uptime monitor + Sentry (backend and web) | You cannot currently tell whether prod is broken | ~1 day |
| 4 | Triage the 1 critical + 5 high dependabot alerts | Known, published, and the count is rising | ~0.5 day |
| 5 | Schedule a patch-and-reboot window (100 packages, reboot required) | Also the first real test of `restart:` policy — do it deliberately, not via a crash | ~1 hr + window |
| 6 | Make releases identifiable — stamp the deployed commit (build arg / `VERSION` file / image tag) | Nothing on the box says what is running; this assessment had to checksum the tree to find out | ~2 hrs |
| 7 | Add swap (or resize); 1.0 GiB available with no swap | Removes the OOM cliff | ~15 min |
| 8 | Move rate limiting to Redis, or set `WORKERS=1` | Current limits are ~3x their documented values | ~0.5 day |
| 9 | Delete or fix the unused `docker-compose.prod.yml` | It describes a stack that isn't running — a trap for the next deploy | ~15 min |
| 10 | Image-tag deploys + documented rollback; migrations as a release step | Makes releases reversible and repeatable | ~1–2 days |
| 11 | Rotate the Apple Wallet key | Needs your Apple account | ~1 hr |
| 12 | Clean up / isolate the three unhealthy `bcards` containers | They consume RAM on a 3.8 GiB box and expose Mongo | ~1 hr |

Items 1 and 2 are roughly three hours together and remove the two risks that could end the product. Nothing in the
architecture restack is a prerequisite for any of this.
