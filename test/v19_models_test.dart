import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/export/backup.dart';
import 'package:health_app/export/health_report.dart';
import 'package:health_app/insights/health_snapshot.dart';
import 'package:health_app/insights/monthly_recap.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/meal_template.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/models/fasting.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/mood.dart';
import 'package:health_app/models/sleep_schedule.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/platform/home_widgets.dart';
import 'package:health_app/models/workout_program.dart';
import 'package:health_app/workout/intervals.dart';

WorkoutSession _w(
  String id,
  DateTime start, {
  WorkoutType type = WorkoutType.run,
  String? program,
  String? routine,
  int minutes = 30,
}) => WorkoutSession(
  id: id,
  type: type,
  start: start,
  end: start.add(Duration(minutes: minutes)),
  activeSeconds: minutes * 60,
  distanceMeters: 3000,
  activeKcal: 200,
  intervalProgram: program,
  routineId: routine,
);

void main() {
  group('Mood', () {
    test('round-trips and drops unknown tags and bad moods', () {
      const e = MoodEntry(
        mood: Mood.good,
        tags: {MoodTag.calm, MoodTag.tired},
        note: 'Long walk',
      );
      final back = MoodEntry.fromJson(e.toJson())!;
      expect(back.mood, Mood.good);
      expect(back.tags, {MoodTag.calm, MoodTag.tired});
      expect(back.note, 'Long walk');
      expect(MoodEntry.fromJson({'m': 9}), isNull);
      expect(
        MoodEntry.fromJson({
          'm': 3,
          't': ['calm', 'nope'],
        })!.tags,
        {MoodTag.calm},
      );
    });

    test('patterns need a few days each way and a real difference', () {
      final days = {
        for (var i = 0; i < 6; i++)
          DateTime(2026, 10, i + 1): MoodEntry(
            mood: i.isEven ? Mood.great : Mood.low,
          ),
      };
      final p = MoodInsights.compare(
        'workout',
        days,
        (d) => d.day.isOdd, // the great days
      )!;
      expect(p.withIt, 5);
      expect(p.without, 2);
      expect(
        MoodInsights.compare('x', {
          DateTime(2026): days.values.first,
        }, (_) => true),
        isNull,
      );
    });
  });

  group('Fasting', () {
    test('stages follow hours fasted', () {
      expect(FastingStage.at(const Duration(hours: 2)), FastingStage.fed);
      expect(FastingStage.at(const Duration(hours: 13)), FastingStage.burning);
      expect(FastingStage.at(const Duration(hours: 30)), FastingStage.deep);
      // The clock set back during a fast.
      expect(FastingStage.at(const Duration(hours: -2)), FastingStage.fed);
    });

    test('streak counts goal-reaching fasts on consecutive days', () {
      FastRecord f(int day, int hours) => FastRecord(
        start: DateTime(2026, 10, day - 1, 20),
        end: DateTime(2026, 10, day - 1, 20).add(Duration(hours: hours)),
        goal: const Duration(hours: 16),
      );
      final history = [f(13, 16), f(14, 17), f(15, 16)];
      expect(fastingStreak(history, DateTime(2026, 10, 15)), 3);
      // A short fast breaks it.
      expect(
        fastingStreak([
          f(13, 16),
          f(14, 10),
          f(15, 16),
        ], DateTime(2026, 10, 15)),
        1,
      );
      expect(FastRecord.fromJson(history.first.toJson())!.goal.inHours, 16);
    });
  });

  group('Sleep schedule', () {
    test('time in bed crosses midnight and wind-down goes before bed', () {
      const s = SleepSchedule(
        bedtime: (hour: 23, minute: 0),
        wake: (hour: 7, minute: 0),
        windDown: Duration(minutes: 45),
      );
      expect(s.goalHours, 8);
      expect(s.windDownAt, (hour: 22, minute: 15));
      final back = SleepSchedule.fromJson(s.toJson());
      expect(back.bedtime, s.bedtime);
      expect(back.windDown, s.windDown);
    });

    test('consistency counts on-target nights and the streak', () {
      final today = DateTime(2026, 10, 15);
      final hours = [7.8, 8.1, 6.0, 8.0, 7.6, 7.9, 8.2];
      final c = sleepConsistency(
        sleepOn: (d) => hours[today.difference(d).inDays % hours.length],
        today: today,
        goalHours: 8,
      );
      // 7.5h or more counts.
      expect(c.onTarget, 6);
      expect(c.nights, 7);
      expect(c.streak, 2);
    });
  });

  group('Programs', () {
    test('sessions are matched in order to later workouts', () {
      final start = DateTime(2026, 10, 1);
      final p = WorkoutProgram.couchTo5k;
      final progress = ProgramProgress.of(p, start, [
        _w('old', DateTime(2026, 9, 30), program: 'C25K Week 1'),
        _w('a', DateTime(2026, 10, 2), program: 'C25K Week 1'),
        _w('x', DateTime(2026, 10, 3)), // a plain run doesn't count
        _w('b', DateTime(2026, 10, 4), program: 'C25K Week 1'),
        _w('c', DateTime(2026, 10, 6), program: 'C25K Week 1'),
        _w('d', DateTime(2026, 10, 8), program: 'C25K Week 2'),
      ]);
      expect(progress.completed, 4);
      expect(progress.week, 1);
      expect(progress.doneThisWeek, 1);
      expect(progress.next!.title, 'C25K Week 2');
    });

    test('strength sessions match by routine', () {
      final progress = ProgramProgress.of(
        WorkoutProgram.beginnerStrength,
        DateTime(2026, 10, 1),
        [
          _w(
            'a',
            DateTime(2026, 10, 2),
            type: WorkoutType.strength,
            routine: 'preset_full',
          ),
        ],
      );
      expect(progress.completed, 1);
      expect(WorkoutProgram.beginnerStrength.sessionCount, 18);
    });

    test('Couch to 5K labels run and walk and restores by name', () {
      final week1 = IntervalProgram.byName('C25K Week 1')!;
      expect(week1.phases[1].label, 'Run');
      expect(week1.phases[2].label, 'Walk');
      // 5 + 8 × 1 + 7 × 1.5 (no walk after the last run) + 5.
      expect(week1.total, const Duration(minutes: 28, seconds: 30));
    });
  });

  group('Monthly recap', () {
    test('adds up the month and finds the best day', () {
      final today = DateTime(2026, 10, 15);
      double? value(MetricType t, DateTime d) => switch (t) {
        MetricType.steps => d.day == 10 ? 15000 : 5000,
        MetricType.weight when d.day == 1 => 80,
        MetricType.weight when d.day == 15 => 78.5,
        MetricType.sleep => 7,
        _ => null,
      };
      final r = MonthlyRecap.build(
        month: today,
        today: today,
        dailyValue: value,
        goalFor: (_) => null,
        sessions: [
          _w('a', DateTime(2026, 10, 3)),
          _w('b', DateTime(2026, 10, 5)),
          _w('c', DateTime(2026, 9, 30)),
        ],
      );
      expect(r.days, 15);
      expect(r.steps, 14 * 5000 + 15000);
      expect(r.bestStepDay, DateTime(2026, 10, 10));
      expect(r.workouts, 2);
      expect(r.weightChangeKg, closeTo(-1.5, 0.001));
      expect(r.averageSleep, 7);
      expect(r.topWorkout, WorkoutType.run);
      expect(r.activeDays, 2);
    });
  });

  group('Recipes and meals', () {
    const rice = Food(
      id: 'rice',
      name: 'Rice',
      perServing: Nutrients(kcal: 130, carbs: 28),
      servingLabel: '100 g',
      servingGrams: 100,
    );
    const oil = Food(
      id: 'oil',
      name: 'Olive Oil',
      perServing: Nutrients(kcal: 120, fat: 14),
      servingLabel: '1 tbsp (14 g)',
      servingGrams: 14,
    );

    test('a recipe divides its total into servings', () {
      const r = Recipe(
        id: 'r1',
        name: 'Rice Bowl',
        servings: 2,
        ingredients: [
          FoodPortion(food: rice, amount: 300, inGrams: true),
          FoodPortion(food: oil, amount: 1),
        ],
      );
      // (3 × 130 + 120) / 2 = 255 kcal; (300 + 14) / 2 = 157 g.
      expect(r.perServing.kcal, closeTo(255, 0.01));
      expect(r.servingGrams, closeTo(157, 0.01));
      final food = r.toFood();
      expect(food.id, 'r1');
      expect(food.nutrientsFor(1).kcal, closeTo(255, 0.01));
      final back = Recipe.fromJson(r.toJson())!;
      expect(back.ingredients, hasLength(2));
      expect(back.servings, 2);
    });

    test('bad templates and recipes are dropped', () {
      expect(
        MealTemplate.fromJson({'id': 'x', 'name': 'A', 'items': []}),
        isNull,
      );
      expect(
        Recipe.fromJson({'id': 'x', 'name': 'A', 'servings': 0, 'items': []}),
        isNull,
      );
    });
  });

  group('Health report', () {
    test('rows summarise a period and the PDF is made', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final from = DateTime(2026, 10, 1), to = DateTime(2026, 10, 10);
      double? value(MetricType t, DateTime d) => switch (t) {
        MetricType.bloodPressureSystolic => 110.0 + d.day,
        MetricType.restingHeartRate when d.day.isEven => 60,
        _ => null,
      };
      final sys = HealthReport.rowFor(
        MetricType.bloodPressureSystolic,
        from,
        to,
        value,
      )!;
      expect(sys.days, 10);
      expect(sys.low, '111 mmHg');
      expect(sys.high, '120 mmHg');
      expect(HealthReport.rowFor(MetricType.hrv, from, to, value), isNull);
      final pdf = await HealthReport(
        from: from,
        to: to,
        created: to,
        patient: const [('Name', 'Alex')],
        vitals: [sys],
        activity: const [],
        medications: const [('Vitamin D', '1000 IU', 'Daily at 8:00 AM')],
        adherence: 0.9,
        moodAverage: 3.6,
      ).toPdf();
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    });

    test('every design makes a PDF', () async {
      final from = DateTime(2026, 1, 1);
      final report = HealthReport(
        from: from,
        to: from,
        created: from,
        patient: const [('Name', 'Alex')],
        vitals: const [
          ReportRow(
            label: 'Resting HR',
            average: '60 bpm',
            low: '55 bpm',
            high: '66 bpm',
            days: 3,
          ),
        ],
        activity: const [],
        medications: const [],
      );
      for (final d in ReportDesign.values) {
        final pdf = await report.toPdf(design: d);
        expect(String.fromCharCodes(pdf.take(4)), '%PDF', reason: d.name);
      }
    });
  });

  group('Blood pressure and glucose', () {
    test('categories follow the usual thresholds', () {
      expect(HealthSnapshot.bloodPressureStanding(115, 75), Standing.good);
      expect(HealthSnapshot.bloodPressureStanding(125, 78), Standing.fair);
      expect(HealthSnapshot.bloodPressureStanding(145, 92), Standing.attention);
      expect(HealthSnapshot.glucoseStanding(95), Standing.good);
      expect(HealthSnapshot.glucoseStanding(160), Standing.fair);
      expect(HealthSnapshot.glucoseStanding(45), Standing.attention);
    });

    test('glucose is shown in mmol/L for metric and mg/dL for imperial', () {
      Units.system = UnitSystem.metric;
      expect(formatValue(MetricType.bloodGlucose, 90.08), '5.0');
      expect(Units.unitFor(MetricType.bloodGlucose), 'mmol/L');
      Units.system = UnitSystem.imperial;
      expect(formatValue(MetricType.bloodGlucose, 90), '90');
      Units.system = UnitSystem.metric;
    });

    test('the fasting widget opens the fasting timer', () {
      expect(HomeWidgets.isFastingLink(Uri.parse('health://fasting')), isTrue);
      expect(HomeWidgets.isFastingLink(Uri.parse('health://stats')), isFalse);
    });

    test('new documents are part of backups', () {
      expect(
        Backup.documentKeys,
        containsAll(['mood', 'fasting', 'sleepSchedule', 'program']),
      );
    });
  });
}
