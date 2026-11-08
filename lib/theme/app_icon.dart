import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

part 'app_icon_data.dart';

/// A background or line colour in Create Your Own: one colour, a
/// gradient, or (backgrounds only) none, for see-through.
@immutable
class IconPaint {
  const IconPaint(this.id, this.label, this.colors);

  final String id;
  final String label;
  final List<Color> colors;

  /// See-through: Android only, as the iPhone fills an icon's clear parts
  /// with black.
  bool get isClear => colors.isEmpty;
}

enum IconPatternKind { dots, grid, lines, scanlines, waves }

/// A texture over a theme icon's background, as in its theme.
@immutable
class IconPattern {
  const IconPattern(this.kind, this.color, this.spacing);

  final IconPatternKind kind;
  final Color color;

  /// In a 1024-wide icon.
  final double spacing;
}

/// An icon the app can show on the Home Screen. Every one is built into
/// the app (drawn from the same data as app_icon_data.dart): the original,
/// one per style, and each background and line colour that go together.
@immutable
class AppIcon {
  const AppIcon._({
    required this.name,
    required this.label,
    required this.nativeName,
    required this.tile,
    required this.line,
    this.pattern,
    this.outline,
    this.outlineWidth = 0,
    this.shadow,
    this.shadowOffset = 0,
    this.sketch = false,
    this.background,
    this.lineColor,
  });

  /// The app's own icon.
  static final original = AppIcon._(
    name: 'original',
    label: 'Original',
    nativeName: 'Default',
    tile: _backgrounds.first.colors,
    line: _lines.first.colors,
    background: _backgrounds.first,
    lineColor: _lines.first,
  );

  /// Its name: a preset, a theme, or `custom` (for mixes).
  final String name;
  final String label;

  /// Its name on the phone: the Android launcher entry `.Icon<name>`, and
  /// the iOS icon set `AppIcon-<name>` (`Default` is the app's own).
  final String nativeName;

  /// The background's colours, a gradient from top left when more than
  /// one; empty for see-through.
  final List<Color> tile;

  /// The line's colours, a gradient from top when more than one.
  final List<Color> line;
  final IconPattern? pattern;

  /// Drawn under the line, [outlineWidth] wider (in a 1024-wide icon).
  final Color? outline;
  final double outlineWidth;

  /// A solid shadow, [shadowOffset] down and right.
  final Color? shadow;
  final double shadowOffset;

  /// A thinner line with a second, fainter pencil pass beside it.
  final bool sketch;

  /// For a mix: what it's made of.
  final IconPaint? background;
  final IconPaint? lineColor;

  /// The offer name for every mix (Create Your Own).
  static const custom = 'custom';

  /// Backgrounds and line colours for Create Your Own, the original's
  /// first.
  static List<IconPaint> get backgrounds => _backgrounds;
  static List<IconPaint> get lines => _lines;

  /// Mixes offered by name, such as White on Black.
  static final List<AppIcon> presets = [
    for (final (name, label, bg, ln) in _presets)
      _mix(_paint(_backgrounds, bg), _paint(_lines, ln), name, label)!,
  ];

  /// One per style.
  static List<AppIcon> get themes => _themes;

  /// Every name an icon can have.
  static Set<String> get offerable => {
    for (final i in presets) i.name,
    for (final i in themes) i.name,
    custom,
  };

  /// The icon with [line] on [background], or null if they don't go
  /// together (the line wouldn't show).
  static AppIcon? mix(IconPaint background, IconPaint line) =>
      _mix(background, line, custom, '${background.label}, ${line.label}');

  static AppIcon? _mix(IconPaint bg, IconPaint ln, String name, String label) {
    if (bg.id == _backgrounds.first.id && ln.id == _lines.first.id) {
      return original;
    }
    if (!(_mixes[bg.id]?.contains(ln.id) ?? false)) return null;
    String pascal(String id) => id[0].toUpperCase() + id.substring(1);
    return AppIcon._(
      name: name,
      label: label,
      nativeName: 'Mix${pascal(bg.id)}${pascal(ln.id)}',
      tile: bg.colors,
      line: ln.colors,
      background: bg,
      lineColor: ln,
    );
  }

  static IconPaint _paint(List<IconPaint> paints, String id) =>
      paints.firstWhere((p) => p.id == id);

  /// The preset or theme icon called [name]; null for
  /// [custom] or an unknown name.
  static AppIcon? byName(String name) =>
      [...presets, ...themes].where((i) => i.name == name).firstOrNull;

  /// The icon saved as [nativeName], with its preset's name and label if
  /// it's one.
  static AppIcon? byNativeName(String nativeName) {
    if (nativeName == original.nativeName) return original;
    for (final i in [...presets, ...themes]) {
      if (i.nativeName == nativeName) return i;
    }
    for (final bg in _backgrounds) {
      for (final ln in _lines) {
        final m = mix(bg, ln);
        if (m?.nativeName == nativeName) return m;
      }
    }
    return null;
  }

  /// A mix from Create Your Own (including presets), not a theme's icon.
  bool get isMix => background != null;

  /// Whether [platform] can show it.
  bool availableOn(TargetPlatform platform) =>
      tile.isNotEmpty || platform == TargetPlatform.android;

  @override
  bool operator ==(Object other) =>
      other is AppIcon && other.nativeName == nativeName;

  @override
  int get hashCode => nativeName.hashCode;

  @override
  String toString() => nativeName;
}
