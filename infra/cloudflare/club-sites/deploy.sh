#!/bin/bash
# Uploads the club-sites Worker and routes *.myotherapp.in/* to it.
# Needs a Cloudflare token with Account › Workers Scripts › Edit and
# Zone › Workers Routes › Edit, stored as an "Authorization: Bearer …" header
# line in ~/.config/moa/cloudflare.authheader (mode 600).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ACCOUNT="e29f4da682f820b5ce4381163a1baf4a"
ZONE="9b1fdc0d2717f7aefff5145ee0853d67"
AUTH="@$HOME/.config/moa/cloudflare.authheader"

curl -sS -H "$AUTH" -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/workers/scripts/club-sites" \
  -F 'metadata={"main_module":"worker.js","compatibility_date":"2024-09-23"};type=application/json' \
  -F "worker.js=@$here/worker.js;type=application/javascript+module"
echo
if ! curl -sS -H "$AUTH" "https://api.cloudflare.com/client/v4/zones/$ZONE/workers/routes" | grep -q '"pattern":"\*.myotherapp.in/\*"'; then
  curl -sS -H "$AUTH" -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/workers/routes" \
    -H "Content-Type: application/json" --data '{"pattern":"*.myotherapp.in/*","script":"club-sites"}'
  echo
fi
