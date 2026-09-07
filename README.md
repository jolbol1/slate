# Slate for iPad

A native, offline UIKit slate targeting iOS 12 or later, including the original iPad Air. Open `Slate.xcodeproj` in Xcode 16 or later. There are no third-party dependencies.

**Slate layout.** The striped clapper bar across the top is the clap button. Under it sit the production title, the date and the lock status, then a row of tags: camera roll, camera letter, sound roll, frame rate, INT/EXT, DAY/NIGHT and SYNC/MOS. The three big counter cards are Scene, Shot and Take. Below them are the written lines for director, camera (DP or operator), filter and notes, and at the bottom the lock button and the clock.

- Scene and Take start at 1, with independent +/− buttons (0–9999).
- Shot starts at **A** and its +/− buttons move through **A–Z**, stopping at either end. Existing saved shot numbers map to letters (1 → A, 2 → B, etc.; values outside 1–26 clamp to A or Z). Scene, Take and lock state are preserved.
- Take returns to 1 whenever Scene or Shot changes. Settings can turn this off. Settings can also step Take up by one after each clap.
- **Written details**: production, director, camera (DP or operator), camera roll, sound roll, filter and notes. Tap the production title, any written line, or the roll tags to open the **Slate Details** sheet. Each keystroke saves. Text is limited to the width of a real slate line.
- **Tags** toggle in place with one tap: camera letter A–Z, INT/EXT, DAY/NIGHT and SYNC/MOS. The FPS tag opens a frame-rate picker.
- The date comes from the device clock and is shown as, for example, 7 SEP 2026.
- Double-tap the lock button within 0.6 seconds to lock or unlock. A single tap does nothing. While locked, the counters, tags, written lines and the details editor are all disabled.
- **Tap to Clap** plays a short, locally bundled sync sound, drops the sticks and flashes the screen. It remains available while the slate is locked. Settings can switch between the natural clap and a clean beep, adjust volume, or turn the flash off.
- Counters, details, lock state and settings save on every change in this app's local UserDefaults and restore on reopening. Saves from earlier versions open with empty details. Deleting the app removes its saved values. Reinstall over the existing app with the same bundle identifier to retain them.
- **Settings** groups: slate sound (clap or beep, volume, screen flash, preview), take counter (reset on new scene or shot, next take after clap), clock timecode (24, 25, 30, 48, 50 or 60 fps), slate (edit details, reset counters to Scene 1 · A · Take 1) and the Fully Free Apps promise. Reset and clear actions ask for confirmation.
- Portrait and landscape layouts on iPad and iPhone, large high-contrast numbers, and an awake display while the app is active.
- A continuously updating `HH:MM:SS:FF` local time-of-day reference at **24 fps** by default, including while locked. It follows the device clock; it is not synced to a camera or an external timecode source.
- VoiceOver and Switch Control can activate the lock with their normal accessibility activation gesture. Every tag and written line has an accessibility label and value.

The app follows the **Fully Free Apps** promise: free to download and use, with no ads, in-app purchases, accounts, analytics or tracking. It has no network code or third-party SDKs. Fully Free Apps is a trading name of MWD Studios Ltd. See [APP_STORE.md](APP_STORE.md) for the publishing plan and [PRIVACY.md](PRIVACY.md) for the privacy-policy draft.

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

With an iPad simulator installed, choose it in Xcode and press **⌘U** to exercise the counter controls, details editor, lock, relaunch persistence, and portrait/landscape layouts. The UI tests launch the app with `--reset-state`, which clears the app's saved values in that simulator.

To run the UI tests on one simulator and collect screenshots into `build/shots`:

```sh
scripts/screenshots.sh "iPad Air 11-inch (M4)" ipad
scripts/screenshots.sh "iPhone 17" iphone
```

The clap and beep files are original, deterministic PCM audio generated by `scripts/generate-sounds.py`. They can be regenerated without downloading anything.
