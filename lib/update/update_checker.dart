import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/utils/log.dart';

/// A newer build on GitHub, with a direct link to its file.
@immutable
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.build,
    required this.url,
  });

  final String version;
  final int build;

  /// The .apk or .ipa itself, or the release page if it has none for
  /// this phone.
  final Uri url;

  /// Reads GitHub's latest release: its tag (`v1.0.0+99`, `1.0.0-99`)
  /// gives the version and build, and the asset for [platform] the link.
  /// Null if it can't be read.
  static AppUpdate? fromRelease(Object? json, TargetPlatform platform) {
    if (json is! Map<String, Object?>) return null;
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final m = RegExp(r'(\d+\.\d+\.\d+)[+\-_ ](\d+)').firstMatch(tag);
    final build = int.tryParse(m?.group(2) ?? '');
    if (m == null || build == null) return null;
    final ext = platform == TargetPlatform.iOS ? '.ipa' : '.apk';
    Uri? asset;
    final assets = json['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is! Map) continue;
        final name = a['name'];
        final link = a['browser_download_url'];
        // The store builds are never on GitHub, but skip them anyway.
        if (name is String &&
            link is String &&
            name.toLowerCase().endsWith(ext) &&
            !name.contains('-store')) {
          asset = _github(link);
          break;
        }
      }
    }
    final page = json['html_url'];
    final url = asset ?? (page is String ? _github(page) : null);
    if (url == null) return null;
    return AppUpdate(version: m.group(1)!, build: build, url: url);
  }

  /// Only https links on GitHub are followed.
  static Uri? _github(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'https') return null;
    return uri.host == 'github.com' || uri.host.endsWith('.github.com')
        ? uri
        : null;
  }
}

/// Checks GitHub for a newer build of the app (GitHub version only; see
/// [kStoreEdition]). Releases are tagged `v<version>+<build>` with the
/// APK and IPA attached; until there are any, it finds nothing.
class UpdateChecker extends ChangeNotifier {
  UpdateChecker({
    this.currentBuild,
    Future<String?> Function(Uri)? fetch,
    TargetPlatform? platform,
    SharedPreferencesAsync? prefs,
    bool enabled = !kStoreEdition,
  }) : _fetch = fetch ?? _download,
       _platform = platform ?? defaultTargetPlatform,
       // Named parameters can't be private, so these can't be
       // initializing formals.
       // ignore: prefer_initializing_formals
       _prefs = prefs,
       // ignore: prefer_initializing_formals
       _enabled = enabled;

  static final releases = Uri.https(
    'api.github.com',
    '/repos/UntrustedTech/open-health/releases/latest',
  );

  /// The once-a-day background check (Workmanager task name).
  static const dailyTask = 'update-check';
  static const _notifiedKey = 'updateNotifiedBuild';

  /// Looks once a day while the app is closed (GitHub version on Android;
  /// iOS has no reliable periodic background work, so it checks on open).
  static Future<void> scheduleDaily() async {
    if (kStoreEdition || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await Workmanager().registerPeriodicTask(
      dailyTask,
      dailyTask,
      frequency: const Duration(days: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Whether the background check should notify about [available]: once
  /// per build, and not for one the app already told the user about.
  Future<bool> shouldNotify() async {
    final update = _available;
    if (update == null || !await shouldAnnounce()) return false;
    return await _prefs?.getInt(_notifiedKey) != update.build;
  }

  Future<void> markNotified() async {
    if (_available case final update?) {
      await _prefs?.setInt(_notifiedKey, update.build);
    }
  }

  /// How often it looks, at most (on launch and when the app comes back).
  static const interval = Duration(hours: 12);
  static const _dismissedKey = 'updateDismissedBuild';

  /// This app's build; nothing is checked until it's known.
  int? currentBuild;
  final Future<String?> Function(Uri) _fetch;
  final TargetPlatform _platform;
  final SharedPreferencesAsync? _prefs;
  final bool _enabled;
  DateTime? _checked;
  bool _checking = false;

  AppUpdate? _available;

  /// A newer build, if there is one.
  AppUpdate? get available => _available;

  /// Looks for a newer build, unless it looked in the last [interval].
  Future<void> check({DateTime? now, bool force = false}) async {
    final current = currentBuild;
    if (!_enabled || _checking || current == null) return;
    final at = now ?? DateTime.now();
    final last = _checked;
    if (!force && last != null && at.difference(last) < interval) return;
    _checking = true;
    try {
      final body = await _fetch(releases);
      _checked = at;
      if (body == null) return;
      final update = AppUpdate.fromRelease(jsonDecode(body), _platform);
      final newer = update != null && update.build > current ? update : null;
      if (newer?.build != _available?.build) {
        _available = newer;
        notifyListeners();
      }
    } on FormatException catch (e) {
      logError('Updates: bad answer: $e');
    } finally {
      _checking = false;
    }
  }

  /// Whether to tell the user about [available] when the app opens: once
  /// per build, then it stays in Settings.
  Future<bool> shouldAnnounce() async {
    final update = _available;
    if (update == null) return false;
    try {
      final seen = await _prefs?.getInt(_dismissedKey);
      return seen != update.build;
    } on Exception catch (e) {
      logError('Updates: could not read: $e');
      return false;
    }
  }

  Future<void> markAnnounced() async {
    final update = _available;
    if (update == null) return;
    try {
      await _prefs?.setInt(_dismissedKey, update.build);
    } on Exception catch (e) {
      logError('Updates: could not save: $e');
    }
  }

  static const _timeout = Duration(seconds: 10);
  static const _maxBytes = 512 * 1024;

  /// The answer, or null when there's no release (404, also while the
  /// repo is private) or no connection.
  static Future<String?> _download(Uri url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(url).timeout(_timeout);
      req.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'HealthApp/1');
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(_timeout)) {
        bytes.add(chunk);
        if (bytes.length > _maxBytes) return null;
      }
      return utf8.decode(bytes.takeBytes(), allowMalformed: true);
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } on HttpException catch (e) {
      logError('Updates: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
