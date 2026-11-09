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
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` updates in place and keeps progress. If adb reports any `INSTALL_FAILED_*` error, stop and tell Cesar with the full message. Never run `adb uninstall` (it erases progress), and don't touch the keystore. The usual causes:

- `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: the APK was signed with another key (see "Signing keystore" below; restoring it is Cesar's step).
- `INSTALL_FAILED_VERSION_DOWNGRADE`: the phone has a higher build number than this APK.

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
   id=$(gh api repos/ctorres345/PawlyPaint/rulesets --jq '.[] | select(.name == "main") | .id')
   f=$(mktemp)
   gh api "repos/ctorres345/PawlyPaint/rulesets/$id" --jq '{name, target, enforcement, conditions, bypass_actors,
     rules: ([.rules[] | select(.type != "required_status_checks")] + [{type: "required_status_checks",
       parameters: {strict_required_status_checks_policy: false,
         required_status_checks: [{context: "check", integration_id: 15368}]}}])}' > "$f"
   gh api -X PUT "repos/ctorres345/PawlyPaint/rulesets/$id" --input "$f"
   ```
   `integration_id` 15368 is GitHub Actions, so a commit status posted from outside Actions can't satisfy the check. Any Actions job named `check` can, though (next paragraph).
3. Verify: `gh api repos/ctorres345/PawlyPaint/rules/branches/main --jq '.[].type'` lists `required_status_checks`.

Limit: the ruleset lets the admin role bypass it always. That keeps the direct release push (above) working and lets Cesar merge the PR that introduced the gate, but agents run `gh` and `git` with Cesar's admin token, so GitHub does not stop an agent that merges a red PR (`gh pr merge --admin`) or pushes to `main`. Only the rules stop it: agents never merge a PR and never push to `main` except the approved release commit. Closing the gap (no bypass, releases through a PR) is Cesar's decision.

Limit: on a pull request GitHub runs the workflow files from the PR itself. A PR that edits `.github/workflows/`, or adds any workflow with a job named `check`, can turn the check green without the real gate. The gate script and `tier.py` still come from `main`, but only an unchanged workflow uses them. Cesar reads every change under `.github/workflows/` before merging; a green check on such a PR proves nothing.

## Regenerate assets

Music, sounds and the icon come from `tool/*.py`; never hand-edit the outputs. Commands are in the README, "Development".
