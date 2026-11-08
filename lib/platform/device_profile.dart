import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:health_app/utils/log.dart';

enum DevicePlatform { android, ios, other }

/// The phone the app is running on. Used to pick the right health platform
/// and to give device-specific help (e.g. turning on Samsung Health sync).
@immutable
class DeviceProfile {
  const DeviceProfile({
    required this.platform,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
  });

  static const unknown = DeviceProfile(
    platform: DevicePlatform.other,
    manufacturer: '',
    model: 'This device',
    osVersion: '',
  );

  final DevicePlatform platform;
  final String manufacturer;
  final String model;
  final String osVersion;

  bool get isAndroid => platform == DevicePlatform.android;
  bool get isIOS => platform == DevicePlatform.ios;
  bool get isSamsung => manufacturer.toLowerCase() == 'samsung';

  /// e.g. "Samsung SM-S921B" or "iPhone 16 Pro".
  String get displayName {
    if (isIOS || manufacturer.isEmpty) return model;
    final maker = manufacturer[0].toUpperCase() + manufacturer.substring(1);
    return model.toLowerCase().startsWith(manufacturer.toLowerCase())
        ? model
        : '$maker $model';
  }

  /// e.g. "Android 15" or "iOS 26.0".
  String get systemName => switch (platform) {
    DevicePlatform.android => 'Android $osVersion',
    DevicePlatform.ios => 'iOS $osVersion',
    DevicePlatform.other => osVersion,
  };

  /// Reads the current device's details. Never throws.
  static Future<DeviceProfile> detect([DeviceInfoPlugin? plugin]) async {
    final info = plugin ?? DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return DeviceProfile(
          platform: DevicePlatform.android,
          manufacturer: a.manufacturer,
          model: a.model,
          osVersion: a.version.release,
        );
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return DeviceProfile(
          platform: DevicePlatform.ios,
          manufacturer: 'Apple',
          model: i.modelName,
          osVersion: i.systemVersion,
        );
      }
    } on Exception catch (e) {
      logError('DeviceProfile: detection failed: $e');
    }
    return unknown;
  }
}
