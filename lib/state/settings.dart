import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/gem_style.dart' show GemShape, gemShape;

/// The table the canvas sits on, and the sheet itself.
enum CanvasTheme {
  linen('Linen', Color(0xFFF1E7E1), Color(0xFFFBF8F3), Color(0x14000000)),
  wood('Wooden desk', Color(0xFF9C7457), Color(0xFFFBF5EC), Color(0x22000000)),
  night('Night sky', Color(0xFF221D3B), Color(0xFFF4F0FA), Color(0x33FFFFFF));

  const CanvasTheme(this.label, this.desk, this.sheet, this.pattern);

  final String label;
  final Color desk;
  final Color sheet;

  /// Colour of the desk's texture (linen weave, wood grain or stars).
  final Color pattern;
}

/// The canvas theme everything is drawn with; set from the player's settings.
CanvasTheme canvasTheme = CanvasTheme.linen;

/// Look of the canvas right now, for painters' caches and repaints.
Object currentLook() => (canvasTheme, gemShape);

/// Player preferences that change how the game looks and feels.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs,
      {required this.relaxed, required this.haptics, required this.theme, required GemShape shape})
      : _shape = shape {
    gemShape = shape;
    canvasTheme = theme;
  }

  static const _relaxedKey = 'relaxed_mode';
  static const _hapticsKey = 'haptics_on';
  static const _themeKey = 'canvas_theme';
  static const _shapeKey = 'drill_shape';

  static Future<AppSettings> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null;
    }
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return AppSettings._(
      prefs,
      relaxed: prefs?.getBool(_relaxedKey) ?? false,
      haptics: prefs?.getBool(_hapticsKey) ?? true,
      theme: pick(CanvasTheme.values, prefs?.getString(_themeKey), CanvasTheme.linen),
      shape: pick(GemShape.values, prefs?.getString(_shapeKey), GemShape.square),
    );
  }

  /// In-memory settings for tests.
  factory AppSettings.memory() =>
      AppSettings._(null, relaxed: false, haptics: true, theme: CanvasTheme.linen, shape: GemShape.square);

  final SharedPreferences? _prefs;

  /// No timer, score or counted mistakes: just painting.
  bool relaxed;
  bool haptics;
  CanvasTheme theme;
  GemShape _shape;
  GemShape get shape => _shape;

  Future<void> setRelaxed(bool v) => _set(() => relaxed = v, (p) => p.setBool(_relaxedKey, v));
  Future<void> setHaptics(bool v) => _set(() => haptics = v, (p) => p.setBool(_hapticsKey, v));
  Future<void> setTheme(CanvasTheme v) => _set(() {
        theme = v;
        canvasTheme = v;
      }, (p) => p.setString(_themeKey, v.name));
  Future<void> setShape(GemShape v) => _set(() {
        _shape = v;
        gemShape = v;
      }, (p) => p.setString(_shapeKey, v.name));

  Future<void> _set(VoidCallback change, Future<bool> Function(SharedPreferences) save) async {
    change();
    notifyListeners();
    final prefs = _prefs;
    if (prefs != null) await save(prefs);
  }

  /// Vibration feedback, when it is turned on.
  void selection() {
    if (haptics) HapticFeedback.selectionClick();
  }

  void light() {
    if (haptics) HapticFeedback.lightImpact();
  }

  void medium() {
    if (haptics) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (haptics) HapticFeedback.heavyImpact();
  }
}

/// Makes [AppSettings] available to the widget tree.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child}) : super(notifier: settings);

  static AppSettings of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  static AppSettings read(BuildContext context) => context.getInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
