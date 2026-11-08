import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_icon.dart';
import 'package:health_app/utils/log.dart';

/// The Home Screen icon. Only the app's own for now; an icon chosen in an
/// earlier version goes back to the original.
class AppIcons extends ChangeNotifier {
  AppIcons(this._health, {MethodChannel? channel, TargetPlatform? platform})
    : _channel = channel ?? const MethodChannel('health/icon'),
      _platform = platform ?? defaultTargetPlatform;

  static const docKey = 'appIcon';

  final HealthStore _health;
  final MethodChannel _channel;
  final TargetPlatform _platform;

  AppIcon _chosen = AppIcon.original;

  AppIcon get chosen => _chosen;

  /// The chosen icon as a picture for notifications (a PNG's path); null
  /// for the original, which notifications show already.
  String? get picture => _picture;
  String? _picture;

  /// Tints notifications' small icon to match; null for the original.
  Color? get notificationColor => _chosen == AppIcon.original
      ? null
      : (_chosen.tile.firstOrNull ?? _chosen.line.firstOrNull);

  /// The icons to pick from: none besides the original for now.
  List<AppIcon> get choices => const [];

  bool get canCreate => false;

  /// Backgrounds this phone can show, for Create Your Own.
  List<IconPaint> get backgrounds => [
    for (final b in AppIcon.backgrounds)
      if (!b.isClear || _platform == TargetPlatform.android) b,
  ];

  /// Whether [icon] can be chosen now.
  bool allows(AppIcon icon) =>
      icon == AppIcon.original ||
      choices.contains(icon) ||
      (canCreate && icon.isMix && icon.availableOn(_platform));

  /// Reads the saved choice, and makes sure the
  /// phone shows it (Android switches icons only once the app is left, so
  /// a switch can be lost if the app is closed first).
  Future<void> load() async {
    try {
      final doc = await _health.loadDocument(docKey);
      _chosen = switch (doc?['icon']) {
        final String name => AppIcon.byNativeName(name) ?? AppIcon.original,
        _ => AppIcon.original,
      };
    } on Exception catch (e) {
      logError('AppIcons: could not load: $e');
    }
    notifyListeners();
    if (!await _check()) await _apply();
  }

  Future<void> choose(AppIcon icon) async {
    if (icon == _chosen || !allows(icon)) return;
    _chosen = icon;
    notifyListeners();
    await _save();
    await _apply();
  }

  /// Goes back to the original if the chosen icon is no longer offered;
  /// whether it did.
  Future<bool> _check() async {
    if (allows(_chosen)) return false;
    _chosen = AppIcon.original;
    notifyListeners();
    await _save();
    await _apply();
    return true;
  }

  Future<void> _save() =>
      _health.saveDocument(docKey, {'icon': _chosen.nativeName});

  Future<void> _apply() async {
    try {
      final ok = await _channel.invokeMethod<bool>('set', _chosen.nativeName);
      if (ok != true) logError('AppIcons: ${_chosen.name} was not applied');
      _picture = _chosen == AppIcon.original
          ? null
          : await _channel.invokeMethod<String>('picture', _chosen.nativeName);
      notifyListeners();
    } on MissingPluginException {
      // No handler (e.g. in tests).
    } on PlatformException catch (e) {
      logError('AppIcons: could not set icon: $e');
    }
  }
}
