import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/insights/progress_stats.dart';
import 'package:health_app/insights/training_stats.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/activity_heatmap.dart';
import 'package:health_app/workout/workout_stats.dart';

/// Keeps the home screen widgets up to date (Android, and iPhone through
/// the HealthWidgets extension).
///
/// Widgets read plain values saved here (no health history, just today's
/// totals). The "+250 ml" button runs in the background, so it only queues
/// the amount in `pendingWater`; the app adds it to the encrypted store the
/// next time it opens.
abstract final class HomeWidgets {
  static const _providers = [
    'health.untrustedtech.dev.ActivityWidget',
    'health.untrustedtech.dev.WaterWidget',
    'health.untrustedtech.dev.WorkoutWidget',
    'health.untrustedtech.dev.ProgressWidget',
    'health.untrustedtech.dev.FastingWidget',
  ];

  /// The iPhone widgets' kinds share the Android class names
  /// (ios/HealthWidgets/HealthWidgets.swift).
  static Iterable<String> get _iosKinds =>
      _providers.map((name) => name.split('.').last);

  /// The App Group the iPhone widgets share with the app.
  static const iosAppGroup = 'group.health.untrustedtech.dev';

  static bool get _supported => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };

  /// Points the plugin at the App Group (iPhone). Call before the rest.
  static Future<void> init() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await HomeWidget.setAppGroupId(iosAppGroup);
    } on PlatformException catch (e) {
      logError('HomeWidgets: no App Group: $e');
    }
  }

  /// Weeks of activity on the Progress widget.
  static const heatWeeks = 16;

  /// The theme chosen in Appearance (null for the app's own), so the
  /// widgets wear the same colours as the app. Set by the app.
  static Skin? skin;

  /// The theme's surfaces with the user's own accent.
  static bool myColour = false;
  static const _pendingKey = 'pendingWater';

  /// The newest widget water tap the app has added; see [_drain].
  static const _drainedKey = 'pendingWaterDrained';
  static const waterStepMl = 250;

  /// Workouts the widget's Start buttons may launch.
  static const startableTypes = {
    WorkoutType.run,
    WorkoutType.walk,
    WorkoutType.cycle,
    WorkoutType.strength,
  };

  static final _day = DateFormat('yyyy-MM-dd');

  /// Saves today's values and redraws every widget. With [hidden] (App
  /// Lock on) the values are removed and the widgets show a lock.
  static Future<void> update(
    HealthStore health,
    WorkoutStore workouts, {
    bool hidden = false,
    FastingStore? fasting,
  }) async {
    if (!_supported) return;
    if (hidden) return _hide();
    try {
      await HomeWidget.saveWidgetData<bool>('hidden', false);
      final week = workouts.thisWeek;
      final weekFrom = weekStart(
        health.today,
        firstDay: workouts.plan.weekStart,
      );
      final values = <String, Object>{
        // Widgets show zeros once this date is no longer today.
        'date': _day.format(health.today),
        'move': health.todayValue(MetricType.activeEnergy).round(),
        'moveGoal': health.goals.activeEnergy.round(),
        'exercise': health.todayValue(MetricType.exerciseMinutes).round(),
        'exerciseGoal': health.goals.exerciseMinutes.round(),
        'steps': health.todayValue(MetricType.steps).round(),
        'stepsGoal': health.goals.steps.round(),
        'water':
            health.todayValue(MetricType.water).round() +
            await _pendingTotal(health.today),
        // Water has its own date: the widget's button can add to it
        // without the app (see [homeWidgetBackgroundCallback]).
        'waterDate': _day.format(health.today),
        // Weekly values show zero once this (exclusive) end date arrives.
        'weekEnds': _day.format(
          DateTime(weekFrom.year, weekFrom.month, weekFrom.day + 7),
        ),
        'waterGoal': health.goals.water.round(),
        'weekMinutes': week.minutes,
        'weekGoal': workouts.settings.weeklyGoalMinutes,
        'weekCount': week.count,
        'streak': workouts.streak,
        ...widgetText(goalMl: health.goals.water),
        ...progressData(
          workouts.all,
          today: health.today,
          firstDay: workouts.plan.weekStart,
        ),
        'imperial': Units.imperial,
      };
      for (final MapEntry(:key, :value) in values.entries) {
        await HomeWidget.saveWidgetData(key, value);
      }
      if (fasting != null) {
        for (final MapEntry(:key, :value) in fastingData(fasting).entries) {
          await HomeWidget.saveWidgetData<Object>(key, value);
        }
      }
      final look = health.personalization;
      // Widgets fall back to their own colours without an accent.
      await HomeWidget.saveWidgetData<int>(
        'accent',
        look.themedWidgets ? look.accent.color.color.toARGB32() : null,
      );
      final colours = themeColours(
        themed: look.themedWidgets,
        accent: look.accent.color,
        mode: health.themeMode,
        skin: skin,
        myColour: myColour,
      );
      for (final MapEntry(:key, :value) in colours.entries) {
        await HomeWidget.saveWidgetData<int>(key, value);
      }
      await _redraw();
    } on Exception catch (e) {
      logError('HomeWidgets: update failed: $e');
    }
  }

  /// The app's look for the widgets, light and dark: surface, text, its
  /// secondary shade and accent, and "wMode" (0 follows the phone, 1 light,
  /// 2 dark). Unthemed widgets keep the app's own surfaces and data colours.
  @visibleForTesting
  static Map<String, int?> themeColours({
    required bool themed,
    required CupertinoDynamicColor accent,
    required ThemeMode mode,
    Skin? skin,
    bool myColour = false,
  }) {
    final s = themed ? skin : null;
    int argb(Color c) => c.toARGB32();
    (int, int, int, int) of(bool dark) {
      final c = s?.colors(dark);
      final accentColour = c == null || myColour
          ? (dark ? accent.darkColor : accent.color)
          : c.accent;
      return (
        argb(c?.card ?? (dark ? Palette.card.darkColor : Palette.card.color)),
        argb(
          c?.label ?? (dark ? Palette.label.darkColor : Palette.label.color),
        ),
        argb(
          c?.secondaryLabel ??
              (dark
                  ? Palette.secondaryLabel.darkColor
                  : Palette.secondaryLabel.color),
        ),
        argb(accentColour),
      );
    }

    final (bgL, labelL, secL, accentL) = of(false);
    final (bgD, labelD, secD, accentD) = of(true);
    final forced = s?.brightness;
    return {
      'wBgL': bgL,
      'wBgD': bgD,
      'wLabelL': labelL,
      'wLabelD': labelD,
      'wSecL': secL,
      'wSecD': secD,
      // Removed when unthemed, so the widgets use their own colours.
      'wAccentL': themed ? accentL : null,
      'wAccentD': themed ? accentD : null,
      'wMode': switch ((forced, mode)) {
        (Brightness.light, _) || (null, ThemeMode.light) => 1,
        (Brightness.dark, _) || (null, ThemeMode.dark) => 2,
        _ => 0,
      },
    };
  }

  /// Water labels in the user's units, e.g. "of 2,000 ml". The amount
  /// itself is formatted by the widget from the live total.
  @visibleForTesting
  static Map<String, String> widgetText({required double goalMl}) => {
    'waterGoalText': tr(
      'of ${formatValue(MetricType.water, goalMl)} ${Units.waterUnit}',
    ),
    'waterButton':
        '+ ${formatValue(MetricType.water, waterStepMl.toDouble())} '
        '${Units.waterUnit}',
  };

  /// Numbers and heatmap for the Progress widget. The heatmap is one digit
  /// (0–4) per day, oldest first, in whole Monday–Sunday weeks ending with
  /// this one; days after today are "-".
  @visibleForTesting
  static Map<String, Object> progressData(
    List<WorkoutSession> workouts, {
    required DateTime today,
    int firstDay = DateTime.monday,
  }) {
    final minutes = activityByDay(workouts, today: today);
    final first = weekStart(today);
    final start = DateTime(
      first.year,
      first.month,
      first.day - 7 * (heatWeeks - 1),
    );
    final heat = StringBuffer();
    for (var i = 0; i < heatWeeks * 7; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      heat.write(
        day.isAfter(today) ? '-' : ActivityHeatmap.levelOf(minutes[day] ?? 0),
      );
    }
    return {
      'progWorkouts': workouts.length,
      'progMonth': workoutsThisMonth(workouts, today),
      // The heatmap stays Monday-first to match the widget's rows.
      'progStreak': weekStreak(workouts, today, firstDay: firstDay),
      'progHeat': heat.toString(),
    };
  }

  /// The Fasting widget's values: the running fast's start (epoch
  /// milliseconds, null when not fasting), its goal and the schedule name.
  /// The widget counts up by itself, so these change only on start/end.
  @visibleForTesting
  static Map<String, Object?> fastingData(FastingStore fasting) => {
    'fastStart': fasting.started?.millisecondsSinceEpoch,
    'fastGoalMin': fasting.goal.inMinutes,
    'fastLabel': fasting.preset.label,
  };

  static const _links = MethodChannel('health/links');

  /// The link of the widget tap that opened or resumed the app, once (later
  /// calls return null until the next tap).
  static Future<Uri?> takeLink() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) return _takeIosLink();
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final link = await _links.invokeMethod<String>('take');
      return link == null ? null : Uri.tryParse(link);
    } on PlatformException catch (e) {
      logError('HomeWidgets: no link: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static bool _launchLinkTaken = false;

  /// The tap that launched the app, once; later taps arrive on [taps].
  static Future<Uri?> _takeIosLink() async {
    if (_launchLinkTaken) return null;
    _launchLinkTaken = true;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } on PlatformException catch (e) {
      logError('HomeWidgets: no link: $e');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Widget taps while the app is running (iPhone). Android's are taken
  /// with [takeLink] when the app resumes.
  static Stream<Uri?> get taps => defaultTargetPlatform == TargetPlatform.iOS
      ? HomeWidget.widgetClicked
      : const Stream.empty();

  /// True for the workout Live Activity's link (back to the workout).
  static bool isWorkoutLink(Uri? uri) =>
      uri != null &&
      uri.scheme == 'health' &&
      uri.host == 'workout' &&
      (uri.path.isEmpty || uri.path == '/');

  /// True for the Fasting widget's link (opens the fasting timer).
  static bool isFastingLink(Uri? uri) =>
      uri != null && uri.scheme == 'health' && uri.host == 'fasting';

  /// True for the Progress widget's link (opens Stats).
  static bool isStatsLink(Uri? uri) =>
      uri != null && uri.scheme == 'health' && uri.host == 'stats';

  /// Every value the widgets read.
  static const _dataKeys = [
    'date',
    'move',
    'moveGoal',
    'exercise',
    'exerciseGoal',
    'steps',
    'stepsGoal',
    'water',
    'waterDate',
    'weekEnds',
    'waterGoal',
    'weekMinutes',
    'weekGoal',
    'weekCount',
    'streak',
    'imperial',
    'progWorkouts',
    'progMonth',
    'progStreak',
    'progHeat',
    'waterGoalText',
    'waterButton',
    'accent',
    'wBgL',
    'wBgD',
    'wLabelL',
    'wLabelD',
    'wSecL',
    'wSecD',
    'wAccentL',
    'wAccentD',
    'wMode',
    'fastStart',
    'fastGoalMin',
    'fastLabel',
    _pendingKey,
  ];

  static Future<void> _redraw() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (final kind in _iosKinds) {
        await HomeWidget.updateWidget(iOSName: kind);
      }
      return;
    }
    for (final name in _providers) {
      await HomeWidget.updateWidget(qualifiedAndroidName: name);
    }
  }

  /// Removes the data and shows the widgets' lock card.
  static Future<void> _hide() async {
    try {
      await HomeWidget.saveWidgetData<bool>('hidden', true);
      for (final key in _dataKeys) {
        if (key == _pendingKey) continue; // Water still waiting to be added.
        await HomeWidget.saveWidgetData<Object>(key, null);
      }
      await _redraw();
    } on Exception catch (e) {
      logError('HomeWidgets: hide failed: $e');
    }
  }

  /// Removes everything the widgets store (after "Erase All Data").
  static Future<void> clear() async {
    if (!_supported) return;
    const keys = [..._dataKeys, _drainedKey, 'hidden'];
    try {
      for (final key in keys) {
        await HomeWidget.saveWidgetData<Object>(key, null);
      }
      await _redraw();
    } on Exception catch (e) {
      logError('HomeWidgets: clear failed: $e');
    }
  }

  static Future<void>? _draining;

  /// Adds water logged from the widget while the app was closed. Calls
  /// while one is running share it, so nothing is added twice.
  static Future<void> drainPendingWater(HealthStore health) {
    if (!_supported) return Future.value();
    return _draining ??= _drain(health).whenComplete(() => _draining = null);
  }

  /// Water taps are only ever written by the widget's isolate; the app
  /// only records the newest tap it has added ([_drainedKey]). Nothing is
  /// written to the same key from two isolates, so no tap can be lost.
  static Future<void> _drain(HealthStore health) async {
    try {
      final drained = await _drainedUntil();
      final pending = [
        for (final p in parsePending(
          await HomeWidget.getWidgetData<String>(_pendingKey),
        ))
          if (p.$1.millisecondsSinceEpoch > drained) p,
      ];
      if (pending.isEmpty) return;
      final newest = pending
          .map((p) => p.$1.millisecondsSinceEpoch)
          .reduce((a, b) => a > b ? a : b);
      // Marked first: if adding fails part way, nothing is added twice.
      await HomeWidget.saveWidgetData<String>(_drainedKey, '$newest');
      for (final (time, ml) in pending) {
        await health.addEntry(MetricType.water, ml.toDouble(), date: time);
      }
    } on Exception catch (e) {
      logError('HomeWidgets: could not add widget water: $e');
    }
  }

  /// Epoch millis of the newest widget tap already added (0 if none).
  static Future<int> _drainedUntil() async =>
      int.tryParse(await HomeWidget.getWidgetData<String>(_drainedKey) ?? '') ??
      0;

  static Future<int> _pendingTotal(DateTime today) async {
    final drained = await _drainedUntil();
    final pending = parsePending(
      await HomeWidget.getWidgetData<String>(_pendingKey),
    );
    final todayText = _day.format(today);
    return pending
        .where(
          (p) =>
              p.$1.millisecondsSinceEpoch > drained &&
              _day.format(p.$1) == todayText,
        )
        .fold<int>(0, (sum, p) => sum + p.$2);
  }

  /// Format: "epochMillis:ml,epochMillis:ml". Bad items are skipped.
  @visibleForTesting
  static List<(DateTime, int)> parsePending(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return [
      for (final item in raw.split(','))
        if (item.split(':') case [final t, final ml]
            when int.tryParse(t) != null && int.tryParse(ml) != null)
          (
            DateTime.fromMillisecondsSinceEpoch(int.parse(t)),
            int.parse(ml).clamp(0, 2000),
          ),
    ];
  }

  /// The workout a widget link asks to start, if it's allowed.
  static WorkoutType? startTypeFrom(Uri? uri) {
    if (uri == null || uri.scheme != 'health' || uri.host != 'workout') {
      return null;
    }
    final type = WorkoutType.fromName(uri.queryParameters['type']);
    return startableTypes.contains(type) ? type : null;
  }
}

/// Taps handled one after another, so quick taps can't overwrite each
/// other's read-modify-write.
Future<void> _widgetTaps = Future.value();

/// Runs in a background isolate when the widget's "+250 ml" is tapped.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) {
  if (uri?.host != 'addwater') return Future.value();
  return _widgetTaps = _widgetTaps.then((_) => _addWidgetWater());
}

Future<void> _addWidgetWater() async {
  try {
    // The lock card has no button, but a stale one might still be tapped.
    if (await HomeWidget.getWidgetData<bool>('hidden') ?? false) return;
    final raw = await HomeWidget.getWidgetData<String>(HomeWidgets._pendingKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = '$now:${HomeWidgets.waterStepMl}';
    await HomeWidget.saveWidgetData<String>(
      HomeWidgets._pendingKey,
      raw == null || raw.isEmpty ? item : '$raw,$item',
    );
    // After midnight the saved total belongs to yesterday: start from
    // zero. Only water's own date changes; the other values keep theirs,
    // so the widgets still know how old they are.
    final today = HomeWidgets._day.format(DateTime.now());
    // Before the app first saves 'waterDate' (just after an update), the
    // shared date stands in for it.
    final waterDate =
        await HomeWidget.getWidgetData<String>('waterDate') ??
        await HomeWidget.getWidgetData<String>('date');
    final isToday = waterDate == today;
    final shown = isToday
        ? await HomeWidget.getWidgetData<int>('water') ?? 0
        : 0;
    await HomeWidget.saveWidgetData<int>(
      'water',
      shown + HomeWidgets.waterStepMl,
    );
    await HomeWidget.saveWidgetData<String>('waterDate', today);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'health.untrustedtech.dev.WaterWidget',
    );
  } on Exception catch (e) {
    logError('HomeWidgets: widget water failed: $e');
  }
}
