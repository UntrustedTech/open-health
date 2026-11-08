import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/motion.dart';

/// Picks the route map style by example: what a run looks like as a
/// private trace and over a street map.
class RouteStylePicker extends StatelessWidget {
  const RouteStylePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MapStyle value;
  final ValueChanged<MapStyle> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
    child: Row(
      children: [
        for (final (i, (style, label)) in [
          (MapStyle.trace, 'Private Trace'),
          (MapStyle.street, 'Street Map'),
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _Option(
              style: style,
              label: label,
              selected: value == style,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(style);
              },
            ),
          ),
        ],
      ],
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.style,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final MapStyle style;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$label example',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
              padding: const EdgeInsets.all(3),
              decoration: ShapeDecoration(
                shape: AppTheme.squircle(
                  18,
                  side: BorderSide(
                    color: selected ? tint : context.separatorColor,
                    width: selected ? 2.5 : 1,
                  ),
                ),
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: AppTheme.squircle(15)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: RoutePreviewPainter(
                      street: style == MapStyle.street,
                      dark: context.isDark,
                      route: tint,
                      background: context.cardBackground,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: context.subheadline),
            const SizedBox(height: 6),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? tint : context.tertiaryLabel,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// An example run: as the offline trace, or on an illustrated street map.
class RoutePreviewPainter extends CustomPainter {
  RoutePreviewPainter({
    required this.street,
    required this.dark,
    required this.route,
    required this.background,
  });

  final bool street;
  final bool dark;
  final Color route;
  final Color background;

  /// A loop around a park, in 0..1 coordinates.
  static const _run = [
    Offset(0.22, 0.80),
    Offset(0.22, 0.52),
    Offset(0.30, 0.40),
    Offset(0.30, 0.22),
    Offset(0.52, 0.20),
    Offset(0.70, 0.22),
    Offset(0.78, 0.34),
    Offset(0.78, 0.56),
    Offset(0.66, 0.66),
    Offset(0.52, 0.66),
    Offset(0.46, 0.80),
    Offset(0.30, 0.82),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Offset o) => Offset(o.dx * size.width, o.dy * size.height);
    final rect = Offset.zero & size;
    if (street) {
      _paintStreets(canvas, size, at);
    } else {
      canvas.drawRect(rect, Paint()..color = background);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              route.withValues(alpha: 0.12),
              route.withValues(alpha: 0.02),
            ],
          ).createShader(rect),
      );
    }

    final path = Path()..moveTo(at(_run.first).dx, at(_run.first).dy);
    for (final p in _run.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    final w = size.shortestSide / 40;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = route.withValues(alpha: street ? 0.30 : 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(colors: [route.withValues(alpha: 0.6), route])
            .createShader(rect),
    );
    void dot(Offset o, Color c) {
      canvas.drawCircle(o, w * 1.8, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(o, w * 1.3, Paint()..color = c);
    }

    dot(at(_run.first), Palette.green);
    dot(at(_run.last), Palette.red);
  }

  void _paintStreets(Canvas canvas, Size size, Offset Function(Offset) at) {
    final land = dark ? const Color(0xFF2B2D31) : const Color(0xFFF2EFE9);
    final block = dark ? const Color(0xFF34373C) : const Color(0xFFE6E1D8);
    final park = dark ? const Color(0xFF233A2A) : const Color(0xFFCDE8C4);
    final water = dark ? const Color(0xFF1E3550) : const Color(0xFFAAD3F0);
    final road = dark ? const Color(0xFF4A4D53) : const Color(0xFFFFFFFF);
    final major = dark ? const Color(0xFF6B5A35) : const Color(0xFFFCE3A3);
    canvas.drawRect(Offset.zero & size, Paint()..color = land);

    // City blocks on a grid.
    const cols = [0.0, 0.18, 0.34, 0.56, 0.74, 0.90];
    const rows = [0.0, 0.16, 0.36, 0.60, 0.72, 0.88];
    for (var i = 0; i < cols.length - 1; i++) {
      for (var j = 0; j < rows.length - 1; j++) {
        final r = Rect.fromPoints(
          at(Offset(cols[i] + 0.025, rows[j] + 0.025)),
          at(Offset(cols[i + 1] - 0.025, rows[j + 1] - 0.025)),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(2)),
          Paint()..color = block,
        );
      }
    }
    // A park in the middle and a river along the bottom edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          at(const Offset(0.36, 0.30)),
          at(const Offset(0.72, 0.58)),
        ),
        Radius.circular(size.width * 0.04),
      ),
      Paint()..color = park,
    );
    final river = Path()
      ..moveTo(0, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.84,
        size.width,
        size.height * 0.95,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(river, Paint()..color = water);

    final streets = Paint()
      ..color = road
      ..strokeWidth = size.shortestSide / 45;
    for (final x in cols.skip(1)) {
      canvas.drawLine(at(Offset(x, 0)), at(Offset(x, 0.9)), streets);
    }
    for (final y in rows.skip(1)) {
      canvas.drawLine(at(Offset(0, y)), at(Offset(1, y)), streets);
    }
    // One main road.
    canvas.drawLine(
      at(const Offset(0, 0.16)),
      at(const Offset(1, 0.16)),
      Paint()
        ..color = major
        ..strokeWidth = size.shortestSide / 28,
    );
  }

  @override
  bool shouldRepaint(RoutePreviewPainter old) =>
      old.street != street ||
      old.dark != dark ||
      old.route != route ||
      old.background != background;
}
