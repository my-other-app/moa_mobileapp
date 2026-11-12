#!/bin/bash
# Gives the club-mail Worker its key (MAILBOX_HOOK_SECRET), read from a file
# that holds only the key: the same value as the server's
# APP_MAILBOX_HOOK_SECRET. The key never reaches the command line or a log.
#   ./set-secret.sh ~/.config/moa/mailbox-hook.secret
set -euo pipefail
file="${1:?usage: set-secret.sh <file holding the key>}"
ACCOUNT="e29f4da682f820b5ce4381163a1baf4a"
AUTH="@$HOME/.config/moa/cloudflare.authheader"
# macOS's own Python: a python3 earlier on the PATH may be a broken install.
PY="$(command -v /usr/bin/python3 || command -v python3)"
"$PY" - "$file" <<'PY' |
import json, sys
key = open(sys.argv[1]).read().strip()
if len(key) < 32:
    sys.exit("the key is shorter than 32 characters")
print(json.dumps({"name": "MAILBOX_HOOK_SECRET", "text": key, "type": "secret_text"}))
PY
  curl -sS -H "$AUTH" -H "Content-Type: application/json" -X PUT \
    "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/workers/scripts/club-mail/secrets" --data @- |
  "$PY" -c 'import json,sys; d=json.load(sys.stdin); print("secret set" if d.get("success") else d.get("errors"))'
