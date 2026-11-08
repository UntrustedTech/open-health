import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/calories.dart';
import 'package:health_app/workout/geo.dart';
import 'package:health_app/workout/intervals.dart';
import 'package:health_app/workout/workout_stats.dart';

GeoPoint _p(double lat, double lng, int sec, {double accuracy = 5}) => GeoPoint(
  lat: lat,
  lng: lng,
  time: DateTime(2026, 10, 11, 8).add(Duration(seconds: sec)),
  accuracy: accuracy,
);

WorkoutSession _session({
  required String id,
  WorkoutType type = WorkoutType.run,
  required DateTime start,
  int seconds = 1800,
  double meters = 5000,
  List<int> splits = const [],
  List<ExerciseLog> exercises = const [],
}) => WorkoutSession(
  id: id,
  type: type,
  start: start,
  end: start.add(Duration(seconds: seconds)),
  activeSeconds: seconds,
  distanceMeters: meters,
  activeKcal: 300,
  splits: splits,
  exercises: exercises,
);

void main() {
  group('geo', () {
    test('haversine distance matches a known value', () {
      // One thousandth of a degree of latitude is about 111 m.
      final d = haversineMeters(_p(51.5, -0.1, 0), _p(51.501, -0.1, 10));
      expect(d, closeTo(111.2, 0.5));
    });

    test('filter drops inaccurate fixes and impossible jumps', () {
      final filter = RouteFilter(maxSpeedMps: 12);
      expect(filter.accept(_p(51.5, -0.1, 0)), isTrue);
      expect(filter.accept(_p(51.5001, -0.1, 3, accuracy: 80)), isFalse);
      // 1.1 km in 5 s is far too fast for a run.
      expect(filter.accept(_p(51.51, -0.1, 5)), isFalse);
      expect(filter.accept(_p(51.5001, -0.1, 6)), isTrue);
    });

    test('standing still adds no distance, walking slowly still does', () {
      final filter = RouteFilter(maxSpeedMps: 12);
      expect(filter.accept(_p(51.5, -0.1, 0, accuracy: 10)), isTrue);
      // Drifting about 2 m each second, within the 10 m accuracy.
      for (var i = 1; i <= 5; i++) {
        final lat = 51.5 + (i.isEven ? 0.00002 : -0.00002);
        expect(filter.accept(_p(lat, -0.1, i, accuracy: 10)), isFalse);
      }
      // 11 m on from where we stood.
      expect(filter.accept(_p(51.5001, -0.1, 8, accuracy: 10)), isTrue);
    });

    test('downsample keeps points at least 5 m apart plus the last one', () {
      final points = [
        for (var i = 0; i <= 20; i++) _p(51.5 + i * 0.00001, -0.1, i),
      ];
      final out = downsample(points, minMeters: 5);
      expect(out.length, lessThan(points.length));
      expect(out.first, points.first);
      expect(out.last, points.last);
    });
  });

  test('active calories exclude resting energy (MET - 1)', () {
    // Running (MET 9.8) for 30 minutes at 70 kg.
    expect(
      activeCalories(
        met: 9.8,
        weightKg: 70,
        duration: const Duration(minutes: 30),
      ),
      closeTo(308, 0.5),
    );
    expect(
      activeCalories(
        met: 0.5,
        weightKg: 70,
        duration: const Duration(hours: 1),
      ),
      0,
    );
  });

  group('intervals', () {
    const tabata = IntervalProgram(
      name: 'Tabata',
      work: Duration(seconds: 20),
      rest: Duration(seconds: 10),
      rounds: 8,
      warmup: Duration(seconds: 60),
    );

    test('lays out warm-up, work and rest phases', () {
      expect(tabata.phases.length, 1 + 8 * 2 - 1);
      expect(tabata.total, const Duration(seconds: 60 + 8 * 20 + 7 * 10));
    });

    test('finds the phase and time left at any moment', () {
      final at = tabata.phaseAt(const Duration(seconds: 65));
      expect(at?.phase.kind, PhaseKind.work);
      expect(at?.phase.round, 1);
      expect(at?.remaining, const Duration(seconds: 15));
      expect(tabata.phaseAt(const Duration(hours: 1)), isNull);
    });
  });

  group('workout model', () {
    test('round-trips through JSON and rejects bad rows', () {
      final s =
          _session(
            id: 'w1',
            start: DateTime(2026, 10, 11, 7),
            splits: const [300, 310],
            exercises: const [
              ExerciseLog(
                exerciseId: 'bench_press',
                sets: [SetLog(reps: 8, weightKg: 60, done: true)],
              ),
            ],
          ).copyWith(
            notes: 'Felt great',
            rpe: 7,
            laps: const [Lap(seconds: 600, meters: 2000)],
          );

      final back = WorkoutSession.tryFromJson(s.toJson());

      expect(back?.notes, 'Felt great');
      expect(back?.rpe, 7);
      expect(back?.splits, [300, 310]);
      expect(back?.laps.single.meters, 2000);
      expect(back?.exercises.single.sets.single.weightKg, 60);
      expect(WorkoutSession.tryFromJson({'id': 1}), isNull);
    });

    test('pace is seconds per km', () {
      final s = _session(
        id: 'w',
        start: DateTime(2026),
        seconds: 1500,
        meters: 5000,
      );
      expect(s.paceSecondsPerKm, 300);
    });
  });

  group('stats and records', () {
    final today = DateTime(2026, 10, 11); // a Sunday

    test('weekly summary counts Monday to Sunday', () {
      final list = [
        _session(id: 'a', start: DateTime(2026, 10, 5, 7)), // Monday
        _session(id: 'b', start: DateTime(2026, 10, 11, 7), seconds: 600),
        _session(id: 'c', start: DateTime(2026, 10, 4, 7)), // last week
      ];
      final week = weekSummary(list, today);
      expect(week.count, 2);
      expect(week.minutes, 40);
      expect(week.kilometres, 10);
    });

    test('day streak counts consecutive days ending today or yesterday', () {
      final list = [
        _session(id: 'a', start: DateTime(2026, 10, 10, 7)),
        _session(id: 'b', start: DateTime(2026, 10, 9, 7)),
        _session(id: 'c', start: DateTime(2026, 10, 7, 7)),
      ];
      expect(dayStreak(list, today), 2);
      expect(dayStreak(list, DateTime(2026, 10, 13)), 0);
    });

    test('records find the fastest km, fastest 5K and heaviest lift', () {
      final list = [
        _session(
          id: 'a',
          start: DateTime(2026, 10, 1),
          meters: 6000,
          splits: const [320, 300, 310, 305, 315, 330],
        ),
        _session(
          id: 'b',
          start: DateTime(2026, 10, 2),
          type: WorkoutType.strength,
          meters: 0,
          exercises: const [
            ExerciseLog(
              exerciseId: 'squat',
              sets: [
                SetLog(reps: 5, weightKg: 100, done: true),
                SetLog(reps: 1, weightKg: 120, done: false),
              ],
            ),
          ],
        ),
      ];

      final r = personalRecords(list);

      expect(r.fastestKmSeconds, 300);
      expect(r.fastest5kSeconds, 300 + 310 + 305 + 315 + 320);
      expect(r.longestRunMeters, 6000);
      // Only completed sets count; estimated 1RM by the Epley formula.
      expect(r.bestLifts[ExerciseCatalog.canonical('squat')]?.weightKg, 100);
      expect(
        r.bestLifts[ExerciseCatalog.canonical('squat')]?.estimatedOneRepMax,
        closeTo(116.7, 0.1),
      );
    });
  });

  test('old and new ids for one exercise share a record', () {
    final list = [
      _session(
        id: 'old',
        type: WorkoutType.strength,
        start: DateTime(2026, 9, 1),
        meters: 0,
        exercises: const [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [SetLog(reps: 5, weightKg: 80, done: true)],
          ),
        ],
      ),
      _session(
        id: 'new',
        type: WorkoutType.strength,
        start: DateTime(2026, 10, 1),
        meters: 0,
        exercises: const [
          ExerciseLog(
            exerciseId: '0025',
            sets: [SetLog(reps: 5, weightKg: 85, done: true)],
          ),
        ],
      ),
    ];

    final lifts = personalRecords(list).bestLifts;

    expect(lifts.keys, ['0025']);
    expect(lifts['0025']?.weightKg, 85);
  });
}
