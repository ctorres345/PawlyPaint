# Runbook

Recurring manual steps for PawlyPaint. Agents follow these steps as written and never improvise. A release or an install on someone's phone is Cesar's to trigger: an agent prepares the steps and waits for his go-ahead.

No secrets belong in this file.

## Before any step

```bash
flutter pub get
flutter analyze && flutter test
```

Both must pass on the commit you release or install.

Before a release or any Android build, check the signing keystore is in place. Without it, `flutter build apk` silently creates a new key, and that APK can't update the phones (see "Signing keystore" below):

```bash
test -f ~/.android/debug.keystore || { echo "stop: no ~/.android/debug.keystore; tell Cesar, don't build"; false; }
```

A non-zero exit means stop.

## Release a new version

```
CHANGELOG entry ─► bump version ─► push the tag ─► Cesar approves the run ─► CI drafts the release ─► Cesar publishes, then promotes
```

1. Ask Cesar before starting a release.
2. Add a `## x.y.z (YYYY-MM-DD)` entry at the top of `CHANGELOG.md`, and move any "Unreleased" items into it.
3. Bump `version:` in `pubspec.yaml`: `x.y.z+N`, where `N` goes up by one every GitHub release **and** every Google Play upload (Android refuses to update over a lower build number, and Play rejects a code it has already seen). Both flavors share this one counter, so a sideload release may skip numbers; that is fine. Bump `N` before building any bundle you will upload, even when the upload is only a fix for a rejected one.
4. Commit and push to `main`. This release commit is the one allowed direct push to `main`, and only after Cesar's go-ahead; all other work goes through a `cesar/PAP-<n>` PR.
5. Check the release commit is what `main` holds (`git status --porcelain` is empty and `git rev-parse HEAD` equals `git rev-parse origin/main`), then tag it and push the tag. The tag push is part of the same go-ahead; never push a `vx.y.z` tag for anything else, since each one starts a release build.
   ```bash
   git tag vx.y.z && git push origin vx.y.z
   ```
6. The `release-apk` workflow (`.github/workflows/release-apk.yml`) starts and waits for Cesar: he opens the run on GitHub (Actions, `release-apk`, the run for `vx.y.z`), checks it is the tag he asked for **and** that the run's commit is the release commit on `main` (the short hash on the run page, or `gh run view <id> --json headSha`, equals `gh api repos/ctorres345/PawlyPaint/commits/main --jq .sha`; if `main` has moved on since step 4, it must equal the release commit pushed there, and when unsure he doesn't approve), and only then approves `sideload-release` under "Review deployments". A tag runs the workflow file of its own commit, so a run on any other commit could carry a changed workflow that leaks the key. An agent tells him the run is waiting and never approves it. Then, on GitHub, the workflow:
   - stops unless the tag is `vx.y.z`, matches `pubspec.yaml`, points at a commit on `main`, and `CHANGELOG.md` has a `## x.y.z` section;
   - builds `flutter build apk --release --flavor sideload` with the same Flutter pin as the review gate, signed with the debug keystore from the `sideload-release` environment secret (see "Signing keystore" below);
   - stops unless `apksigner` shows exactly the certificate every release so far has had (`fa1510ef...5390`);
   - creates a **draft** release `vx.y.z` with `PawlyPaint-x.y.z.apk` and that CHANGELOG section as notes. A draft doesn't show on the Releases page, so her phone can't see it yet.

   Find the run for this tag (it can take a few seconds to appear; if nothing shows after a minute, stop and tell Cesar), then follow it until it ends:
   ```bash
   gh run list --workflow release-apk.yml --branch vx.y.z --event push --limit 1 --json databaseId --jq '.[0].databaseId'
   gh run watch <that id> --exit-status
   ```
   Run the watch in the background: it waits through Cesar's approval, which can take long. A watch that times out or is stopped is not a build failure; look again with `gh run view <that id> --json status,conclusion`. If the run fails (`conclusion` is `failure`), report the failed step's error to Cesar and stop: don't delete or re-push the tag, and don't build on the Mac unless he asks (see "If CI can't build" below).
7. Read the draft's notes (`gh release view vx.y.z`): they hold that section and nothing else.
8. Cesar publishes the draft as a **pre-release**, tries it, then promotes it to a full release himself:
   ```bash
   gh release edit vx.y.z --draft=false --prerelease
   ```

### If CI can't build (Mac fallback, only when Cesar asks)

Run "Before any step" (the keystore check included), then:

1. Build and name the APK:
   ```bash
   flutter build apk --release --flavor sideload
   cp build/app/outputs/flutter-apk/app-sideload-release.apk build/PawlyPaint-x.y.z.apk
   ```
2. Check the signing key matches the last release. An APK signed with another key can't update the phones, and their only way out is an uninstall that erases progress.
   ```bash
   apksigner=$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/build-tools/*/apksigner | sort -V | tail -1)
   rm -rf build/prev
   gh release download v<previous x.y.z> --pattern 'PawlyPaint-<previous x.y.z>.apk' --dir build/prev
   "$apksigner" verify --print-certs build/prev/PawlyPaint-<previous x.y.z>.apk | grep 'SHA-256'
   "$apksigner" verify --print-certs build/PawlyPaint-x.y.z.apk | grep 'SHA-256'
   ```
   - Two lines with the same SHA-256: continue.
   - Two lines that differ: stop and tell Cesar. Don't touch the keystore; restoring it is his step (see "Signing keystore" below).
   - A missing line or an error: the check itself failed, not the keys. Stop and tell Cesar; don't touch the keystore.
3. Write the release notes: the new `## x.y.z` section of `CHANGELOG.md`, without its heading, into `build/notes.md`.
   ```bash
   awk -v v="## x.y.z " 'index($0, v) == 1 {f = 1; next} /^## /{f = 0} f' CHANGELOG.md > build/notes.md
   ```
   Read `build/notes.md` and check it holds that section and nothing else.
4. If `gh run list --workflow release-apk.yml --branch vx.y.z` shows a run that is waiting or in progress, ask Cesar to cancel it (`gh run cancel <id>`) before going on. If the CI run already made a draft for `vx.y.z`, stop and ask Cesar what to do with it. Otherwise create a **pre-release** on the release commit, with the APK attached in the same call, so no release ever exists without its APK. Cesar promotes it to a full release himself.
   ```bash
   timeout 600 gh release create vx.y.z build/PawlyPaint-x.y.z.apk --prerelease --target "$(git rev-parse HEAD)" --title "PawlyPaint x.y.z" --notes-file build/notes.md
   ```
   `timeout` comes from GNU coreutils (`brew install coreutils`); stock macOS lacks it. If the command fails or stalls once, run `gh release view vx.y.z` once to report what exists (it may show a draft), give Cesar that output and the APK path, and stop. Don't re-run `gh release create`, upload, or delete anything.

## Install on an Android phone

From the phone: open the newest full release on the GitHub Releases page (not one marked Pre-release), download `PawlyPaint-x.y.z.apk`, open it, and allow "install unknown apps" if asked. A newer APK installs over the old one and keeps progress. If the phone says "App not installed", never uninstall the old app (that erases progress): stop and tell Cesar. The cause is a different signing key or a lower build number.

From the Mac, phone plugged in with USB debugging on:

```bash
flutter build apk --release --flavor sideload
adb install -r build/app/outputs/flutter-apk/app-sideload-release.apk
```

`-r` updates in place and keeps progress. If adb reports any `INSTALL_FAILED_*` error, stop and tell Cesar with the full message. Never run `adb uninstall` (it erases progress), and don't touch the keystore. The usual causes:

- `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: the APK was signed with another key (see "Signing keystore" below; restoring it is Cesar's step).
- `INSTALL_FAILED_VERSION_DOWNGRADE`: the phone has a higher build number than this APK.

## Build flavors (Android)

Android has two flavors. Always pass `--flavor`: a build without it fails.

| Flavor | App id | Content | For |
| --- | --- | --- | --- |
| `sideload` | `com.pawlypaint.pawlypaint` | Everything: fan-art courses and, later, For You | Her phone and yours, from GitHub Releases |
| `store` | `com.cjtech.pawlypaint` | Shared courses only | Google Play (internal, closed and production tracks) |

```bash
flutter run --flavor sideload                 # or --flavor store
flutter build apk --release --flavor sideload  # build/app/outputs/flutter-apk/app-sideload-release.apk
flutter build apk --release --flavor store     # needs the upload key (below); build/app/outputs/flutter-apk/app-store-release.apk
```

- **Why the ids differ.** Android treats the app id as the app's identity, and an update must come from the same signing key. Her app is signed with the Mac's debug key and must keep updating, so `sideload` keeps the old id. Google Play signs the store app with its own key (PAP-32), so it needs a different id. Both install side by side and keep separate progress.
- **What `--flavor store` changes in Dart.** Flutter passes the flavor to the app (`appFlavor`, read in `lib/data/build_flavor.dart`). The store build lists no course in `sideloadOnlyCourseIds` (`lib/data/sideload_courses.dart`) and the compiler drops its art. Picture ids and saved-progress keys are the same in both builds.
- **Check a store build before it goes anywhere** (the grep must print `0`; the same grep on the sideload build prints more than `0`):
  ```bash
  unzip -p build/app/outputs/flutter-apk/app-store-release.apk lib/arm64-v8a/libapp.so | strings -a | /usr/bin/grep -ciE 'minecraft|vocaloid|kpop|Blocky World|Virtual Stage|K-Pop Stage'
  ```
- Play takes an `.aab`, not an APK. For a bundle, run the same check on its `base/lib/arm64-v8a/libapp.so` (`unzip -p <file>.aab base/lib/arm64-v8a/libapp.so | strings -a | /usr/bin/grep -ciE '...'`). The filter only applies to `--flavor store`: any other flavor name, or a build without `--flavor`, ships the fan art.
- **Both flavors show the same name and icon** (the store name is PAP-33's call). On a phone that has both, tell them apart in Settings → Apps → PawlyPaint → App info (the package name is `com.cjtech.pawlypaint` for the store app and `com.pawlypaint.pawlypaint` for sideload), and never uninstall the sideload one: that erases her progress.
- **Save format version.** Progress is saved as version 3 (PAP-78, v0.12 Fresh paint).
  - First launch of v0.12: a version 1 or 2 save is reset once. A raw copy goes to `progress_v1_before_reset` (written once, never overwritten), only the two tutorial flags stay, version 3 is written and Home shows the Fresh paint card until she closes it. Settings, music and name keys are separate and untouched. If the copy cannot be written, the session is read-only and the reset retries next launch.
  - Restore by hand: copy that key's value back into `progress_v1` on a build older than v0.12 (a v0.12 build would reset it again), then delete `progress_v1_before_reset`. Without the delete, a later v0.12 install resets again and keeps no copy of what she earned since the restore, because that key is never overwritten.
  - Older builds: v0.11 or older over a phone that ran v0.12 shows the save read-only ("comes from a newer PawlyPaint"), so nothing she does there is saved. Never install a build older than PAP-15 over a phone that has run one: it writes the save without `secrets`, `celebrated`, `keptOpen`, `streakBonusPaid` and `daysPlayed`, so they are lost for good.
- **Signing.** `sideload` is signed with the Mac's debug key ("Signing keystore" below). `store` is signed with the upload key from `android/key.properties` ("Upload key (store build)" below). A store release build without that file fails with a message; it never falls back to the debug key.
- **Build the store bundle** (needs the upload key set up first). **Bump the build number first.** Every Play upload needs a `versionCode` (the `+N` in `pubspec.yaml`) higher than both the last GitHub release and the last Play upload (the shared counter, "Release a new version" step 3). The bump must reach `main` before the next release builds on it, or that release would reuse a number Play has already seen: commit it in the PR of the ticket that does the upload, or, with Cesar's go-ahead, as a release commit (the one allowed direct push to `main`). Then build:
  ```bash
  rm -rf build/app/outputs/bundle   # clear any stale bundle first
  flutter build appbundle --release --flavor store   # build/app/outputs/bundle/storeRelease/app-store-release.aab
  ```
  Always pass `--flavor store`: `flutter build appbundle` without it builds both flavors and can leave an upload-signed bundle with fan art at that same path. Never upload a bundle until the fan-art grep below prints `0`.

  Then check the fan-art grep above prints `0`, and that the bundle is signed with the upload key, not the debug key (the SHA-256 must differ from the debug key's (`FA:15:10:EF:...:00:53:90` in `keytool` format; `apksigner` prints it as `fa1510ef...5390`), and match the one Cesar noted when he made the key):
  ```bash
  keytool -printcert -jarfile build/app/outputs/bundle/storeRelease/app-store-release.aab | grep SHA256
  ```
  Then check Google Play's upload rules (PAP-50), right after the build above. Cesar's shell defines `grep` as a function that drops `-c`, so these checks call `/usr/bin/grep`:
  ```bash
  # 1. Target API: expect targetSdkVersion="36" or higher (minSdkVersion stays 24 so her Galaxy S22 installs).
  #    This is the merged manifest Gradle packs into the bundle (bundletool isn't installed to read the .aab itself).
  /usr/bin/grep -A2 '<uses-sdk' build/app/intermediates/merged_manifest/storeRelease/processStoreReleaseMainManifest/AndroidManifest.xml
  # Version code: must be higher than the last Play upload (Play Console shows it) and the last GitHub release.
  /usr/bin/grep -o 'android:versionCode="[0-9]*"' build/app/intermediates/merged_manifest/storeRelease/processStoreReleaseMainManifest/AndroidManifest.xml

  # 2. 16 KB pages: every 64-bit library must have LOAD alignment 0x4000 or more (32-bit armeabi-v7a is exempt).
  d=$(mktemp -d) && unzip -q build/app/outputs/bundle/storeRelease/app-store-release.aab 'base/lib/*' -d "$d"
  readelf=$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf | tail -1)
  [ -x "$readelf" ] || { echo "stop: no llvm-readelf, install the NDK"; false; }
  for f in "$d"/base/lib/arm64-v8a/*.so "$d"/base/lib/x86_64/*.so; do
    echo "${f#$d/}: $("$readelf" -lW "$f" | awk '/LOAD/{print $NF}' | sort -u | tr '\n' ' ')"
  done
  ```
  Any alignment below `0x4000` (for example `0x1000`) fails the rule: update Flutter or the plugin that ships that library before uploading. Every line must end in a value (`0x4000` or `0x10000`); a blank value, an error or a missing library means the check did not run, so stop.
  To check an APK's signer, use `apksigner verify --print-certs <apk>` (from `~/Library/Android/sdk/build-tools/<version>/`); `keytool -jarfile` can't read modern APK signatures.
- **`Unresolved reference` in a plugin's Kotlin during the first flavor build** is a stale build cache, not a code error. Run `flutter clean` (it only removes `build/`) and build again.
- **Never install a local store build on a phone that has (or will get) the Play build.** The two are signed with different keys, so the install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and if `flutter run` offers to uninstall first, answer no: that erases the store app's progress. Test Play builds through the internal track.
- iPhone builds have no flavor and carry the sideload content.

## Google Play internal test

The internal test track puts the `store` build on Cesar's phone (and a few trusted testers) through Google Play, weeks before the closed test. It is not a GitHub release: no CHANGELOG entry, pre-release or APK. The shared `+N` build-number counter ("Release a new version" step 3) still applies. Cesar presses every Play Console button; agents never touch Play Console or the upload key. Menu names below follow Google's help pages and may move: if one is missing, follow the Dashboard and tell the agent what you saw.

```
agent: bump +N, build, check bundle ─► Cesar: Create new release ─► upload .aab ─► Start rollout ─► testers opt in ─► install from Play
```

### One time: create the app (Cesar)

Source: [Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152).

1. In Play Console, click **Create app**. Fill in the app name, default language, **Game**, **Free** and a contact email. Accept the declarations (Developer Program Policies, US export laws, Play App Signing Terms). **Free is permanent**: Play never lets a free app become paid. The name and language can change later.
2. The package name (`com.cjtech.pawlypaint`) comes from the first bundle you upload and becomes permanent then. Play also needs it to be unique across Google Play: if the upload says it is taken, stop and tell the agent.
3. Open **Test and release > Testing > Internal testing > Testers**. Click **Create email list**, name it, add the Google account emails (up to 100), then **Save changes** and **Create**. Tick the list, add a feedback email, **Save changes**.
4. The opt-in link on the same tab works only after the first rollout; send it then ("Every upload" step 5).

Internal testing has no tester-count or waiting-period rule, also for personal accounts created after Nov 2023. The 12 testers for 14 days rule belongs to the closed test (PAP-30). Source: [Test requirements](https://support.google.com/googleplay/android-developer/answer/14151465).

### Every upload

1. **Agent:** bump `+N` in `pubspec.yaml` (higher than the last GitHub release and the last Play upload; see "Release a new version" step 3), land it on `main` through the upload ticket's PR or, with Cesar's go-ahead, a release commit ("Build flavors"). After it is on `main`, the agent updates to `main` (clean tree, `git rev-parse HEAD` equals `origin/main`), runs "Before any step" (pub get, analyze and test, keystore check), then builds the store bundle and runs every check in "Build flavors" (fan-art grep prints `0`, upload-key SHA, `targetSdkVersion`, `versionCode`, 16 KB alignment). The agent gives Cesar the path `build/app/outputs/bundle/storeRelease/app-store-release.aab`, the `versionCode` it checked and the `keytool -printcert -jarfile ... | grep SHA256` line of the bundle. **Before the first upload, Cesar compares that SHA-256 with the fingerprint he noted when he made the upload key ("Upload key (store build)" step 2) and stops if they differ**: Play registers the first bundle's signing certificate as the upload key, and only a support reset (days) undoes a wrong one.
2. **Cesar:** open **Test and release > Testing > Internal testing** and click **Create new release**. If the button is greyed out, finish the tasks the **Dashboard** lists first.
3. **First upload only:** keep the default Google-generated app signing key; never choose "use the same key as upload" or export a key. You sign the bundle only with the upload key ("Upload key (store build)").
4. Click **Upload** and add the `.aab`. Check the release name, add short release notes (500 characters max per language), then **Next**. Read anything under **Show more**, then **Start rollout**.
5. Send testers the opt-in link from the **Testers** tab, once the release shows as available in Play Console (see "Testers": the link only works once the app is **Published**).

Source: [Prepare and roll out a release](https://support.google.com/googleplay/android-developer/answer/9859348).

If Play rejects a bundle for its version code, bump `+N` again and rebuild. Google doesn't say whether a number from a rejected or draft upload can be reused, so treat every number you tried as used: Cesar tells the agent each number he tried, and the re-bump goes to `main` (through the ticket's PR, or a release commit with Cesar's go-ahead) before the rebuilt bundle is handed over. Play Console's "last upload" does not show rejected attempts.

### Testers

- They need a Google account on the email list. They open the opt-in link on the phone, accept, then install from the Play Store. Searching Play will not find the app.
- The opt-in link only works once the app status is **Published**. A first upload reaches internal testers within minutes, but for up to 48 hours (or until the first review) they see a temporary name and listing. This is expected. Source: [Set up an open, closed, or internal test](https://support.google.com/googleplay/android-developer/answer/9845334).
- The Play app (`com.cjtech.pawlypaint`) installs next to the sideload app (`com.pawlypaint.pawlypaint`) and keeps separate progress. Never uninstall the sideload app (erases her progress), and never install a local store build over the Play build ("Build flavors"). If a phone already has a `com.cjtech.pawlypaint` app that was not installed from Play (Settings → Apps → PawlyPaint → App info shows the package name and where it was installed from), the Play install fails with a signature conflict. Ask whoever plays on it first, because uninstalling loses that app's progress. Uninstall only that `com.cjtech.pawlypaint` app, never `com.pawlypaint.pawlypaint`, then install from Play.
- Before PAP-51's id change, local store builds used `com.pawlypaint.pawlypaint.store`. A phone that ran one still has that app, now obsolete: nothing updates it. After asking whoever plays on it, it can be uninstalled. Read the full package name first, because the sideload app is exactly `com.pawlypaint.pawlypaint` and the obsolete one only starts with it.

### Smoke test (Cesar, on the Play install)

- [ ] Open each course.
- [ ] Play one picture in Paint, one in Sort and one in Time Attack.
- [ ] No fan-art course and no For You course is visible.
- [ ] Settings → Apps → PawlyPaint shows the Play app (`com.cjtech.pawlypaint`) and the sideload app (`com.pawlypaint.pawlypaint`).

## Install on an iPhone

One-time setup (Xcode, Apple ID, signing team, Developer Mode) is in the README, "Installing on an iPhone".

```bash
flutter build ios --release
xcrun devicectl list devices
xcrun devicectl device install app --device <identifier> build/ios/iphoneos/Runner.app
```

- `devicectl device install` updates in place and keeps progress. Never use `flutter install` for an update: it uninstalls first and erases progress.
- A free Apple ID signature expires after 7 days. Re-run the build and install; progress is kept.

## Upload key (store build)

The `store` flavor is signed with an upload key that only Cesar creates and holds. Agents never run `keytool` against the keystore (no `-genkey`, no `-list` on the `.jks`), and never read, print or move the keystore or `key.properties`.

One time, Cesar's steps:

1. Create the key (pick a strong password; `keytool` asks for it twice). Keep the file outside the repo:
   ```bash
   keytool -genkey -v -keystore ~/.android/pawlypaint-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Note the certificate fingerprint for later checks: `keytool -list -v -keystore ~/.android/pawlypaint-upload.jks -alias upload | grep SHA256`.
3. Create `android/key.properties` (git-ignored) with your values:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=/Users/<you>/.android/pawlypaint-upload.jks
   ```
   All four lines are required. Use a password with ASCII characters only and no backslash (`\`): this file treats a backslash as an escape and the build would say the password is wrong.
4. **Back up both the `.jks` and the passwords in two places** outside the Mac (for example an encrypted drive and a password manager attachment). Tell the agent when done.
5. Play App Signing is turned on when you create the app in Play Console and upload the first bundle (PAP-51). Keep the default "Google-generated app signing key"; never pick "use the same key as upload" or export a key. Google then holds the app signing key; this upload key only proves uploads come from you.

- Never commit or paste the keystore, `key.properties` or the passwords. Both are git-ignored; a `gitleaks` scan must stay clean.
- If the upload key is lost, the app is not lost: ask Play Console support to reset the upload key. Back it up anyway; the reset takes days.
- On a new Mac, copy the `.jks` back to the same path and recreate `android/key.properties` before building the store bundle.

## Signing keystore (Android)

Release APKs of the `sideload` flavor are signed with the Mac's Android debug keystore (`~/.android/debug.keystore`). An APK signed with a different key cannot update the installed app, so losing it means uninstalling and losing progress.

- Keep a backup of that file outside the Mac (an encrypted drive or password manager attachment).
- Never commit it or paste it anywhere, with one exception: the `SIDELOAD_DEBUG_KEYSTORE_B64` secret of the `sideload-release` GitHub environment, which the `release-apk` workflow signs with. It is an environment secret, not a repo secret: only a run for a `v*` tag can ask for it, and every such run waits until Cesar approves it on GitHub. That approval, with his commit check ("Release a new version", step 6), is the gate, because a tag runs the workflow file from the tagged commit, so a tag on a changed workflow could otherwise read the key. GitHub can't tell an agent from Cesar here (agents use his token), so the rule that agents never approve is what keeps it his. Only Cesar sets it up, once, from the Mac, before any `v*` tag is pushed. First the environment, with him as required reviewer and `v*` tags as the only allowed refs:
  ```bash
  gh api -X PUT repos/ctorres345/PawlyPaint/environments/sideload-release -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true' -F 'reviewers[][type]=User' -F 'reviewers[][id]=11773798' && gh api -X POST repos/ctorres345/PawlyPaint/environments/sideload-release/deployment-branch-policies -f name='v*' -f type=tag
  ```
  Check it. The first command must print only `tag v*`, the second `ctorres345`:
  ```bash
  gh api repos/ctorres345/PawlyPaint/environments/sideload-release/deployment-branch-policies --jq '.branch_policies[] | .type + " " + .name'
  gh api repos/ctorres345/PawlyPaint/environments/sideload-release --jq '.protection_rules[] | select(.type == "required_reviewers") | .reviewers[].reviewer.login'
  ```
  Only when both print that, add the keystore (piped straight in, so it never shows on screen):
  ```bash
  base64 -i ~/.android/debug.keystore | gh secret set SIDELOAD_DEBUG_KEYSTORE_B64 --env sideload-release --repo ctorres345/PawlyPaint
  ```
  No password secret is needed: the debug config uses Android's fixed debug password. Agents never run these, never approve a `sideload-release` run, never read the secret, and never edit the workflow to print or upload the keystore. The workflow refuses to release an APK whose certificate isn't the one every release has had, so a wrong secret fails the run instead of shipping.
- On a new Mac, Cesar copies it back to the same path **before the first Flutter build**: a build without it silently creates a new keystore. An agent that finds no `~/.android/debug.keystore` stops and tells him before any build.
- Restoring the backup is Cesar's step only; agents stop and tell him. He first moves the current file aside, never deleting or overwriting it, then copies the backup in and rebuilds:
  ```bash
  mv -n ~/.android/debug.keystore ~/.android/debug.keystore.$(date +%F-%H%M%S)
  test ! -e ~/.android/debug.keystore || echo "stop: not moved aside"
  ```

## Turn on the pre-push review gate (once per clone)

The gate blocks pushing a `cesar/*` branch until a review is recorded. It needs the NousFX gate in `~/.claude/hooks/`.

The link points at the main checkout's `.githooks/pre-push`. If that file is missing, git skips the hook without a word and every push passes. So link it only after `.githooks/pre-push` is on `main`, keep the main checkout on `main`, and verify it.

```bash
common=$(git rev-parse --path-format=absolute --git-common-dir)
if test -f "$common/../.githooks/pre-push"; then
  ln -s "$common/../.githooks/pre-push" "$common/hooks/pre-push"
else
  echo "stop: .githooks/pre-push is not in the main checkout; merge it to main first"
fi
```

Verify, in any shell, without pushing anything. It feeds the hook a fake push of the current commit; a working gate prints "Blocked" and `exit=2`. Anything else means the gate is off.

```bash
common=$(git rev-parse --path-format=absolute --git-common-dir)
if test -n "$(git config --get core.hooksPath)"; then
  echo "broken: core.hooksPath is set, so git ignores .git/hooks"
elif test -f "$common/hooks/pre-push"; then
  echo "refs/heads/cesar/PAP-0 $(git rev-parse HEAD) refs/heads/cesar/PAP-0 0000000000000000000000000000000000000000" | "$common/hooks/pre-push"; echo "exit=$?"
else
  echo "broken: no hook, or the link points at nothing"
fi
```

Run the verify again after switching the main checkout to another branch: the link follows whatever is checked out there.

Don't set `core.hooksPath`: it would switch off graphify's hooks. Bypass once with `git push --no-verify`.

## Require the CI review gate on `main` (once, Cesar only)

The `review-gate / check` job (`.github/workflows/review-gate.yml`) runs on every PR. It only blocks merges once `main` requires it. `main` already has a ruleset named `main` (no deletion, no force-push, PRs required). Turning this on is Cesar's call; an agent gives him these steps and waits.

1. Check that the workflow is on `main` and has run on at least one PR (GitHub lists a check only after it ran).
2. Add the required check to the existing ruleset. In the browser: Settings → Rules → Rulesets → `main` → "Require status checks to pass" → add `check` from GitHub Actions → Save. Or from a shell:
   ```bash
   if ! id=$(gh api repos/ctorres345/PawlyPaint/rulesets --jq '.[] | select(.name == "main") | .id'); then
     echo "stop: could not list rulesets; nothing changed"
   elif [ -z "$id" ]; then
     echo "stop: no ruleset named main; nothing changed"
   else
     f=$(mktemp)
     gh api "repos/ctorres345/PawlyPaint/rulesets/$id" --jq '
       def want: {context: "check", integration_id: 15368};
       {name, target, enforcement, conditions, bypass_actors,
         rules: (if any(.rules[]; .type == "required_status_checks")
           then [.rules[] | if .type == "required_status_checks"
             then .parameters.required_status_checks |= (map(select(.context != "check")) + [want])
             else . end]
           else .rules + [{type: "required_status_checks",
             parameters: {strict_required_status_checks_policy: false, required_status_checks: [want]}}] end)}' > "$f" \
       && gh api -X PUT "repos/ctorres345/PawlyPaint/rulesets/$id" --input "$f"
     rm -f "$f"
   fi
   ```
   It keeps every other rule and required check, and running it twice changes nothing. `integration_id` 15368 is GitHub Actions, so a commit status posted from outside Actions can't satisfy the check. Any Actions job named `check` can, though (next paragraph).
3. Verify: `gh api repos/ctorres345/PawlyPaint/rules/branches/main --jq '.[].type'` lists `required_status_checks`.

Limit: the ruleset lets the admin role bypass it always. That keeps the direct release push (above) working and lets Cesar merge the PR that introduced the gate, but agents run `gh` and `git` with Cesar's admin token, so GitHub does not stop an agent that merges a red PR (`gh pr merge --admin`) or pushes to `main`. Only the rules stop it: agents never merge a PR and never push to `main` except the approved release commit. Closing the gap (no bypass, releases through a PR) is Cesar's decision.

Limit: on a pull request GitHub runs the workflow files from the PR itself. A PR that edits `.github/workflows/`, or adds any workflow with a job named `check`, can turn the check green without the real gate. The gate script and `tier.py` still come from `main`, but only an unchanged workflow uses them. A green check on such a PR proves nothing, so `.github/CODEOWNERS` names Cesar as owner of `.github/`, `.claude/` and `.nousfx/` (the workflow, the gate copies and the check command). The `main` ruleset requires a Code Owner review, and GitHub doesn't let an author approve their own PR, so a PR of Cesar's that touches those paths merges only through his admin bypass after he reads it: a deliberate, visible step. PRs that don't touch them are unaffected. Check the setting is still on:

```bash
gh api repos/ctorres345/PawlyPaint/rules/branches/main --jq '.[] | select(.type == "pull_request") | .parameters.require_code_owner_review'
```

It prints `true`.

## Regenerate assets

Music, sounds and the icon come from `tool/*.py`; never hand-edit the outputs. Commands are in the README, "Development". Puzzle picture sources come from "Local art generation" below.

## Local art generation

Puzzle pictures are drawn by Z-Image Turbo with the PIXELART-REDMOND LoRA on ComfyUI, on Cesar's Windows PC (RTX 5070 Ti, 16 GB), and fetched over the home network by `tool/pixel_gen.py` on the Mac. The style and canvas sizes are in `design/brief.md`, "Local generation". No address belongs in this repo: the host lives only in the `PAWLY_COMFY_HOST` environment variable on the Mac (or `--host`).

### One time: set up ComfyUI on the PC

1. Install the ComfyUI Windows portable build for NVIDIA (`ComfyUI_windows_portable_nvidia.7z`) from the [ComfyUI releases](https://github.com/comfyanonymous/ComfyUI/releases) and extract it.
2. Put the model files in its `ComfyUI\models\` folders, with exactly these names (`pixel_gen.py` asks for them by name):

   | File | Folder | Source | Licence |
   |---|---|---|---|
   | `z_image_turbo_bf16.safetensors` | `diffusion_models` | [Comfy-Org/z_image_turbo](https://huggingface.co/Comfy-Org/z_image_turbo) (from [Tongyi-MAI/Z-Image-Turbo](https://huggingface.co/Tongyi-MAI/Z-Image-Turbo)) | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
   | `qwen_3_4b.safetensors` | `text_encoders` | [Comfy-Org/z_image_turbo](https://huggingface.co/Comfy-Org/z_image_turbo) (from [Qwen/Qwen3-4B](https://huggingface.co/Qwen/Qwen3-4B)) | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) |
   | `ae.safetensors` | `vae` | [Comfy-Org/z_image_turbo](https://huggingface.co/Comfy-Org/z_image_turbo) | not stated on the repack; check the repo before using the art outside the game |
   | `ZImageTurbo_PixelArt_Redmond.safetensors` | `loras` | [artificialguybr/PIXELART-REDMOND-ZIMAGETURBO](https://huggingface.co/artificialguybr/PIXELART-REDMOND-ZIMAGETURBO), saved under this name | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) |

   ComfyUI itself is [GPL-3.0](https://github.com/comfyanonymous/ComfyUI/blob/master/LICENSE); the pictures it makes are not part of it. The [ComfyUI Z-Image Turbo guide](https://docs.comfy.org/tutorials/image/z-image/z-image-turbo) shows the same files and folders.
3. Start it from the portable folder so it listens on the home network: add `--listen --port 8188` to the command line in `run_nvidia_gpu.bat`, then run it.
4. **Cesar:** Windows shows a firewall prompt for Python. Allow it on Private networks only, never Public. `--listen` has no login, so anyone on the network can queue jobs: in the firewall rule's Scope, limit the remote address to the Mac, and don't install ComfyUI-Manager or custom nodes on this server.

### Every session: check the server

On the Mac, set the host for this shell (ask Cesar for the PC's name or address; never commit it):

```bash
export PAWLY_COMFY_HOST=http://<pc>:8188
curl -s "$PAWLY_COMFY_HOST/system_stats" | head -c 200
curl -s "$PAWLY_COMFY_HOST/object_info/LoraLoaderModelOnly" | grep -o 'ZImageTurbo_PixelArt_Redmond.safetensors' | head -1
curl -s "$PAWLY_COMFY_HOST/object_info/UNETLoader" | grep -o 'z_image_turbo_bf16.safetensors' | head -1
```

Each line must print something. No answer: the PC is asleep or ComfyUI is not running (`pixel_gen.py` then stops with "ComfyUI not reachable at <host>" and writes nothing). A missing file name: a model file was renamed or replaced, which changes the style; put the file from the table back.

### Make pictures

Run with the Via venv (the fit check needs Pillow) and keep the output outside the repo:

```bash
~/.local/share/nousfx/via/venv/bin/python3 tool/pixel_gen.py --test owl --out ~/Releases/pawlypaint/<KEY>/owl
```

- `--prompt "<subject and setting>" --grid <16|24|32|40> --name <slug>` for a new picture; `--entry <course>/<slug>` makes a recorded picture again.
- Canvases: every grid is tried at grid x 8 and grid x 16 px (`CELL_PX`), 6 seeds each, and the prompt says "drawn on a <grid>x<grid> pixel grid".
- Check 1, before converting: the on-lattice share, the share of colour runs (across and down) that are a whole number of cells long, within 15%. Under 60% (`ON_LATTICE_MIN`) the model drew its own blocks and the try is rejected. 60% comes from the PAP-97 slice: a 42% owl passed the old 40% gate and looked wrong, so a 44% fawn that looked right is rejected too. A try over it is read with the plain fixed lattice: no block search, no snapping.
- Check 2, after converting: every small source region (0.3 to 7 cells, a colour well apart from its surround: eyes, pupils, nose, cheeks) must keep a puzzle region on its side of the colours, within half a cell and at 0.5 to 2 times its area. Paired features (two eyes) must get the same cell shape on both sides. A miss inside the subject rejects the try.
- Kept tries: `<name>-c<scale>-s<seed>.png` (the source) and `puzzle-<...>.png` (the converted puzzle, 16 px a cell). Rejected ones go to `rejected/`, the puzzle only when it got that far. Lost features are boxed: magenta inside the subject, amber outside.
- `report.json` lists every try with its time, `on_lattice` share, lost `features` and why it was rejected.
- Contact sheet of one or more runs, every try with its numbers:

```bash
~/.local/share/nousfx/via/venv/bin/python3 tool/contact_sheet.py ~/Releases/pawlypaint/<KEY>/owl ~/Releases/pawlypaint/<KEY>/fox --out ~/Releases/pawlypaint/<KEY>/sheet.png
```

- Nothing kept: it prints the closest tries and exits non-zero. Try more `--seeds` or a simpler subject; the thresholds are in `tool/art_to_puzzle.py` (`ON_LATTICE_TOLERANCE`, `FEATURE_*`) and `tool/pixel_gen.py` (`ON_LATTICE_MIN`).
- An approved source goes to `design/assets/`, with `fit`, `prompt`, `seed` and `scale` in its `design/assets.toml` entry; then `tool/art_to_puzzle.py --check` and `--build`.
