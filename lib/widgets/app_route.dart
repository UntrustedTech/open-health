import 'package:flutter/cupertino.dart';

import 'package:health_app/l10n/language.dart';

/// The app's page route: the iOS slide and swipe-back, but quicker than
/// Cupertino's 500 ms so moving between screens stays under the 400 ms
/// at which a wait starts to be noticed (see DESIGN.md).
class AppRoute<T> extends CupertinoPageRoute<T> {
  AppRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
    super.title,
    super.maintainState,
    super.allowSnapshotting,
  });

  /// In the app's language, as the next page's back button shows it.
  @override
  String? get title => switch (super.title) {
    final t? => tr(t),
    null => null,
  };

  static const duration = Duration(milliseconds: 340);

  @override
  Duration get transitionDuration => duration;
}
