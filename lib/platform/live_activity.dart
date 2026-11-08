import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/workout/workout_tracker.dart';

/// The workout being recorded, on the iPhone Lock Screen and in the
/// Dynamic Island (see ios/HealthWidgets/WorkoutLiveActivity.swift). Its
/// clock counts by itself, so it's only updated on pause, resume and new
/// distance. Nothing happens on other platforms.
abstract final class LiveActivity {
  static const _channel = MethodChannel('health/live_activity');

  static bool get _supported => defaultTargetPlatform == TargetPlatform.iOS;

  /// Shows [tracker]'s workout. False when it can't be shown (before iOS
  /// 16.2, Live Activities turned off, or not an iPhone).
  static Future<bool> start(WorkoutTracker tracker) async {
    if (!_supported) return false;
    return await _call('start', {
          'name': tr(tracker.type.label),
          'type': tracker.type.name,
          'color': tracker.type.color.toARGB32(),
          ...stateOf(tracker),
        }) ??
        false;
  }

  static Future<void> update(WorkoutTracker tracker) async {
    if (_supported) await _call('update', stateOf(tracker));
  }

  static Future<void> end() async {
    if (_supported) await _call('end');
  }

  /// What the Live Activity shows: time recorded, whether it's paused and
  /// the distance so far (GPS workouts).
  @visibleForTesting
  static Map<String, Object> stateOf(WorkoutTracker tracker) => {
    'elapsed': tracker.elapsed.inSeconds,
    'paused': tracker.status == TrackerStatus.paused,
    'detail': tracker.type.usesGps && tracker.distanceMeters > 0
        ? formatDistance(tracker.distanceMeters)
        : '',
  };

  static Future<bool?> _call(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<bool>(method, args);
    } on PlatformException catch (e) {
      logError('LiveActivity: $method failed: $e');
    } on MissingPluginException {
      // Builds without the widget extension.
    }
    return null;
  }
}
