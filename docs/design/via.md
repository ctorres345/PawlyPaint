# Design decisions and Via ledger

<!-- via:ledger:start -->
```json
{
  "findings": [
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
      "status": "new",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "paint",
      "rule": "contrast",
      "severity": "low",
      "file": "lib/ui/star_meter.dart",
      "line": 96,
      "issue": "Lost-star outline #d5c2c6 on #fff8f8 is about 1.5:1. The text line and the screen-reader label carry the same information, and the style matches the finish sheet.",
      "last_seen": "2026-11-16T12:35:28",
      "run": "20261116T172654Z"
    },
    {
      "id": "VIA-sort-1e27ace6",
      "status": "new",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "sort",
      "rule": "spec-meter-text-copy",
      "severity": "low",
      "file": "lib/ui/star_meter.dart",
      "line": 33,
      "issue": "Sort's 3-star line reads '… left for 3 stars · no shakes', not the target's '… · a shake costs the 3rd star'. It was shortened so it fits on one line at 360 dp.",
      "last_seen": "2026-11-16T12:35:28",
      "run": "20261116T172654Z"
    },
    {
      "id": "VIA-sort-2f359c0e",
      "status": "new",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "sort",
      "rule": "peek-overlap",
      "severity": "low",
      "file": "lib/ui/sort/sort_layout.dart",
      "line": 106,
      "issue": "At 360 dp the Hold-to-peek card covers about 2x4 beads at the top left of the board. This predates PAP-8: the before build overlaps by about the same amount, and the meter adds about 13 dp.",
      "last_seen": "2026-11-16T12:35:28",
      "run": "20261116T172654Z"
    },
    {
      "id": "VIA-sort-919b6275",
      "status": "new",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "sort",
      "rule": "hierarchy",
      "severity": "low",
      "file": "lib/ui/star_meter.dart",
      "line": 140,
      "issue": "The last-chance warning differs only by primary color; the star at risk looks the same as the others.",
      "last_seen": "2026-11-16T12:35:28",
      "run": "20261116T172654Z"
    },
    {
      "id": "VIA-sort-f202061c",
      "status": "new",
      "first_seen": "2026-11-16T12:35:22",
      "screen": "sort",
      "rule": "text-scaling",
      "severity": "low",
      "file": "lib/ui/star_meter.dart",
      "line": 95,
      "issue": "At 2x font the line fills the width while the 16 dp stars stay fixed. The line stays one line and readable (verified on device after the minHeight fix).",
      "last_seen": "2026-11-16T12:35:28",
      "run": "20261116T172654Z"
    }
  ]
}
```

| ID | Screen | Severity | Status | Location | Issue |
|---|---|---|---|---|---|
| VIA-home-50f280ae | home | low | new | lib/ui/home\_screen.dart\:300 | Level pills and mode bars on open course cards use Colors.white70 and white54, so they cannot follow a dark theme. Existing code, not added by PAP-41. |
| VIA-paint-1ff2fb53 | paint | low | new | lib/ui/star\_meter.dart\:96 | Lost-star outline \#d5c2c6 on \#fff8f8 is about 1.5\:1. The text line and the screen-reader label carry the same information, and the style matches the finish sheet. |
| VIA-sort-1e27ace6 | sort | low | new | lib/ui/star\_meter.dart\:33 | Sort's 3-star line reads '… left for 3 stars · no shakes', not the target's '… · a shake costs the 3rd star'. It was shortened so it fits on one line at 360 dp. |
| VIA-sort-2f359c0e | sort | low | new | lib/ui/sort/sort\_layout.dart\:106 | At 360 dp the Hold-to-peek card covers about 2x4 beads at the top left of the board. This predates PAP-8\: the before build overlaps by about the same amount, and the meter adds about 13 dp. |
| VIA-sort-919b6275 | sort | low | new | lib/ui/star\_meter.dart\:140 | The last-chance warning differs only by primary color; the star at risk looks the same as the others. |
| VIA-sort-f202061c | sort | low | new | lib/ui/star\_meter.dart\:95 | At 2x font the line fills the width while the 16 dp stars stay fixed. The line stays one line and readable (verified on device after the minHeight fix). |
<!-- via:ledger:end -->
