import 'package:flutter/services.dart';
import 'package:health_app/security/app_lock.dart';

/// Answers the unlock prompt without any UI.
class FakeAuthenticator implements Authenticator {
  bool hasLock = true;

  /// The screen lock check throws, as on a platform error.
  bool checkFails = false;
  bool succeed = true;
  int prompts = 0;

  @override
  Future<bool> available() async {
    if (checkFails) throw PlatformException(code: 'error');
    return hasLock;
  }

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return succeed;
  }
}
