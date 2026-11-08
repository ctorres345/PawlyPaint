# Runbook

Recurring manual steps for PawlyPaint. Agents follow these steps as written and never improvise. A release or an install on someone's phone is Cesar's to trigger: an agent prepares the steps and waits for his go-ahead.

No secrets belong in this file.

## Before any step

```bash
flutter pub get
flutter analyze && flutter test
```

Both must pass on the commit you release or install.

## Release a new version

```
CHANGELOG entry ─► bump version ─► build APK ─► pre-release on GitHub ─► Cesar promotes it
```

1. Ask Cesar before starting a release.
2. Add a `## x.y.z (YYYY-MM-DD)` entry at the top of `CHANGELOG.md`, and move any "Unreleased" items into it.
3. Bump `version:` in `pubspec.yaml`: `x.y.z+N`, where `N` goes up by one every release (Android refuses to update over a lower build number).
4. Commit and push to `main`. This release commit is the one allowed direct push to `main`, and only after Cesar's go-ahead; all other work goes through a `cesar/PAP-<n>` PR.
5. Build and name the APK:
   ```bash
   flutter build apk --release
   cp build/app/outputs/flutter-apk/app-release.apk build/PawlyPaint-x.y.z.apk
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
   - Two lines that differ: stop, restore the keystore (below) and rebuild.
   - A missing line or an error: the check itself failed, not the keys. Stop and tell Cesar; don't touch the keystore.
7. Check the release commit is what `main` holds (`git status --porcelain` is empty and `git rev-parse HEAD` equals `git rev-parse origin/main`), then create a **pre-release** tagged on that commit. Cesar promotes it to a full release himself.
   ```bash
   gh release create vx.y.z --prerelease --target "$(git rev-parse HEAD)" --title "PawlyPaint x.y.z" --notes-file <notes>
   timeout 300 gh release upload vx.y.z build/PawlyPaint-x.y.z.apk
   ```
   `timeout` comes from GNU coreutils (`brew install coreutils`); stock macOS lacks it. If the upload fails or stalls once, stop and give Cesar the APK path so he can attach it by hand.

## Install on an Android phone

From the phone: open the newest release on the GitHub Releases page, download `PawlyPaint-x.y.z.apk`, open it, and allow "install unknown apps" if asked. A newer APK installs over the old one and keeps progress. If the phone says "App not installed", never uninstall the old app (that erases progress): stop and tell Cesar. The cause is a different signing key or a lower build number.

From the Mac, phone plugged in with USB debugging on:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` updates in place and keeps progress. If adb reports `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, stop and never uninstall (that erases progress): the APK was signed with another key. Restore the keystore backup (below) and rebuild.

## Install on an iPhone

One-time setup (Xcode, Apple ID, signing team, Developer Mode) is in the README, "Installing on an iPhone".

```bash
flutter build ios --release
xcrun devicectl list devices
xcrun devicectl device install app --device <identifier> build/ios/iphoneos/Runner.app
```

- `devicectl device install` updates in place and keeps progress. Never use `flutter install` for an update: it uninstalls first and erases progress.
- A free Apple ID signature expires after 7 days. Re-run the build and install; progress is kept.

## Signing keystore (Android)

Release APKs are signed with the Mac's Android debug keystore (`~/.android/debug.keystore`). An APK signed with a different key cannot update the installed app, so losing it means uninstalling and losing progress.

- Keep a backup of that file outside the Mac (an encrypted drive or password manager attachment).
- Never commit it or paste it anywhere. On a new Mac, copy it back to the same path **before the first Flutter build**: a build without it silently creates a new keystore.

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

## Regenerate assets

Music, sounds and the icon come from `tool/*.py`; never hand-edit the outputs. Commands are in the README, "Development".
