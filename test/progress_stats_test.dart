import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/progress_stats.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/widgets/activity_heatmap.dart';
import 'package:health_app/widgets/area_chart.dart';

WorkoutSession _w(DateTime start, {double kg = 100, int reps = 5}) =>
    WorkoutSession(
      id: '${start.millisecondsSinceEpoch}',
      type: WorkoutType.strength,
      start: start,
      end: start.add(const Duration(minutes: 45)),
      activeSeconds: 2700,
      exercises: [
        ExerciseLog(
          exerciseId: 'squat',
          sets: [
            SetLog(reps: reps, weightKg: kg, done: true),
            SetLog(reps: reps, weightKg: kg - 10, done: true),
          ],
        ),
      ],
    );

void main() {
  final today = DateTime(2026, 10, 11); // a Sunday

  test('week streak counts weeks in a row, forgiving this week', () {
    final ws = [
      _w(DateTime(2026, 9, 22)),
      _w(DateTime(2026, 9, 29)),
      _w(DateTime(2026, 10, 1)),
    ];
    // Nothing yet this week: the streak runs to last week.
    expect(weekStreak(ws, today), 2);
    expect(weekStreak([...ws, _w(DateTime(2026, 10, 6))], today), 3);
    // A missed week ends it.
    expect(weekStreak(ws, DateTime(2026, 10, 20)), 0);
  });

  test('week streak follows the chosen first day of the week', () {
    // A Saturday and the Sunday after it.
    final ws = [_w(DateTime(2026, 10, 3)), _w(DateTime(2026, 10, 4))];

    expect(weekStreak(ws, today), 1);
    expect(weekStreak(ws, today, firstDay: DateTime.sunday), 2);
  });

  test('workouts this month', () {
    expect(
      workoutsThisMonth([
        _w(DateTime(2026, 10, 1)),
        _w(DateTime(2026, 9, 30)),
        _w(DateTime(2025, 10, 2)),
      ], today),
      1,
    );
  });

  test('exercise series by metric', () {
    final ws = [_w(DateTime(2026, 9, 1)), _w(DateTime(2026, 10, 1), kg: 110)];
    expect(
      exerciseSeries(ws, 'squat', ExerciseMetric.heaviest).map((p) => p.value),
      [100, 110],
    );
    expect(
      exerciseSeries(ws, 'squat', ExerciseMetric.volume).first.value,
      100 * 5 + 90 * 5,
    );
    expect(
      exerciseSeries(ws, 'squat', ExerciseMetric.oneRepMax).last.value,
      greaterThan(110),
    );
  });

  test('ranges clip and 30-day change compares like with like', () {
    final pts = [
      (date: DateTime(2026, 6, 1), value: 80.0),
      (date: DateTime(2026, 9, 5), value: 78.0),
      (date: DateTime(2026, 10, 10), value: 76.5),
    ];
    expect(ProgressRange.month.clip(pts, today), hasLength(1));
    expect(ProgressRange.all.clip(pts, today), hasLength(3));
    expect(changeOver(pts, today), closeTo(-1.5, 1e-9));
    expect(changeOver(pts.take(1).toList(), today), isNull);
  });

  test('heatmap levels follow time trained', () {
    expect(ActivityHeatmap.levelOf(0), 0);
    expect(ActivityHeatmap.levelOf(20), 1);
    expect(ActivityHeatmap.levelOf(50), 3);
    expect(ActivityHeatmap.levelOf(120), 4);
  });

  testWidgets('area chart shows a point when touched', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: AreaChart(
              points: [
                (date: DateTime(2026, 9, 1), value: 70),
                (date: DateTime(2026, 10, 1), value: 72),
              ],
              color: const Color(0xFF34C759),
              format: (v) => '${v.toStringAsFixed(1)} kg',
              goal: 68,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(AreaChart)) + const Offset(40, 100),
    );
    await gesture.moveBy(const Offset(5, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
