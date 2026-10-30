# Store listing kit (Google Play + Apple App Store)

Everything needed to fill in the store forms. Items marked **(owner)** need your
decision or your account; nothing here has been submitted anywhere.

## Before the first upload (owner)

| Item | Why it matters |
| --- | --- |
| **App name: Tap Tap Cricket** (chosen) | Check the stores for an existing app with the same name before your first upload |
| **Package / bundle id** (currently `com.taptapcricket.game`) | **Permanent** after the first Play upload. Keep it, or change it now in `export_presets.cfg` (Android, Android Store, iOS) |
| Developer accounts | Google Play Console (one-time US$25); Apple Developer Program (US$99/year) |
| Contact email + public privacy-policy URL | Both stores require them. `PRIVACY_POLICY.md` is ready; publish it as a web page (e.g. GitHub Pages) and fill in the email |
| Commentary voices | Current English voices are **robotic placeholders** (eSpeak NG). Fine for testing; recommended to replace with recorded lines before release (same file names in `assets/audio/vo_*.wav`) |

## Text

- **Name (30 chars max):** Tap Tap Cricket
- **Short description (Play, 80 max):** One-tap street cricket: time your swing, hit sixes, chase your best score!
- **Subtitle (App Store, 30 max):** One-tap street cricket
- **Full description:**

> Grab your bat - the neighbourhood match is on!
>
> Tap Tap Cricket is simple, one-tap cricket. Watch the bowler run in, tap SWING at the
> right moment, and send the ball over the rooftops. Mistime it and the stumps fly.
>
> - One button, real cricket: timing decides everything - fours, sixes, catches, bowled
> - Starts gentle and gets faster: pace and spin bowlers grow tougher ball by ball
> - Batter's-eye view or classic side-on view
> - Day, evening, floodlit night and rain
> - Decorated trucks blast their horns for every four and six
> - Fifty and hundred celebrations - raise the bat!
> - Optional hints show you exactly when to hit
> - Play in landscape or portrait
> - Fully offline: no ads, no account, no data collected
>
> How long can you bat?

- **Category:** Games > Sports
- **Tags / keywords (App Store, 100 chars):** cricket,batting,one tap,arcade,sixes,offline,street cricket,sports,casual

## Graphics (in the repo)

| Asset | File | Store |
| --- | --- | --- |
| App icon 512x512 | `assets/icons/icon_512_play.png` | Play |
| App icon 1024x1024 (no transparency) | `assets/icons/icon_1024.png` | App Store (also built into the iOS export) |
| Feature graphic 1024x500 | `store/feature_graphic_1024x500.png` | Play |
| Phone screenshots 1920x1080 and 1080x1920 | `store/screenshots/play_phone_*` | Play |
| iPhone 6.9" screenshots 2868x1320 | `store/screenshots/iphone69_*` | App Store |
| iPad 13" screenshots 2752x2064 | `store/screenshots/ipad13_*` | App Store |

## Google Play forms

- **App or game:** Game. **Free or paid:** Free. **Ads:** No.
- **Data safety:** "Does your app collect or share any of the required user data types?"
  **No.** Encrypted in transit: not applicable (no data sent). Data deletion: not applicable.
- **Content rating (IARC questionnaire):** no violence, no blood, no sexual content, no
  language, no gambling, no user interaction/chat, no sharing of location, no purchases.
  Expected rating: Everyone / PEGI 3.
- **Target audience:** choose the age groups you want. If you include under-13s the app
  joins Google's Families programme; this game has no ads, no data collection and no
  links, which that programme requires.
- **App access:** all features available without login.
- **Government / news / health / financial features:** none.
- **Upload:** use the signed `.aab` from the GitHub release (see below). Start with an
  internal or closed test track.

## Apple App Store forms

- **Privacy "nutrition label":** Data Not Collected.
- **Age rating:** answer "None" to every content question -> 4+.
- **Export compliance:** the app uses no non-exempt encryption (already declared in the
  build: `ITSAppUsesNonExemptEncryption = NO`).
- **Sign-in required:** No. **Account deletion:** not applicable (no accounts).

## Building store files

**Android (.aab for Google Play)** - built by CI on every push:
1. Create an upload key once on your computer (keep it and its password safe; never
   commit it):
   `keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000`
2. In GitHub: Settings -> Secrets and variables -> Actions, add
   `ANDROID_UPLOAD_KEYSTORE_BASE64` (the file, base64-encoded: `base64 -w0 upload.keystore`),
   `ANDROID_UPLOAD_KEY_ALIAS` (`upload`) and `ANDROID_UPLOAD_KEYSTORE_PASSWORD`.
3. The next build attaches `TapTapCricket-play-<n>.aab` to its release. Upload that to
   Play Console. Turn on **Play App Signing** (Google holds the final signing key).
   Each build's version code is its build number, so every upload is newer.

Without the secrets, CI still builds a debug-signed `pipeline-check` bundle (artifact)
to prove the store build works - that one cannot be uploaded.

**iOS** - CI (`ios-check` job, macOS) exports the Xcode project and compiles it unsigned
on every push. To publish you need a Mac with Xcode (or a cloud Mac):
1. Put your Apple Team ID in `export_presets.cfg` (`application/app_store_team_id`) and
   export the iOS preset from Godot (or download the `TapTapCricket-ios-xcode-project`
   artifact).
2. Open `TapTapCricket.xcodeproj`, choose your team for signing, Product -> Archive,
   then Distribute App -> App Store Connect.

## Requirements checklist (verified)

| Requirement | Status |
| --- | --- |
| Play: target API level | targetSdk **36** (checked in the built APK) |
| Play: App Bundle format | `.aab` built by CI (`Android Store` preset, Gradle) |
| Play: 64-bit native code | arm64-v8a included |
| Play: 16 KB page-size alignment | checked in CI (`zipalign -c -P 16`) |
| Play: version code increases | = CI build number |
| Play: minimal permissions | only VIBRATE |
| Play: privacy policy + Data safety | text ready (`PRIVACY_POLICY.md`), answers above |
| Back button / gesture | closes screens, pauses a match, quits only from the menu (tested) |
| Pauses when the app goes to the background | yes (tested earlier) |
| Works in portrait and landscape, phones and tablets | tested at 16:9, 20:9, 4:3, 9:16, 9:20, 3:4 |
| App Store: 1024 icon without transparency | `assets/icons/icon_1024.png` (RGB) |
| App Store: privacy manifest | generated by the Godot export (checked by the CI iOS job) |
| App Store: encryption declaration | `ITSAppUsesNonExemptEncryption = NO` |
| App Store: iPhone + iPad | targeted device family: iPhone and iPad, all orientations |
| Open-source licences shown in the app | Settings -> Credits & licences (Godot MIT + third parties, Lato OFL) |
| No ads, no tracking, offline | yes |
