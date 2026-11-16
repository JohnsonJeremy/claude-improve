#!/bin/bash
# Builds the Apple Reminders MCP server on this Mac and packages it as a
# Claude desktop extension (apple-reminders.mcpb).
#
#   ./build.sh          build + package
#   ./build.sh test     build + package, then create/edit/delete one test reminder
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This must be run on a Mac." >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "The Swift compiler is missing. Run:  xcode-select --install" >&2
  echo "Then run this script again." >&2
  exit 1
fi
macos_major="$(sw_vers -productVersion | cut -d. -f1)"
if (( macos_major < 14 )); then
  echo "macOS 14 (Sonoma) or newer is required; this Mac runs $(sw_vers -productVersion)." >&2
  exit 1
fi

BUNDLE=build/bundle
BIN="$BUNDLE/server/reminders-mcp"
rm -rf build
mkdir -p "$BUNDLE/server"

echo "Compiling..."
xcrun swiftc -O -swift-version 5 Sources/main.swift -o "$BIN" \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist

echo "Signing (ad hoc, local only)..."
codesign --force --sign - --options runtime \
  --identifier local.apple-reminders-mcp \
  --entitlements entitlements.plist "$BIN"
codesign --verify --strict "$BIN"

cp manifest.json "$BUNDLE/manifest.json"
(cd "$BUNDLE" && zip -q -r -X ../apple-reminders.mcpb .)

echo
echo "Built: $(pwd)/build/apple-reminders.mcpb"
echo "Check: $BIN --doctor"

if [[ "${1:-}" == "test" ]]; then
  echo
  "$BIN" --self-test
fi
