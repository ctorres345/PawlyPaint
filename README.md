# PawlyPaint

A cozy jewel (diamond) painting game for iPhone and Android, built with Flutter.
Made for one very special player: it isn't on any app store.

## What's in it

- **Two ways to play every picture**
  - **Paint**: fill a numbered canvas with sparkly drills. Tap or drag over the glowing spots of the selected color; pinch to zoom. Each tray color has a ring that fills as you paint, a mini-map shows where you are when zoomed in, and boosters (bomb, magic wand, wide brush) earned by finishing pictures fill spots for you.
  - **Sort** (inspired by Jewel Coloring): the picture starts scrambled. Tap misplaced beads to send them to the tray, and beads in the tray fly back to any spot that needs their color. Mind the tray space, shake it when full, and hold the little preview to peek at the finished picture.
- **Courses**: Cozy Classics, Animal Friends, Garden and Sweet Treats, plus two special collections (Blocky World and Virtual Stage). Each has 5 Easy, 5 Medium and 5 Hard mystery pictures (90 in all), drawn in code.
- **Daily picture** with a streak, a **gallery** of finished pictures, and **12 badges** to earn.
- **Guided tutorials** for both modes the first time you play them (replay from "How to play").
- **Music and sounds**: a menu song and three painting themes (Chill, Fever, Hip), random or chosen, plus sound effects. All composed for the app (`tool/compose_music.py`, `tool/compose_sfx.py`), with volume sliders and on/off switches.
- **Settings**: relaxed mode (no timer, score or counted mistakes), vibration, canvas background (linen, wooden desk, night sky) and square or round drills.
- Stars, best scores and half-finished pictures are saved on the phone.

---

## Installing on an Android phone

The easy way, from the phone itself:

1. On the phone, open the [Releases page](https://github.com/ctorres345/PawlyPaint/releases) (signed in to GitHub, since the repository is private) and tap the newest version.
2. Download `PawlyPaint-x.y.z.apk` and open it.
3. If Android asks, allow your browser (or Files app) to **install unknown apps**, then tap **Install**.
4. To update later, install the newer APK the same way. It goes on top of the old one and keeps all progress.

From the Mac, with the phone plugged in by USB (USB debugging turned on in the phone's Developer options):

```bash
cd ~/Projects/pawlypaint
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` updates the installed app and keeps its progress.

## Installing on an iPhone

Apps that aren't from the App Store have to be built on a Mac with Xcode and signed with your Apple ID.

### One-time setup

1. Install **Xcode** from the Mac App Store, then in Terminal:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   xcodebuild -downloadPlatform iOS
   brew install --cask flutter
   brew install cocoapods
   ```
   (If Xcode later says "iOS platform not installed" even after the download, restart the Mac.)
2. Open Xcode, go to **Settings > Accounts**, and add your Apple ID. A free account works.
3. Open `ios/Runner.xcworkspace` in Xcode, select **Runner** > **Signing & Capabilities**, and pick your **Personal Team**. (Already set in this repo for the current team.)
4. On the iPhone: **Settings > Privacy & Security > Developer Mode** on (the phone restarts). Plug it into the Mac and tap **Trust**.

### Build and install (and update)

With the iPhone unlocked and plugged in (or on the same Wi-Fi after the first time):

```bash
cd ~/Projects/pawlypaint
flutter build ios --release
xcrun devicectl list devices
xcrun devicectl device install app --device <identifier from the list> build/ios/iphoneos/Runner.app
```

`devicectl device install` updates the app in place and **keeps progress**.
Avoid `flutter install` for updates: it uninstalls the old copy first, which erases progress.

### First launch

iOS blocks apps from a personal developer account until you trust it once:
**Settings > General > VPN & Device Management**, tap your Apple ID under "Developer App", then **Trust**.

### Every 7 days (free Apple ID)

Apps signed with a free Apple ID stop opening after 7 days. Plug the phone in and run the build and install commands again. Progress is kept. (A paid Apple Developer account extends this to a year.)

---

## Development

```bash
flutter pub get
flutter run          # on a connected phone or emulator
flutter test         # rules, scoring, sort solvability, progress, badges
flutter analyze
```

Regenerating assets (all made from scratch, no third-party art or audio):

```bash
python3 tool/compose_music.py <out-dir>   # WAV loops, then convert to .m4a into assets/music/
python3 tool/compose_sfx.py assets/sfx
python3 tool/make_icon.py assets/icon && dart run flutter_launcher_icons
```

### Layout

- `lib/data`: courses and the pictures, drawn from shapes (`art_canvas.dart`, `artworks.dart`, `art/*.dart`), plus the tutorial heart.
- `lib/logic`: pure rules (scoring, Sort mode, drag lines).
- `lib/state`: game and sort controllers, saved progress, music and sounds, settings, achievements.
- `lib/ui`: screens, the canvas painters, tray, gallery, settings and tutorials.
