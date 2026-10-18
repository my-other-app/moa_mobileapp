# Media CDN at `media.myotherapp.in`

A Cloudflare Worker in front of the S3 bucket. It serves the public pictures — event posters, club logos and covers, speakers', team members' and partners' photos, posts' images, the stock avatars and store photos — from Cloudflare's edge near the viewer. No new vendor: DNS is already on Cloudflare.

Until now, every one of these pictures reached a browser as a presigned S3 link from us-east-1. That meant about 280 ms per hop from India, a different address every few days (so nothing could cache it for long), and S3 egress on every view.

## How it fits together

- **Backend:** with `APP_MEDIA_CDN_URL=https://media.myotherapp.in`, every public picture in an API response, on a club's site, in a link preview or behind an email is handed out as `https://media.myotherapp.in/<key>`. The address is built in one place, `app/core/storage/media.py`. Unset, the backend hands out the signed links exactly as before.
- **Route:** `media.myotherapp.in/*` → `media`. This is more specific than club-sites' `*.myotherapp.in/*`, so it wins for this host. club-sites also lists `media` as reserved.
- **Allow-list:** only one file directly inside one of these folders, with a `.png`, `.jpg`, `.jpeg`, `.webp` or `.gif` name, is ever served:
  - `clubs/logos/` (holds event posters too)
  - `clubs/covers/`
  - `clubs/team/`
  - `clubs/partners/`
  - `clubs/threads/`
  - `events/speakers/`
  - `avatars/`
  - `events/{id}/merch/`

  Anything else gets a 404 without S3 being asked. That covers tickets and certificates (`docs/`), template art and signatures (`templates/`), designer uploads (`…/layout/`), email pictures, event files, close-out reports and profile pictures. The list lives in three places that must agree: `media.js` here, `PUBLIC_FOLDERS` in the backend's `app/core/storage/media.py`, and the IAM policy below.
- **Reading S3:** the bucket is private, so the Worker signs each `GetObject` itself with AWS Signature V4 (`sigv4.js`, using WebCrypto, no SDK). The key it signs with can read the public folders and nothing else.
- **Cache:** the Worker uses the Cache API, keyed by the path alone. A query string never creates a new copy, so it can't be used to push every request through to S3.

  | Key | `Cache-Control` |
  |---|---|
  | Versioned: `v-<32 hex>.<ext>` and its sizes `v-<hex>.<size>.<ext>`. The backend writes these once and never again. | `public, max-age=31536000, immutable` |
  | Older: uuid names from before versioning | `public, max-age=3600, s-maxage=86400` (an hour in the browser, a day at the edge) |
  | Missing | `public, max-age=60` |
- **Headers:** the content type comes from the extension, not from S3. S3's `ETag` and `Last-Modified` are passed on, and a matching `If-None-Match` or `If-Modified-Since` gets a 304. Every response also carries `Access-Control-Allow-Origin: *` and `X-Content-Type-Options: nosniff`. `x-cache: HIT|MISS` shows where the answer came from.
- **Abuse:** pictures are meant to be shown anywhere: the app, emails, WhatsApp previews, other sites. Most requests carry no `Referer`, so there is no Referer check. Abuse is bounded in three ways:
  - the path-only cache key;
  - the minute-long cache of a missing key;
  - `MISS_LIMITER`, which allows 300 S3 reads per minute per client address per Cloudflare location. Cache hits are never counted.
- **Errors:**
  - S3 refuses the signature, fails or can't be reached: 502, never cached.
  - A secret is missing: 503, never cached.
  - S3 says `AccessDenied`: treated as a missing key (404). This is what S3 answers about a missing key to a reader without `s3:ListBucket`.

## Sizes: made at upload, not resized on the fly

Every public image column already makes its sizes when the picture is uploaded: `thumbnail`, `medium` and `large`, from 100 to 1,800 pixels wide. They sit next to the original in the bucket. The backend lists them in the `srcset` of a club site's images, and the app and the public site pick a size by name. They cost nothing per request and are a fixed set of addresses, which is what a cache wants.

On-the-fly resizing (`?w=` through Cloudflare Image Transformations) was considered and left out:

- **Limit:** the zone is on the Free plan, which allows 5,000 unique transformations a month. Past that, a new size of a new picture fails with error 9422 until the month turns over. On Images Paid, each 1,000 beyond the allowance costs $0.50. With a few sizes per picture, a growing catalogue would reach that limit.
- **Setup:** transformations are a zone setting to turn on in the dashboard. Nothing here may change the zone.

It can be added later behind a fixed allow-list of widths if a size is ever missing.

## Before switching it on: the Workers plan

On the Workers Free plan, an account gets **100,000 requests a day across all its Workers**, and club-sites already uses part of that. Every picture view is one Worker request, whether it is a cache hit or a miss.

So move the account to **Workers Paid** before `APP_MEDIA_CDN_URL` carries real traffic. It costs $5 a month with 10 million requests included, then $0.30 per million. For scale: 50,000 people a day each viewing 40 pictures is about 60 million requests a month, roughly $20. The S3 egress for the same views would be about 6 TB.

## Switch it on, in this order

Each step is safe on its own. Nothing changes for anyone until step 6.

### 0. Deploy the backend with the setting off

Deploy the branch with `APP_MEDIA_CDN_URL` unset. Responses stay exactly as they were. New uploads are stored under versioned names (`v-<hex>`).

### 1. A read-only key for the Worker (AWS console)

1. In **IAM → Users → Create user**, create `moa-media-cdn` with no console access.
2. Attach this inline policy. Replace `BUCKET` with the backend's `APP_S3_BUCKET`. If `APP_S3_BASE_PATH` is not empty, put it in front of each folder.

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "MediaCdnReadsPublicPicturesOnly",
         "Effect": "Allow",
         "Action": "s3:GetObject",
         "Resource": [
           "arn:aws:s3:::BUCKET/clubs/logos/*",
           "arn:aws:s3:::BUCKET/clubs/covers/*",
           "arn:aws:s3:::BUCKET/clubs/team/*",
           "arn:aws:s3:::BUCKET/clubs/partners/*",
           "arn:aws:s3:::BUCKET/clubs/threads/*",
           "arn:aws:s3:::BUCKET/events/speakers/*",
           "arn:aws:s3:::BUCKET/avatars/*",
           "arn:aws:s3:::BUCKET/events/*/merch/*"
         ]
       }
     ]
   }
   ```

   - **No `s3:ListBucket`:** without it, a missing key answers 403, and the Worker serves that as a 404.
   - **SSE-KMS:** if the bucket encrypts with its own KMS key, also allow `kms:Decrypt` on that key. The default encryption (SSE-S3) needs nothing more.
3. Under **Security credentials → Create access key**, create a key for an "Application running outside AWS". Keep the key ID and secret for step 4.

### 2. DNS (Cloudflare dashboard → `myotherapp.in` → DNS → Records)

| Type | Name | IPv6 address | Proxy status | TTL |
|---|---|---|---|---|
| AAAA | `media` | `100::` | **Proxied** | Auto |

`100::` is the "originless" address for a Worker that answers every request itself. The proxied wildcard `*.myotherapp.in` already covers `media`, but an explicit record keeps it working if the wildcard ever changes. An exact name wins over the wildcard.

### 3. Deploy the Worker

From this folder, with the token club-sites deploys with. It needs Workers Scripts Edit and Workers Routes Edit on the account:

```
cd infra/cloudflare/media
export CLOUDFLARE_API_TOKEN="$(sed -n 's/^Authorization: Bearer //p' ~/.config/moa/cloudflare.authheader)"
npx wrangler deploy
```

This uploads `worker.js`, `media.js` and `sigv4.js`, and adds the route `media.myotherapp.in/*`. Until step 4, the Worker answers 503 and caches nothing.

If `APP_S3_BASE_PATH` is not empty, set `S3_BASE_PATH` in `wrangler.toml` to the same value first. Check that `S3_REGION` is the bucket's region: S3 console → the bucket → Properties → AWS Region.

### 4. Secrets

Each `secret put` takes effect at once and survives later deploys. Unlike `[vars]`, they are never in `wrangler.toml`.

```
npx wrangler secret put S3_BUCKET              # the backend's APP_S3_BUCKET
npx wrangler secret put S3_ACCESS_KEY_ID       # from step 1
npx wrangler secret put S3_SECRET_ACCESS_KEY   # from step 1
```

### 5. Check a few pictures through the CDN

Take a real key from what the API hands out now. A signed link's path is the key:

```
url=$(curl -s https://api.myotherapp.in/api/v1/discover/home | grep -o 'https://[^"]*amazonaws\.com/[^"?]*' | grep -E '/(clubs|events|avatars)/' | head -1)
key=${url#*amazonaws.com/}
curl -sI "https://media.myotherapp.in/$key"   # 200, content-type image/…, x-cache: MISS
curl -sI "https://media.myotherapp.in/$key"   # x-cache: HIT
etag=$(curl -sI "https://media.myotherapp.in/$key" | sed -n 's/^etag: //Ip' | tr -d '\r')
curl -sI -H "If-None-Match: $etag" "https://media.myotherapp.in/$key"   # 304
curl -sI "https://media.myotherapp.in/docs/ticket/x/0-a.pdf"            # 404, S3 never asked
```

Run `npx wrangler tail media` alongside to see each request. A 502 with "S3 refused our signature" in the tail means one of these is wrong: the key, the secret, the region or the bucket name.

### 6. Turn it on in the backend

1. Add this line to the server's `.env`:

   ```
   APP_MEDIA_CDN_URL=https://media.myotherapp.in
   ```

2. Recreate the backend so it reads the new `.env`, always from a freshly
   built image (`--build`), and with stdin closed:

   ```
   sudo docker-compose -f docker-compose.prod.yml up -d --build --no-deps backend < /dev/null
   ```

   A plain `up -d backend` recreates from whatever image is on the box. On
   2026-10-17 that image lacked a package installed only by `exec pip`, and
   production was down for 20 minutes. Check that `.env` is the current one
   before recreating: it has been overwritten by a stale copy before.

A malformed value (a path, a query) stops the backend at startup, so watch it come up. From then on, every response hands out CDN addresses. The app and the public site pick them up as their caches expire: the discover site's pages within a few minutes.

### 7. Publish the club sites again

A published club site is a stored page. Pages made before step 6 still point their images at the API's image route. That still works, because the route now redirects to the CDN, but it costs a hop per picture. Publish every site again:

```
sudo docker-compose -f docker-compose.prod.yml exec -T backend python scripts/republish_sites.py < /dev/null
```

The nightly refresh would get there within a day anyway.

### 8. Optional: deploy club-sites again

`./deploy.sh` in `../club-sites` makes it treat `media` as one of our names. The media route already wins for this host, so this is only belt and braces.

## Turning it off

1. Remove `APP_MEDIA_CDN_URL` from the server's `.env`.
2. Recreate the backend.
3. Republish the club sites (step 7).

Responses go back to signed links. **Keep the Worker running:** addresses already handed out keep working through it. Those are link previews cached by WhatsApp and others, pages in browsers' caches, and the app's image cache.

## Removing a picture for good

A versioned picture may be kept for a year: by browsers, which can't be reached, and by Cloudflare. For a picture that must disappear, for example one taken down for privacy:

1. Delete the object in S3.
2. Purge its address: Cloudflare dashboard → Caching → Configuration → **Custom Purge** → URL.

## Test locally

```
node --test test/*.test.js     # or: npm test
```

`test/worker.test.js` runs the Worker under Node 18+ with S3 (`fetch`), the edge cache (`caches.default`) and the rate limiter stubbed. It covers:

- which paths are pictures and which are never served;
- signing against AWS's worked example and botocore's own output;
- versioned and older keys;
- HEAD, query strings and conditional requests;
- S3's refusals;
- the miss limit.

`npx wrangler deploy --dry-run` checks `wrangler.toml` and bundles the Worker without uploading anything.
