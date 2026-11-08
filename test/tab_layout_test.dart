import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/personalization.dart';
import 'package:health_app/models/tab_layout.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/platform/home_widgets.dart';

void main() {
  test('layouts move, hide and round-trip', () {
    const fitness = TabLayout(FitnessSection.values);
    final moved = fitness
        .withMoved(FitnessSection.values.indexOf(FitnessSection.progress), 0)
        .withVisible(FitnessSection.today, false);
    expect(moved.visible.first, FitnessSection.progress);
    expect(moved.visible, isNot(contains(FitnessSection.today)));
    expect(moved.order, hasLength(FitnessSection.values.length));

    final look = const Personalization().copyWith(fitness: moved);
    expect(Personalization.fromJson(look.toJson()), look);
  });

  test('old or odd saved layouts are repaired', () {
    final l = TabLayout.fromJson({
      'order': ['allData', 'nope', 'allData'],
      'hidden': ['more', 7],
    }, HealthSection.values);
    // Saved order kept; sections it didn't know take their usual place.
    expect(l.order.first, HealthSection.vitals);
    expect(l.order.last, HealthSection.allData);
    expect(l.order.toSet(), HealthSection.values.toSet());
    expect(l.hidden, {HealthSection.more});
    // Settings saved before tabs could be customised.
    expect(
      Personalization.fromJson(const {}).fitness,
      const TabLayout(FitnessSection.values),
    );
  });

  test('the Progress widget gets totals and 16 weeks of activity', () {
    final today = DateTime(2026, 10, 7); // a Wednesday
    final data = HomeWidgets.progressData([
      WorkoutSession(
        id: 'a',
        type: WorkoutType.run,
        start: DateTime(2026, 10, 6, 7),
        end: DateTime(2026, 10, 6, 8),
        activeSeconds: 3600,
      ),
      WorkoutSession(
        id: 'b',
        type: WorkoutType.run,
        start: DateTime(2026, 9, 28, 7),
        end: DateTime(2026, 9, 28, 7, 20),
        activeSeconds: 1200,
      ),
    ], today: today);
    final heat = data['progHeat']! as String;
    expect(heat, hasLength(HomeWidgets.heatWeeks * 7));
    // This week: Mon 0, Tue (60 min) 4, Wed today 0, then 4 days to come.
    expect(heat.substring(heat.length - 7), '040----');
    expect(heat.substring(heat.length - 14, heat.length - 13), '1');
    expect(data['progWorkouts'], 2);
    expect(data['progMonth'], 1);
    expect(data['progStreak'], 2);
    expect(HomeWidgets.isStatsLink(Uri.parse('health://stats')), isTrue);
  });
}
