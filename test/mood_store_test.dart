import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/cycle.dart';
import 'package:health_app/models/mood.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/mood_store.dart';

void main() {
  test('a logged mood is there after the app restarts', () async {
    final repo = InMemoryHealthRepository();
    final now = DateTime(2026, 10, 15, 21, 30);
    final health = HealthStore(repo, clock: () => now);
    await health.load();
    final mood = MoodStore(health);
    await mood.load();
    await mood.log(
      health.today,
      const MoodEntry(mood: Mood.great, tags: {MoodTag.calm}, note: 'Nice'),
    );

    final again = MoodStore(HealthStore(repo, clock: () => now)..load());
    await again.load();
    expect(again.today?.mood, Mood.great);
    expect(again.today?.tags, {MoodTag.calm});
  });

  test('habits tick off, count streaks, and are kept', () async {
    final repo = InMemoryHealthRepository();
    final now = DateTime(2026, 10, 15, 21, 30);
    final health = HealthStore(repo, clock: () => now);
    await health.load();
    final mood = MoodStore(health);
    await mood.load();
    expect(await mood.addHabit(' Stretch '), isTrue);
    expect(await mood.addHabit('Stretch'), isFalse);
    expect(await mood.addHabit(''), isFalse);
    await mood.addHabit('Read');

    // Done the last two days; today not yet, which doesn't break it.
    await mood.toggleHabit('Stretch', DateTime(2026, 10, 13));
    await mood.toggleHabit('Stretch', DateTime(2026, 10, 14));
    expect(mood.streak('Stretch'), 2);
    await mood.toggleHabit('Stretch', health.today);
    expect(mood.streak('Stretch'), 3);
    await mood.toggleHabit('Stretch', health.today);
    expect(mood.didHabit('Stretch', health.today), isFalse);
    await mood.toggleHabit('Read', health.today);

    final again = MoodStore(HealthStore(repo, clock: () => now)..load());
    await again.load();
    expect(again.habits, ['Stretch', 'Read']);
    expect(again.streak('Stretch'), 2);
    expect(again.didHabit('Read', now), isTrue);

    // A rename keeps the history; a clash with another habit is refused.
    expect(await again.renameHabit('Stretch', 'Read'), isFalse);
    expect(await again.renameHabit('Stretch', 'Yoga'), isTrue);
    expect(again.habits, ['Yoga', 'Read']);
    expect(again.streak('Yoga'), 2);

    await again.removeHabit('Read');
    expect(again.habits, ['Yoga']);
    expect(again.didHabit('Read', now), isFalse);
  });

  test('cycle days are there after the app restarts', () async {
    final repo = InMemoryHealthRepository();
    final now = DateTime(2026, 10, 15, 21, 30);
    final health = HealthStore(repo, clock: () => now);
    await health.load();
    final cycle = CycleStore(health);
    await cycle.load();
    await cycle.setEnabled(true);
    await cycle.startPeriod(DateTime(2026, 10, 2));
    final again = CycleStore(health);
    await again.load();
    expect(again.days.keys, [DateTime(2026, 10, 2)]);
  });

  test('imported period days never replace logged ones', () async {
    final health = HealthStore(
      InMemoryHealthRepository(),
      clock: () => DateTime(2026, 10, 15),
    );
    await health.load();
    final cycle = CycleStore(health);
    await cycle.load();
    await cycle.startPeriod(DateTime(2026, 10, 2), flow: PeriodFlow.light);
    await cycle.log(
      DateTime(2026, 10, 3),
      const CycleDay(symptoms: {Symptom.cramps}),
    );

    final added = await cycle.importDays({
      DateTime(2026, 10, 2): PeriodFlow.heavy,
      DateTime(2026, 10, 3, 8): PeriodFlow.medium,
      DateTime(2026, 10, 4): PeriodFlow.spotting,
    });

    expect(added, 2);
    expect(cycle.dayOf(DateTime(2026, 10, 2)).flow, PeriodFlow.light);
    expect(cycle.dayOf(DateTime(2026, 10, 3)).flow, PeriodFlow.medium);
    expect(cycle.dayOf(DateTime(2026, 10, 3)).symptoms, {Symptom.cramps});
    expect(cycle.dayOf(DateTime(2026, 10, 4)).flow, PeriodFlow.spotting);
    expect(
      await cycle.importDays({DateTime(2026, 10, 4): PeriodFlow.heavy}),
      0,
    );
  });

  test('day keys round-trip and reject bad dates', () {
    expect(dayKey(DateTime(2026, 3, 7)), '20260307');
    expect(parseDayKey('20260307'), DateTime(2026, 3, 7));
    expect(parseDayKey('20261332'), isNull);
    expect(parseDayKey('2026-03-07'), isNull);
  });

  test('habit looks, order and best streak are kept', () async {
    final repo = InMemoryHealthRepository();
    final now = DateTime(2026, 10, 15, 21, 30);
    final health = HealthStore(repo, clock: () => now);
    await health.load();
    final mood = MoodStore(health);
    await mood.load();
    await mood.addHabit('Stretch');
    await mood.addHabit('Read');
    // A 3-day run, a gap, then 1 day: best 3, current 1.
    for (final d in [1, 2, 3, 5]) {
      await mood.toggleHabit('Stretch', DateTime(2026, 10, 10 + d));
    }
    expect(mood.bestStreak('Stretch'), 3);
    expect(mood.bestStreak('Read'), 0);

    await mood.setLook('Stretch', icon: 'gym', color: 'red');
    await mood.moveHabit('Read', -1);
    await mood.moveHabit('Read', -1); // Already first: ignored.
    expect(mood.habits, ['Read', 'Stretch']);

    final again = MoodStore(HealthStore(repo, clock: () => now)..load());
    await again.load();
    expect(again.habits, ['Read', 'Stretch']);
    expect(again.look('Stretch'), (icon: 'gym', color: 'red'));
    expect(again.bestStreak('Stretch'), 3);

    // A rename carries the look; removing drops it.
    await again.renameHabit('Stretch', 'Yoga');
    expect(again.look('Yoga').icon, 'gym');
    await again.removeHabit('Yoga');
    await again.addHabit('Yoga');
    expect(again.look('Yoga'), (icon: null, color: null));
  });
}
