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
CHANGELOG entry ─► bump version ─► build APK ─► pre-release on GitHub ─► Cesar promotes it
```

1. Ask Cesar before starting a release.
2. Add a `## x.y.z (YYYY-MM-DD)` entry at the top of `CHANGELOG.md`, and move any "Unreleased" items into it.
3. Bump `version:` in `pubspec.yaml`: `x.y.z+N`, where `N` goes up by one every GitHub release **and** every Google Play upload (Android refuses to update over a lower build number, and Play rejects a code it has already seen). Both flavors share this one counter, so a sideload release may skip numbers; that is fine. Bump `N` before building any bundle you will upload, even when the upload is only a fix for a rejected one.
4. Commit and push to `main`. This release commit is the one allowed direct push to `main`, and only after Cesar's go-ahead; all other work goes through a `cesar/PAP-<n>` PR.
5. Build and name the APK:
   ```bash
   flutter build apk --release --flavor sideload
   cp build/app/outputs/flutter-apk/app-sideload-release.apk build/PawlyPaint-x.y.z.apk
   ```
6. Check the signing key matches the last release. An APK signed with another key can't update the phones, and their only way out is an uninstall that erases progress.
   ```bash
   apksigner=$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/build-tools/*/apksigner | tail -1)
   rm -rf build/prev
   gh release download v<previous x.y.z> --pattern 'PawlyPaint-<previous x.y.z>.apk' --dir build/prev
   "$apksigner" verify --print-certs build/prev/PawlyPaint-<previous x.y.z>.apk | grep 'SHA-256'
   "$apksigner" verify --print-certs build/PawlyPaint-x.y.z.apk | grep 'SHA-256'
   ```
   - Two lines with the same SHA-256: continue.
   - Two lines that differ: stop and tell Cesar. Don't touch the keystore; restoring it is his step (see "Signing keystore" below).
   - A missing line or an error: the check itself failed, not the keys. Stop and tell Cesar; don't touch the keystore.
7. Write the release notes: the new `## x.y.z` section of `CHANGELOG.md`, without its heading, into `build/notes.md`.
   ```bash
   awk -v v="## x.y.z " 'index($0, v) == 1 {f = 1; next} /^## /{f = 0} f' CHANGELOG.md > build/notes.md
   ```
   Read `build/notes.md` and check it holds that section and nothing else.
8. Check the release commit is what `main` holds (`git status --porcelain` is empty and `git rev-parse HEAD` equals `git rev-parse origin/main`), then create a **pre-release** tagged on that commit, with the APK attached in the same call, so no release ever exists without its APK. Cesar promotes it to a full release himself.
   ```bash
   timeout 600 gh release create vx.y.z build/PawlyPaint-x.y.z.apk --prerelease --target "$(git rev-parse HEAD)" --title "PawlyPaint x.y.z" --notes-file build/notes.md
   ```
   `timeout` comes from GNU coreutils (`brew install coreutils`); stock macOS lacks it. If the command fails or stalls once, run `gh release view vx.y.z` once to report what exists (it may show a draft), give Cesar that output and the APK path, and stop. Don't re-run `gh release create`, upload, or delete anything.

## Install on an Android phone

From the phone: open the newest release on the GitHub Releases page, download `PawlyPaint-x.y.z.apk`, open it, and allow "install unknown apps" if asked. A newer APK installs over the old one and keeps progress. If the phone says "App not installed", never uninstall the old app (that erases progress): stop and tell Cesar. The cause is a different signing key or a lower build number.

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
| `store` | `com.pawlypaint.pawlypaint.store` | Shared courses only | Google Play (internal, closed and production tracks) |

```bash
flutter run --flavor sideload                 # or --flavor store
flutter build apk --release --flavor sideload  # build/app/outputs/flutter-apk/app-sideload-release.apk
flutter build apk --release --flavor store     # needs the upload key (below); build/app/outputs/flutter-apk/app-store-release.apk
```

- **Why the ids differ.** Android treats the app id as the app's identity, and an update must come from the same signing key. Her app is signed with the Mac's debug key and must keep updating, so `sideload` keeps the old id. Google Play signs the store app with its own key (PAP-32), so it needs a different id. Both install side by side and keep separate progress.
- **What `--flavor store` changes in Dart.** Flutter passes the flavor to the app (`appFlavor`, read in `lib/data/build_flavor.dart`). The store build lists no course in `sideloadOnlyCourseIds` (`lib/data/sideload_courses.dart`) and the compiler drops its art. Picture ids and saved-progress keys are the same in both builds.
- **Check a store build before it goes anywhere** (the grep must print `0`; the same grep on the sideload build prints more than `0`):
  ```bash
  unzip -p build/app/outputs/flutter-apk/app-store-release.apk lib/arm64-v8a/libapp.so | strings -a | grep -ciE 'minecraft|vocaloid|kpop|Blocky World|Virtual Stage|K-Pop Stage'
  ```
- Play takes an `.aab`, not an APK. For a bundle, run the same check on its `base/lib/arm64-v8a/libapp.so` (`unzip -p <file>.aab base/lib/arm64-v8a/libapp.so | strings -a | grep -ciE '...'`). The filter only applies to `--flavor store`: any other flavor name, or a build without `--flavor`, ships the fan art.
- **Both flavors show the same name and icon** (the store name is PAP-33's call). On a phone that has both, tell them apart in Settings → Apps → PawlyPaint → App info (the package name ends in `.store`), and never uninstall the sideload one: that erases her progress.
- **Signing.** `sideload` is signed with the Mac's debug key ("Signing keystore" below). `store` is signed with the upload key from `android/key.properties` ("Upload key (store build)" below). A store release build without that file fails with a message; it never falls back to the debug key.
- **Build the store bundle** (needs the upload key set up first):
  ```bash
  rm -rf build/app/outputs/bundle   # clear any stale bundle first
  flutter build appbundle --release --flavor store   # build/app/outputs/bundle/storeRelease/app-store-release.aab
  ```
  Always pass `--flavor store`: `flutter build appbundle` without it builds both flavors and can leave an upload-signed bundle with fan art at that same path. Never upload a bundle until the fan-art grep below prints `0`.

  Then check the fan-art grep above prints `0`, and that the bundle is signed with the upload key, not the debug key (the SHA-256 must differ from the debug key's (`FA:15:10:EF:...:00:53:90` in `keytool` format; `apksigner` prints it as `fa1510ef...5390`), and match the one Cesar noted when he made the key):
  ```bash
  keytool -printcert -jarfile build/app/outputs/bundle/storeRelease/app-store-release.aab | grep SHA256
  ```
  Then check Google Play's upload rules (PAP-50). Use `/usr/bin/grep` (see the fan-art note above):
  ```bash
  # 1. Target API: expect targetSdkVersion="36" or higher (minSdkVersion stays 24 so her Galaxy S22 installs).
  /usr/bin/grep -h -A2 '<uses-sdk' build/app/intermediates/merged_manifest/storeRelease/*/AndroidManifest.xml

  # 2. 16 KB pages: every 64-bit library must have LOAD alignment 0x4000 or more (32-bit armeabi-v7a is exempt).
  d=$(mktemp -d) && unzip -q build/app/outputs/bundle/storeRelease/app-store-release.aab 'base/lib/*' -d "$d"
  readelf=$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf | tail -1)
  for f in "$d"/base/lib/arm64-v8a/*.so "$d"/base/lib/x86_64/*.so; do
    echo "${f#$d/}: $("$readelf" -lW "$f" | awk '/LOAD/{print $NF}' | sort -u | tr '\n' ' ')"
  done
  ```
  Any alignment below `0x4000` (for example `0x1000`) fails the rule: update Flutter or the plugin that ships that library before uploading.
  To check an APK's signer, use `apksigner verify --print-certs <apk>` (from `~/Library/Android/sdk/build-tools/<version>/`); `keytool -jarfile` can't read modern APK signatures.
- **`Unresolved reference` in a plugin's Kotlin during the first flavor build** is a stale build cache, not a code error. Run `flutter clean` (it only removes `build/`) and build again.
- **Never install a local store build on a phone that has (or will get) the Play build.** The two are signed with different keys, so the install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and if `flutter run` offers to uninstall first, answer no: that erases the store app's progress. Test Play builds through the internal track.
- iPhone builds have no flavor and carry the sideload content.

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
- Never commit it or paste it anywhere. On a new Mac, Cesar copies it back to the same path **before the first Flutter build**: a build without it silently creates a new keystore. An agent that finds no `~/.android/debug.keystore` stops and tells him before any build.
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

Music, sounds and the icon come from `tool/*.py`; never hand-edit the outputs. Commands are in the README, "Development".
