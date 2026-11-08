import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/insights/achievements.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';

final _now = DateTime(2026, 10, 12, 12);

void main() {
  late InMemoryHealthRepository repo;
  late HealthStore health;
  late WorkoutStore workouts;

  setUp(() async {
    repo = InMemoryHealthRepository();
    health = HealthStore(repo, clock: () => _now);
    await health.load();
    await health.completeOnboarding(name: 'Sam', withSampleData: false);
    workouts = WorkoutStore(repo, health, clock: () => _now);
    await workouts.load();
  });

  test('badges from before tiers become the matching tier', () async {
    await repo.saveDocument(AchievementStore.docKey, {
      'earned': {
        'steps10k': '2026-01-02T00:00:00.000',
        'run10k': '2026-03-04T00:00:00.000',
        'unknownOld': '2026-01-01T00:00:00.000',
      },
      'seen': ['steps10k'],
    });
    final store = AchievementStore(health, workouts);
    await store.load();
    expect(store.tierEarnedOn('steps', Tier.bronze), DateTime(2026, 1, 2));
    expect(store.tierEarnedOn('longestRun', Tier.silver), DateTime(2026, 3, 4));
  });

  test('a goal set before any weigh-in starts from the first one', () async {
    await health.setBodyGoal(
      BodyGoal(objective: GoalObjective.lose, startDate: DateTime(2026, 10, 1)),
    );
    expect(health.goalStartKg, isNull);
    await health.addEntry(MetricType.weight, 82);
    expect(health.goalStartKg, 82);
  });

  test('new tiers are recorded once, each with its date', () async {
    await health.addEntry(MetricType.steps, 16000);
    final store = AchievementStore(health, workouts);
    await store.load();

    final steps = store.all.firstWhere((a) => a.id == 'steps');
    expect(steps.tier, Tier.silver);
    final fresh = await store.recordNew();
    expect(fresh.map((a) => a.id), contains('steps'));
    expect(store.tierEarnedOn('steps', Tier.bronze), _now);
    expect(store.tierEarnedOn('steps', Tier.silver), _now);
    expect(await store.recordNew(), isEmpty);
    expect(store.unseen.map((a) => a.id), contains('steps'));

    await store.markAllSeen();
    expect(store.unseen, isEmpty);
    expect(store.medals, greaterThanOrEqualTo(2));
    expect(store.totalMedals, store.all.length * 5);
  });
}
