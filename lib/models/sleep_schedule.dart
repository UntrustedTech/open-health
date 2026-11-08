import 'package:flutter/foundation.dart';

/// A time of day, in minutes after midnight.
typedef ClockTime = ({int hour, int minute});

/// The user's sleep schedule: bedtime, wake time and an optional
/// wind-down reminder before bed.
@immutable
class SleepSchedule {
  const SleepSchedule({
    this.enabled = false,
    this.bedtime = (hour: 22, minute: 30),
    this.wake = (hour: 6, minute: 30),
    this.windDown = const Duration(minutes: 30),
    this.remind = true,
  });

  final bool enabled;
  final ClockTime bedtime;
  final ClockTime wake;

  /// How long before bedtime the wind-down reminder comes.
  final Duration windDown;
  final bool remind;

  /// Wind-down choices offered.
  static const windDownChoices = [15, 30, 45, 60];

  /// Time in bed, bedtime to wake (crossing midnight as needed).
  Duration get timeInBed {
    final bed = bedtime.hour * 60 + bedtime.minute;
    final up = wake.hour * 60 + wake.minute;
    final minutes = (up - bed) % (24 * 60);
    return Duration(minutes: minutes == 0 ? 24 * 60 : minutes);
  }

  /// The sleep goal implied by the schedule, in hours.
  double get goalHours => timeInBed.inMinutes / 60;

  /// When the wind-down reminder fires.
  ClockTime get windDownAt {
    final m =
        (bedtime.hour * 60 + bedtime.minute - windDown.inMinutes) % (24 * 60);
    return (hour: m ~/ 60, minute: m % 60);
  }

  SleepSchedule copyWith({
    bool? enabled,
    ClockTime? bedtime,
    ClockTime? wake,
    Duration? windDown,
    bool? remind,
  }) => SleepSchedule(
    enabled: enabled ?? this.enabled,
    bedtime: bedtime ?? this.bedtime,
    wake: wake ?? this.wake,
    windDown: windDown ?? this.windDown,
    remind: remind ?? this.remind,
  );

  Map<String, Object?> toJson() => {
    'on': enabled,
    'bed': bedtime.hour * 60 + bedtime.minute,
    'wake': wake.hour * 60 + wake.minute,
    'wind': windDown.inMinutes,
    'remind': remind,
  };

  static SleepSchedule fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const SleepSchedule();
    const d = SleepSchedule();
    ClockTime time(Object? v, ClockTime fallback) =>
        v is int && v >= 0 && v < 24 * 60
        ? (hour: v ~/ 60, minute: v % 60)
        : fallback;
    final wind = json['wind'];
    return SleepSchedule(
      enabled: json['on'] == true,
      bedtime: time(json['bed'], d.bedtime),
      wake: time(json['wake'], d.wake),
      windDown: wind is int && windDownChoices.contains(wind)
          ? Duration(minutes: wind)
          : d.windDown,
      remind: json['remind'] != false,
    );
  }
}

/// How well recent nights matched the schedule.
typedef SleepConsistency = ({
  /// Nights with data in the window.
  int nights,

  /// Nights with sleep within [onTargetMargin] of the goal.
  int onTarget,

  /// On-target nights in a row, ending last night.
  int streak,

  /// Average sleep over nights with data, in hours.
  double? average,
});

/// Sleep this close to the goal counts as on target.
const onTargetMargin = Duration(minutes: 30);

/// Compares the last [days] nights with [goalHours]. [sleepOn] gives the
/// hours slept on a day (the night before it), or null without data.
SleepConsistency sleepConsistency({
  required double? Function(DateTime day) sleepOn,
  required DateTime today,
  required double goalHours,
  int days = 7,
}) {
  final target = goalHours - onTargetMargin.inMinutes / 60;
  var nights = 0, onTarget = 0;
  var total = 0.0;
  for (var i = 0; i < days; i++) {
    final h = sleepOn(DateTime(today.year, today.month, today.day - i));
    if (h == null) continue;
    nights++;
    total += h;
    if (h >= target) onTarget++;
  }
  var streak = 0;
  for (var i = 0; i < 366; i++) {
    final h = sleepOn(DateTime(today.year, today.month, today.day - i));
    // Today's night may not be synced yet; it doesn't break the streak.
    if (h == null && i == 0) continue;
    if (h == null || h < target) break;
    streak++;
  }
  return (
    nights: nights,
    onTarget: onTarget,
    streak: streak,
    average: nights == 0 ? null : total / nights,
  );
}
