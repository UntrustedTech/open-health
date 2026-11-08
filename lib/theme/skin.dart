import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:health_app/theme/app_theme.dart';

/// How cards cast shadows: the app's soft lift, none, or a hard, offset
/// cartoon shadow.
enum SkinShadow { none, soft, hard }

/// A pattern drawn over the page background.
enum PatternKind { dots, grid, lines, scanlines, waves }

/// How outlines are drawn: clean lines, by hand in pencil, or as playful
/// squiggles. See [DrawnBorder].
enum LineStyle { solid, sketch, squiggle }

/// A skin's page pattern: [kind] every [spacing] points, in a colour per
/// brightness.
@immutable
class SkinPattern {
  const SkinPattern({
    required this.kind,
    required this.spacing,
    required this.light,
    required this.dark,
  });

  final PatternKind kind;
  final double spacing;
  final Color light;
  final Color dark;
}

/// A theme's colours for one brightness. Only the surfaces, text and
/// accent change; data colours (rings, charts) stay the app's so they keep
/// their meaning.
@immutable
class SkinColors {
  const SkinColors({
    required this.background,
    required this.card,
    required this.label,
    required this.accent,
    this._cardRaised,
    this._secondaryLabel,
    this._tertiaryLabel,
    this._separator,
    this._fill,
    this._outline,
  });

  final Color background;
  final Color card;
  final Color label;
  final Color accent;
  final Color? _cardRaised;
  final Color? _secondaryLabel;
  final Color? _tertiaryLabel;
  final Color? _separator;
  final Color? _fill;
  final Color? _outline;

  // Unset colours are mixed from the ones given.
  Color get cardRaised => _cardRaised ?? Color.lerp(card, background, 0.6)!;
  Color get secondaryLabel => _secondaryLabel ?? Color.lerp(label, card, 0.32)!;
  Color get tertiaryLabel => _tertiaryLabel ?? Color.lerp(label, card, 0.42)!;
  Color get separator => _separator ?? label.withValues(alpha: 0.12);
  Color get fill => _fill ?? label.withValues(alpha: 0.06);
  Color get outline => _outline ?? label;

  /// Whether the style chose its own outline colour.
  bool get hasOwnOutline => _outline != null;

  SkinColors _copy({Color? accent, Color? outline}) => SkinColors(
    background: background,
    card: card,
    label: label,
    accent: accent ?? this.accent,
    cardRaised: _cardRaised,
    secondaryLabel: _secondaryLabel,
    tertiaryLabel: _tertiaryLabel,
    separator: _separator,
    fill: _fill,
    outline: outline ?? _outline,
  );

  /// These colours with [accent] for buttons and highlights.
  SkinColors withAccent(Color accent) => _copy(accent: accent);

  /// Page and card colours made from one chosen page colour, with text
  /// dark or light, whichever reads best on it.
  factory SkinColors.fromPage(Color page, {required Color accent}) {
    final light = page.computeLuminance() > 0.4;
    return SkinColors(
      background: page,
      // Cards stand out a little from the page: lighter on light pages,
      // a touch lighter on dark ones.
      card: Color.lerp(page, const Color(0xFFFFFFFF), light ? 0.6 : 0.08)!,
      label: light ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F3),
      accent: accent,
    );
  }

  /// These colours with [outline] for card and button outlines.
  SkinColors withOutline(Color outline) => _copy(outline: outline);

  Map<String, Object?> toJson() {
    String hex(Color c) =>
        '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    return {
      'background': hex(background),
      'card': hex(card),
      'label': hex(label),
      'accent': hex(accent),
      if (_cardRaised case final c?) 'cardRaised': hex(c),
      if (_secondaryLabel case final c?) 'secondaryLabel': hex(c),
      if (_tertiaryLabel case final c?) 'tertiaryLabel': hex(c),
      if (_separator case final c?) 'separator': hex(c),
      if (_fill case final c?) 'fill': hex(c),
      if (_outline case final c?) 'outline': hex(c),
    };
  }
}

/// An alternative look for the whole app: colours,
/// card shape and font. Without one, the app uses its own "Soft" design.
@immutable
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    this.radius,
    this.outline = 0,
    this.shadow = SkinShadow.soft,
    this.shadowOffset = 4,
    this.fontFamily,
    this.brightness,
    this.pattern,
    this.dockedTabBar = false,
    this.upperTitles = false,
    this.lineStyle = LineStyle.solid,
    this.revision = 0,
  });

  final String id;
  final String name;
  final SkinColors light;
  final SkinColors dark;
  final double? radius;
  final double outline;
  final SkinShadow shadow;
  final double shadowOffset;

  /// A font registered for this skin, or null for the app's.
  final String? fontFamily;

  /// Light or dark whatever the phone's setting, or null to follow it.
  final Brightness? brightness;

  /// Drawn over the page background.
  final SkinPattern? pattern;

  /// A full-width tab bar along the bottom instead of the floating one.
  final bool dockedTabBar;

  /// Page titles in capitals.
  final bool upperTitles;

  /// How outlines are drawn.
  final LineStyle lineStyle;

  /// Changes when the user edits a customizable theme, so the app redraws.
  final int revision;

  SkinColors colors(bool dark) => dark ? this.dark : light;

  CupertinoDynamicColor _dynamic(Color Function(SkinColors) pick) =>
      CupertinoDynamicColor.withBrightness(
        color: pick(light),
        darkColor: pick(dark),
      );

  CupertinoDynamicColor get background => _dynamic((c) => c.background);
  CupertinoDynamicColor get label => _dynamic((c) => c.label);
  CupertinoDynamicColor get tertiaryLabel => _dynamic((c) => c.tertiaryLabel);
  CupertinoDynamicColor get accent => _dynamic((c) => c.accent);

  /// This skin's colour for one of the app's surface or text colours, or
  /// null for any other colour.
  Color? replace(Color color, bool dark) {
    final c = colors(dark);
    if (identical(color, Palette.background)) return c.background;
    if (identical(color, Palette.card)) return c.card;
    if (identical(color, Palette.cardRaised)) return c.cardRaised;
    if (identical(color, Palette.label)) return c.label;
    if (identical(color, Palette.secondaryLabel)) return c.secondaryLabel;
    if (identical(color, Palette.tertiaryLabel)) return c.tertiaryLabel;
    if (identical(color, Palette.separator)) return c.separator;
    if (identical(color, Palette.fill)) return c.fill;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Skin && other.id == id && other.revision == revision;

  @override
  int get hashCode => Object.hash(id, revision);
}

/// Puts a [Skin] over the app.
class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});

  final Skin? skin;

  static Skin? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin;

  @override
  bool updateShouldNotify(SkinScope old) => old.skin != skin;
}

/// Card shape under the current skin.
extension SkinShape on BuildContext {
  Skin? get skin => SkinScope.of(this);

  /// [radius] as the skin draws cards. Only the standard card radii
  /// (lists, cards and hero cards) change, so pills and chips stay round.
  double cardRadius(double radius) {
    final r = skin?.radius;
    final isCard =
        radius == AppTheme.listRadius ||
        radius == AppTheme.radius ||
        radius == AppTheme.heroRadius;
    return r != null && isCard ? r : radius;
  }

  /// [cardRadius] for clipping and box decorations.
  BorderRadius cardBorderRadius(double radius) =>
      BorderRadius.circular(cardRadius(radius));

  /// A radius inside a card of [card] radius that keeps an even gap of
  /// [inset] to the card's edge, so nested corners line up.
  double innerRadius(double card, double inset) =>
      (cardRadius(card) - inset).clamp(0, double.infinity).toDouble();

  /// The shape of a card of [radius] (the standard radius or larger),
  /// with the skin's corners and outline.
  ShapeBorder cardShape(double radius) =>
      outlinedShape(skin?.radius ?? radius, cardOutline);

  /// A rounded shape with [side] as its outline: sketched by hand when the
  /// skin asks for it.
  OutlinedBorder outlinedShape(double radius, BorderSide side) =>
      switch (skin?.lineStyle ?? LineStyle.solid) {
        LineStyle.solid => AppTheme.squircle(radius, side: side),
        final style => DrawnBorder(
          style: style,
          borderRadius: BorderRadius.circular(radius),
          side: side,
        ),
      };

  /// A skin's shadow for cards drawn without one by default (none without
  /// a skin).
  List<BoxShadow>? get skinShadows => skin == null ? null : cardShadows;

  /// A selectable tile's shape: a thin hairline (or the skin's outline),
  /// and a line in [color] while [selected].
  ShapeBorder choiceShape({required bool selected, required Color color}) =>
      outlinedShape(
        skin?.radius ?? 20,
        selected
            ? BorderSide(
                color: color,
                width: cardOutline.width < 1.6 ? 1.6 : cardOutline.width,
              )
            : cardOutline == BorderSide.none
            ? BorderSide(color: separatorColor, width: 0.8)
            : cardOutline,
      );

  /// The outline colour. An outline in the style's accent follows the
  /// Theme Colour the user picked instead, like the rest of the accents.
  Color get _outlineColour {
    final c = skin!.colors(isDark);
    return c.outline == c.accent
        ? CupertinoTheme.of(this).primaryColor
        : c.outline;
  }

  /// The line around cards, or none.
  BorderSide get cardOutline {
    final s = skin;
    if (s == null || s.outline <= 0) return BorderSide.none;
    return BorderSide(color: _outlineColour, width: s.outline);
  }

  /// The shadow under cards.
  List<BoxShadow>? get cardShadows {
    final s = skin;
    return switch (s?.shadow) {
      null || SkinShadow.soft => isDark ? null : AppTheme.cardShadow,
      SkinShadow.none => null,
      SkinShadow.hard => [
        BoxShadow(
          color: _outlineColour,
          offset: Offset(s!.shadowOffset, s.shadowOffset),
        ),
      ],
    };
  }
}

/// Draws a [SkinPattern] across its area.
class PatternPainter extends CustomPainter {
  const PatternPainter(this.pattern, this.color);

  final SkinPattern pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final step = pattern.spacing;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    switch (pattern.kind) {
      case PatternKind.dots:
        for (var y = step / 2; y < size.height; y += step) {
          for (var x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 1.4, paint);
          }
        }
      case PatternKind.grid:
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case PatternKind.lines:
        // Ruled paper: lines across, and a margin line down the left.
        for (var y = step * 2; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        canvas.drawLine(
          Offset(step * 1.2, 0),
          Offset(step * 1.2, size.height),
          Paint()
            ..color = color
            ..strokeWidth = 1.5,
        );
      case PatternKind.scanlines:
        final band = Paint()..color = color;
        for (var y = 0.0; y < size.height; y += step) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, step / 2), band);
        }
      case PatternKind.waves:
        // Rows of gentle waves, every other row shifted half a wave.
        final wave = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        final length = step * 1.25, height = step / 10;
        var row = 0;
        for (var y = step / 2; y < size.height + step; y += step, row++) {
          final path = Path();
          final start = row.isEven ? -length : -length / 2;
          path.moveTo(start, y);
          for (var x = start; x < size.width + length; x += length) {
            path
              ..quadraticBezierTo(x + length / 4, y - height, x + length / 2, y)
              ..quadraticBezierTo(
                x + length * 3 / 4,
                y + height,
                x + length,
                y,
              );
          }
          canvas.drawPath(path, wave);
        }
    }
  }

  @override
  bool shouldRepaint(PatternPainter old) =>
      old.pattern != pattern || old.color != color;
}

/// A rounded rectangle whose outline is drawn rather than ruled: by hand
/// in pencil ([LineStyle.sketch]: two slightly wobbly passes that overshoot
/// at a corner) or as a squiggle ([LineStyle.squiggle]: an even wave all
/// round). It fills and clips like a plain rounded rectangle; only the
/// line differs.
///
/// The line is worked out from the rectangle's size, so a card looks the
/// same every frame and doesn't shimmer as it scrolls.
class DrawnBorder extends RoundedRectangleBorder {
  const DrawnBorder({required this.style, super.side, super.borderRadius});

  final LineStyle style;

  @override
  DrawnBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) => DrawnBorder(
    style: style,
    side: side ?? this.side,
    borderRadius: borderRadius ?? this.borderRadius,
  );

  @override
  ShapeBorder scale(double t) => DrawnBorder(
    style: style,
    side: side.scale(t),
    borderRadius: borderRadius * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is RoundedRectangleBorder) {
      return DrawnBorder(
        style: style,
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          a.borderRadius,
          borderRadius,
          t,
        )!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is RoundedRectangleBorder) {
      return DrawnBorder(
        style: style,
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadiusGeometry.lerp(
          borderRadius,
          b.borderRadius,
          t,
        )!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (style) {
      case LineStyle.solid:
        super.paint(canvas, rect, textDirection: textDirection);
      case LineStyle.sketch:
        final r = borderRadius
            .resolve(textDirection)
            .toRRect(rect)
            .deflate(side.width / 2);
        // Two passes, the second lighter and a little off the first.
        final seed = (rect.width * 31 + rect.height * 17).round();
        canvas.drawPath(
          sketchPath(r, seed: seed),
          paint..strokeWidth = side.width * 0.75,
        );
        canvas.drawPath(
          sketchPath(r, seed: seed + 7, overshoot: 4),
          paint
            ..color = side.color.withValues(alpha: side.color.a * 0.55)
            ..strokeWidth = side.width * 0.5,
        );
      case LineStyle.squiggle:
        final r = _waveRect(rect, textDirection);
        canvas.drawPath(
          _cached(r, () => squigglePath(r)),
          paint..strokeWidth = side.width,
        );
    }
  }

  static const _amplitude = 1.3;

  /// Where the wave runs: inset by its height and half the line, so the
  /// whole line stays inside the card. The fill follows the same wave.
  RRect _waveRect(Rect rect, TextDirection? textDirection) => borderRadius
      .resolve(textDirection)
      .toRRect(rect)
      .deflate(side.width / 2 + _amplitude);

  /// A squiggly card fills, clips and casts its shadow along its wave, so
  /// no straight edge shows past it.
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    if (style != LineStyle.squiggle) {
      return super.getOuterPath(rect, textDirection: textDirection);
    }
    final r = _waveRect(rect, textDirection);
    return _cached(r, () => squigglePath(r));
  }

  // A plain rounded rectangle is filled with a shortcut that would ignore
  // the wave.
  @override
  bool get preferPaintInterior => style != LineStyle.squiggle;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    if (style == LineStyle.squiggle) {
      canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
    } else {
      super.paintInterior(canvas, rect, paint, textDirection: textDirection);
    }
  }

  // Outlines worked out before, by size and corners, placed at the origin:
  // lists repaint many cards of the same size.
  static final _paths = <(Size, Radius, LineStyle, int), Path>{};

  static Path _cached(RRect r, Path Function() build, [int seed = 0]) {
    final key = (r.outerRect.size, r.tlRadius, LineStyle.squiggle, seed);
    var path = _paths[key];
    if (path == null) {
      if (_paths.length >= 64) _paths.remove(_paths.keys.first);
      final origin = r.shift(-r.outerRect.topLeft);
      path = _paths[key] = r == origin
          ? build()
          : build().shift(-r.outerRect.topLeft);
    }
    return path.shift(r.outerRect.topLeft);
  }

  /// [r]'s outline as a hand-drawn line: points every few pixels nudged
  /// in and out, starting and ending a little past the top-left corner.
  @visibleForTesting
  static Path sketchPath(RRect r, {required int seed, double overshoot = 2}) {
    final outline = Path()..addRRect(r);
    final path = Path();
    var rand = seed & 0x7fffffff;
    double next() {
      // A small, fast, repeatable generator (an LCG): 0–1.
      rand = (rand * 1103515245 + 12345) & 0x7fffffff;
      return rand / 0x7fffffff;
    }

    const step = 6.0, wobble = 1.1;
    for (final metric in outline.computeMetrics()) {
      final length = metric.length;
      var first = true;
      var drift = 0.0;
      for (var d = 0.0; d <= length + overshoot * step; d += step) {
        final t = metric.getTangentForOffset(d % length);
        if (t == null) continue;
        // Drift slowly, as a hand does, rather than jitter.
        drift = (drift + (next() - 0.5) * wobble).clamp(-wobble, wobble);
        final normal = Offset(-t.vector.dy, t.vector.dx);
        final p = t.position + normal * drift;
        if (first) {
          path.moveTo(p.dx, p.dy);
          first = false;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
    }
    return path;
  }

  /// [r]'s outline as an even wave, with a whole number of waves so the
  /// line meets itself smoothly.
  @visibleForTesting
  static Path squigglePath(RRect r, {double wavelength = 24}) {
    final outline = Path()..addRRect(r);
    final path = Path();
    for (final metric in outline.computeMetrics()) {
      final length = metric.length;
      final waves = (length / wavelength).round().clamp(4, 1 << 20);
      final step = length / (waves * 8);
      for (var i = 0; i <= waves * 8; i++) {
        final d = i * step;
        final t = metric.getTangentForOffset(d == length ? 0 : d);
        if (t == null) continue;
        final normal = Offset(-t.vector.dy, t.vector.dx);
        final p =
            t.position + normal * (_amplitude * math.sin(i / 8 * 2 * math.pi));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    }
    return path;
  }

  @override
  bool operator ==(Object other) =>
      other is DrawnBorder &&
      other.style == style &&
      other.side == side &&
      other.borderRadius == borderRadius;

  @override
  int get hashCode => Object.hash(DrawnBorder, style, side, borderRadius);
}
