import 'package:flutter/foundation.dart';

enum PeriodFlow {
  spotting('Spotting'),
  light('Light'),
  medium('Medium'),
  heavy('Heavy');

  const PeriodFlow(this.label);

  final String label;

  /// Spotting alone doesn't start a period.
  bool get isPeriod => this != spotting;

  static PeriodFlow? fromName(Object? n) =>
      values.where((f) => f.name == n).firstOrNull;
}

enum Symptom {
  cramps('Cramps'),
  headache('Headache'),
  bloating('Bloating'),
  fatigue('Fatigue'),
  moodChanges('Mood Changes'),
  acne('Acne'),
  backPain('Back Pain'),
  breastTenderness('Breast Tenderness'),
  nausea('Nausea'),
  cravings('Cravings'),
  sleepChanges('Sleep Changes'),
  hotFlashes('Hot Flashes');

  const Symptom(this.label);

  final String label;

  static Symptom? fromName(Object? n) =>
      values.where((s) => s.name == n).firstOrNull;
}

/// What was logged on one day.
@immutable
class CycleDay {
  const CycleDay({this.flow, this.symptoms = const {}});

  final PeriodFlow? flow;
  final Set<Symptom> symptoms;

  bool get isEmpty => flow == null && symptoms.isEmpty;

  Map<String, Object?> toJson() => {
    if (flow case final f?) 'flow': f.name,
    if (symptoms.isNotEmpty) 'sym': [for (final s in symptoms) s.name],
  };

  static CycleDay fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const CycleDay();
    final sym = json['sym'];
    return CycleDay(
      flow: PeriodFlow.fromName(json['flow']),
      symptoms: Set.unmodifiable({
        if (sym is List)
          for (final s in sym) ?Symptom.fromName(s),
      }),
    );
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A day as a storage key: "20261015".
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// Reads a [dayKey], or null if it isn't one (or isn't a real date).
DateTime? parseDayKey(String key) {
  if (!RegExp(r'^\d{8}$').hasMatch(key)) return null;
  final y = int.parse(key.substring(0, 4));
  final m = int.parse(key.substring(4, 6));
  final d = int.parse(key.substring(6, 8));
  final date = DateTime(y, m, d);
  // Rejects 20261332 and the like, which DateTime would roll over.
  return date.year == y && date.month == m && date.day == d ? date : null;
}

/// [d] moved by whole calendar days (safe across DST).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Whole days from [a] to [b] (calendar days, safe across DST).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// A logged period: its first and last day.
typedef Period = ({DateTime start, DateTime end});

enum CyclePhase {
  period('Period'),
  follicular('Follicular'),
  fertile('Fertile Window'),
  luteal('Luteal');

  const CyclePhase(this.label);

  final String label;
}

/// Averages and predictions from the logged days. Estimates only.
@immutable
class CycleForecast {
  const CycleForecast({
    required this.periods,
    required this.cycleLength,
    required this.periodLength,
    required this.nextStart,
    required this.fertileStart,
    required this.fertileEnd,
    required this.ovulation,
    required this.cycleDay,
    required this.phase,
    required this.basedOn,
  });

  static const defaultCycle = 28;
  static const defaultPeriod = 5;

  /// Cycles shorter or longer than this are left out of the average.
  static const _minCycle = 15;
  static const _maxCycle = 60;

  /// Cycles averaged.
  static const _recent = 6;

  /// Logged periods, oldest first.
  final List<Period> periods;
  final int cycleLength;
  final int periodLength;

  /// Predicted next period start (null until a period is logged).
  final DateTime? nextStart;
  final DateTime? fertileStart;
  final DateTime? fertileEnd;
  final DateTime? ovulation;

  /// Day of the current cycle (1 = first day of the last period).
  final int? cycleDay;
  final CyclePhase? phase;

  /// How many full cycles the averages come from.
  final int basedOn;

  bool isPredictedPeriod(DateTime day) {
    final s = nextStart;
    if (s == null) return false;
    // This and the following predicted cycle.
    for (var k = 0; k < 2; k++) {
      final start = addDays(s, cycleLength * k);
      final d = daysBetween(start, day);
      if (d >= 0 && d < periodLength) return true;
    }
    return false;
  }

  bool isFertile(DateTime day) {
    final a = fertileStart, b = fertileEnd;
    if (a == null || b == null) return false;
    for (var k = 0; k < 2; k++) {
      final from = addDays(a, cycleLength * k);
      final to = addDays(b, cycleLength * k);
      if (daysBetween(from, day) >= 0 && daysBetween(day, to) >= 0) {
        return true;
      }
    }
    return false;
  }

  static List<int> _lastCycles(List<int> values) => values.length > _recent
      ? values.sublist(values.length - _recent)
      : values;

  static CycleForecast from(Map<DateTime, CycleDay> days, DateTime today) {
    final periods = _periods(days);
    final starts = [for (final p in periods) p.start];
    final gaps = [
      for (var i = 1; i < starts.length; i++)
        daysBetween(starts[i - 1], starts[i]),
    ].where((g) => g >= _minCycle && g <= _maxCycle).toList();
    final recentGaps = _lastCycles(gaps);
    final cycle = recentGaps.isEmpty
        ? defaultCycle
        : (recentGaps.reduce((a, b) => a + b) / recentGaps.length).round();
    final recentLengths = _lastCycles([
      for (final p in periods) daysBetween(p.start, p.end) + 1,
    ]);
    final periodLen = recentLengths.isEmpty
        ? defaultPeriod
        : (recentLengths.reduce((a, b) => a + b) / recentLengths.length)
              .round()
              .clamp(1, 12);

    if (starts.isEmpty) {
      return CycleForecast(
        periods: periods,
        cycleLength: cycle,
        periodLength: periodLen,
        nextStart: null,
        fertileStart: null,
        fertileEnd: null,
        ovulation: null,
        cycleDay: null,
        phase: null,
        basedOn: recentGaps.length,
      );
    }
    final t = dateOnly(today);
    final last = starts.last;
    var next = addDays(last, cycle);
    // A late period: keep predicting from today rather than the past.
    while (daysBetween(t, next) < 0) {
      next = addDays(next, cycle);
    }
    // Ovulation is about 14 days before the next period.
    final ovulation = addDays(next, -14);
    final fertileStart = addDays(ovulation, -5);
    final fertileEnd = addDays(ovulation, 1);
    final cycleDay = daysBetween(last, t) + 1;
    // Logged through today, or still within a typical period length.
    final inPeriod =
        periods.isNotEmpty &&
        (daysBetween(periods.last.end, t) <= 0 || cycleDay <= periodLen);
    final phase = inPeriod
        ? CyclePhase.period
        : daysBetween(fertileStart, t) >= 0 && daysBetween(t, fertileEnd) >= 0
        ? CyclePhase.fertile
        : daysBetween(t, fertileStart) > 0
        ? CyclePhase.follicular
        : CyclePhase.luteal;
    return CycleForecast(
      periods: periods,
      cycleLength: cycle,
      periodLength: periodLen,
      nextStart: next,
      fertileStart: fertileStart,
      fertileEnd: fertileEnd,
      ovulation: ovulation,
      cycleDay: cycleDay,
      phase: phase,
      basedOn: recentGaps.length,
    );
  }

  /// Groups flow days into periods. A gap of one day without flow doesn't
  /// end a period; spotting can extend one but not start one.
  static List<Period> _periods(Map<DateTime, CycleDay> days) {
    final flowDays =
        days.entries
            .where((e) => e.value.flow != null)
            .map((e) => (day: dateOnly(e.key), flow: e.value.flow!))
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day));
    final out = <Period>[];
    DateTime? start, end;
    for (final d in flowDays) {
      if (start != null && end != null && daysBetween(end, d.day) <= 2) {
        end = d.day;
        continue;
      }
      if (start != null && end != null) out.add((start: start, end: end));
      if (d.flow.isPeriod) {
        start = d.day;
        end = d.day;
      } else {
        start = null;
        end = null;
      }
    }
    if (start != null && end != null) out.add((start: start, end: end));
    return out;
  }
}
