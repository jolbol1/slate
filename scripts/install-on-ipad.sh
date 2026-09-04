#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
slate_device_id="${1:-YOUR_DEVICE_UDID}"
slate_installer="$(command -v ios-deploy || true)"
if [ -z "$slate_installer" ] && [ -x /opt/homebrew/bin/ios-deploy ]; then
    slate_installer=/opt/homebrew/bin/ios-deploy
fi
if [ -z "$slate_installer" ]; then
    echo 'Install the USB installer first: brew install ios-deploy' >&2
    exit 1
fi

xcodebuild -project Slate.xcodeproj -scheme Slate -configuration Release \
    -destination "id=$slate_device_id" -derivedDataPath build/device \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration build

"$slate_installer" --id "$slate_device_id" \
    --bundle "$PWD/build/device/Build/Products/Release-iphoneos/Slate.app" \
    --no-wifi --timeout 15

echo 'Installed. Open Slate on the iPad. Existing saved numbers are preserved.'
