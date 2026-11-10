# Putting Tap Tap Cricket on Google Play - step by step

Everything inside the game and the build is ready. The steps below need **you** (your
Google account, your payment, your key). Nothing is submitted automatically.

Time needed: about 1 hour of your work, plus Google's waiting times (account
verification, and the testing period described in step 6).

---

## 1. Create your upload key (once, about 5 minutes)

Google needs every upload to be signed with a key that only you have.

1. Install Java (free): open <https://adoptium.net>, download **Temurin JDK**, install
   with the default options.
2. In this repository, download `tools/make_play_upload_key.bat` to your PC and
   double-click it.
3. Pick a strong password and **write it down**. Answer the questions (name, city,
   country code `PK`); press Enter to skip any you like, then type `yes`.
4. A folder opens: `Documents\TapTapCricket-upload-key`.
   - `upload.keystore` is your key. **Back it up** to a USB drive and to cloud storage.
     If you lose it, Google can reset it, but that takes days.
   - Never send it to anyone and never put it in the repository.

## 2. Give the key to the GitHub build (once, about 3 minutes)

GitHub repository → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**. Add these three:

| Name | Value |
| --- | --- |
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | everything inside `upload.keystore.base64.txt` (open it with Notepad, Ctrl+A, Ctrl+C) |
| `ANDROID_UPLOAD_KEY_ALIAS` | `upload` |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | your password |

Secrets are hidden: nobody can read them back, not even in the build logs.

From the next push on, every build's release page has a file
**`TapTapCricket-play-<number>.aab`**: that is the file you upload to Google Play.
If the secrets are wrong (for example a typo in the password), the build turns red and
says so, instead of quietly producing nothing.

## 3. Put the privacy policy online (once, about 5 minutes)

Google requires a public web link to a privacy policy. The text is ready:
`PRIVACY_POLICY.md`, and a web-page version `docs/privacy-policy.html`.

1. Fill in a contact email in **both** files (the line that says
   `developer contact email`). A separate address just for the game is a good idea,
   because it is shown publicly.
2. Easiest way to publish it: repository **Settings** → **Pages** → Source
   *Deploy from a branch* → choose your main branch and the `/docs` folder → Save.
   After a minute the policy is at
   `https://<your-github-name>.github.io/<repository-name>/privacy-policy.html`.
   (GitHub Pages on a private repository needs a paid GitHub plan. If the repository
   is private, you can paste the policy into any free website builder or Google Sites
   instead.)

## 4. Create the Google Play developer account

<https://play.google.com/console>: one-time fee of US$25, and identity verification
(ID document). Choose a **personal** or **organisation** account. Verification can
take a few days.

## 5. Create the app and fill in the forms

In Play Console → **Create app**: name **Tap Tap Cricket**, language English, **Game**,
**Free**. Then go through *Set up your app*. Every answer is in `STORE_LISTING.md`:

| Play Console section | Where to find the answer |
| --- | --- |
| Privacy policy | your link from step 3 |
| App access | "All functionality is available without special access" |
| Ads | **No** |
| Content rating (questionnaire) | `STORE_LISTING.md` → Google Play forms (expect *Everyone* / PEGI 3) |
| Target audience | your choice (the game has no ads, no data collection) |
| Data safety | **No data collected or shared** |
| Government apps, financial features, health | none |
| Store listing text | `STORE_LISTING.md` → Text (name, short and full description) |
| App icon 512x512 | `assets/icons/icon_512_play.png` |
| Feature graphic 1024x500 | `store/feature_graphic_1024x500.png` |
| Phone screenshots | `store/screenshots/play_phone_1` ... `_5` (1080x1920) |
| Category | Games → Sports |

When asked about **Play App Signing**, keep it **on** (Google keeps the final signing
key safe; your upload key only proves uploads come from you).

## 6. Test track first, then production

1. **Testing → Internal testing**: create a release, upload the `.aab`, add yourself as a
   tester, install from the link on your phone, and play it.
2. New **personal** developer accounts must run a **closed test** before they can
   publish to everyone (at the time of writing: at least 12 testers opted in for 14 days
   in a row; check the current rule shown in your Play Console). Friends and family
   with an Android phone and a Gmail address can be your testers.
3. When the closed test requirement is met: **Production** → create release → upload
   the latest `.aab` → **Send for review**. Google's review usually takes from a few
   hours to a few days.

## 7. Updates later

Push changes → wait for the build → upload the newest `TapTapCricket-play-<n>.aab`
as a new release. The version number goes up automatically with every build. To change
the version name people see (now **1.0.0**), edit `version/name` in
`export_presets.cfg`.

---

### Before you publish (recommended, not required by Google)

- The commentary voices are **placeholders** made by a speech synthesiser. They work,
  but sound robotic. You can replace any `assets/audio/vo_*.wav` with your own
  recording of the same line (same file name).
- Search Google Play for "Tap Tap Cricket" to make sure no other app uses the name.
- The package name `com.taptapcricket.game` becomes **permanent** after the first
  upload. Change it in `export_presets.cfg` now if you want something else.
