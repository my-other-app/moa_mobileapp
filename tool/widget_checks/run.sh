#!/bin/sh
# Checks the widgets' Swift rules on a Mac (docs/HOME_WIDGETS.md, "Checks"):
# what "For you" picks from the front page -- against the picks the Dart
# tests hold (test/fixtures/widgets/for_you_expected.json) -- and the
# event-day card's clock. tool/widget_checks/run.sh
# Needs Xcode's command-line tools.
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
W="$ROOT/ios/NextUpWidget"
BIN="$(mktemp -d)/check"
xcrun swiftc -O -target arm64-apple-macosx14.0 -o "$BIN" \
  "$ROOT/tool/widget_checks/main.swift" \
  "$W/ForYouData.swift" "$W/NextUpData.swift" "$W/EventDayAttributes.swift"
"$BIN" "$ROOT/test/fixtures/widgets"
