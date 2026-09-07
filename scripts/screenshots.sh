#!/bin/bash
# Runs the UI tests on one simulator and saves screenshots to build/shots/<prefix>-*.png.
# Usage: scripts/screenshots.sh "iPad Air 11-inch (M4)" ipad
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
device="$1"; prefix="$2"
out="build/shots"; mkdir -p "$out"
bundle="com.james.local.slate2026"
udid="$(xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for v in d.values() for x in v if x['name']=='$device'))")"
xcrun simctl boot "$udid" 2>/dev/null || true

run_test() {
    local name="$1"; local result="build/$prefix-$name.xcresult"
    rm -rf "$result"
    xcodebuild -project Slate.xcodeproj -scheme Slate -sdk iphonesimulator -derivedDataPath build \
        -destination "id=$udid" test CODE_SIGNING_ALLOWED=NO -resultBundlePath "$result" \
        -only-testing:"SlateUITests/SlateUITests/$name" 2>&1 | grep -E "error:|failed|passed|Executed" || true
}

shoot() {
    xcrun simctl launch "$udid" "$bundle" >/dev/null
    sleep 3
    xcrun simctl io "$udid" screenshot "$out/$prefix-$1.png" >/dev/null
    echo "$out/$prefix-$1.png"
}

run_test testSlateFieldsCountersLockAndRelaunch
shoot landscape-locked
run_test testPortraitLayoutSheetsAndTakeSettings
shoot portrait

# Sheets are attached by the portrait test.
tmp="$(mktemp -d)"
xcrun xcresulttool export attachments --path "build/$prefix-testPortraitLayoutSheetsAndTakeSettings.xcresult" --output-path "$tmp" >/dev/null
python3 - "$tmp" "$out" "$prefix" <<'PY'
import json, os, re, shutil, sys
tmp, out, prefix = sys.argv[1:4]
for test in json.load(open(os.path.join(tmp, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName", "")
        m = re.match(r"^(details-sheet|settings-sheet|portrait)_", name)
        if m:
            shutil.copy(os.path.join(tmp, a["exportedFileName"]), os.path.join(out, f"{prefix}-{m.group(1)}.png"))
            print(os.path.join(out, f"{prefix}-{m.group(1)}.png"))
PY
rm -rf "$tmp"
