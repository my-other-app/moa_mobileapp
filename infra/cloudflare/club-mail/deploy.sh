#!/bin/bash
# Uploads the club-mail Worker (Email Routing's catch-all for myotherapp.in ->
# the API). Keeps its secret (MAILBOX_HOOK_SECRET, set by set-secret.sh) and
# sets its plain-text settings:
#   API_URL  where it posts (default: the production API's hook)
#   FORWARD  JSON {"local": "verified@address"} sent on without the API (default: none)
# Email Routing itself (enable, catch-all -> this Worker) is a dashboard step:
# README.md. Needs a Cloudflare token with Account › Workers Scripts › Edit,
# stored as an "Authorization: Bearer …" header line in
# ~/.config/moa/cloudflare.authheader (mode 600).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ACCOUNT="e29f4da682f820b5ce4381163a1baf4a"
AUTH="@$HOME/.config/moa/cloudflare.authheader"
API_URL="${API_URL:-https://api.myotherapp.in/api/v1/hooks/mailbox/cloudflare}"
FORWARD="${FORWARD:-}"
metadata=$(python3 - "$API_URL" "$FORWARD" <<'PY'
import json, sys
api_url, forward = sys.argv[1], sys.argv[2] or "{}"
json.loads(forward)  # FORWARD must be JSON
print(json.dumps({
    "main_module": "worker.js", "compatibility_date": "2024-09-23",
    "bindings": [{"type": "plain_text", "name": "API_URL", "text": api_url},
                 {"type": "plain_text", "name": "FORWARD", "text": forward}],
    "keep_bindings": ["secret_text"],
}))
PY
)
curl -sS -H "$AUTH" -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/workers/scripts/club-mail" \
  -F "metadata=$metadata;type=application/json" \
  -F "worker.js=@$here/worker.js;type=application/javascript+module" |
  python3 -c 'import json,sys; d=json.load(sys.stdin); print("uploaded" if d.get("success") else d.get("errors"))'
