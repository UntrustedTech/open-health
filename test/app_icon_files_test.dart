import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/theme/app_icon.dart';

/// Every icon the app can switch to must be built for both phones, under
/// the same name (tool/make_app_icons.py writes them all).
void main() {
  final mixes = [
    for (final bg in AppIcon.backgrounds)
      for (final ln in AppIcon.lines) ?AppIcon.mix(bg, ln),
  ].where((i) => i != AppIcon.original);
  final alternates = [...mixes, ...AppIcon.themes];

  test('every preset is a mix, and names are unique', () {
    for (final p in AppIcon.presets) {
      expect(mixes, contains(p), reason: p.name);
    }
    final native = [for (final i in alternates) i.nativeName];
    expect(native.toSet(), hasLength(native.length));
    expect(AppIcon.byNativeName('MixBlackWhite'), AppIcon.byName('dark'));
    expect(AppIcon.byNativeName('Nope'), isNull);
  });

  test('a line that wouldn\'t show can\'t be mixed', () {
    final black = AppIcon.backgrounds.firstWhere((b) => b.id == 'black');
    final blackLine = AppIcon.lines.firstWhere((l) => l.id == 'black');
    final white = AppIcon.lines.firstWhere((l) => l.id == 'white');
    expect(AppIcon.mix(black, blackLine), isNull);
    expect(AppIcon.mix(black, white), AppIcon.byName('dark'));
    // Every background has some line.
    for (final bg in AppIcon.backgrounds) {
      expect(
        AppIcon.lines.where((l) => AppIcon.mix(bg, l) != null),
        isNotEmpty,
        reason: bg.id,
      );
    }
  });

  test('Android has a launcher entry and icon for each', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final entries = {
      for (final m in RegExp(
        r'android:name="\.Icon(\w+)"\s+'
        r'android:enabled="(true|false)"[^>]*'
        r'android:icon="@mipmap/(\w+)"',
      ).allMatches(manifest))
        m.group(1)!: (m.group(2)!, m.group(3)!),
    };
    expect(entries.keys.toSet(), {
      AppIcon.original.nativeName,
      for (final i in alternates) i.nativeName,
    });
    entries.forEach((name, entry) {
      final (enabled, mipmap) = entry;
      // Only the original is on until another is chosen.
      expect(enabled, name == 'Default' ? 'true' : 'false', reason: name);
      expect(
        File('android/app/src/main/res/mipmap-anydpi-v26/$mipmap.xml')
            .existsSync(),
        isTrue,
        reason: mipmap,
      );
    });
    // MainActivity no longer opens from the launcher itself.
    expect(
      RegExp('category.LAUNCHER').allMatches(manifest),
      hasLength(entries.length),
    );
  });

  test('the iPhone has an opaque 1024 px icon set for each it can show', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final listed = RegExp(
      r'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "([^"]*)"',
    ).allMatches(project).map((m) => m.group(1)).toList();
    final expected = {
      for (final i in alternates)
        if (i.availableOn(TargetPlatform.iOS)) 'AppIcon-${i.nativeName}',
    };
    // Debug, Release and Profile.
    expect(listed, hasLength(3));
    for (final names in listed) {
      expect(names!.split(' ').toSet(), expected);
    }
    for (final name in expected) {
      final png = File('ios/Runner/Assets.xcassets/$name.appiconset/icon.png')
          .readAsBytesSync();
      final header = ByteData.sublistView(png, 16, 26);
      expect(header.getUint32(0), 1024, reason: name);
      expect(header.getUint32(4), 1024, reason: name);
      // Colour type 2: RGB, no alpha (App Store icons can't have any).
      expect(header.getUint8(9), 2, reason: name);
    }
    // No icon sets left over from dropped icons.
    final sets = Directory('ios/Runner/Assets.xcassets')
        .listSync()
        .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .where((n) => n.startsWith('AppIcon-'))
        .map((n) => n.replaceAll('.appiconset', ''));
    expect(sets.toSet(), expected);
  });
}
