import 'package:flutter/foundation.dart';

import 'package:health_app/models/training_plan.dart';

/// A completed plan session: which routine, and when.
typedef DoneSession = ({String routineId, DateTime date});

@immutable
class PlannedDay {
  const PlannedDay({required this.date, this.routineId, this.done = false});

  final DateTime date;

  /// Null on a rest day.
  final String? routineId;

  /// True once that routine was trained on [date].
  final bool done;

  bool get isRest => routineId == null;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Weekdays in display order for the chosen first day of the week.
List<int> weekOrder(int weekStart) => [
  for (var i = 0; i < 7; i++) (weekStart - 1 + i) % 7 + 1,
];

/// What's planned on [date] (the history decides rotation order and
/// whether today's session is already done).
PlannedDay sessionFor(
  DateTime date,
  TrainingPlan plan,
  List<DoneSession> history,
) {
  final day = _day(date);
  final key = TrainingPlan.dateKey(day);
  final doneToday = history.where((h) => _sameDay(h.date, day)).toList();

  String? routine;
  if (plan.overrides.containsKey(key)) {
    routine = plan.overrides[key];
  } else if (plan.mode == PlanMode.weekday) {
    routine = plan.days[day.weekday];
  } else {
    routine = _rotationNext(
      plan.rotation,
      history.where((h) => h.date.isBefore(day)).toList(),
    );
    // Something from the rotation was trained today: that's today's.
    final today = doneToday
        .where((h) => plan.rotation.contains(h.routineId))
        .lastOrNull;
    if (today != null) routine = today.routineId;
  }
  return PlannedDay(
    date: day,
    routineId: routine,
    done: routine != null && doneToday.any((h) => h.routineId == routine),
  );
}

/// The first planned, not-yet-done session from [from] onwards (within
/// two weeks), or null if nothing is planned.
PlannedDay? nextSession(
  DateTime from,
  TrainingPlan plan,
  List<DoneSession> history,
) {
  final start = _day(from);
  for (var i = 0; i < 14; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    if (plan.mode == PlanMode.rotation &&
        !plan.overrides.containsKey(TrainingPlan.dateKey(day))) {
      final today = sessionFor(day, plan, history);
      if (today.isRest) return null;
      if (!today.done) return today;
      // Done today: the next routine in the rotation is tomorrow.
      final next = _rotationNext(plan.rotation, history);
      return PlannedDay(
        date: DateTime(day.year, day.month, day.day + 1),
        routineId: next,
      );
    }
    final s = sessionFor(day, plan, history);
    if (!s.isRest && !s.done) return s;
  }
  return null;
}

String? _rotationNext(List<String> rotation, List<DoneSession> history) {
  if (rotation.isEmpty) return null;
  final sorted = [...history]..sort((a, b) => a.date.compareTo(b.date));
  final last = sorted.lastWhere(
    (h) => rotation.contains(h.routineId),
    orElse: () => (routineId: '', date: DateTime(0)),
  );
  final i = rotation.indexOf(last.routineId);
  return rotation[(i + 1) % rotation.length];
}
