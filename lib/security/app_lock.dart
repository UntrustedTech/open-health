import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

/// Checks who's holding the phone: fingerprint, face, or the screen lock.
abstract interface class Authenticator {
  /// True when the phone has a screen lock or biometrics set up. May throw
  /// when that can't be checked.
  Future<bool> available();

  /// Shows the system prompt; true when it succeeds.
  Future<bool> authenticate(String reason);
}

class DeviceAuthenticator implements Authenticator {
  DeviceAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Throws [PlatformException] when the phone can't say.
  @override
  Future<bool> available() => _auth.isDeviceSupported();

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // The phone's PIN or pattern works too, if biometrics fail.
      return await _auth.authenticate(localizedReason: reason);
    } on LocalAuthException catch (e) {
      logError('AppLock: ${e.code.name}');
      return false;
    } on PlatformException catch (e) {
      logError('AppLock: authentication failed: $e');
      return false;
    }
  }
}

/// How long the app can be in the background before it locks.
enum LockAfter {
  immediately('Immediately', Duration.zero),
  oneMinute('After 1 Minute', Duration(minutes: 1)),
  fiveMinutes('After 5 Minutes', Duration(minutes: 5)),
  fifteenMinutes('After 15 Minutes', Duration(minutes: 15));

  const LockAfter(this.label, this.delay);

  final String label;
  final Duration delay;

  static LockAfter fromName(Object? n) =>
      values.firstWhere((v) => v.name == n, orElse: () => LockAfter.oneMinute);
}

/// Locks the app behind the device's biometrics or screen lock, and can hide
/// it in the app switcher. Settings are saved (encrypted) with everything
/// else, but aren't part of backups.
class AppLock extends ChangeNotifier with WidgetsBindingObserver {
  AppLock(
    this._health, {
    Authenticator? authenticator,
    MethodChannel? secureChannel,
    DateTime Function()? clock,
  }) : _auth = authenticator ?? DeviceAuthenticator(),
       _secure = secureChannel ?? const MethodChannel('health/secure'),
       _clock = clock ?? DateTime.now;

  static const docKey = 'security';

  final HealthStore _health;
  final Authenticator _auth;
  final MethodChannel _secure;
  final DateTime Function() _clock;

  bool _enabled = false;
  bool _hideInSwitcher = false;
  bool _widgetData = false;
  LockAfter _after = LockAfter.oneMinute;
  bool _locked = false;
  bool _prompting = false;
  DateTime? _leftAt;

  bool get enabled => _enabled;
  bool get hideInSwitcher => _hideInSwitcher;

  /// Whether home screen widgets may show data while the lock is on.
  bool get showWidgetData => _widgetData;

  /// Widgets show a lock card instead of data.
  bool get hidesWidgets => _enabled && !_widgetData;
  LockAfter get lockAfter => _after;
  bool get locked => _locked;

  bool _noScreenLock = false;

  /// App Lock is on but the phone's screen lock has since been removed,
  /// so there's nothing to check against and the lock can't protect
  /// anything. The user isn't locked out, but should be told.
  bool get screenLockMissing => _enabled && _noScreenLock;

  /// Whether the phone has a screen lock to check against, noting when
  /// it doesn't (see [screenLockMissing]). Assumes it has one when the
  /// check fails, so an error never skips the check (failing closed).
  Future<bool> _hasScreenLock() async {
    bool has;
    try {
      has = await _auth.available();
      // Any failure (a PlatformException, local_auth's own exceptions)
      // fails closed.
    } on Exception catch (e) {
      logError('AppLock: support check failed: $e');
      return true;
    }
    if (_disposed) return has;
    if (has == _noScreenLock) {
      _noScreenLock = !has;
      notifyListeners();
    }
    return has;
  }

  /// Loads settings; the app starts locked when the lock is on, or when
  /// the settings can't be read (failing closed, not open).
  Future<void> load() async {
    try {
      final doc = await _health.loadDocument(docKey);
      _enabled = doc?['enabled'] == true;
      _hideInSwitcher = doc?['hide'] == true;
      _widgetData = doc?['widgets'] == true;
      _after = LockAfter.fromName(doc?['after']);
      _locked = _enabled;
      if (_enabled) await _hasScreenLock();
    } on Exception catch (e) {
      logError('AppLock: could not read settings, starting locked: $e');
      _locked = true;
    }
    // The window starts without the flag; only set it when wanted.
    if (_hideInSwitcher) await _applySecure();
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Locked on leaving rather than on return, so nothing shows for a
  /// frame; undone on return if the app wasn't away long enough.
  bool _lockedOnLeave = false;

  /// Time away by the phone's uptime as well as by the clock, so setting
  /// the clock back while away doesn't keep the app unlocked.
  final _away = Stopwatch();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        // The system prompt itself doesn't count as leaving; but if the
        // prompt ends without success, the user left with it (see
        // [_promptEnded]).
        if (_prompting) {
          _awayDuringPrompt = true;
          return;
        }
        if (!_enabled || _leftAt != null) return;
        _leftAt = _clock();
        _away
          ..reset()
          ..start();
        if (!_locked) {
          _locked = true;
          _lockedOnLeave = true;
          notifyListeners();
        }
      case AppLifecycleState.resumed:
        final left = _leftAt;
        _leftAt = null;
        _away.stop();
        final byClock = left == null ? null : _clock().difference(left);
        if (_lockedOnLeave &&
            byClock != null &&
            !byClock.isNegative &&
            byClock < _after.delay &&
            _away.elapsed < _after.delay) {
          _locked = false;
          notifyListeners();
        }
        _lockedOnLeave = false;
        // The screen lock may have been removed or added while away.
        if (_enabled) unawaited(_hasScreenLock());
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  /// The app was sent to the background while a prompt was showing.
  bool _awayDuringPrompt = false;

  void _promptStarted() {
    _prompting = true;
    _awayDuringPrompt = false;
  }

  /// A prompt was cancelled because the user left the app (pressed Home
  /// while it showed): lock, as for any other leaving, rather than stay
  /// open in the background.
  void _promptEnded(bool ok) {
    _prompting = false;
    final state = WidgetsBinding.instance.lifecycleState;
    final away =
        _awayDuringPrompt ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    _awayDuringPrompt = false;
    if (ok || !_enabled || !away || _locked) return;
    _locked = true;
    notifyListeners();
  }

  /// Back does nothing while locked, rather than quietly closing screens
  /// behind the lock. This observer is added before the app's own (in
  /// [load]), so it's asked first.
  @override
  Future<bool> didPopRoute() async => _locked;

  /// Asks for fingerprint, face or screen lock; unlocks on success.
  Future<bool> unlock() async {
    if (!_locked) return true;
    if (_prompting) return false;
    _promptStarted();
    var ok = false;
    try {
      // Without any screen lock there's nothing to check against.
      ok = !await _hasScreenLock() || await _auth.authenticate('Unlock Health');
      if (ok) {
        _locked = false;
        notifyListeners();
      }
      return ok;
    } finally {
      _promptEnded(ok);
    }
  }

  /// With App Lock on, asks for fingerprint, face or screen lock before a
  /// sensitive action (like exporting everything), so someone holding the
  /// unlocked app can't take the data. True when the lock is off.
  Future<bool> confirm(String reason) async {
    if (!_enabled) return true;
    if (_prompting) return false;
    _promptStarted();
    var ok = false;
    try {
      ok = !await _hasScreenLock() || await _auth.authenticate(reason);
      return ok;
    } finally {
      _promptEnded(ok);
    }
  }

  /// Turns the lock on or off. Both need a successful check first, so
  /// someone else can't change it. Returns false if it didn't change.
  Future<LockChange> setEnabled(bool on) async {
    final hasLock = await _hasScreenLock();
    if (on && !hasLock) return LockChange.noScreenLock;
    var ok = !hasLock; // Turning off with nothing to check against.
    if (!ok) {
      _promptStarted();
      try {
        ok = await _auth.authenticate(
          on ? 'Turn on App Lock' : 'Turn off App Lock',
        );
      } finally {
        _promptEnded(ok);
      }
    }
    if (!ok) return LockChange.failed;
    _enabled = on;
    _locked = false;
    // Otherwise the app switcher's snapshot would show what the lock
    // hides; it can be turned back off.
    final hide = on && !_hideInSwitcher;
    if (hide) _hideInSwitcher = true;
    notifyListeners();
    if (hide) await _applySecure();
    await _save();
    return LockChange.changed;
  }

  Future<void> setLockAfter(LockAfter after) async {
    _after = after;
    notifyListeners();
    await _save();
  }

  Future<void> setHideInSwitcher(bool hide) async {
    _hideInSwitcher = hide;
    notifyListeners();
    await _applySecure();
    await _save();
  }

  Future<void> setShowWidgetData(bool show) async {
    _widgetData = show;
    notifyListeners();
    await _save();
  }

  /// Clears settings after "Erase All".
  Future<void> reset() async {
    final wasHidden = _hideInSwitcher;
    _enabled = false;
    _hideInSwitcher = false;
    _widgetData = false;
    _after = LockAfter.oneMinute;
    _locked = false;
    notifyListeners();
    if (wasHidden) await _applySecure();
  }

  Future<void> _applySecure() async {
    try {
      await _secure.invokeMethod<void>('setSecure', _hideInSwitcher);
    } on MissingPluginException {
      // No handler (e.g. in tests).
    } on PlatformException catch (e) {
      logError('AppLock: could not set secure flag: $e');
    }
  }

  Future<void> _save() => _health.saveDocument(docKey, {
    'enabled': _enabled,
    'hide': _hideInSwitcher,
    'widgets': _widgetData,
    'after': _after.name,
  });
}

enum LockChange { changed, failed, noScreenLock }
