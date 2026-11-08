import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/update/whats_new.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/platform/device_profile.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import 'package:health_app/screens/onboarding/setup_about_step.dart';
import 'package:health_app/screens/onboarding/setup_finishing.dart';
import 'package:health_app/screens/onboarding/setup_goal_step.dart';
import 'package:health_app/screens/onboarding/setup_page.dart';
import 'package:health_app/screens/onboarding/setup_steps.dart';
import 'package:health_app/screens/onboarding/setup_units_step.dart';
import 'package:health_app/screens/onboarding/welcome_page.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// How a new user wants to start: with their own data from Health
/// Connect, from scratch, or with demo data to look around.
enum DataChoice { connect, fresh, demo }

/// First launch: a welcome page, then a guided setup (name and age, where
/// data comes from, preferences, details, goals, food, fitness and
/// reminders). Every step can be skipped; skipped steps are listed on
/// Summary until they're done.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  /// The setup steps, in order. Page 0 is the welcome; the page after the
  /// last step is the summary of what was set up.
  static const _steps = SetupStep.values;

  final _name = TextEditingController();
  final _skipped = <SetupStep>{};
  int _page = 0;
  bool _forward = true;
  DataChoice? _choice;
  bool _busy = false;

  /// Playing the closing "setting up" sequence.
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    super.dispose();
  }

  /// Back from installing Health Connect (or from settings): check again,
  /// so connecting is offered as soon as it can be.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final sync = context.read<HealthSyncService>();
    if (!sync.connected) unawaited(sync.refreshStatus());
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = page > _page;
      _page = page;
    });
  }

  StepNav _nav(SetupStep step) => StepNav(
    step: step.index + 1,
    steps: _steps.length,
    // Moves are relative to this step's own page, so a late callback (say
    // after a slow connect) can never jump past a page.
    onBack: () => _go(step.index),
    onDone: (skipped) {
      setState(() => skipped ? _skipped.add(step) : _skipped.remove(step));
      _go(step.index + 2);
    },
  );

  /// Demo data is added only when it was chosen (not skipped past) and
  /// nothing is connected.
  bool get _withDemo =>
      _choice == DataChoice.demo &&
      !_skipped.contains(SetupStep.connect) &&
      !context.read<HealthSyncService>().connected;

  Future<void> _finish() async {
    setState(() => _busy = true);
    final store = context.read<HealthStore>();
    // Skipping Reminders didn't ask; medication reminders and the workout
    // timer still need notifications, so ask once now.
    if (_skipped.contains(SetupStep.reminders)) {
      try {
        await context
            .read<NotificationController>()
            .notifier
            .requestPermission();
      } on Object catch (e) {
        logError('Setup: notification permission failed: $e');
      }
      if (!mounted) return;
    }
    // Before setup ends, as the home screen then looks for it at once.
    await WhatsNew.of(context)?.markFreshInstall();
    if (!mounted) return;
    try {
      await store.completeOnboarding(
        name: _name.text,
        withSampleData: _withDemo,
        setupLeft: {..._skipped},
      );
    } finally {
      // Normally this screen is gone by now; if not, it stays usable.
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Finishes after the closing sequence; if saving fails, goes back to
  /// the last page with a message rather than leaving the sequence up.
  Future<void> _finishFromSequence() async {
    try {
      await _finish();
    } on Exception catch (e) {
      logError('Setup: could not finish: $e');
      if (!mounted) return;
      setState(() => _finishing = false);
      await showMessage(
        context,
        title: 'Couldn\'t Finish Setup',
        message: 'Something went wrong saving your settings. Please try again.',
      );
    }
  }

  Future<void> _connect() async {
    final sync = context.read<HealthSyncService>();
    if (sync.status == SourceStatus.needsInstall) {
      await sync.openInstallPage();
      return;
    }
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await sync.connect();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (ok && mounted && _page == SetupStep.connect.index + 1) {
      _nav(SetupStep.connect).onDone(false);
    }
  }

  Future<void> _continueConnected() async {
    final sync = context.read<HealthSyncService>();
    if (await sync.needsAccessRequest()) return _connect();
    if (mounted) _nav(SetupStep.connect).onDone(false);
  }

  @override
  Widget build(BuildContext context) {
    if (_finishing) {
      return SetupFinishing(sampleData: _withDemo, onDone: _finishFromSequence);
    }
    final page = switch (_page) {
      0 => _buildWelcome(context),
      final p when p > _steps.length => _buildDone(context),
      final p => switch (_steps[p - 1]) {
        SetupStep.about => AboutStep(nav: _nav(SetupStep.about), name: _name),
        SetupStep.connect => _buildConnect(context),
        SetupStep.preferences => PreferencesStep(
          nav: _nav(SetupStep.preferences),
        ),
        SetupStep.profile => ProfileStep(nav: _nav(SetupStep.profile)),
        SetupStep.bodyGoal => BodyGoalStep(nav: _nav(SetupStep.bodyGoal)),
        SetupStep.goals => GoalsStep(nav: _nav(SetupStep.goals)),
        SetupStep.food => FoodStep(nav: _nav(SetupStep.food)),
        SetupStep.fitness => FitnessStep(nav: _nav(SetupStep.fitness)),
        SetupStep.reminders => RemindersStep(nav: _nav(SetupStep.reminders)),
      },
    };
    final reduce = Motion.reduced(context);
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      child: AnimatedSwitcher(
        duration: reduce ? Duration.zero : Motion.medium,
        switchInCurve: Motion.curve,
        switchOutCurve: Motion.curve,
        // Pages slide in from the side they're going to, and fade.
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(_page);
          final dx = (incoming == _forward) ? 0.08 : -0.08;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: Offset(dx, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(_page), child: page),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) =>
      WelcomePage(onStart: () => _go(1));

  Widget _buildConnect(BuildContext context) {
    final sync = context.watch<HealthSyncService>();
    final device = context.watch<DeviceProfile>();
    final status = sync.status;
    final source = sync.sourceName;
    // Still checking (it starts with the app): wait rather than offer
    // only a fresh start.
    final checking = status == null;
    final canConnect =
        checking ||
        status == SourceStatus.available ||
        status == SourceStatus.needsInstall;
    final error = sync.error;
    final nav = _nav(SetupStep.connect);
    // Connecting is the default whenever it's possible.
    final choice =
        _choice ??
        (sync.connected || canConnect ? DataChoice.connect : DataChoice.fresh);
    void choose(DataChoice c) {
      HapticFeedback.selectionClick();
      setState(() => _choice = c);
    }

    final VoidCallback onContinue = switch (choice) {
      DataChoice.connect when checking => () {},
      DataChoice.connect when !sync.connected && canConnect => _connect,
      // Connected, but Apple Health may never have asked (it asks once).
      DataChoice.connect when sync.connected => _continueConnected,
      _ => () {
        _choice = choice;
        nav.onDone(false);
      },
    };
    return SetupPage(
      icon: Icons.sync_rounded,
      color: AppTheme.accent,
      title: 'Your Data',
      subtitle:
          'How would you like to start? You can connect, add or remove data '
          'any time in Profile.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: sync.connected ? null : () => nav.onDone(true),
      busy: _busy || (checking && choice == DataChoice.connect),
      continueLabel: switch (choice) {
        DataChoice.connect when sync.connected => 'Continue',
        DataChoice.connect when status == SourceStatus.needsInstall =>
          'Install $source',
        DataChoice.connect => 'Connect $source',
        DataChoice.fresh => 'Start Fresh',
        DataChoice.demo => 'Explore With Demo Data',
      },
      onContinue: onContinue,
      children: [
        SetupChoice(
          icon: Icons.favorite_rounded,
          color: Palette.red,
          title: sync.connected ? '$source Connected' : 'Use $source',
          subtitle: canConnect || sync.connected
              ? 'Steps, sleep, heart and workouts from ${_phone(device)} '
                    'and watch.'
              : '$source isn\'t available on ${_phone(device)}.',
          badge: canConnect || sync.connected ? 'Recommended' : null,
          selected: choice == DataChoice.connect,
          onTap: canConnect || sync.connected
              ? () => choose(DataChoice.connect)
              : null,
          details: _ConnectDetails(
            source: source,
            samsung: device.isSamsung,
            connected: sync.connected,
            error: error,
          ),
        ),
        const SizedBox(height: 10),
        SetupChoice(
          icon: Icons.edit_note_rounded,
          color: Palette.blue,
          title: 'Start Fresh',
          subtitle:
              'Begin with a clean slate and log everything yourself. You can '
              'connect later.',
          selected: choice == DataChoice.fresh,
          onTap: () => choose(DataChoice.fresh),
        ),
        const SizedBox(height: 10),
        SetupChoice(
          icon: Icons.science_rounded,
          color: Palette.purple,
          title: 'Try With Demo Data',
          subtitle:
              'Fill Health with realistic sample data to see what it can do. '
              'Remove it in one tap from Profile.',
          selected: choice == DataChoice.demo,
          onTap: sync.connected ? null : () => choose(DataChoice.demo),
        ),
      ],
    );
  }

  static String _phone(DeviceProfile device) =>
      device.platform == DevicePlatform.other
      ? 'this device'
      : 'your ${device.displayName}';

  Widget _buildDone(BuildContext context) {
    final green = context.resolve(Palette.green);
    return SetupPage(
      icon: Icons.check_rounded,
      color: Palette.green,
      title: _skipped.isEmpty ? 'You\'re All Set' : 'Almost There',
      subtitle: _skipped.isEmpty
          ? 'Health is ready. Change anything later in Profile.'
          : 'Steps you skipped wait for you on Summary, so you can finish '
                'them whenever you like.',
      onBack: () => _go(_page - 1),
      continueLabel: 'Start Using Health',
      busy: _busy,
      onContinue: () => setState(() => _finishing = true),
      children: [
        GroupedSection(
          children: [
            for (final step in _steps)
              CupertinoListTile(
                leading: Icon(
                  _skipped.contains(step)
                      ? Icons.radio_button_unchecked_rounded
                      : Icons.check_circle_rounded,
                  color: _skipped.contains(step)
                      ? context.tertiaryLabel
                      : green,
                ),
                title: Text(step.label),
                additionalInfo: _skipped.contains(step)
                    ? const Text('Later')
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        const _PrivacyNote(),
      ],
    );
  }
}

/// What Health Connect is, shown under its option.
class _ConnectDetails extends StatelessWidget {
  const _ConnectDetails({
    required this.source,
    required this.samsung,
    required this.connected,
    required this.error,
  });

  final String source;
  final bool samsung;
  final bool connected;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What is $source?',
          style: context.subheadline.copyWith(fontWeight: FontWeight.w700),
        ),
        point(
          Icons.hub_rounded,
          defaultTargetPlatform == TargetPlatform.iOS
              ? 'Your iPhone\'s secure home for health data, shared by apps '
                    'like your watch\'s app.'
              : 'Android\'s secure hub for health data, shared by apps like '
                    '${samsung ? 'Samsung Health and ' : ''}your watch\'s app.',
        ),
        point(
          Icons.verified_user_rounded,
          'You choose what Health reads. It all stays on your phone.',
        ),
        if (connected)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: context.resolve(Palette.green),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text('Connected', style: context.headline),
              ],
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error,
              style: context.footnote.copyWith(color: context.destructive),
            ),
          ),
      ],
    );
  }
}

/// Where the user's data lives, shown before setup finishes.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => IosCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconTile(
          icon: Icons.shield_rounded,
          color: Palette.green,
          size: 36,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Data Stays Yours', style: context.headline),
              const SizedBox(height: 4),
              Text(
                'Anyone can read Health\'s code. Everything you log or bring in '
                'is stored on this device only, and encrypted. Nothing leaves '
                'it unless you back it up or export it to a place you choose. '
                'There are no accounts, ads or trackers.',
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
