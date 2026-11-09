import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:health_app/update/update_checker.dart';
import 'package:health_app/update/whats_new.dart';

Map<String, Object?> _release(String tag, {List<String> files = const []}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/UntrustedTech/health/releases/tag/$tag',
  'assets': [
    for (final f in files)
      {
        'name': f,
        'browser_download_url':
            'https://github.com/UntrustedTech/health/releases/download/$tag/$f',
      },
  ],
};

void main() {
  group('AppUpdate.fromRelease', () {
    test('reads the version, build and the file for this phone', () {
      final json = _release(
        'v1.0.0+99',
        files: ['Health-1.0.0-99.apk', 'Health-1.0.0-99.ipa'],
      );
      final android = AppUpdate.fromRelease(json, TargetPlatform.android)!;
      expect(android.version, '1.0.0');
      expect(android.build, 99);
      expect(android.url.path, endsWith('Health-1.0.0-99.apk'));
      final iphone = AppUpdate.fromRelease(json, TargetPlatform.iOS)!;
      expect(iphone.url.path, endsWith('Health-1.0.0-99.ipa'));
    });

    test('falls back to the release page, and skips store files', () {
      final json = _release('1.2.0-120', files: ['Health-1.2.0-120-store.apk']);
      final u = AppUpdate.fromRelease(json, TargetPlatform.android)!;
      expect(u.build, 120);
      expect(u.url.path, endsWith('/releases/tag/1.2.0-120'));
    });

    test('reads the build from hidden notes when the tag has none', () {
      final json = {
        ..._release('v1.0.0', files: ['Health-1.0.0.apk']),
        'body': 'Open Health 1.0.0\n\n<!-- build 128 -->\n',
      };
      final u = AppUpdate.fromRelease(json, TargetPlatform.android)!;
      expect(u.version, '1.0.0');
      expect(u.build, 128);
      expect(u.url.path, endsWith('Health-1.0.0.apk'));
      expect(
        AppUpdate.fromRelease(_release('v1.0.0'), TargetPlatform.android),
        isNull,
      );
    });

    test('ignores drafts, bad tags and links off GitHub', () {
      expect(
        AppUpdate.fromRelease({
          ..._release('v1.0.0+5'),
          'draft': true,
        }, TargetPlatform.android),
        isNull,
      );
      expect(
        AppUpdate.fromRelease(_release('latest'), TargetPlatform.android),
        isNull,
      );
      expect(
        AppUpdate.fromRelease({
          'tag_name': 'v1.0.0+5',
          'html_url': 'https://evil.example/x',
          'assets': [
            {
              'name': 'Health.apk',
              'browser_download_url': 'http://github.com/x.apk',
            },
          ],
        }, TargetPlatform.android),
        isNull,
      );
      expect(AppUpdate.fromRelease('nope', TargetPlatform.android), isNull);
    });
  });

  group('UpdateChecker', () {
    test('finds only newer builds', () async {
      var body =
          '{"tag_name": "v1.0.0+98", "html_url": '
          '"https://github.com/UntrustedTech/health/releases/tag/v1.0.0+98"}';
      final checker = UpdateChecker(
        currentBuild: 98,
        // On even in the store version's tests.
        enabled: true,
        fetch: (_) async => body,
        platform: TargetPlatform.android,
      );
      final now = DateTime(2026, 10, 25, 9);
      await checker.check(now: now);
      expect(checker.available, isNull);

      body = body.replaceAll('98', '99');
      // Not again within the interval...
      await checker.check(now: now.add(const Duration(hours: 1)));
      expect(checker.available, isNull);
      // ...but after it.
      await checker.check(now: now.add(UpdateChecker.interval));
      expect(checker.available?.build, 99);
    });

    test('nothing when offline, unreleased or off', () async {
      final offline = UpdateChecker(currentBuild: 1, fetch: (_) async => null);
      await offline.check();
      expect(offline.available, isNull);

      final unknownBuild = UpdateChecker(
        fetch: (_) async => throw StateError(''),
      );
      await unknownBuild.check();
      expect(unknownBuild.available, isNull);

      var asked = false;
      final store = UpdateChecker(
        currentBuild: 1,
        enabled: false,
        fetch: (_) async {
          asked = true;
          return null;
        },
      );
      await store.check();
      expect(asked, isFalse);
    });
  });

  test('notifies once per build, not after the app showed it', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    UpdateChecker make() => UpdateChecker(
      currentBuild: 98,
      enabled: true,
      prefs: prefs,
      fetch: (_) async =>
          '{"tag_name": "v1.0.0+99", "html_url": '
          '"https://github.com/UntrustedTech/open-health/releases"}',
      platform: TargetPlatform.android,
    );
    final first = make();
    await first.check(force: true);
    expect(await first.shouldNotify(), isTrue);
    await first.markNotified();
    final again = make();
    await again.check(force: true);
    expect(await again.shouldNotify(), isFalse);
    // The pop-up still shows once in the app.
    expect(await again.shouldAnnounce(), isTrue);
  });

  test('What\'s New lists notes after the last seen build', () {
    const notes = <int, List<WhatsNewItem>>{
      5: [(icon: IconData(1), title: 'five', detail: '')],
      7: [(icon: IconData(2), title: 'seven', detail: '')],
    };
    expect(notesSince(4, 7, notes).map((n) => n.title), ['seven', 'five']);
    expect(notesSince(5, 7, notes).map((n) => n.title), ['seven']);
    expect(notesSince(7, 7, notes), isEmpty);
    expect(whatsNewNotes, isNotEmpty);
  });

  test('What\'s New shows once per update, never on a new install', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = SharedPreferencesAsync();
    var build = 128;
    final whatsNew = WhatsNew(prefs, build: () async => build);
    // Set up in this version: nothing to tell.
    await whatsNew.markFreshInstall();
    expect(await whatsNew.takeUnseen(), isEmpty);
    // Updated to a build with notes: shown once.
    build = 129;
    final notes = whatsNewNotes[129] ?? const [];
    expect(await whatsNew.takeUnseen(), notes);
    expect(await whatsNew.takeUnseen(), isEmpty);
  });

  test(
    'What\'s New shows this build\'s notes to users from before it',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final whatsNew = WhatsNew(
        SharedPreferencesAsync(),
        build: () async => 128,
      );
      expect(await whatsNew.takeUnseen(), whatsNewNotes[128]);
    },
  );
}
