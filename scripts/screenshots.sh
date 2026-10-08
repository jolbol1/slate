#!/bin/bash
# Runs the UI tests on one simulator and saves screenshots to build/shots/<prefix>-*.png.
# Usage: scripts/screenshots.sh "iPad Air 11-inch (M4)" ipad
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [ "$#" -ne 2 ] || [[ ! "$2" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo 'Usage: scripts/screenshots.sh "Simulator name" output-prefix' >&2
    exit 1
fi
device="$1"; prefix="$2"
out="build/shots"; mkdir -p "$out"
udid="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for v in d.values() for x in v if x["name"]==sys.argv[1]))' "$device")"
xcrun simctl boot "$udid" 2>/dev/null || true

run_test() {
    local name="$1"; local result="build/$prefix-$name.xcresult"
    rm -rf "$result"
    xcodebuild -project Slate.xcodeproj -scheme Slate -sdk iphonesimulator -derivedDataPath build \
        -destination "id=$udid" test CODE_SIGNING_ALLOWED=NO -resultBundlePath "$result" \
        IPHONEOS_DEPLOYMENT_TARGET=15.0 \
        -only-testing:"SlateUITests/SlateUITests/$name" >"build/$prefix-$name.log" 2>&1 || {
        tail -60 "build/$prefix-$name.log" >&2
        return 1
    }
    grep -E "error:|failed|passed|Executed" "build/$prefix-$name.log" || true
}

run_test testSlateFieldsCountersLockAndRelaunch
run_test testPortraitLayoutSheetsAndTakeSettings

# Capture from test attachments before XCTest resets simulator orientation.
for test_name in testSlateFieldsCountersLockAndRelaunch testPortraitLayoutSheetsAndTakeSettings; do
tmp="$(mktemp -d)"
xcrun xcresulttool export attachments --path "build/$prefix-$test_name.xcresult" --output-path "$tmp" >/dev/null
python3 - "$tmp" "$out" "$prefix" <<'PY'
import json, os, re, shutil, sys
tmp, out, prefix = sys.argv[1:4]
for test in json.load(open(os.path.join(tmp, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName", "")
        m = re.match(r"^(details-sheet|settings-sheet|portrait|landscape|landscape-locked)_", name)
        if m:
            shutil.copy(os.path.join(tmp, a["exportedFileName"]), os.path.join(out, f"{prefix}-{m.group(1)}.png"))
            print(os.path.join(out, f"{prefix}-{m.group(1)}.png"))
PY
rm -rf "$tmp"
done

# Bake screenshot orientation into PNG pixels for App Store size validation.
for shot in "$out/$prefix-"*.png; do
    swift scripts/normalize-screenshot.swift "$shot"
    mv "${shot%.png}.normalized.png" "$shot"
done
