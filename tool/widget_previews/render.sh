#!/bin/sh
# Draws the iOS widgets' views to PNG on a Mac (docs/HOME_WIDGETS.md,
# "Previews"): tool/widget_previews/render.sh [out-dir]
# Needs Xcode's command-line tools (macOS 14 or later).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/build/widget_previews}"
W="$ROOT/ios/NextUpWidget"
BIN="$(mktemp -d)/render"
xcrun swiftc -O -target arm64-apple-macosx14.0 -o "$BIN" \
  "$ROOT/tool/widget_previews/main.swift" "$ROOT/tool/widget_previews/PreviewData.swift" \
  "$W/WidgetStyle.swift" "$W/NextUpWidget.swift" "$W/NextUpData.swift" \
  "$W/NetworkingWidget.swift" "$W/NetworkingData.swift" "$W/QRCode.swift"
"$BIN" "$ROOT/assets/fonts" "$OUT"
