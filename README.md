# Slate for iPad

A native, offline UIKit slate targeting iOS 12 or later, including the original iPad Air. Open `Slate.xcodeproj` in Xcode 16 or later. There are no third-party dependencies.

- Scene and Take start at 1, with independent +/− buttons (0–9999).
- Shot starts at **A** and its +/− buttons move through **A–Z**, stopping at either end. Existing saved shot numbers map to letters (1 → A, 2 → B, etc.; values outside 1–26 clamp to A or Z). Scene, Take and lock state are preserved.
- Double-tap the lock button within 0.6 seconds to lock or unlock. A single tap does nothing. All six counter buttons are disabled while locked.
- Numbers and lock state save on every change in this app's local UserDefaults and restore on reopening. Deleting the app removes its saved values. Reinstall over the existing app with the same bundle identifier to retain them.
- Portrait and landscape layouts, large high-contrast numbers, and an awake display while the app is active.
- A continuously updating `HH:MM:SS:FF` local time-of-day reference at **24 fps**, including while locked. It follows the iPad's clock; it is not synced to a camera or an external timecode source.
- VoiceOver and Switch Control can activate the lock with their normal accessibility activation gesture.

## Install on your iPad for free

1. Open `Slate.xcodeproj` on your Mac.
2. In **Xcode → Settings → Accounts**, add your normal Apple Account. Accept Apple's free developer agreement if prompted. You do not need a paid Apple Developer Program membership.
3. Connect the iPad by USB, unlock it, and trust the Mac if prompted.
4. Select the **Slate** project, then the **Slate** app target → **Signing & Capabilities**. Keep **Automatically manage signing** enabled and choose your **Personal Team**. If the bundle identifier is unavailable, change `com.james.local.slate2026` to a unique identifier once.
5. Select your iPad as the run destination in Xcode's top toolbar.
6. **iOS 16 and later only:** If prompted, enable **Settings → Privacy & Security → Developer Mode** on the iPad, restart, and confirm. Pair with Xcode first if that option isn't visible.
7. Press **⌘R** in Xcode. If the iPad asks you to trust the developer, follow its instructions under **Settings → General → VPN & Device Management**.

After installation, unplug the iPad. The app works entirely offline. With a free Personal Team, the provisioning profile expires **7 days from issuance**. Build and run it again from Xcode to renew it. For a full week of use, install shortly before you need it, and keep the Mac available if it needs renewal. Keep the app installed and use the same bundle identifier when renewing.

The in-app lock prevents number changes; it does not stop Home gestures or the physical lock button. If you also need to prevent leaving the app, use iPad Guided Access.

Apple references: [Free Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account/), [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

## Development

If command-line tools are selected instead of Xcode, prefix commands with:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Run persistence, boundary and locking tests on the Mac:

```sh
swift test
```

Build for a simulator (no signing account required):

```sh
xcodebuild -project Slate.xcodeproj -scheme Slate -sdk iphonesimulator -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

With an iPad simulator installed, choose it in Xcode and press **⌘U** to exercise the counter controls, lock, relaunch persistence, and portrait/landscape layouts.
