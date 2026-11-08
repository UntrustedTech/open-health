import 'dart:math';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/workout/geo.dart';

/// Shows a GPS route either over an OpenStreetMap street map or as a
/// private, offline trace, depending on the user's setting.
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.points,
    required this.style,
    required this.color,
    this.interactive = false,
  });

  final List<GeoPoint> points;
  final MapStyle style;
  final Color color;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Center(
        child: Text(
          'Waiting for GPS…',
          style: context.subheadline.copyWith(color: context.secondaryLabel),
        ),
      );
    }
    return Semantics(
      label: 'Route map',
      image: true,
      child: style == MapStyle.street
          ? _StreetMap(points: points, color: color, interactive: interactive)
          : CustomPaint(
              painter: RouteTracePainter(
                points: points,
                color: color,
                grid: context.separatorColor,
              ),
              size: Size.infinite,
            ),
    );
  }
}

class _StreetMap extends StatefulWidget {
  const _StreetMap({
    required this.points,
    required this.color,
    required this.interactive,
  });

  final List<GeoPoint> points;
  final Color color;
  final bool interactive;

  @override
  State<_StreetMap> createState() => _StreetMapState();
}

class _StreetMapState extends State<_StreetMap> {
  final _controller = MapController();
  bool _ready = false;

  List<LatLng> get _line => [
    for (final p in widget.points) LatLng(p.lat, p.lng),
  ];

  @override
  void didUpdateWidget(_StreetMap old) {
    super.didUpdateWidget(old);
    // During a live workout, keep the whole route in view as it grows.
    if (_ready &&
        !widget.interactive &&
        widget.points.length != old.points.length) {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: _line,
          padding: const EdgeInsets.all(28),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = _line;
    final color = widget.color;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        onMapReady: () => _ready = true,
        initialCameraFit: CameraFit.coordinates(
          coordinates: line,
          padding: const EdgeInsets.all(28),
        ),
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // Required by the OpenStreetMap tile usage policy.
          userAgentPackageName: 'health.untrustedtech.dev',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: line,
              strokeWidth: 5,
              color: color,
              borderStrokeWidth: 2,
              borderColor: const Color(0xFFFFFFFF),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            _dot(line.first, Palette.green),
            _dot(line.last, Palette.red),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© OpenStreetMap contributors (openstreetmap.org/copyright)',
            ),
          ],
        ),
      ],
    );
  }

  Marker _dot(LatLng at, Color color) => Marker(
    point: at,
    width: 14,
    height: 14,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 2.5),
      ),
    ),
  );
}

/// Draws the route shape with no map underneath (works offline).
class RouteTracePainter extends CustomPainter {
  RouteTracePainter({
    required this.points,
    required this.color,
    required this.grid,
  });

  final List<GeoPoint> points;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    // Equirectangular projection, corrected for latitude, fitted to size.
    final midLat =
        points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
    final k = cos(midLat * pi / 180);
    final xs = [for (final p in points) p.lng * k];
    final ys = [for (final p in points) p.lat];
    final minX = xs.reduce(min), maxX = xs.reduce(max);
    final minY = ys.reduce(min), maxY = ys.reduce(max);
    const pad = 20.0;
    final span = max(max(maxX - minX, maxY - minY), 1e-6);
    final scale = min(size.width - 2 * pad, size.height - 2 * pad) / span;
    final dx = (size.width - (maxX - minX) * scale) / 2;
    final dy = (size.height - (maxY - minY) * scale) / 2;
    Offset at(int i) => Offset(
      dx + (xs[i] - minX) * scale,
      size.height - dy - (ys[i] - minY) * scale,
    );

    // Soft tint instead of a grid, so the route itself stands out.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(colors: [color.withValues(alpha: 0.6), color])
            .createShader(Offset.zero & size),
    );
    void dot(Offset o, Color c) {
      canvas.drawCircle(o, 7, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(o, 5, Paint()..color = c);
    }

    dot(at(0), Palette.green);
    dot(at(points.length - 1), Palette.red);
  }

  @override
  bool shouldRepaint(RouteTracePainter old) =>
      !identical(old.points, points) ||
      old.points.length != points.length ||
      old.color != color ||
      old.grid != grid;
}
