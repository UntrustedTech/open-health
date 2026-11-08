import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/platform/app_icons.dart';
import 'package:health_app/theme/app_icon.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_mark.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Appearance → App Icon: the Home Screen icon. Shown only when there are
/// icons to choose from.
class AppIconSection extends StatelessWidget {
  const AppIconSection({super.key});

  @override
  Widget build(BuildContext context) {
    final icons = context.watch<AppIcons>();
    final choices = icons.choices;
    if (choices.isEmpty) return const SizedBox.shrink();
    final chosen = icons.chosen;
    // One made in Create Your Own shows on its tile.
    final own = chosen.isMix && !choices.contains(chosen) ? chosen : null;
    final android = defaultTargetPlatform == TargetPlatform.android;
    return GroupedSection(
      header: 'App Icon',
      footer: android
          ? 'The new icon shows once you leave the app. Some launchers need '
                'it added to the Home Screen again.'
          : 'Your phone asks you to confirm the change. For a see-through '
                'look, touch and hold the Home Screen, tap Edit, then '
                'Customize, and choose Clear.',
      hasLeading: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
          child: LayoutBuilder(
            builder: (context, c) {
              // Four to a row on phones, more when there's room.
              final perRow = (c.maxWidth / 86).floor().clamp(4, 8);
              final width = c.maxWidth / perRow;
              return Wrap(
                runSpacing: 10,
                children: [
                  for (final icon in choices)
                    SizedBox(
                      width: width,
                      child: _IconTile(
                        label: icon.label,
                        preview: AppIconPreview(icon: icon, size: 58),
                        selected: chosen == icon,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          icons.choose(icon);
                        },
                      ),
                    ),
                  if (icons.canCreate)
                    SizedBox(
                      width: width,
                      child: _IconTile(
                        label: 'Create Your Own',
                        preview: own == null
                            ? const CreateIconTile(size: 58)
                            : AppIconPreview(icon: own, size: 58),
                        selected: own != null,
                        onTap: () => IconBuilderScreen.open(context),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.label,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget preview;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: tr(label),
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          _Ring(selected: selected, radius: 19, child: preview),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.type(
              12,
              selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? context.tint
                  : context.resolve(Palette.secondaryLabel),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A ring in the tint colour round what's selected.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.selected,
    required this.radius,
    required this.child,
    this.shape = BoxShape.rectangle,
  });

  final bool selected;
  final double radius;
  final BoxShape shape;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Motion.reduced(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: shape,
      borderRadius: shape == BoxShape.circle
          ? null
          : BorderRadius.circular(radius),
      border: Border.all(
        color: selected ? context.tint : const Color(0x00000000),
        width: 2.5,
      ),
    ),
    child: child,
  );
}

/// The Create Your Own tile before an icon is made: a brush on a plain tile.
class CreateIconTile extends StatelessWidget {
  const CreateIconTile({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: ShapeDecoration(
      color: context.resolve(Palette.fill),
      shape: AppTheme.squircle(
        size * 0.225,
        side: BorderSide(color: context.resolve(Palette.separator)),
      ),
    ),
    child: Icon(Icons.brush_rounded, size: size * 0.45, color: context.tint),
  );
}

/// [icon] as it looks on the Home Screen, drawn from the same data the
/// real icons were made from (tool/make_app_icons.py), so it always
/// matches. A see-through icon shows on a checkerboard.
class AppIconPreview extends StatelessWidget {
  const AppIconPreview({super.key, required this.icon, required this.size});

  final AppIcon icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tile = icon.tile;
    // White and see-through tiles need an edge on a light page.
    final edge = tile.isEmpty || tile.first.computeLuminance() > 0.8;
    return Container(
      width: size,
      height: size,
      foregroundDecoration: edge
          ? ShapeDecoration(
              shape: AppTheme.squircle(
                size * 0.225,
                side: BorderSide(color: context.resolve(Palette.separator)),
              ),
            )
          : null,
      decoration: ShapeDecoration(
        // iOS icons' corners: about 22.5% of their size.
        shape: AppTheme.squircle(size * 0.225),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: _IconPainter(icon)),
    );
  }
}

/// Paints an icon in a square, as tool/make_app_icons.py draws it in 1024.
class _IconPainter extends CustomPainter {
  const _IconPainter(this.icon);

  final AppIcon icon;

  static const _box = 1024.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _box);
    const all = Rect.fromLTWH(0, 0, _box, _box);
    final tile = icon.tile;
    if (tile.isEmpty) {
      _checkerboard(canvas);
    } else {
      final paint = Paint();
      if (tile.length == 1) {
        paint.color = tile.single;
      } else {
        paint.shader = _gradient(tile, Offset.zero, const Offset(_box, _box));
      }
      canvas.drawRect(all, paint);
    }
    if (icon.pattern case final p?) _pattern(canvas, p);

    final mark = AppMarkPath.build();
    final width = icon.sketch ? AppMarkPath.width * 0.82 : AppMarkPath.width;
    void pass(List<Color> colors, double w, Offset at, [double alpha = 1]) {
      canvas
        ..save()
        ..translate(_box / 2 + at.dx, _box / 2 + at.dy);
      final paint = AppMarkPath.stroke(w);
      if (colors.length == 1) {
        paint.color = colors.single.withValues(alpha: alpha);
      } else {
        // Down across the line, as in the icon (1024 space, moved to the
        // centre).
        paint.shader = _gradient(
          [for (final c in colors) c.withValues(alpha: alpha)],
          const Offset(380 - _box / 2, 230 - _box / 2),
          const Offset(300 - _box / 2, 800 - _box / 2),
        );
      }
      canvas
        ..drawPath(mark, paint)
        ..restore();
    }

    if (icon.shadow case final shadow?) {
      final off = icon.shadowOffset;
      pass([shadow], width + icon.outlineWidth, Offset(off, off));
    }
    if (icon.outline case final outline?) {
      pass([outline], width + icon.outlineWidth, Offset.zero);
    }
    pass(icon.line, width, Offset.zero);
    if (icon.sketch) {
      pass(icon.line, AppMarkPath.width * 0.4, const Offset(12, -9), 0.55);
    }
  }

  /// [colors] spread evenly from [from] to [to].
  static Shader _gradient(List<Color> colors, Offset from, Offset to) =>
      ui.Gradient.linear(from, to, colors, [
        for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
      ]);

  static void _checkerboard(Canvas canvas) {
    const cell = _box / 8;
    canvas.drawColor(const Color(0xFFC7C7CC), BlendMode.src);
    final dark = Paint()..color = const Color(0xFF8E8E93);
    for (var y = 0; y < 8; y++) {
      for (var x = y.isEven ? 0 : 1; x < 8; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
      }
    }
  }

  static void _pattern(Canvas canvas, IconPattern p) {
    final s = p.spacing;
    final n = (_box / s).ceil();
    final fill = Paint()..color = p.color;
    switch (p.kind) {
      case IconPatternKind.dots:
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            canvas.drawCircle(
              Offset(s / 2 + i * s, s / 2 + j * s),
              s * 0.14,
              fill,
            );
          }
        }
      case IconPatternKind.grid:
        for (var k = 1; k < n; k++) {
          canvas
            ..drawRect(Rect.fromLTWH(k * s - 2, 0, 4, _box), fill)
            ..drawRect(Rect.fromLTWH(0, k * s - 2, _box, 4), fill);
        }
      case IconPatternKind.lines:
        for (var k = 1; k < n; k++) {
          canvas.drawRect(Rect.fromLTWH(0, k * s - 2, _box, 4), fill);
        }
      case IconPatternKind.scanlines:
        for (var k = 0; k < n; k++) {
          canvas.drawRect(Rect.fromLTWH(0, k * s, _box, s / 2), fill);
        }
      case IconPatternKind.waves:
        final amp = s * 0.12;
        final path = Path();
        for (var k = 0; k < n; k++) {
          path.moveTo(0, s / 2 + k * s);
          for (var w = 0; w <= n; w++) {
            path
              ..relativeQuadraticBezierTo(s / 4, -amp, s / 2, 0)
              ..relativeQuadraticBezierTo(s / 4, amp, s / 2, 0);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = p.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.icon != icon;
}

/// App Icon → Create Your Own: a background and a line colour, from those
/// built into the app.
class IconBuilderScreen extends StatefulWidget {
  const IconBuilderScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Create Your Own',
      builder: (_) => const IconBuilderScreen(),
    ),
  );

  @override
  State<IconBuilderScreen> createState() => _IconBuilderScreenState();
}

class _IconBuilderScreenState extends State<IconBuilderScreen> {
  late IconPaint _background;
  late IconPaint _line;

  @override
  void initState() {
    super.initState();
    // Start from the icon in use, if it's a mix.
    final chosen = context.read<AppIcons>().chosen;
    _background = chosen.background ?? AppIcon.backgrounds.first;
    _line = chosen.lineColor ?? AppIcon.lines.first;
  }

  void _pickBackground(IconPaint bg) {
    HapticFeedback.selectionClick();
    setState(() {
      _background = bg;
      // Keep the line if it shows here, or take the first that does.
      if (AppIcon.mix(bg, _line) == null) {
        _line = AppIcon.lines.firstWhere(
          (l) => AppIcon.mix(bg, l) != null,
          orElse: () => _line,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final icons = context.watch<AppIcons>();
    final icon = AppIcon.mix(_background, _line) ?? AppIcon.original;
    final inUse = icons.chosen == icon;
    return LargeTitlePage(
      title: 'Create Your Own',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Semantics(
              image: true,
              label: tr('Preview: {0}').replaceFirst('{0}', tr(icon.label)),
              excludeSemantics: true,
              child: AppIconPreview(icon: icon, size: 120),
            ),
          ),
        ),
        GroupedSection(
          header: 'Background Colour',
          hasLeading: false,
          children: [
            _Swatches(
              paints: icons.backgrounds,
              selected: _background,
              enabled: (_) => true,
              onTap: _pickBackground,
            ),
          ],
        ),
        GroupedSection(
          header: 'Line Colour',
          footer:
              'Colours that wouldn\'t show on this background are greyed '
              'out.',
          hasLeading: false,
          children: [
            _Swatches(
              paints: AppIcon.lines,
              selected: _line,
              enabled: (l) => AppIcon.mix(_background, l) != null,
              onTap: (l) {
                HapticFeedback.selectionClick();
                setState(() => _line = l);
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: CupertinoButton.filled(
            onPressed: inUse
                ? null
                : () {
                    unawaited(icons.choose(icon));
                    Navigator.of(context).pop();
                  },
            child: Text(inUse ? 'In Use' : 'Use This Icon'),
          ),
        ),
      ],
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.paints,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final List<IconPaint> paints;
  final IconPaint selected;
  final bool Function(IconPaint) enabled;
  final ValueChanged<IconPaint> onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in paints)
          _Swatch(
            paint: p,
            selected: p.id == selected.id,
            enabled: enabled(p),
            onTap: () => onTap(p),
          ),
      ],
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.paint,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconPaint paint;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = paint.colors;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: tr(paint.label),
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.25,
          child: _Ring(
            selected: selected,
            radius: 0,
            shape: BoxShape.circle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.resolve(Palette.separator)),
                color: colors.length == 1 ? colors.single : null,
                gradient: colors.length > 1
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      )
                    : null,
              ),
              child: colors.isEmpty
                  ? ClipOval(
                      child: CustomPaint(
                        painter: _IconPainter(
                          AppIcon.mix(paint, AppIcon.lines.first) ??
                              AppIcon.original,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
