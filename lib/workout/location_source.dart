import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:health_app/workout/geo.dart';

enum LocationAccess { granted, denied, servicesOff }

/// GPS positions for live workouts.
abstract interface class LocationSource {
  /// Checks and, if needed, asks for location permission.
  Future<LocationAccess> ensureAccess();

  /// Opens system settings so the user can turn location on or allow it.
  Future<void> openSettings(LocationAccess problem);

  /// High-accuracy positions. On Android this runs a foreground service
  /// with a notification, and on iOS it keeps running in the background, so
  /// tracking continues with the screen off.
  Stream<GeoPoint> positions();
}

class GeolocatorSource implements LocationSource {
  const GeolocatorSource();

  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.servicesOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccess.granted,
      _ => LocationAccess.denied,
    };
  }

  @override
  Future<void> openSettings(LocationAccess problem) async {
    if (problem == LocationAccess.servicesOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  @override
  Stream<GeoPoint> positions() {
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            distanceFilter: 3,
            intervalDuration: const Duration(seconds: 1),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Workout in progress',
              notificationText: 'Health is recording your route.',
              notificationChannelName: 'Workout tracking',
              notificationIcon: AndroidResource(name: 'ic_stat_health'),
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : defaultTargetPlatform == TargetPlatform.iOS
        // Keeps recording with the phone locked or in a pocket (needs the
        // "location" background mode in Info.plist); the blue status bar
        // pill shows that the route is being recorded.
        ? AppleSettings(
            accuracy: LocationAccuracy.best,
            activityType: ActivityType.fitness,
            distanceFilter: 3,
            allowBackgroundLocationUpdates: true,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          )
        : const LocationSettings(distanceFilter: 3);
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => GeoPoint(
        lat: p.latitude,
        lng: p.longitude,
        time: p.timestamp,
        accuracy: p.accuracy,
        altitude: p.altitude == 0 ? null : p.altitude,
      ),
    );
  }
}
