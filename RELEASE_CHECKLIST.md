# Release checklist (Google Play + Apple App Store)

Status legend: ✅ done · 🟡 in progress · ⬜ not started · 👤 needs owner action

## Identity (owner decisions)

- 👤 Final game title (current "Pocket Boundary" is provisional; needs trademark/store search)
- 👤 Publisher name and support contact email/URL
- 👤 Confirm fictional team names (Pindi Falcons, Karachi Comets, Lahore Lanterns) after a public-branding check
- ⬜ Final icon and store art (current icon is a placeholder vector)

## Build & platform

- ✅ Godot 4.7.2 + matching templates pinned and verified
- ✅ Windows/Linux exports; release builds exclude the dev harness and tests
- 🟡 Android debug APK via CI (needs first CI run to confirm)
- ⬜ Android application id confirmation (`com.devtorque.pocketboundary` is a placeholder), versioning, adaptive icons
- 👤 Android upload keystore: generate and back up **outside** the repository (password manager + offline copy); never commit
- ⬜ Signed release AAB (after keystore)
- 👤 Play Console account, identity verification, and check which testing-track requirements apply to the account (e.g. closed testing with testers before production for new personal accounts — verify current policy)
- 👤 Mac access for iOS (Xcode version per current Godot docs), Apple Developer account, team selection, device pairing
- ⬜ iOS Xcode project export, signing, bundle id, icons, orientations, device families
- ⬜ TestFlight build (only after approval)

## Quality gates

- ✅ Automated rules/scoring/save tests passing
- ⬜ Device tests: touch latency, 60 FPS measurement, suspend/resume, aspect ratios, notches
- ⬜ Human play-test (first-use questions in PROGRESS.md)
- ⬜ Crash/error cleanup on devices

## Store materials

- ⬜ Screenshots captured from actual gameplay on each required device size
- ⬜ Short/long description; age rating questionnaires (no ads, no purchases, no data collection)
- ⬜ Privacy policy draft matching the actual build (currently: no network, no accounts, no analytics, local saves only; vibration permission on Android)
- ⬜ Licence/credits screen in-app (Godot MIT notice, Lato OFL)

## Approvals (never automatic)

- 👤 Explicit approval required for: any purchase, any store submission, accepting legal agreements, public release.
