# Redesign art

Illustrations for the redesign approved in PAP-19. Cesar made them in Gemini from his Mochi reference art.

- Each file is the original art with its background cut out and scaled down to at most 512 px (1024 px in `app_icon/`). Smaller art is never scaled up. Nothing is redrawn. Don't edit these files by hand; replace one with a new cutout of new art instead.
- Every PNG has a transparent background, except `app_icon/app_icon.png`, which sits on a solid light pink. Its pixels read `#FDEAF0`, a shade off the launcher's `#FCE4EC` (`adaptive_icon_background`), so the launcher icon ticket should pick one of the two.
- `test/art_assets_test.dart` checks that every bundled folder is declared in `pubspec.yaml` and holds only PNGs, and that each one decodes, is at most 1024 px and has transparent corners and a mostly clear border.

| Folder | Contents | Used by |
|---|---|---|
| `brand/` | mark, wordmark and full logo, `_light` and `_dark` | Home top bar |
| `icons/` | game icons: boosters, modes, rewards, locks, stars, palette swatches | Home, dock, play screens, Unlocks |
| `mochi/` | Mochi poses and avatar | empty states, results, hints, nameplate |
| `difficulty/` | Mochi difficulty icons, Easy to Extreme | Course screen, Keep painting |
| `courses/` | course covers (`cafe.png` is Cat Café) | Home course shelf |
| `tiers/` | badge tier frames, center left empty | Badges |
| `badges/` | badge art | Badges |
| `app_icon/` | the app icon and its adaptive foreground, not bundled | a later launcher icon ticket |

The original Gemini sheets are kept outside the repo.
