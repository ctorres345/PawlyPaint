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
    }
  ]
}
```

| ID | Screen | Severity | Status | Location | Issue |
|---|---|---|---|---|---|
| VIA-home-50f280ae | home | low | new | lib/ui/home\_screen.dart\:300 | Level pills and mode bars on open course cards use Colors.white70 and white54, so they cannot follow a dark theme. Existing code, not added by PAP-41. |
<!-- via:ledger:end -->
