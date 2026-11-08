import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import 'package:health_app/models/muscles.dart';
import 'package:health_app/theme/app_theme.dart';

enum BodyFigure { male, female }

enum BodySide { front, back }

class BodyPart {
  BodyPart(this.slug, this.path);

  final String slug;
  final Path path;
}

class BodyView {
  BodyView(this.box, this.parts);

  /// The outline's coordinate box.
  final Rect box;
  final List<BodyPart> parts;

  /// The muscle under [point] (in outline coordinates), if any.
  Muscle? muscleAt(Offset point) {
    for (final p in parts.reversed) {
      final m = Muscle.fromSlug(p.slug);
      if (m != null && p.path.contains(point)) return m;
    }
    return null;
  }
}

/// Body outlines from MuscleMap (MIT, see assets/data/MUSCLEMAP-LICENSE.txt).
class BodyMapData {
  BodyMapData._(this._views);

  final Map<String, BodyView> _views;

  static Future<BodyMapData>? _loading;

  /// The outlines once loaded, so later maps draw without a spinner.
  static BodyMapData? cached;

  /// Loads (once) and parses the bundled outlines.
  static Future<BodyMapData> load([AssetBundle? bundle]) =>
      _loading ??= (bundle ?? rootBundle)
          .loadString('assets/data/body_paths.json')
          .then((json) => cached = parse(json));

  static BodyMapData parse(String json) {
    final decoded = jsonDecode(json) as Map<String, Object?>;
    final views = <String, BodyView>{};
    for (final MapEntry(:key, :value) in decoded.entries) {
      if (value is! Map) continue;
      final box = (value['box'] as List).cast<num>();
      final parts = <BodyPart>[];
      for (final p in (value['parts'] as List).whereType<Map>()) {
        final path = Path();
        for (final side in const ['common', 'left', 'right']) {
          for (final d in (p[side] as List? ?? const []).whereType<String>()) {
            path.addPath(parseSvgPathData(d), Offset.zero);
          }
        }
        parts.add(BodyPart(p['slug'] as String, path));
      }
      views[key] = BodyView(
        Rect.fromLTWH(
          box[0].toDouble(),
          box[1].toDouble(),
          box[2].toDouble(),
          box[3].toDouble(),
        ),
        parts,
      );
    }
    return BodyMapData._(views);
  }

  BodyView view(BodyFigure figure, BodySide side) =>
      _views['${figure.name}_${side.name}']!;
}

/// Front or back body outline with muscles tinted by [intensity] (0..1).
/// Tap a muscle to get [onMuscleTap].
class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.side,
    this.figure = BodyFigure.male,
    this.intensity = const {},
    this.color,
    this.selected,
    this.onMuscleTap,
  });

  final BodySide side;
  final BodyFigure figure;
  final Map<Muscle, double> intensity;

  /// Defaults to the app accent.
  final Color? color;
  final Muscle? selected;
  final ValueChanged<Muscle>? onMuscleTap;

  @override
  Widget build(BuildContext context) {
    if (BodyMapData.cached case final data?) return _build(context, data);
    return FutureBuilder<BodyMapData>(
      future: BodyMapData.load(),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        return _build(context, data);
      },
    );
  }

  Widget _build(BuildContext context, BodyMapData data) {
    final view = data.view(figure, side);
    final painter = _BodyPainter(
      view: view,
      intensity: intensity,
      color: switch (color) {
        final c? => context.resolve(c),
        null => context.tint,
      },
      base: context.resolve(CupertinoColors.systemGrey5),
      neutral: context.resolve(CupertinoColors.systemGrey4),
      outline: context.resolve(CupertinoColors.systemGrey3),
      selected: selected,
    );
    return AspectRatio(
      aspectRatio: view.box.width / view.box.height,
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          onTapUp: onMuscleTap == null
              ? null
              : (d) {
                  final m = view.muscleAt(
                    _toOutline(view, c.biggest, d.localPosition),
                  );
                  if (m != null) {
                    HapticFeedback.selectionClick();
                    onMuscleTap?.call(m);
                  }
                },
          child: Semantics(
            label: '${side == BodySide.front ? 'Front' : 'Back'} body map',
            child: CustomPaint(size: c.biggest, painter: painter),
          ),
        ),
      ),
    );
  }

  static Offset _toOutline(BodyView v, Size size, Offset p) {
    final scale = size.width / v.box.width;
    return Offset(p.dx / scale + v.box.left, p.dy / scale + v.box.top);
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.view,
    required this.intensity,
    required this.color,
    required this.base,
    required this.neutral,
    required this.outline,
    required this.selected,
  });

  final BodyView view;
  final Map<Muscle, double> intensity;
  final Color color;
  final Color base;
  final Color neutral;
  final Color outline;
  final Muscle? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / view.box.width;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-view.box.left, -view.box.top);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / scale
      ..color = outline;
    for (final p in view.parts) {
      final m = Muscle.fromSlug(p.slug);
      final level = m == null ? 0.0 : (intensity[m] ?? 0).clamp(0.0, 1.0);
      final fill = m == null
          ? neutral
          : level > 0
          ? Color.lerp(base, color, 0.25 + 0.75 * level)!
          : base;
      canvas.drawPath(p.path, Paint()..color = fill);
      if (m != null && m == selected) {
        canvas.drawPath(
          p.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 / scale
            ..color = color,
        );
      } else {
        canvas.drawPath(p.path, stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.view != view ||
      old.intensity != intensity ||
      old.color != color ||
      old.base != base ||
      old.selected != selected;
}
