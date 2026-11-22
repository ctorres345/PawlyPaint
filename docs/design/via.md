# Design decisions and Via ledger

<!-- via:ledger:start -->
```json
{
  "findings": [
    {
      "id": "VIA-badges-35bfaa7f",
      "status": "new",
      "first_seen": "2026-11-19T01:03:54",
      "screen": "badges",
      "rule": "rainbow-medal-flat",
      "severity": "low",
      "file": "lib/ui/theme/paw_widgets.dart",
      "line": 375,
      "issue": "A chosen rainbow title would show a flat beige medal on the nameplate instead of the rainbow ring.",
      "last_seen": "2026-11-19T01:03:54",
      "run": "20261119T060321Z"
    },
    {
      "id": "VIA-badges-82d5e463",
      "status": "fixed",
      "first_seen": "2026-11-18T19:04:51",
      "screen": "badges",
      "rule": "badge-progress",
      "severity": "low",
      "file": "lib/ui/badges_screen.dart",
      "line": 227,
      "issue": "Locked badges show no progress counter and tier names are plain text.",
      "last_seen": "2026-11-18T19:04:51",
      "run": "20261118T234807Z",
      "fixed_in": "20261119T034952Z"
    },
    {
      "id": "VIA-badges-a8faa03e",
      "status": "new",
      "first_seen": "2026-11-19T01:03:54",
      "screen": "badges",
      "rule": "spec-nameplate-caption",
      "severity": "low",
      "file": "lib/ui/badges_screen.dart",
      "line": 54,
      "issue": "Prototype caption mentions multiplayer; the app says \"Your nameplate. It shows on Home.\" because multiplayer does not exist yet.",
      "last_seen": "2026-11-19T01:03:54",
      "run": "20261119T060321Z"
    },
    {
      "id": "VIA-badges-db3fe00a",
      "status": "new",
      "first_seen": "2026-11-19T01:03:54",
      "screen": "badges",
      "rule": "spec-combo-count-format",
      "severity": "low",
      "file": "lib/ui/badges_screen.dart",
      "line": 458,
      "issue": "Prototype shows Sort combo as \"x72 / x60\" with her best above target; the app shows \"30 / 30\" capped, with no x prefix.",
      "last_seen": "2026-11-19T01:03:54",
      "run": "20261119T060321Z"
    },
    {
      "id": "VIA-badges-f2ac400e",
      "status": "new",
      "first_seen": "2026-11-19T01:03:54",
      "screen": "badges",
      "rule": "gold-frame-contrast",
      "severity": "low",
      "file": "lib/ui/theme/tokens.dart",
      "line": 94,
      "issue": "Light-theme gold medal frame #C48F12 on surface is 2.84:1, under 3:1 for non-text. The tier label beside it (#7D5A00, 6.2:1) carries the meaning, and the frame is the prototype --gold token.",
      "last_seen": "2026-11-19T01:03:54",
      "run": "20261119T060321Z"
    },
    {
      "id": "VIA-badges-fc5dea80",
      "status": "fixed",
      "first_seen": "2026-11-18T22:50:09",
      "screen": "badges",
      "rule": "nameplate-not-tappable",
      "severity": "low",
      "file": "lib/ui/badges_screen.dart",
      "line": 58,
      "issue": "The nameplate pill on Badges does nothing when tapped; only the Name button edits.",
      "last_seen": "2026-11-18T22:50:09",
      "run": "20261119T034952Z",
      "fixed_in": "20261119T060321Z"
    },
    {
      "id": "VIA-catch-up-summary-c7b9b25c",
      "status": "new",
      "first_seen": "2026-11-18T17:37:35",
      "screen": "catch-up-summary",
      "rule": "dialog-style-mismatch",
      "severity": "low",
      "file": "lib/ui/unlock_ui.dart",
      "line": 116,
      "issue": "The welcome-back summary (PAP-41 AlertDialog) and the new celebration card look different: tint, title weight, button width.",
      "last_seen": "2026-11-18T17:54:40",
      "run": "20261118T223303Z"
    },
    {
      "id": "VIA-completion-sheet-56b8f47f",
      "status": "new",
      "first_seen": "2026-11-18T15:42:45",
      "screen": "completion-sheet",
      "rule": "locked-tile-no-marker",
      "severity": "low",
      "file": "lib/ui/frame_picker.dart",
      "line": 211,
      "issue": "After tapping a locked frame, its tile shows no mark linking it to the hint below.",
      "last_seen": "2026-11-18T15:42:45",
      "run": "20261118T204245Z"
    },
    {
      "id": "VIA-completion-sheet-7a4daff4",
      "status": "open",
      "first_seen": "2026-11-18T14:12:34",
      "screen": "completion-sheet",
      "rule": "mascot-contrast",
      "severity": "low",
      "file": "lib/ui/completion_sheet.dart",
      "line": 46,
      "issue": "White Mochi has little contrast on the pale sheet (unchanged from main).",
      "last_seen": "2026-11-18T15:42:45",
      "run": "20261118T204245Z"
    },
    {
      "id": "VIA-completion-sheet-b8d5f5eb",
      "status": "open",
      "first_seen": "2026-11-18T14:12:34",
      "screen": "completion-sheet",
      "rule": "save-low-emphasis",
      "severity": "low",
      "file": "lib/ui/picture_export.dart",
      "line": 207,
      "issue": "Save to Photos is a plain text button (unchanged from main).",
      "last_seen": "2026-11-18T15:42:45",
      "run": "20261118T204245Z"
    },
    {
      "id": "VIA-completion-sheet-ca163f7b",
      "status": "new",
      "first_seen": "2026-11-18T15:42:45",
      "screen": "completion-sheet",
      "rule": "secret-frame-label",
      "severity": "low",
      "file": "lib/logic/photo_frames.dart",
      "line": 28,
      "issue": "The hidden frame is labelled \"Secret\", which reads like a placeholder next to Wood or Lace.",
      "last_seen": "2026-11-18T15:42:45",
      "run": "20261118T204245Z"
    },
    {
      "id": "VIA-completion-sheet-d2363e50",
      "status": "open",
      "first_seen": "2026-11-18T14:12:34",
      "screen": "completion-sheet",
      "rule": "hint-shifts-buttons",
      "severity": "low",
      "file": "lib/ui/frame_picker.dart",
      "line": 150,
      "issue": "The unlock hint appearing pushes Save to Photos and the main button down (animated by AnimatedSize).",
      "last_seen": "2026-11-18T15:42:45",
      "run": "20261118T204245Z"
    },
    {
      "id": "VIA-completion-sheet-e71bc830",
      "status": "fixed",
      "first_seen": "2026-11-18T14:12:34",
      "screen": "completion-sheet",
      "rule": "frame-preview",
      "severity": "med",
      "file": "lib/ui/completion_sheet.dart",
      "line": 56,
      "issue": "Picking a frame changes only the tile outline; the picture preview above (and the gallery viewer, lib/ui/gallery_screen.dart:172) still shows no frame, so she sees the frame only in Photos.",
      "last_seen": "2026-11-18T14:12:34",
      "run": "20261118T190747Z",
      "fixed_in": "20261118T195952Z"
    },
    {
      "id": "VIA-course-65d0d4fb",
      "status": "new",
      "first_seen": "2026-11-18T22:50:09",
      "screen": "course",
      "rule": "filled-star-contrast",
      "severity": "med",
      "file": "lib/ui/theme/tokens.dart",
      "line": 81,
      "issue": "Light-theme star #E0A21B on surface #FFFDF9 is about 2.25:1, under the 3:1 non-text minimum. The value is the PAP-19 prototype's --star token.",
      "last_seen": "2026-11-18T22:50:09",
      "run": "20261119T034952Z",
      "ticket": "PAP-63"
    },
    {
      "id": "VIA-course-70c78701",
      "status": "fixed",
      "first_seen": "2026-11-18T19:04:51",
      "screen": "course",
      "rule": "empty-star-contrast",
      "severity": "med",
      "file": "lib/ui/course_screen.dart",
      "line": 321,
      "issue": "Unearned stars used the outline color and almost vanished on dark tiles.",
      "last_seen": "2026-11-18T19:04:51",
      "run": "20261118T234807Z",
      "fixed_in": "20261119T002037Z"
    },
    {
      "id": "VIA-gallery-fdbb613c",
      "status": "fixed",
      "first_seen": "2026-11-18T19:04:51",
      "screen": "gallery",
      "rule": "gallery-footer-copy",
      "severity": "low",
      "file": "lib/ui/gallery_screen.dart",
      "line": 150,
      "issue": "Footer said gray tiles are unfinished pictures, but they are grouped in one ? tile.",
      "last_seen": "2026-11-18T19:04:51",
      "run": "20261118T234807Z",
      "fixed_in": "20261119T002037Z"
    },
    {
      "id": "VIA-home-1cffbe82",
      "status": "new",
      "first_seen": "2026-11-22T12:09:36",
      "screen": "home",
      "rule": "dismiss-motion",
      "severity": "low",
      "file": "lib/ui/home_screen.dart",
      "line": 156,
      "issue": "Dismissing the card removes it in one frame, so the cards below jump up.",
      "last_seen": "2026-11-22T12:09:36",
      "run": "20261122T170918Z",
      "ticket": "PAP-88"
    },
    {
      "id": "VIA-home-50f280ae",
      "status": "fixed",
      "first_seen": "2026-11-12T03:55:25",
      "screen": "home",
      "rule": "hardcoded-white-pill",
      "severity": "low",
      "file": "lib/ui/home_screen.dart",
      "line": 300,
      "issue": "Level pills and mode bars on open course cards use Colors.white70 and white54, so they cannot follow a dark theme. Existing code, not added by PAP-41.",
      "last_seen": "2026-11-12T03:55:25",
      "run": "20261112T085516Z",
      "fixed_in": "20261118T223303Z"
    },
    {
      "id": "VIA-home-709d46fe",
      "status": "open",
      "first_seen": "2026-11-22T11:37:04",
      "screen": "home",
      "rule": "text-clipped-largest-font",
      "severity": "med",
      "file": "lib/ui/home_screen.dart",
      "line": 607,
      "issue": "At the largest font the locked Today's picture and Time Attack cards cut their hint text (fixed-height _LockedHero). It is the same on main without the new card; the course labels under the tip bar are only the list's scroll edge, since Home is a ListView.",
      "last_seen": "2026-11-22T12:09:36",
      "run": "20261122T170918Z",
      "ticket": "PAP-88"
    },
    {
      "id": "VIA-home-774c8889",
      "status": "fixed",
      "first_seen": "2026-11-18T19:04:51",
      "screen": "home",
      "rule": "shelf-title-truncation",
      "severity": "low",
      "file": "lib/ui/home_screen.dart",
      "line": 683,
      "issue": "Course shelf titles like Animal Friends were cut with an ellipsis at 78 wide.",
      "last_seen": "2026-11-18T19:04:51",
      "run": "20261118T234807Z",
      "fixed_in": "20261119T002037Z"
    },
    {
      "id": "VIA-home-7d19a298",
      "status": "fixed",
      "first_seen": "2026-11-18T17:37:35",
      "screen": "home",
      "rule": "home-middle-stack-mixed",
      "severity": "low",
      "file": "lib/ui/home_screen.dart",
      "line": 702,
      "issue": "Gallery/How to play pills, the Unlocks strip and the Time Attack bar each use a different treatment; the strip has no progress bar.",
      "last_seen": "2026-11-18T17:54:40",
      "run": "20261118T223303Z",
      "fixed_in": "20261118T234807Z"
    },
    {
      "id": "VIA-home-b40beffb",
      "status": "open",
      "first_seen": "2026-11-19T01:03:54",
      "screen": "home",
      "rule": "summary-note-fixed-margin",
      "severity": "low",
      "file": "lib/ui/badges_screen.dart",
      "line": 130,
      "issue": "The badge summary note uses a fixed 164 pt bottom margin to clear the unlock strip and dock; at very large text, or with no strip, the gap may be off.",
      "last_seen": "2026-11-22T12:09:36",
      "run": "20261122T170918Z"
    },
    {
      "id": "VIA-paint-1ff2fb53",
      "status": "open",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "paint",
      "rule": "contrast",
      "severity": "low",
      "file": "lib/ui/star_meter.dart",
      "line": 96,
      "issue": "Lost-star outline #d5c2c6 on #fff8f8 is about 1.5:1. The text line and the screen-reader label carry the same information, and the style matches the finish sheet.",
      "last_seen": "2026-11-16T13:48:37",
      "run": "20261116T180954Z"
    },
    {
      "id": "VIA-paint-3ba78c04",
      "status": "new",
      "first_seen": "2026-11-16T13:48:37",
      "screen": "paint",
      "rule": "overlap-blend",
      "severity": "low",
      "file": "lib/ui/board.dart",
      "line": null,
      "issue": "Rings (and Sort spots) now draw as one path, so where two overlap at far zoom-out the alpha no longer doubles up.",
      "last_seen": "2026-11-16T13:48:37",
      "run": "20261116T180954Z"
    },
    {
      "id": "VIA-paint-bad787f8",
      "status": "new",
      "first_seen": "2026-11-16T13:48:37",
      "screen": "paint",
      "rule": "raster-resample",
      "severity": "low",
      "file": "lib/ui/desk.dart",
      "line": null,
      "issue": "The desk background is now a baked bitmap (max side 2560 px); on phones above about DPR 2.9 its linen and grain lines resample and look slightly softer than the vector desk.",
      "last_seen": "2026-11-16T13:48:37",
      "run": "20261116T180954Z"
    },
    {
      "id": "VIA-picture-viewer-68ee0f44",
      "status": "new",
      "first_seen": "2026-11-18T15:42:45",
      "screen": "picture-viewer",
      "rule": "paper-color-mismatch",
      "severity": "low",
      "file": "lib/ui/gallery_screen.dart",
      "line": 182,
      "issue": "The gallery fills the frame opening with the canvas theme sheet colour, while saves use the default paper; on non-linen themes the preview and the photo differ (the unframed viewer already did).",
      "last_seen": "2026-11-18T15:42:45",
      "run": "20261118T204245Z"
    },
    {
      "id": "VIA-settings-25814e62",
      "status": "new",
      "first_seen": "2026-11-18T22:50:09",
      "screen": "settings",
      "rule": "canvas-swatch-edge",
      "severity": "low",
      "file": "lib/ui/settings_screen.dart",
      "line": 330,
      "issue": "Night sky swatch blends into the dark card; Linen has a faint edge on the light card.",
      "last_seen": "2026-11-18T22:50:09",
      "run": "20261119T034952Z"
    },
    {
      "id": "VIA-settings-af984119",
      "status": "fixed",
      "first_seen": "2026-11-18T19:04:51",
      "screen": "settings",
      "rule": "drills-vs-beads",
      "severity": "low",
      "file": "lib/ui/settings_screen.dart",
      "line": 69,
      "issue": "Settings says Drills while the Vibration caption says beads (wording from main).",
      "last_seen": "2026-11-18T19:04:51",
      "run": "20261118T234807Z",
      "fixed_in": "20261119T034952Z"
    },
    {
      "id": "VIA-sort-1e27ace6",
      "status": "open",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "sort",
      "rule": "spec-meter-text-copy",
      "severity": "low",
      "file": "lib/ui/star_meter.dart",
      "line": 33,
      "issue": "Sort's 3-star line reads '… left for 3 stars · no shakes', not the target's '… · a shake costs the 3rd star'. It was shortened so it fits on one line at 360 dp.",
      "last_seen": "2026-11-16T13:48:37",
      "run": "20261116T180954Z"
    },
    {
      "id": "VIA-sort-2f359c0e",
      "status": "open",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "sort",
      "rule": "peek-overlap",
      "severity": "low",
      "file": "lib/ui/sort/sort_layout.dart",
      "line": 106,
      "issue": "At 360 dp the Hold-to-peek card covers about 2x4 beads at the top left of the board. This predates PAP-8: the before build overlaps by about the same amount, and the meter adds about 13 dp.",
      "last_seen": "2026-11-16T13:48:37",
      "run": "20261116T180954Z"
    },
    {
      "id": "VIA-sort-919b6275",
      "status": "open",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "sort",
      "rule": "hierarchy",
      "severity": "low",
      "file": "lib/ui/star_meter.dart",
      "line": 140,
      "issue": "The last-chance warning differs only by primary color; the star at risk looks the same as the others.",
      "last_seen": "2026-11-16T13:48:37",
      "run": "20261116T180954Z"
    },
    {
      "id": "VIA-sort-f202061c",
      "status": "open",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "sort",
      "rule": "text-scaling",
      "severity": "low",
      "file": "lib/ui/star_meter.dart",
      "line": 95,
      "issue": "At 2x font the line fills the width while the 16 dp stars stay fixed. The line stays one line and readable (verified on device after the minHeight fix).",
      "last_seen": "2026-11-16T13:48:37",
      "run": "20261116T180954Z"
    },
    {
      "id": "VIA-unlock-celebration-92d6e35b",
      "status": "new",
      "first_seen": "2026-11-18T17:37:35",
      "screen": "unlock-celebration",
      "rule": "celebration-primary-cta",
      "severity": "low",
      "file": "lib/ui/unlock_celebration.dart",
      "line": 179,
      "issue": "The board's primary action is 'Try it now'; the build uses 'See my unlocks' because most rewards have no content yet, and leaving from the finish screen goes Home anyway.",
      "last_seen": "2026-11-18T17:54:40",
      "run": "20261118T223303Z"
    },
    {
      "id": "VIA-unlocks-b9b8c3e0",
      "status": "new",
      "first_seen": "2026-11-18T17:37:35",
      "screen": "unlocks",
      "rule": "no-dark-theme",
      "severity": "low",
      "file": "lib/main.dart",
      "line": 40,
      "issue": "The app has no dark theme yet, so dark screenshots cannot be taken. Colors come from ColorScheme, so the new screens follow one when PAP-20 adds it.",
      "last_seen": "2026-11-18T17:54:40",
      "run": "20261118T223303Z"
    },
    {
      "id": "VIA-unlocks-ba02ff9c",
      "status": "new",
      "first_seen": "2026-11-18T17:37:35",
      "screen": "unlocks",
      "rule": "three-star-icon-shared",
      "severity": "low",
      "file": "lib/ui/unlocks_screen.dart",
      "line": 54,
      "issue": "The same gold star marks total stars on Home and three-star pictures on Unlocks.",
      "last_seen": "2026-11-18T17:54:40",
      "run": "20261118T223303Z"
    },
    {
      "id": "VIA-unlocks-bc103898",
      "status": "new",
      "first_seen": "2026-11-18T17:54:40",
      "screen": "unlocks",
      "rule": "spec-earned-row-action",
      "severity": "med",
      "file": "lib/ui/unlocks_screen.dart",
      "line": 332,
      "issue": "The PAP-19 board ends each earned row with a tonal 'Use' / 'Try it' button. The build has none: only frames have content yet, and frames are picked when saving from Gallery or the finish sheet, so there is nothing to use from here.",
      "last_seen": "2026-11-18T17:54:40",
      "run": "20261118T223303Z"
    },
    {
      "id": "VIA-unlocks-de3de95e",
      "status": "new",
      "first_seen": "2026-11-18T17:37:35",
      "screen": "unlocks",
      "rule": "three-star-wording",
      "severity": "low",
      "file": "lib/ui/unlocks_screen.dart",
      "line": 326,
      "issue": "Short forms vary: '7 three-star', 'at 5 three-star', '3 more three-star pictures'.",
      "last_seen": "2026-11-18T17:54:40",
      "run": "20261118T223303Z"
    }
  ]
}
```

| ID | Screen | Severity | Status | Location | Issue |
|---|---|---|---|---|---|
| VIA-badges-35bfaa7f | badges | low | new | lib/ui/theme/paw\_widgets.dart\:375 | A chosen rainbow title would show a flat beige medal on the nameplate instead of the rainbow ring. |
| VIA-badges-82d5e463 | badges | low | fixed | lib/ui/badges\_screen.dart\:227 | Locked badges show no progress counter and tier names are plain text. |
| VIA-badges-a8faa03e | badges | low | new | lib/ui/badges\_screen.dart\:54 | Prototype caption mentions multiplayer; the app says "Your nameplate. It shows on Home." because multiplayer does not exist yet. |
| VIA-badges-db3fe00a | badges | low | new | lib/ui/badges\_screen.dart\:458 | Prototype shows Sort combo as "x72 / x60" with her best above target; the app shows "30 / 30" capped, with no x prefix. |
| VIA-badges-f2ac400e | badges | low | new | lib/ui/theme/tokens.dart\:94 | Light-theme gold medal frame \#C48F12 on surface is 2.84\:1, under 3\:1 for non-text. The tier label beside it (\#7D5A00, 6.2\:1) carries the meaning, and the frame is the prototype --gold token. |
| VIA-badges-fc5dea80 | badges | low | fixed | lib/ui/badges\_screen.dart\:58 | The nameplate pill on Badges does nothing when tapped; only the Name button edits. |
| VIA-catch-up-summary-c7b9b25c | catch-up-summary | low | new | lib/ui/unlock\_ui.dart\:116 | The welcome-back summary (PAP-41 AlertDialog) and the new celebration card look different\: tint, title weight, button width. |
| VIA-completion-sheet-56b8f47f | completion-sheet | low | new | lib/ui/frame\_picker.dart\:211 | After tapping a locked frame, its tile shows no mark linking it to the hint below. |
| VIA-completion-sheet-7a4daff4 | completion-sheet | low | open | lib/ui/completion\_sheet.dart\:46 | White Mochi has little contrast on the pale sheet (unchanged from main). |
| VIA-completion-sheet-b8d5f5eb | completion-sheet | low | open | lib/ui/picture\_export.dart\:207 | Save to Photos is a plain text button (unchanged from main). |
| VIA-completion-sheet-ca163f7b | completion-sheet | low | new | lib/logic/photo\_frames.dart\:28 | The hidden frame is labelled "Secret", which reads like a placeholder next to Wood or Lace. |
| VIA-completion-sheet-d2363e50 | completion-sheet | low | open | lib/ui/frame\_picker.dart\:150 | The unlock hint appearing pushes Save to Photos and the main button down (animated by AnimatedSize). |
| VIA-completion-sheet-e71bc830 | completion-sheet | med | fixed | lib/ui/completion\_sheet.dart\:56 | Picking a frame changes only the tile outline; the picture preview above (and the gallery viewer, lib/ui/gallery\_screen.dart\:172) still shows no frame, so she sees the frame only in Photos. |
| VIA-course-65d0d4fb | course | med | new | lib/ui/theme/tokens.dart\:81 | Light-theme star \#E0A21B on surface \#FFFDF9 is about 2.25\:1, under the 3\:1 non-text minimum. The value is the PAP-19 prototype's --star token. |
| VIA-course-70c78701 | course | med | fixed | lib/ui/course\_screen.dart\:321 | Unearned stars used the outline color and almost vanished on dark tiles. |
| VIA-gallery-fdbb613c | gallery | low | fixed | lib/ui/gallery\_screen.dart\:150 | Footer said gray tiles are unfinished pictures, but they are grouped in one ? tile. |
| VIA-home-1cffbe82 | home | low | new | lib/ui/home\_screen.dart\:156 | Dismissing the card removes it in one frame, so the cards below jump up. |
| VIA-home-50f280ae | home | low | fixed | lib/ui/home\_screen.dart\:300 | Level pills and mode bars on open course cards use Colors.white70 and white54, so they cannot follow a dark theme. Existing code, not added by PAP-41. |
| VIA-home-709d46fe | home | med | open | lib/ui/home\_screen.dart\:607 | At the largest font the locked Today's picture and Time Attack cards cut their hint text (fixed-height \_LockedHero). It is the same on main without the new card; the course labels under the tip bar are only the list's scroll edge, since Home is a ListView. |
| VIA-home-774c8889 | home | low | fixed | lib/ui/home\_screen.dart\:683 | Course shelf titles like Animal Friends were cut with an ellipsis at 78 wide. |
| VIA-home-7d19a298 | home | low | fixed | lib/ui/home\_screen.dart\:702 | Gallery/How to play pills, the Unlocks strip and the Time Attack bar each use a different treatment; the strip has no progress bar. |
| VIA-home-b40beffb | home | low | open | lib/ui/badges\_screen.dart\:130 | The badge summary note uses a fixed 164 pt bottom margin to clear the unlock strip and dock; at very large text, or with no strip, the gap may be off. |
| VIA-paint-1ff2fb53 | paint | low | open | lib/ui/star\_meter.dart\:96 | Lost-star outline \#d5c2c6 on \#fff8f8 is about 1.5\:1. The text line and the screen-reader label carry the same information, and the style matches the finish sheet. |
| VIA-paint-3ba78c04 | paint | low | new | lib/ui/board.dart | Rings (and Sort spots) now draw as one path, so where two overlap at far zoom-out the alpha no longer doubles up. |
| VIA-paint-bad787f8 | paint | low | new | lib/ui/desk.dart | The desk background is now a baked bitmap (max side 2560 px); on phones above about DPR 2.9 its linen and grain lines resample and look slightly softer than the vector desk. |
| VIA-picture-viewer-68ee0f44 | picture-viewer | low | new | lib/ui/gallery\_screen.dart\:182 | The gallery fills the frame opening with the canvas theme sheet colour, while saves use the default paper; on non-linen themes the preview and the photo differ (the unframed viewer already did). |
| VIA-settings-25814e62 | settings | low | new | lib/ui/settings\_screen.dart\:330 | Night sky swatch blends into the dark card; Linen has a faint edge on the light card. |
| VIA-settings-af984119 | settings | low | fixed | lib/ui/settings\_screen.dart\:69 | Settings says Drills while the Vibration caption says beads (wording from main). |
| VIA-sort-1e27ace6 | sort | low | open | lib/ui/star\_meter.dart\:33 | Sort's 3-star line reads '… left for 3 stars · no shakes', not the target's '… · a shake costs the 3rd star'. It was shortened so it fits on one line at 360 dp. |
| VIA-sort-2f359c0e | sort | low | open | lib/ui/sort/sort\_layout.dart\:106 | At 360 dp the Hold-to-peek card covers about 2x4 beads at the top left of the board. This predates PAP-8\: the before build overlaps by about the same amount, and the meter adds about 13 dp. |
| VIA-sort-919b6275 | sort | low | open | lib/ui/star\_meter.dart\:140 | The last-chance warning differs only by primary color; the star at risk looks the same as the others. |
| VIA-sort-f202061c | sort | low | open | lib/ui/star\_meter.dart\:95 | At 2x font the line fills the width while the 16 dp stars stay fixed. The line stays one line and readable (verified on device after the minHeight fix). |
| VIA-unlock-celebration-92d6e35b | unlock-celebration | low | new | lib/ui/unlock\_celebration.dart\:179 | The board's primary action is 'Try it now'; the build uses 'See my unlocks' because most rewards have no content yet, and leaving from the finish screen goes Home anyway. |
| VIA-unlocks-b9b8c3e0 | unlocks | low | new | lib/main.dart\:40 | The app has no dark theme yet, so dark screenshots cannot be taken. Colors come from ColorScheme, so the new screens follow one when PAP-20 adds it. |
| VIA-unlocks-ba02ff9c | unlocks | low | new | lib/ui/unlocks\_screen.dart\:54 | The same gold star marks total stars on Home and three-star pictures on Unlocks. |
| VIA-unlocks-bc103898 | unlocks | med | new | lib/ui/unlocks\_screen.dart\:332 | The PAP-19 board ends each earned row with a tonal 'Use' / 'Try it' button. The build has none\: only frames have content yet, and frames are picked when saving from Gallery or the finish sheet, so there is nothing to use from here. |
| VIA-unlocks-de3de95e | unlocks | low | new | lib/ui/unlocks\_screen.dart\:326 | Short forms vary\: '7 three-star', 'at 5 three-star', '3 more three-star pictures'. |
<!-- via:ledger:end -->
