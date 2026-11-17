# Club mail: `yourclub@myotherapp.in`

A Cloudflare Email Worker that brings every mail sent to an address on `myotherapp.in` to the API, so a club's mail shows in its dashboard (**Mail**) and `support@` / `sales@` reach the team's desk.

## How it fits together

- **DNS:** Email Routing's MX records on the domain (`route1/2/3.mx.cloudflare.net`), plus its SPF and DKIM TXT records. Cloudflare adds them when Email Routing is enabled. The domain had no MX before.
- **Rule:** Email Routing → Routing rules → **Catch-all address** → **Send to a Worker** → `club-mail`. Cloudflare runs the Worker once for each envelope recipient.
- **Worker:** `worker.js` posts the raw mail, signed with HMAC-SHA256, to `POST https://api.myotherapp.in/api/v1/hooks/mailbox/cloudflare`. The backend's `app/api/club_mailbox/cloudflare.py` checks the signature from the headers before reading the body. It then keeps the mail for the club whose address it is, or for the desk, and answers `accept` or `reject`.
- **Two signatures:** `X-Moa-Signature` (v1) covers the time, the envelope, the size and Cloudflare's Authentication-Results. `X-Moa-Signature-V2` (v2) covers the same values plus the body's SHA-256 (`X-Moa-Body-Sha256`), so the API also knows the body is the one signed. An API from before v2 checks v1 and ignores the rest. A newer one checks v2 when it is there, and requires it once `APP_MAILBOX_HOOK_REQUIRE_BODY_SIGNATURE=true`.
- **Rejected in the session:** for an address nobody has, a closed mailbox, or a mail that is too large, the Worker calls `setReject(...)`. The sender's own server tells them ("No mailbox here by that name"). A forged sender gets nothing back from us.
- **Never lost:** if the API is restarting or down, the Worker tries 3 times in about 10 s, then throws. Cloudflare gives the sending server a temporary error, and that server delivers again later. The API keeps a mail once even when it arrives twice.
- **Staff addresses:** `FORWARD`, a JSON object such as `{"info": "someone@gmail.com"}`, forwards that local part to an address you have verified in Email Routing (Destination addresses), without asking the API.
- **Logs:** each delivery's outcome only (`accepted`, `rejected:unknown`, `temporary_failure`). Never an address or any content.

Bindings:

| Name | Kind | Set by |
|---|---|---|
| `MAILBOX_HOOK_SECRET` | secret | `set-secret.sh`; the same value as the server's `APP_MAILBOX_HOOK_SECRET` |
| `API_URL` | text | `deploy.sh` (default: the production hook) |
| `FORWARD` | text | `deploy.sh` (`FORWARD='{"info":"x@gmail.com"}' ./deploy.sh`) |
| `MAX_BYTES` | text, optional | default 15 MiB (the API's `APP_MAILBOX_INBOUND_MAX_MB`); a larger mail is refused by its size before it is read |
| `BODY_SIGNATURE` | text, optional | `deploy.sh` (`BODY_SIGNATURE=off ./deploy.sh`); `off` sends v1 alone, as before. Only while the API doesn't require v2 |

## Turning it on

The order matters. Until the API has its key, the Worker's deliveries are answered 503, and senders get a temporary error and retry. Until Email Routing sends mail here, nothing reaches the Worker at all.

1. **Backend deployed** with the Cloudflare hook, and the stack's Caddy files (26 MB for the hook's path).
2. **The key.** Make it once: `openssl rand -hex 32 > ~/.config/moa/mailbox-hook.secret`, then `chmod 600` it.
   - On the server, add `APP_MAILBOX_HOOK_SECRET=<the key>` and `APP_CLUB_MAILBOX=true` to `/srv/moa/.env`.
   - Then run `./dc up -d --no-deps --force-recreate backend`.
3. **The Worker:** run `./deploy.sh`, then `./set-secret.sh ~/.config/moa/mailbox-hook.secret`.
4. **Email Routing:** in the Cloudflare dashboard, open myotherapp.in → Email → Email Routing.
   - Choose **Enable** and let it add its records.
   - Then Routing rules → Catch-all address → Edit → Action **Send to a Worker** → `club-mail` → Save, and make sure it is **Active**.
5. **Check:**
   - On a Pro or Enterprise club, set an address in Mail → Settings, then send it a mail from Gmail. It shows in Mail within seconds.
   - A mail to `nobody-xyz@myotherapp.in` comes back to Gmail as "No mailbox here by that name".
   - Workers → club-mail → Logs shows `accepted` / `rejected:unknown`.

**Rolling back:** set the catch-all back to Drop or Disabled (Cloudflare then refuses mail for the domain), or set `APP_CLUB_MAILBOX=false` (the Worker rejects everything).

## Signing the body (v2): the order

Each step is safe on its own, and a mail refused on the way is never lost (the sender's server tries again):

1. **Deploy the backend** that knows v2. It still takes v1, so the Worker running now goes on working.
2. **Deploy this Worker** (`./deploy.sh`). It sends v1 and v2; the backend checks v2. Send a test mail to a club address and check that the backend's log says `deliveries arrive signed v2` (it says so once per process).
3. **Require v2:** `APP_MAILBOX_HOOK_REQUIRE_BODY_SIGNATURE=true` in the server's `.env`, then recreate the backend. A delivery signed only with v1 is now refused (401 `body_unsigned`).

To go back: set the setting to `false` first. Only then deploy an older Worker, or `BODY_SIGNATURE=off ./deploy.sh`.

Hashing the body costs the Worker CPU time: little for a usual mail, a few milliseconds for one near 15 MiB. On the Workers Free plan (10 ms of CPU per mail), send a large test mail (about 10 MB) after step 2. If the Worker's logs show the CPU limit exceeded, run `BODY_SIGNATURE=off ./deploy.sh` and leave step 3 for later.

## Test locally

```
node --test test/*.test.js     # or: npm test
```

Two tests check the Worker's signatures (v1 and v2) against vectors the backend's own tests check too (`tests/test_club_mailbox_cloudflare.py`), so the two sides can't drift apart.
