import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/platform/device_profile.dart';

void main() {
  test('recognises Samsung phones and formats their name', () {
    const device = DeviceProfile(
      platform: DevicePlatform.android,
      manufacturer: 'samsung',
      model: 'SM-S921B',
      osVersion: '15',
    );

    expect(device.isSamsung, isTrue);
    expect(device.displayName, 'Samsung SM-S921B');
    expect(device.systemName, 'Android 15');
  });

  test('does not repeat the maker when the model already includes it', () {
    const device = DeviceProfile(
      platform: DevicePlatform.android,
      manufacturer: 'Google',
      model: 'Google Pixel 9',
      osVersion: '16',
    );

    expect(device.isSamsung, isFalse);
    expect(device.displayName, 'Google Pixel 9');
  });

  test('describes iPhones', () {
    const device = DeviceProfile(
      platform: DevicePlatform.ios,
      manufacturer: 'Apple',
      model: 'iPhone 16 Pro',
      osVersion: '26.0',
    );

    expect(device.displayName, 'iPhone 16 Pro');
    expect(device.systemName, 'iOS 26.0');
  });
}
