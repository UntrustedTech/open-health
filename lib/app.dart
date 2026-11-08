import 'dart:async';

import 'package:health_app/screens/workouts/active_workout.dart';
import 'package:health_app/screens/workouts/workout_mini_bar.dart';
import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons, ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/screens/error_log_screen.dart';
import 'package:health_app/screens/food/food_diary_screen.dart';
import 'package:health_app/screens/health_screen.dart';
import 'package:health_app/screens/lock_screen.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/screens/onboarding_screen.dart';
import 'package:health_app/screens/privacy_screen.dart';
import 'package:health_app/screens/profile_screen.dart';
import 'package:health_app/screens/summary_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/app_lifecycle.dart';
import 'package:health_app/platform/home_widgets.dart';
import 'package:health_app/screens/fasting/fasting_screen.dart';
import 'package:health_app/screens/workouts/live_workout_screen.dart';
import 'package:health_app/screens/workouts/stats_screen.dart';
import 'package:health_app/screens/workouts/workout_launcher.dart';
import 'package:health_app/screens/workouts/workouts_screen.dart';
import 'package:health_app/sync/background_sync.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/glass_tab_bar.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/shell_tabs.dart';
import 'package:health_app/update/update_checker.dart';
import 'package:health_app/update/update_ui.dart';
import 'package:health_app/update/whats_new.dart';

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Only what the app shell needs, so logging data doesn't rebuild (and
    // re-theme) the whole app.
    final look = context.select<HealthStore, Personalization>(
      (s) => s.personalization,
    );
    final themeMode = context.select<HealthStore, ThemeMode>(
      (s) => s.themeMode,
    );
    final loaded = context.select<HealthStore, bool>((s) => s.loaded);
    final locale = _localeOf(context);
    final onboarded = context.select<HealthStore, bool>((s) => s.onboarded);
    const Skin? skin = null;
    const myColour = false;
    final brightness =
        skin?.brightness ??
        switch (themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => null,
        };
    // Above CupertinoApp there's no MediaQuery yet: ask the platform.
    final reduce =
        look.reduceMotion ||
        View.of(context)
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    // A new accent blends in rather than snapping.
    return TweenAnimationBuilder<CupertinoDynamicColor>(
      tween: _DynamicColorTween(
        end: skin == null || myColour ? look.accent.color : skin.accent,
      ),
      duration: reduce ? Duration.zero : Motion.slow,
      curve: Motion.curve,
      builder: (context, accent, _) => CupertinoApp(
        title: 'Health',
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLanguage.supportedLocales,
        localizationsDelegates: GlobalCupertinoLocalizations.delegates,
        theme: AppTheme.theme(brightness, accent: accent, skin: skin),
        // Draw edge to edge, with status/navigation bar icons that match the
        // current appearance.
        builder: (context, child) {
          final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
          final mq = MediaQuery.of(context);
          return MediaQuery(
            // The in-app "Reduce Motion" calms animations like the system one.
            data: look.reduceMotion ? mq.copyWith(disableAnimations: true) : mq,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value:
                  (dark
                          ? SystemUiOverlayStyle.light
                          : SystemUiOverlayStyle.dark)
                      .copyWith(
                        statusBarColor: const Color(0x00000000),
                        systemNavigationBarColor: const Color(0x00000000),
                        systemNavigationBarContrastEnforced: false,
                      ),
              child: SkinScope(
                skin: skin,
                child: _Locked(child: child ?? const SizedBox.shrink()),
              ),
            ),
          );
        },
        routes: {PrivacyScreen.routeName: (_) => const PrivacyScreen()},
        home: !loaded
            ? const CupertinoPageScaffold(
                child: Center(child: CupertinoActivityIndicator()),
              )
            : onboarded
            ? const HomeShell()
            : const OnboardingScreen(),
      ),
    );
  }
}

/// Puts the lock screen over the app while App Lock is locked.
class _Locked extends StatelessWidget {
  const _Locked({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locked = context.select<AppLock, bool>((l) => l.locked);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hidden from screen readers too while locked.
        ExcludeSemantics(excluding: locked, child: child),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

/// Blends both the light and dark variants of a system colour.
class _DynamicColorTween extends Tween<CupertinoDynamicColor> {
  _DynamicColorTween({super.end});

  @override
  CupertinoDynamicColor lerp(double t) {
    final a = begin ?? end!, b = end!;
    if (t >= 1 || identical(a, b)) return b;
    return CupertinoDynamicColor.withBrightness(
      color: Color.lerp(a.color, b.color, t)!,
      darkColor: Color.lerp(a.darkColor, b.darkColor, t)!,
    );
  }
}

/// Main screen: five tabs under a floating glass tab bar. Each tab keeps
/// its own navigation stack, so the tab bar stays visible on detail screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _tabs = [
    GlassTab('Summary', Icons.space_dashboard_rounded),
    GlassTab('Health', Icons.monitor_heart_rounded),
    GlassTab('Food', Icons.restaurant_rounded),
    GlassTab('Fitness', Icons.directions_run_rounded),
    GlassTab('Profile', Icons.person_rounded),
  ];

  final _navigators = [for (final _ in _tabs) GlobalKey<NavigatorState>()];
  final _heroControllers = [
    for (final _ in _tabs) CupertinoApp.createCupertinoHeroController(),
  ];

  /// Tabs are built the first time they're opened, then kept alive.
  final _visited = <int>{0};
  int _index = 0;
  Timer? _midnight;

  /// The newly selected tab fades and settles into place.
  late final _switch = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: 1,
  );
  late final _fade = CurvedAnimation(parent: _switch, curve: Motion.curve);
  late final _rise = Tween(
    begin: const Offset(0, 0.012),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
    unawaited(_listenToWidgetLinks());
    _taps = HomeWidgets.taps.listen(_openLink);
    _markOpen();
    _updates = _readUpdates()?..addListener(_updateFound);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigators[_index].currentContext;
      if (ctx != null) unawaited(WhatsNew.of(ctx)?.show(ctx));
    });
    ActiveWorkout.instance.addListener(_workoutChanged);
  }

  /// A workout minimized or brought back: the mini bar comes or goes.
  void _workoutChanged() {
    final shown = ActiveWorkout.instance.minimized;
    if (shown == _miniBarShown) return;
    _miniBarShown = shown;
    // It can change while the tree builds (a live screen opening or
    // closing), so the shell rebuilds once that frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  bool _miniBarShown = false;

  StreamSubscription<Uri?>? _taps;

  UpdateChecker? _updates;

  UpdateChecker? _readUpdates() {
    try {
      return context.read<UpdateChecker>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// A newer build was found: tell the user once, over the current tab.
  void _updateFound() {
    final ctx = _navigators[_index].currentContext;
    if (ctx != null) unawaited(announceUpdate(ctx));
  }

  /// Home screen widget buttons open the app with a link such as
  /// `health://workout/start?type=run`. The link is taken when the app
  /// starts and each time it resumes (a tap while it runs in the
  /// background).
  Future<void> _listenToWidgetLinks() async {
    _openLink(await HomeWidgets.takeLink());
  }

  void _openLink(Uri? uri) {
    if (!mounted) return;
    if (HomeWidgets.isFastingLink(uri)) {
      return _openOnTab(ShellTabs.summary, FastingScreen.open);
    }
    if (HomeWidgets.isWorkoutLink(uri)) {
      return _openOnTab(ShellTabs.fitness, LiveWorkoutScreen.reopen);
    }
    if (HomeWidgets.isStatsLink(uri)) {
      return _openOnTab(ShellTabs.fitness, StatsScreen.open);
    }
    final type = HomeWidgets.startTypeFrom(uri);
    if (type == null) return;
    _openOnTab(
      ShellTabs.fitness,
      (ctx) => WorkoutLauncher.showSetup(ctx, type),
    );
  }

  /// Shows [tab], then opens a screen on top of it once it is built.
  void _openOnTab(int tab, Future<void> Function(BuildContext) open) {
    _select(tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigators[tab].currentContext;
      if (ctx != null) unawaited(open(ctx));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updates?.removeListener(_updateFound);
    unawaited(_taps?.cancel());
    ActiveWorkout.instance.removeListener(_workoutChanged);
    _midnight?.cancel();
    _presence?.cancel();
    _poll?.cancel();
    _fade.dispose();
    _switch.dispose();
    for (final c in _heroControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // Follows the phone's language when Settings → Language is System.
    try {
      unawaited(context.read<LanguageController>().systemChanged());
    } on ProviderNotFoundException {
      // Previews and tests.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background checks stay away while the app is open (it syncs itself
    // and both writing the data could lose changes).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(AppPresence.mark(open: false));
      _presence?.cancel();
      _poll?.cancel();
    }
    if (state != AppLifecycleState.resumed) return;
    _markOpen();
    // The day may have changed, the home screen widget may have logged
    // water, and new data may be waiting in Health Connect.
    unawaited(onAppResumed(context));
    unawaited(_listenToWidgetLinks());
    unawaited(_updates?.check());
    _scheduleMidnightRefresh();
  }

  /// Renews the "app is open" mark while the app stays open, so a long
  /// session never looks closed to background checks.
  Timer? _presence;

  /// Checks Health Connect for new readings while the app is open, as
  /// often as set in Health Connect settings (heart rate from a watch
  /// arrives through the day).
  Timer? _poll;

  void _markOpen() {
    unawaited(AppPresence.mark(open: true));
    _presence?.cancel();
    _presence = Timer.periodic(
      AppPresence.heartbeat,
      (_) => AppPresence.mark(open: true),
    );
    _poll?.cancel();
    // Every minute; the service syncs once the chosen interval has passed.
    _poll = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      unawaited(context.read<HealthSyncService>().pollWhileOpen());
    });
  }

  /// Rolls "today" over at midnight while the app stays open.
  void _scheduleMidnightRefresh() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      if (!mounted) return;
      context.read<HealthStore>().refresh();
      _scheduleMidnightRefresh();
    });
  }

  void _select(int i) {
    if (i == _index) {
      // Tapping the current tab returns to its first screen.
      _navigators[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _index = i;
      _visited.add(i);
    });
    if (Motion.reduced(context)) {
      _switch.value = 1;
    } else {
      _switch.forward(from: 0);
    }
  }

  Widget _root(int i) => switch (i) {
    ShellTabs.summary => const SummaryScreen(),
    ShellTabs.health => const HealthScreen(),
    ShellTabs.food => const FoodDiaryScreen(),
    ShellTabs.fitness => const WorkoutsScreen(),
    _ => const ProfileScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final saveFailed = context.select<HealthStore, bool>((s) => s.saveFailed);
    final unreadable = context.select<HealthStore, bool>(
      (s) => s.showUnreadableNotice,
    );
    final mq = MediaQuery.of(context);
    final miniBar = _miniBarShown;
    // Content scrolls under the floating bar (and a minimized workout)
    // but can always scroll clear. The scaffold below already makes room
    // for the keyboard, so pages must not make room again.
    final inner = mq
        .removeViewInsets(removeBottom: true)
        .copyWith(
          padding: mq.padding.copyWith(
            bottom:
                mq.padding.bottom +
                AppTheme.tabBarHeight +
                (miniBar ? WorkoutMiniBar.height + 8 : 0),
          ),
        );
    return ShellTabs(
      select: _select,
      child: CupertinoPageScaffold(
        child: Stack(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              if (_visited.contains(i))
                Offstage(
                  offstage: i != _index,
                  // Same widget types for every tab, so switching never
                  // rebuilds a tab's state.
                  child: FadeTransition(
                    opacity: i == _index ? _fade : kAlwaysCompleteAnimation,
                    child: SlideTransition(
                      position: i == _index
                          ? _rise
                          : const AlwaysStoppedAnimation(Offset.zero),
                      child: TickerMode(
                        enabled: i == _index,
                        // Hidden tabs keep their navigation bars out of page
                        // transitions: every bar shares one hero tag, and a
                        // page opened above the tabs (Edit Profile, a live
                        // workout) could otherwise fly a hidden, unpainted
                        // tab's bar, which crashes.
                        child: HeroMode(
                          enabled: i == _index,
                          child: NavigatorPopHandler(
                            enabled: i == _index,
                            onPopWithResult: (_) =>
                                _navigators[i].currentState?.maybePop(),
                            child: HeroControllerScope(
                              controller: _heroControllers[i],
                              child: MediaQuery(
                                data: inner,
                                child: Navigator(
                                  key: _navigators[i],
                                  onGenerateRoute: (settings) => AppRoute<void>(
                                    settings: settings,
                                    // Back buttons read "‹ Profile" etc.
                                    title: _tabs[i].label,
                                    builder: (_) => _root(i),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            // The tab bar is frosted glass, so content shows blurred behind
            // it rather than fading out.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassTabBar(tabs: _tabs, index: _index, onTap: _select),
            ),
            if (miniBar)
              Positioned(
                left: 12,
                right: 12,
                bottom: mq.padding.bottom + AppTheme.tabBarHeight + 6,
                child: const WorkoutMiniBar(),
              ),
            if (saveFailed)
              const _SaveFailedBanner()
            else if (unreadable)
              _Banner(
                icon: Icons.info_rounded,
                color: context.resolve(Palette.orange),
                text:
                    'Some saved data couldn\'t be read. A copy was kept. '
                    'Tap for details.',
                onTap: () {
                  context.read<HealthStore>().dismissUnreadableNotice();
                  ErrorLogScreen.open(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SaveFailedBanner extends StatelessWidget {
  const _SaveFailedBanner();

  @override
  Widget build(BuildContext context) => _Banner(
    icon: Icons.warning_rounded,
    color: context.destructive,
    text: "Couldn't save your latest change. Please try again.",
  );
}

/// A notice floating at the top of the app.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Semantics(
            liveRegion: true,
            button: onTap != null,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: ShapeDecoration(
                  color: color,
                  shape: AppTheme.squircle(AppTheme.radius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: CupertinoColors.white, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        style: context.subheadline.copyWith(
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's language, or English where there's no [LanguageController]
/// (previews and tests).
Locale _localeOf(BuildContext context) {
  try {
    return context.select<LanguageController, Locale>((l) => l.locale);
  } on ProviderNotFoundException {
    return const Locale('en');
  }
}
