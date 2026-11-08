import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/plate_calculator.dart';
import 'package:health_app/workout/progression.dart';
import 'package:health_app/workout/workout_stats.dart';

List<SetLog> _sets(double kg, List<int> reps) => [
  for (final r in reps) SetLog(reps: r, weightKg: kg, done: true),
];

void main() {
  group('linear progression', () {
    const rule = ProgressionRule(kind: ProgressionKind.linear, increment: 2.5);

    test('adds weight after a fully completed session', () {
      final t = suggestNext(
        rule: rule,
        targetReps: 5,
        history: [
          _sets(100, [5, 5, 5]),
        ],
      );
      expect(t.weightKg, 102.5);
      expect(t.reps, 5);
      expect(t.explanation, contains('+2.5'));
    });

    test('repeats the weight after missed reps', () {
      final t = suggestNext(
        rule: rule,
        targetReps: 5,
        history: [
          _sets(100, [5, 5, 3]),
        ],
      );
      expect(t.weightKg, 100);
      expect(t.explanation, contains('Repeat'));
    });

    test('deloads 10% after stalling three sessions at one weight', () {
      final stuck = _sets(100, [5, 4, 3]);
      final t = suggestNext(
        rule: rule,
        targetReps: 5,
        history: [stuck, stuck, stuck],
      );
      expect(t.deload, isTrue);
      expect(t.weightKg, 90);
      expect(t.explanation, contains('Deload'));
    });

    test('warm-up sets never count', () {
      final history = [
        [
          const SetLog(reps: 5, weightKg: 40, done: true, type: SetType.warmup),
          ..._sets(100, [5, 5, 5]),
        ],
      ];
      expect(
        suggestNext(rule: rule, targetReps: 5, history: history).weightKg,
        102.5,
      );
    });
  });

  group('double progression', () {
    const rule = ProgressionRule(
      kind: ProgressionKind.double,
      increment: 2.5,
      repMin: 8,
      repMax: 12,
    );

    test('adds weight and drops to the bottom of the range at the top', () {
      final t = suggestNext(
        rule: rule,
        targetReps: 8,
        history: [
          _sets(40, [12, 12, 12]),
        ],
      );
      expect(t.weightKg, 42.5);
      expect(t.reps, 8);
    });

    test('otherwise aims for one more rep', () {
      final t = suggestNext(
        rule: rule,
        targetReps: 8,
        history: [
          _sets(40, [10, 9, 9]),
        ],
      );
      expect(t.weightKg, 40);
      // Bring every set up to one more than the weakest.
      expect(t.reps, 10);
      expect(t.explanation, contains('10'));
    });
  });

  test('no history keeps the routine target and says so', () {
    const rule = ProgressionRule(kind: ProgressionKind.linear, increment: 2.5);
    final t = suggestNext(
      rule: rule,
      targetReps: 8,
      history: const [],
      fallbackKg: 20,
    );
    expect(t.weightKg, 20);
    expect(t.explanation, contains('First'));
  });

  group('plate calculator', () {
    test('owned plates find an exact load heaviest-first would miss', () {
      // 30 a side from a pair of 20s and two pairs of 15s: 15 + 15.
      final load = platesFor(80, barKg: 20, owned: {20: 1, 15: 2});
      expect(load.exact, isTrue);
      expect(load.perSide, [15, 15]);
      // Not possible: the closest lighter load.
      final near = platesFor(100, barKg: 20, owned: {20: 1, 15: 1});
      expect(near.exact, isFalse);
      expect(near.achievedKg, 90);
    });

    test('loads plates per side, heaviest first', () {
      final r = platesFor(100, barKg: 20);
      expect(r.perSide, [25, 15]);
      expect(r.exact, isTrue);
    });

    test('uses only the plates you own', () {
      final r = platesFor(60, barKg: 20, owned: {20: 1, 10: 2, 5: 2});
      expect(r.perSide, [20]);
      final r2 = platesFor(100, barKg: 20, owned: {20: 1, 10: 1});
      expect(r2.exact, isFalse);
      expect(r2.achievedKg, 80);
    });

    test('below the bar weight loads nothing', () {
      expect(platesFor(15, barKg: 20).perSide, isEmpty);
    });
  });

  group('personal records while training', () {
    final best = (
      weightKg: 100.0,
      reps: 5,
      estimatedOneRepMax: epley(100, 5),
      date: DateTime(2026),
    );

    test('a heavier lift or a better estimated max is a PR', () {
      expect(
        isPersonalRecord(
          const SetLog(reps: 3, weightKg: 105, done: true),
          best,
        ),
        isTrue,
      );
      expect(
        isPersonalRecord(
          const SetLog(reps: 8, weightKg: 100, done: true),
          best,
        ),
        isTrue,
      );
      expect(
        isPersonalRecord(
          const SetLog(reps: 5, weightKg: 100, done: true),
          best,
        ),
        isFalse,
      );
    });

    test('warm-ups and the first ever set are not celebrated', () {
      expect(
        isPersonalRecord(
          const SetLog(
            reps: 5,
            weightKg: 200,
            done: true,
            type: SetType.warmup,
          ),
          best,
        ),
        isFalse,
      );
      expect(
        isPersonalRecord(const SetLog(reps: 5, weightKg: 50, done: true), null),
        isFalse,
      );
    });
  });

  test('new set fields round-trip and old JSON still loads', () {
    const s = SetLog(
      reps: 0,
      weightKg: 0,
      seconds: 45,
      type: SetType.drop,
      rpe: 8.5,
      done: true,
    );
    final back = SetLog.tryFromJson(s.toJson())!;
    expect(back.type, SetType.drop);
    expect(back.seconds, 45);
    expect(back.rpe, 8.5);
    expect(SetLog.tryFromJson({'r': 5, 'w': 60})?.type, SetType.normal);
    expect(s.toJson().containsKey('t'), isTrue);
    expect(
      const SetLog(reps: 5, weightKg: 60).toJson().containsKey('t'),
      isFalse,
    );
  });
}
