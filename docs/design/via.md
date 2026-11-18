# Design decisions and Via ledger

<!-- via:ledger:start -->
```json
{
  "findings": [
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
      "id": "VIA-home-50f280ae",
      "status": "new",
      "first_seen": "2026-11-12T03:55:25",
      "screen": "home",
      "rule": "hardcoded-white-pill",
      "severity": "low",
      "file": "lib/ui/home_screen.dart",
      "line": 300,
      "issue": "Level pills and mode bars on open course cards use Colors.white70 and white54, so they cannot follow a dark theme. Existing code, not added by PAP-41.",
      "last_seen": "2026-11-12T03:55:25",
      "run": "20261112T085516Z"
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
    }
  ]
}
```

| ID | Screen | Severity | Status | Location | Issue |
|---|---|---|---|---|---|
| VIA-completion-sheet-56b8f47f | completion-sheet | low | new | lib/ui/frame\_picker.dart\:211 | After tapping a locked frame, its tile shows no mark linking it to the hint below. |
| VIA-completion-sheet-7a4daff4 | completion-sheet | low | open | lib/ui/completion\_sheet.dart\:46 | White Mochi has little contrast on the pale sheet (unchanged from main). |
| VIA-completion-sheet-b8d5f5eb | completion-sheet | low | open | lib/ui/picture\_export.dart\:207 | Save to Photos is a plain text button (unchanged from main). |
| VIA-completion-sheet-ca163f7b | completion-sheet | low | new | lib/logic/photo\_frames.dart\:28 | The hidden frame is labelled "Secret", which reads like a placeholder next to Wood or Lace. |
| VIA-completion-sheet-d2363e50 | completion-sheet | low | open | lib/ui/frame\_picker.dart\:150 | The unlock hint appearing pushes Save to Photos and the main button down (animated by AnimatedSize). |
| VIA-completion-sheet-e71bc830 | completion-sheet | med | fixed | lib/ui/completion\_sheet.dart\:56 | Picking a frame changes only the tile outline; the picture preview above (and the gallery viewer, lib/ui/gallery\_screen.dart\:172) still shows no frame, so she sees the frame only in Photos. |
| VIA-home-50f280ae | home | low | new | lib/ui/home\_screen.dart\:300 | Level pills and mode bars on open course cards use Colors.white70 and white54, so they cannot follow a dark theme. Existing code, not added by PAP-41. |
| VIA-paint-1ff2fb53 | paint | low | open | lib/ui/star\_meter.dart\:96 | Lost-star outline \#d5c2c6 on \#fff8f8 is about 1.5\:1. The text line and the screen-reader label carry the same information, and the style matches the finish sheet. |
| VIA-paint-3ba78c04 | paint | low | new | lib/ui/board.dart | Rings (and Sort spots) now draw as one path, so where two overlap at far zoom-out the alpha no longer doubles up. |
| VIA-paint-bad787f8 | paint | low | new | lib/ui/desk.dart | The desk background is now a baked bitmap (max side 2560 px); on phones above about DPR 2.9 its linen and grain lines resample and look slightly softer than the vector desk. |
| VIA-picture-viewer-68ee0f44 | picture-viewer | low | new | lib/ui/gallery\_screen.dart\:182 | The gallery fills the frame opening with the canvas theme sheet colour, while saves use the default paper; on non-linen themes the preview and the photo differ (the unframed viewer already did). |
| VIA-sort-1e27ace6 | sort | low | open | lib/ui/star\_meter.dart\:33 | Sort's 3-star line reads '… left for 3 stars · no shakes', not the target's '… · a shake costs the 3rd star'. It was shortened so it fits on one line at 360 dp. |
| VIA-sort-2f359c0e | sort | low | open | lib/ui/sort/sort\_layout.dart\:106 | At 360 dp the Hold-to-peek card covers about 2x4 beads at the top left of the board. This predates PAP-8\: the before build overlaps by about the same amount, and the meter adds about 13 dp. |
| VIA-sort-919b6275 | sort | low | open | lib/ui/star\_meter.dart\:140 | The last-chance warning differs only by primary color; the star at risk looks the same as the others. |
| VIA-sort-f202061c | sort | low | open | lib/ui/star\_meter.dart\:95 | At 2x font the line fills the width while the 16 dp stars stay fixed. The line stays one line and readable (verified on device after the minHeight fix). |
<!-- via:ledger:end -->
