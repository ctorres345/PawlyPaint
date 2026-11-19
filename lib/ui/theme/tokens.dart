import 'package:flutter/material.dart';

import '../../models/puzzle.dart' show Difficulty;
import '../../state/achievements.dart' show BadgeTier;

/// The redesign tokens (PAP-19 "Tokens" board, approved 2026-11-16).
///
/// Every menu color comes from here, so screens never hard-code one. Light is
/// Latte and dark is Espresso; the other palettes (PAP-44) only swap the
/// eleven palette tokens and keep everything else.
@immutable
class PawTokens extends ThemeExtension<PawTokens> {
  const PawTokens({
    required this.bg,
    required this.surface,
    required this.tint,
    required this.outline,
    required this.accent,
    required this.onAccent,
    required this.soft,
    required this.onSoft,
    required this.muted,
    required this.desk,
    required this.deskLine,
    required this.ink,
    required this.star,
    required this.danger,
    required this.success,
    required this.streak,
    required this.scrim,
    required this.shadow,
    required this.courseTints,
    required this.tiers,
  });

  // Palette tokens: a palette swaps these.
  final Color bg;
  final Color surface;
  final Color tint;
  final Color outline;
  final Color accent;
  final Color onAccent;
  final Color soft;
  final Color onSoft;
  final Color muted;
  final Color desk;
  final Color deskLine;

  // Fixed tokens: a palette keeps these (light and dark still differ).
  final Color ink;
  final Color star;
  final Color danger;
  final Color success;
  final Color streak;
  final Color scrim;

  /// The one card shadow. Dark themes use the outline only.
  final List<BoxShadow> shadow;

  /// Course backgrounds, in [CourseTint] order.
  final List<Color> courseTints;

  /// Frame, fill and text color per badge tier (rainbow is a placeholder).
  final Map<BadgeTier, TierColors> tiers;

  Color courseTint(CourseTint t) => courseTints[t.index];

  static const latte = PawTokens(
    bg: Color(0xFFFBF5EE),
    surface: Color(0xFFFFFDF9),
    tint: Color(0xFFF3E7DA),
    outline: Color(0xFFE7D7C7),
    accent: Color(0xFFB8496E),
    onAccent: Color(0xFFFFFFFF),
    soft: Color(0xFFF7DCE5),
    onSoft: Color(0xFF7A2B47),
    muted: Color(0xFF7A6258),
    desk: Color(0xFFEFE4D6),
    deskLine: Color(0xFFE4D5C3),
    ink: Color(0xFF3B2A24),
    star: Color(0xFFE0A21B),
    danger: Color(0xFFB3372F),
    success: Color(0xFF3F7F52),
    streak: Color(0xFFD9622B),
    scrim: Color(0x731E1715),
    shadow: [
      BoxShadow(color: Color(0x0F3B2A24), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x123B2A24), offset: Offset(0, 4), blurRadius: 12),
    ],
    courseTints: [Color(0xFFF9DCE6), Color(0xFFFCE5C8), Color(0xFFE1F0DC), Color(0xFFF0DFF3), Color(0xFFF3E6D8)],
    tiers: {
      BadgeTier.bronze: TierColors(Color(0xFFB5733A), Color(0xFFF6E3D1), Color(0xFF8A5226)),
      BadgeTier.silver: TierColors(Color(0xFF7C8691), Color(0xFFE7EAEE), Color(0xFF5A636D)),
      BadgeTier.gold: TierColors(Color(0xFFC48F12), Color(0xFFFBEFC8), Color(0xFF7D5A00)),
      BadgeTier.platinum: TierColors(Color(0xFF5B8FA3), Color(0xFFDCEEF3), Color(0xFF2F6A80)),
      BadgeTier.rainbow: TierColors(Color(0xFFE7D7C7), Color(0xFFFFFDF9), Color(0xFF7A6258)),
    },
  );

  static const espresso = PawTokens(
    bg: Color(0xFF1E1715),
    surface: Color(0xFF2A211E),
    tint: Color(0xFF372B26),
    outline: Color(0xFF4A3B35),
    accent: Color(0xFFF08DAE),
    onAccent: Color(0xFF3A1020),
    soft: Color(0xFF4A2A35),
    onSoft: Color(0xFFFFD9E4),
    muted: Color(0xFFC4AEA2),
    desk: Color(0xFF241B18),
    deskLine: Color(0xFF2F2521),
    ink: Color(0xFFF5E9DF),
    star: Color(0xFFF2C14E),
    danger: Color(0xFFFF8A80),
    success: Color(0xFF8FD3A0),
    streak: Color(0xFFFF9A62),
    scrim: Color(0x99000000),
    shadow: [],
    courseTints: [Color(0xFF3A2730), Color(0xFF3A2C1E), Color(0xFF24302A), Color(0xFF33263A), Color(0xFF33291F)],
    tiers: {
      BadgeTier.bronze: TierColors(Color(0xFFE0A574), Color(0xFF3A2A1E), Color(0xFFE0A574)),
      BadgeTier.silver: TierColors(Color(0xFFC3CBD4), Color(0xFF2D3136), Color(0xFFC3CBD4)),
      BadgeTier.gold: TierColors(Color(0xFFF2C14E), Color(0xFF3A311A), Color(0xFFF2C14E)),
      BadgeTier.platinum: TierColors(Color(0xFF9DD3E6), Color(0xFF1E3138), Color(0xFF9DD3E6)),
      BadgeTier.rainbow: TierColors(Color(0xFF4A3B35), Color(0xFF2A211E), Color(0xFFC4AEA2)),
    },
  );

  static PawTokens of(BuildContext context) => Theme.of(context).extension<PawTokens>() ?? latte;

  @override
  PawTokens copyWith() => this;

  @override
  PawTokens lerp(PawTokens? other, double t) => t < 0.5 || other == null ? this : other;
}

/// The background tints a course can wear on Home and its own screen.
enum CourseTint { pink, orange, green, purple, tan }

/// Colors of one badge tier.
@immutable
class TierColors {
  const TierColors(this.frame, this.fill, this.text);

  final Color frame;
  final Color fill;
  final Color text;
}

/// The rainbow tier's frame (PAP-48), fixed in both themes like the tier colors. The first color
/// repeats at the end so a sweep around the frame has no seam.
const rainbowColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFFB347),
  Color(0xFFFFE066),
  Color(0xFF7ED957),
  Color(0xFF5BC0EB),
  Color(0xFF9B7EDE),
  Color(0xFFFF6B6B),
];

/// Difficulty colors on the Course screen stickers (PAP-20). They don't follow
/// the palette, like the gems, and carry dark ink text.
const difficultyColors = {
  Difficulty.easy: Color(0xFF81C784),
  Difficulty.medium: Color(0xFF64B5F6),
  Difficulty.hard: Color(0xFFBA68C8),
  Difficulty.extreme: Color(0xFFFF8A65),
};

/// Ink on the fixed difficulty colors and the star button, in both themes.
const fixedInk = Color(0xFF3B2A24);

/// The bead color in drill previews (Settings), the same in every theme.
const previewGem = Color(0xFFE2445C);

/// Shape and space (PAP-19 tokens).
abstract final class PawRadius {
  static const chip = 12.0;
  static const tile = 20.0;
  static const hero = 28.0;
  static const pill = 999.0;
}

/// Builds the app theme for [t], with Quicksand and the PAP-19 type scale.
ThemeData pawTheme(PawTokens t, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.accent,
    onPrimary: t.onAccent,
    primaryContainer: t.soft,
    onPrimaryContainer: t.onSoft,
    secondary: t.accent,
    onSecondary: t.onAccent,
    secondaryContainer: t.soft,
    onSecondaryContainer: t.onSoft,
    tertiary: t.star,
    onTertiary: fixedInk,
    error: t.danger,
    onError: t.surface,
    surface: t.surface,
    onSurface: t.ink,
    onSurfaceVariant: t.muted,
    surfaceContainerLowest: t.surface,
    surfaceContainerLow: t.bg,
    surfaceContainer: t.tint,
    surfaceContainerHigh: t.tint,
    surfaceContainerHighest: t.tint,
    outline: t.muted,
    outlineVariant: t.outline,
    scrim: t.scrim,
    shadow: t.ink,
    inverseSurface: t.ink,
    onInverseSurface: t.bg,
    inversePrimary: t.soft,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Quicksand',
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    extensions: [t],
  );
  final x = base.textTheme;
  TextStyle? w(TextStyle? s, double size, FontWeight weight) =>
      s?.copyWith(fontSize: size, fontWeight: weight, color: t.ink);
  return base.copyWith(
    textTheme: x.copyWith(
      headlineMedium: w(x.headlineMedium, 26, FontWeight.w800),
      headlineSmall: w(x.headlineSmall, 26, FontWeight.w800),
      titleLarge: w(x.titleLarge, 20, FontWeight.w700),
      titleMedium: w(x.titleMedium, 17, FontWeight.w700),
      titleSmall: w(x.titleSmall, 15, FontWeight.w700),
      bodyLarge: w(x.bodyLarge, 15, FontWeight.w600),
      bodyMedium: w(x.bodyMedium, 15, FontWeight.w600),
      bodySmall: x.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.muted),
      labelLarge: w(x.labelLarge, 15, FontWeight.w700),
      labelMedium: w(x.labelMedium, 13, FontWeight.w700),
      labelSmall: w(x.labelSmall, 11, FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: t.ink,
      titleTextStyle: TextStyle(fontFamily: 'Quicksand', fontSize: 20, fontWeight: FontWeight.w700, color: t.ink),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PawRadius.tile),
        side: BorderSide(color: t.outline),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: t.outline,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(PawRadius.hero))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: t.surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(backgroundColor: t.ink, contentTextStyle: TextStyle(color: t.bg)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onAccent : t.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accent : t.tint),
      trackOutlineColor:
          WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accent : t.outline),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: t.accent, inactiveTrackColor: t.tint, thumbColor: t.accent),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.accent, linearTrackColor: t.tint),
    dividerTheme: DividerThemeData(color: t.outline),
  );
}

extension PawTokensContext on BuildContext {
  /// The redesign tokens of the current theme.
  PawTokens get paw => PawTokens.of(this);
}
