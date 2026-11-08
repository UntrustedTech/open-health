import 'dart:math';

import 'package:flutter/foundation.dart';

/// One GPS fix.
@immutable
class GeoPoint {
  const GeoPoint({
    required this.lat,
    required this.lng,
    required this.time,
    this.accuracy = 0,
    this.altitude,
  });

  final double lat;
  final double lng;
  final DateTime time;

  /// Horizontal accuracy in metres (lower is better).
  final double accuracy;
  final double? altitude;

  /// Compact storage: [lat×1e5, lng×1e5, seconds since [origin], altitude].
  List<int> toCompact(DateTime origin) => [
    (lat * 1e5).round(),
    (lng * 1e5).round(),
    time.difference(origin).inSeconds,
    if (altitude case final a?) a.round(),
  ];

  static GeoPoint? fromCompact(Object? row, DateTime origin) {
    if (row is! List || row.length < 3) return null;
    final [lat, lng, sec, ...rest] = row;
    if (lat is! int || lng is! int || sec is! int) return null;
    final alt = rest.isEmpty ? null : rest.first;
    return GeoPoint(
      lat: lat / 1e5,
      lng: lng / 1e5,
      time: origin.add(Duration(seconds: sec)),
      altitude: alt is int ? alt.toDouble() : null,
    );
  }
}

const _earthRadiusMeters = 6371000.0;

double _rad(double deg) => deg * pi / 180;

/// Great-circle distance between two points in metres.
double haversineMeters(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(_rad(a.lat)) * cos(_rad(b.lat)) * pow(sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * asin(min(1, sqrt(h)));
}

/// Rejects fixes that are too inaccurate or imply an impossible speed
/// (GPS "jumps"), so they don't inflate distance; and fixes within their
/// own error of the last one, so standing still doesn't add distance as
/// the position drifts. Distance is then measured from the last fix kept,
/// so slow movement still counts once it clears the error.
class RouteFilter {
  RouteFilter({required this.maxSpeedMps, this.maxAccuracyMeters = 30});

  final double maxSpeedMps;
  final double maxAccuracyMeters;
  GeoPoint? _last;

  /// Share of a fix's accuracy that a move must exceed to count.
  static const _drift = 0.5;

  /// Starts a new segment, e.g. after a pause.
  void reset() => _last = null;

  bool accept(GeoPoint p) {
    if (p.accuracy > maxAccuracyMeters) return false;
    final last = _last;
    if (last != null) {
      final seconds = p.time.difference(last.time).inMilliseconds / 1000;
      if (seconds <= 0) return false;
      final meters = haversineMeters(last, p);
      if (meters / seconds > maxSpeedMps) return false;
      if (meters < max(p.accuracy, last.accuracy) * _drift) return false;
    }
    _last = p;
    return true;
  }
}

/// Drops points closer than [minMeters] to the previously kept one, always
/// keeping the first and last point.
List<GeoPoint> downsample(List<GeoPoint> points, {double minMeters = 5}) {
  if (points.length < 3) return List.of(points);
  final kept = [points.first];
  for (final p in points.skip(1).take(points.length - 2)) {
    if (haversineMeters(kept.last, p) >= minMeters) kept.add(p);
  }
  kept.add(points.last);
  return kept;
}

/// Speed at each fix of [route], in m/s, averaged over the [window] before
/// it (single fixes are too noisy). A gap longer than [maxGap] is a pause:
/// counting restarts after it, so moving while paused isn't a burst.
List<({DateTime time, double mps})> rollingSpeeds(
  List<GeoPoint> route, {
  Duration window = const Duration(seconds: 15),
  Duration maxGap = const Duration(minutes: 1),
}) {
  final out = <({DateTime time, double mps})>[];
  final travelled = List<double>.filled(route.length, 0);
  var from = 0;
  for (var i = 1; i < route.length; i++) {
    if (route[i].time.difference(route[i - 1].time) > maxGap) {
      from = i;
      continue;
    }
    travelled[i] = travelled[i - 1] + haversineMeters(route[i - 1], route[i]);
    final earliest = route[i].time.subtract(window);
    // The last fix at or before the window's start.
    while (from + 1 < i && !route[from + 1].time.isAfter(earliest)) {
      from++;
    }
    final seconds =
        route[i].time.difference(route[from].time).inMilliseconds / 1000;
    // Half a window of fixes at least, or the first seconds spike.
    if (seconds < window.inSeconds / 2) continue;
    out.add((
      time: route[i].time,
      mps: (travelled[i] - travelled[from]) / seconds,
    ));
  }
  return out;
}

/// The fastest [rollingSpeeds] of [route] in m/s, or null without one.
double? topSpeed(List<GeoPoint> route) {
  double? top;
  for (final s in rollingSpeeds(route)) {
    if (top == null || s.mps > top) top = s.mps;
  }
  return top;
}
