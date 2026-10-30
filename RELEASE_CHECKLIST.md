# Release checklist (Google Play + Apple App Store)

Status legend: ✅ done · 🟡 in progress · ⬜ not started · 👤 needs owner action

## Identity (owner decisions)

- 👤 Final game title (current "Tap Tap Cricket" is provisional; needs trademark/store search)
- 👤 Publisher name and support contact email/URL
- ✅ No team, player, bowler or commentator names are shown in the game
- ✅ Icons for both stores (adaptive + themed Android, 1024 App Store without alpha, 512 Play) and Play feature graphic — from the game's own vector icon; replace if you want a designer icon

## Build & platform

- ✅ Godot 4.7.2 + matching templates pinned and verified
- ✅ Windows/Linux exports; release builds exclude the dev harness and tests
- ✅ Android debug APK exported by CI every push (target SDK 36, min 24, arm64 + armv7, VIBRATE only, 16 KB aligned); version code = build number
- 👤 Android application id confirmation (`com.taptapcricket.game` is a placeholder and becomes permanent at the first Play upload); ✅ versioning; ✅ adaptive icons
- 👤 Android upload keystore: generate and back up **outside** the repository (password manager + offline copy); never commit
- 🟡 App Bundle (.aab) built by CI (`Android Store` preset); signed for Play once the upload key is added as GitHub secrets (see STORE_LISTING.md)
- 👤 Play Console account, identity verification, and check which testing-track requirements apply to the account (e.g. closed testing with testers before production for new personal accounts — verify current policy)
- 👤 Mac access for iOS (Xcode version per current Godot docs), Apple Developer account, team selection, device pairing
- ✅ iOS Xcode project export + unsigned compile verified on a Mac in CI (icons, iPhone+iPad, all orientations, ITSAppUsesNonExemptEncryption=NO, privacy manifest); 👤 signing with your Apple team and archive/upload
- ⬜ TestFlight build (only after approval)

## Quality gates

- ✅ Automated rules/scoring/save tests passing
- 🟡 Aspect ratios (16:9, 20:9, 4:3 both orientations), back button, suspend-pause and CPU per frame verified in the harness; 👤 real-device check
- ⬜ Human play-test (first-use questions in PROGRESS.md)
- ⬜ Crash/error cleanup on devices

## Store materials

- ✅ Screenshots captured from gameplay: Play phone 1920x1080 / 1080x1920, iPhone 6.9" 2868x1320 / 1320x2868, iPad 13" 2752x2064 (`store/screenshots`, RGB)
- ✅ Short/long description and answers for Data safety, IARC/age rating, App Privacy, export compliance (`STORE_LISTING.md`)
- ✅ Privacy policy (`PRIVACY_POLICY.md`); 👤 add contact email and publish at a public URL
- ✅ Licence/credits screen in-app: Settings → Credits & licences (Godot MIT + third parties, Lato OFL)

## Approvals (never automatic)

- 👤 Explicit approval required for: any purchase, any store submission, accepting legal agreements, public release.
