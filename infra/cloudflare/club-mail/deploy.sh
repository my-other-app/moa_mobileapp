#!/bin/bash
# Uploads the club-mail Worker (Email Routing's catch-all for myotherapp.in ->
# the API). Keeps its secret (MAILBOX_HOOK_SECRET, set by set-secret.sh) and
# sets its plain-text settings:
#   API_URL  where it posts (default: the production API's hook)
#   FORWARD  JSON {"local": "verified@address"} sent on without the API (default: none)
#   BODY_SIGNATURE  "off" sends only the older signature (v1), not the one
#            that covers the body (v2); only while the API doesn't require v2
#            (default: both are sent)
# Email Routing itself (enable, catch-all -> this Worker) is a dashboard step:
# README.md. Needs a Cloudflare token with Account › Workers Scripts › Edit,
# stored as an "Authorization: Bearer …" header line in
# ~/.config/moa/cloudflare.authheader (mode 600).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ACCOUNT="e29f4da682f820b5ce4381163a1baf4a"
AUTH="@$HOME/.config/moa/cloudflare.authheader"
# macOS's own Python: a python3 earlier on the PATH may be a broken install.
PY="$(command -v /usr/bin/python3 || command -v python3)"
API_URL="${API_URL:-https://api.myotherapp.in/api/v1/hooks/mailbox/cloudflare}"
FORWARD="${FORWARD:-}"
BODY_SIGNATURE="${BODY_SIGNATURE:-}"
metadata="$(mktemp)"
trap 'rm -f "$metadata"' EXIT
# The metadata goes as a file part: curl's -F would read quotes and commas
# in an inline JSON value as its own syntax.
"$PY" - "$API_URL" "$FORWARD" "$BODY_SIGNATURE" > "$metadata" <<'PY'
import json, sys
api_url, forward, body_signature = sys.argv[1], sys.argv[2] or "{}", sys.argv[3]
json.loads(forward)  # FORWARD must be JSON
bindings = [{"type": "plain_text", "name": "API_URL", "text": api_url},
            {"type": "plain_text", "name": "FORWARD", "text": forward}]
if body_signature:
    bindings.append({"type": "plain_text", "name": "BODY_SIGNATURE", "text": body_signature})
print(json.dumps({
    "main_module": "worker.js", "compatibility_date": "2024-09-23",
    "bindings": bindings,
    "keep_bindings": ["secret_text"],
}))
PY
curl -sS -H "$AUTH" -X PUT "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/workers/scripts/club-mail" \
  -F "metadata=@$metadata;type=application/json" \
  -F "worker.js=@$here/worker.js;type=application/javascript+module" |
  "$PY" -c 'import json,sys; d=json.load(sys.stdin); print("uploaded" if d.get("success") else d.get("errors"))'
