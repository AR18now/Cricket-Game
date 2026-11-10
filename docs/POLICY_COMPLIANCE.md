# Policy compliance review (Google Play, Apple App Store, US export rules)

Reviewed against the game as built on 10 November 2026 (version 1.0.0). This is a careful
engineering review, not legal advice. Store policies change, so re-read the warnings
that Play Console shows when you upload.

## Google Play Developer Program Policies

| Policy area | What the game does | Status |
| --- | --- | --- |
| **Restricted content** (violence, sexual content, hate, gambling, drugs, real-money games) | Cricket only. Wickets are "Bowled!" / "Caught!"; a cartoon duck walks by when you're out for 0 | ✅ none |
| **Intellectual property / impersonation** | Original name, art, sound and music, all made for this project (`ASSET_LICENSES.md`). No real teams, players, leagues, logos, sponsors or broadcasters. Fonts under the SIL OFL; Godot under MIT, credited in Settings → Credits & licences | ✅ |
| **Deceptive behaviour / metadata** | Store text describes only real features. No "#1/best/free" claims, no emoji spam, no keyword stuffing. Screenshots and feature graphic are captured from the real game | ✅ |
| **Icon rules** | No text, no badges, no ranking claims; 512x512 32-bit PNG | ✅ |
| **User data / privacy** | No data collected, sent or shared. No account, no analytics, no crash-reporting SDK, no ads SDK. Only a local save file (settings and best scores) | ✅ Data safety: "No data collected" |
| **Privacy policy** | Written (`PRIVACY_POLICY.md`, `docs/privacy-policy.html`) | 👤 add a contact email and publish the page (see `docs/PLAY_STORE_UPLOAD.md` step 3) |
| **Permissions** | Only `VIBRATE` (normal permission, no prompt). No INTERNET, location, storage, camera, microphone or contacts. Vibration can be turned off in Settings. CI prints the APK's permission list on every build | ✅ |
| **Advertising ID** | Not used; the `AD_ID` permission is not declared | ✅ answer "No" |
| **Ads / monetisation / payments** | None | ✅ |
| **Families policy** (only if you pick ages under 13) | No ads, no data collection, no external links, no chat, no purchases, gentle content | ✅ compatible |
| **Account deletion** | No accounts exist | ✅ not applicable |
| **Device and network abuse** | No network code at all; no background services; no system settings changed | ✅ |
| **Malware / mobile unwanted software** | Plain Godot engine and game scripts; release builds exclude the developer test harness | ✅ |
| **Target API level** | targetSdk 36, minSdk 24 | ✅ above the current Play minimum |
| **64-bit** | arm64-v8a included (plus armeabi-v7a) | ✅ |
| **16 KB memory page size** | Native libraries checked with `zipalign -P 16` in CI | ✅ |
| **App Bundle** | `.aab` built in CI (`Android Store` preset) | ✅ needs your upload key once (`docs/PLAY_STORE_UPLOAD.md`) |
| **Edge-to-edge (Android 15+)** | Edge-to-edge on, immersive full screen; HUD kept inside the safe area (notches, rounded corners) | ✅ |
| **Large screens (Android 16)** | Declared as a game (`appCategory=game`), so the portrait lock stays valid on tablets; layout tested at 9:16, 9:20 and 3:4 | ✅ |
| **Back button / gesture** | Closes panels, pauses a match, exits only from the menu | ✅ |
| **Content rating** | Fill in the IARC questionnaire honestly (answers in `STORE_LISTING.md`); expect Everyone / PEGI 3 | 👤 in Play Console |
| **Developer identity** | Play Console identity verification | 👤 your account |

### Notes Play Console may still show (informational, not policy problems)

- **"This App Bundle contains native code, and you've not uploaded debug symbols."**
  A suggestion for crash reports. Godot's official engine libraries ship without
  debug symbols, so there is nothing to upload. It does not block release.
- **Pre-launch report.** Google's robots play the game automatically on test phones.
  Because the game draws its own interface, the accessibility checker usually cannot
  see the buttons and reports nothing. The game's buttons are large anyway (54 px
  and up; the SWING button much bigger).
- **New personal accounts:** Google requires a closed test (currently 12 testers for 14
  days) before production. This is an account rule, not a problem with the game.

## Apple App Store (for later)

| Guideline | Status |
| --- | --- |
| 2.1 completeness (no placeholder content) | ⚠️ The commentary voices are synthetic placeholders. They work and are not "lorem ipsum", but recorded voices are recommended |
| 4.1 copycats / 5.2 IP | ✅ original name and assets |
| 5.1 privacy | ✅ "Data Not Collected"; the Godot export includes the privacy manifest |
| Export compliance | ✅ `ITSAppUsesNonExemptEncryption = NO` (see below) |
| iPad support | ✅ full screen on iPad, tested at 3:4 |

## US export rules (EAR) and sanctions

- **Encryption:** the game makes no network connections and uses no encryption in its
  own features. Godot contains a TLS library (mbedTLS) that this game never calls. If
  that library were counted, the app would be a publicly available, mass-market item
  (ECCN 5D992.c), which under current rules needs no licence and no filing with the US
  Bureau of Industry and Security. Apple's question ("Does your app use encryption?")
  is answered **No** in the build. On Google Play, the export-laws statement is part of
  the developer agreement you accept: this app is consistent with it.
- **Sanctioned regions:** in Play Console → *Countries / regions*, select **all
  available countries**. Google already leaves out embargoed regions. Don't try to
  distribute outside Play to those places.
- **Content:** no maps, flags, political symbols or real organisations, so the game
  raises no country-specific content issues.

## What only you can do

1. Create the upload key and add the 3 GitHub secrets (`docs/PLAY_STORE_UPLOAD.md` §1–2).
2. Add a contact email to the privacy policy and publish it (§3).
3. Play Console account, forms and closed test (§4–6).
4. Optional: real recorded commentary voices.
