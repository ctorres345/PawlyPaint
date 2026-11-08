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
4. Commit and push to `main`.
5. Build and name the APK:
   ```bash
   flutter build apk --release
   cp build/app/outputs/flutter-apk/app-release.apk build/PawlyPaint-x.y.z.apk
   ```
6. Create a **pre-release**. Cesar promotes it to a full release himself.
   ```bash
   gh release create vx.y.z --prerelease --title "PawlyPaint x.y.z" --notes-file <notes>
   timeout 300 gh release upload vx.y.z build/PawlyPaint-x.y.z.apk
   ```
   If the upload fails or stalls once, stop and give Cesar the APK path so he can attach it by hand.

## Install on an Android phone

From the phone: open the newest release on the GitHub Releases page, download `PawlyPaint-x.y.z.apk`, open it, and allow "install unknown apps" if asked. A newer APK installs over the old one and keeps progress.

From the Mac, phone plugged in with USB debugging on:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` updates in place and keeps progress.

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
- Never commit it or paste it anywhere. Restoring it on a new Mac is a copy back to the same path.

## Turn on the pre-push review gate (once per clone)

The gate blocks pushing a `cesar/*` branch until a review is recorded. It needs the NousFX gate in `~/.claude/hooks/`.

```bash
common=$(git rev-parse --path-format=absolute --git-common-dir)
ln -s "$common/../.githooks/pre-push" "$common/hooks/pre-push"
```

Don't set `core.hooksPath`: it would switch off graphify's hooks. Bypass once with `git push --no-verify`.

## Regenerate assets

Music, sounds and the icon come from `tool/*.py`; never hand-edit the outputs. Commands are in the README, "Development".
