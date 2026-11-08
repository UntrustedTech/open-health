import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:health_app/utils/log.dart';

/// The permissions the phone has given the app, reset by Erase All Data so
/// the next launch is like a fresh install.
abstract final class AppPermissions {
  static const _channel = MethodChannel('health/permissions');

  /// Gives back the app's runtime permissions (location, notifications,
  /// Bluetooth, camera, ...). Android 13+ only: they go once the app
  /// closes, so this returns whether the app should [close]. iOS doesn't
  /// let apps give permissions back.
  static Future<bool> revokeAll() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('revokeAll') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      logError('AppPermissions: could not revoke: $e');
      return false;
    }
  }

  /// Closes the app (Android), which finishes [revokeAll].
  static Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on MissingPluginException {
      // Not on Android, or in tests.
    }
  }
}
