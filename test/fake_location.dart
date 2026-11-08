import 'dart:async';

import 'package:health_app/workout/geo.dart';
import 'package:health_app/workout/location_source.dart';

/// GPS stand-in: tests push points with [emit].
class FakeLocation implements LocationSource {
  LocationAccess access = LocationAccess.granted;
  final _controller = StreamController<GeoPoint>.broadcast();

  void emit(GeoPoint p) => _controller.add(p);

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Future<void> openSettings(LocationAccess problem) async {}

  @override
  Stream<GeoPoint> positions() => _controller.stream;
}
