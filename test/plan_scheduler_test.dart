import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/training_plan.dart';
import 'package:health_app/workout/plan_scheduler.dart';

void main() {
  // Sunday 11 October 2026.
  final sunday = DateTime(2026, 10, 11);
  final monday = DateTime(2026, 10, 12);

  const weekly = TrainingPlan(
    mode: PlanMode.weekday,
    days: {
      DateTime.monday: 'push',
      DateTime.wednesday: 'pull',
      DateTime.friday: 'legs',
    },
  );

  group('weekday plan', () {
    test('finds the routine for a weekday and rest days', () {
      expect(sessionFor(monday, weekly, const []).routineId, 'push');
      expect(sessionFor(sunday, weekly, const []).isRest, isTrue);
    });

    test('next session after a rest day', () {
      final next = nextSession(sunday, weekly, const []);
      expect(next?.date, monday);
      expect(next?.routineId, 'push');
    });

    test('moving one session changes only that date', () {
      final moved = weekly.moveSession(
        from: monday,
        to: DateTime(2026, 10, 13),
      );

      expect(sessionFor(monday, moved, const []).isRest, isTrue);
      expect(
        sessionFor(DateTime(2026, 10, 13), moved, const []).routineId,
        'push',
      );
      // The following Monday is unchanged.
      expect(
        sessionFor(DateTime(2026, 10, 19), moved, const []).routineId,
        'push',
      );
    });

    test('done today means today shows as completed', () {
      final s = sessionFor(monday, weekly, [
        (routineId: 'push', date: DateTime(2026, 10, 12, 18)),
      ]);
      expect(s.routineId, 'push');
      expect(s.done, isTrue);
    });
  });

  group('rotation plan', () {
    const rotation = TrainingPlan(
      mode: PlanMode.rotation,
      rotation: ['a', 'b', 'c'],
    );

    test('moving today\'s rotation session keeps its routine', () {
      final moved = rotation.moveSession(
        from: sunday,
        to: DateTime(2026, 10, 13),
        routineId: 'a',
      );

      expect(sessionFor(sunday, moved, const []).isRest, isTrue);
      expect(
        sessionFor(DateTime(2026, 10, 13), moved, const []).routineId,
        'a',
      );
    });

    test('starts with the first routine', () {
      expect(sessionFor(sunday, rotation, const []).routineId, 'a');
    });

    test('next is the one after the last completed, however the week went', () {
      final history = [
        (routineId: 'a', date: DateTime(2026, 10, 1)),
        (routineId: 'b', date: DateTime(2026, 10, 6)),
      ];
      expect(sessionFor(sunday, rotation, history).routineId, 'c');

      final wrapped = [
        ...history,
        (routineId: 'c', date: DateTime(2026, 10, 9)),
      ];
      expect(sessionFor(sunday, rotation, wrapped).routineId, 'a');
    });

    test('after training today, the next one is tomorrow', () {
      final history = [(routineId: 'a', date: DateTime(2026, 10, 11, 9))];
      final today = sessionFor(sunday, rotation, history);
      expect(today.routineId, 'a');
      expect(today.done, isTrue);

      final next = nextSession(sunday, rotation, history);
      expect(next?.date, monday);
      expect(next?.routineId, 'b');
    });
  });

  test('week order follows the chosen first day', () {
    expect(weekOrder(DateTime.monday).first, DateTime.monday);
    expect(weekOrder(DateTime.sunday).first, DateTime.sunday);
    expect(weekOrder(DateTime.sunday).last, DateTime.saturday);
  });

  test('plans round-trip through JSON', () {
    final p = weekly.moveSession(from: monday, to: DateTime(2026, 10, 13));
    final back = TrainingPlan.fromJson(p.toJson());
    expect(back.days, weekly.days);
    expect(back.overrides, p.overrides);
    expect(back.mode, PlanMode.weekday);
  });
}
