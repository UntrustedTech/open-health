import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:health_app/models/cycle.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/sync/health_connect_source.dart';

/// The plugin with Health Connect's answers made up.
class _FakeHealth extends Health {
  _FakeHealth(this.points);

  final List<HealthDataPoint> points;

  @override
  Future<void> configure() async {}

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async => [
    for (final p in points)
      if (types.contains(p.type)) p,
  ];
}

HealthDataPoint _point(HealthDataType type, HealthValue value, int hour) =>
    HealthDataPoint(
      uuid: '$type$hour',
      value: value,
      type: type,
      unit: HealthDataUnit.NO_UNIT,
      dateFrom: DateTime(2026, 11, 2, hour),
      dateTo: DateTime(2026, 11, 2, hour),
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'phone',
      sourceId: 'com.myfitnesspal.android',
      sourceName: 'MyFitnessPal',
    );

void main() {
  final from = DateTime(2026, 11, 2);
  final to = DateTime(2026, 11, 3);

  test('food from other apps gives calories and each macro', () async {
    final source = HealthConnectSource(
      health: _FakeHealth([
        _point(
          HealthDataType.NUTRITION,
          NutritionHealthValue(calories: 520, protein: 30, carbs: 60),
          8,
        ),
        _point(HealthDataType.NUTRITION, NutritionHealthValue(fat: 12), 12),
      ]),
    );

    final kcal = await source.read(MetricType.dietaryEnergy, from, to);
    final protein = await source.read(MetricType.protein, from, to);
    final fat = await source.read(MetricType.fat, from, to);

    expect(kcal.map((s) => s.value), [520]);
    expect(protein.map((s) => s.value), [30]);
    expect(fat.map((s) => s.start.hour), [12]);
  });

  test('vitals and body fat read as numbers', () async {
    final source = HealthConnectSource(
      health: _FakeHealth([
        _point(
          HealthDataType.RESPIRATORY_RATE,
          NumericHealthValue(numericValue: 15),
          3,
        ),
        _point(
          HealthDataType.BODY_FAT_PERCENTAGE,
          NumericHealthValue(numericValue: 0.22),
          7,
        ),
      ]),
    );

    final breaths = await source.read(MetricType.respiratoryRate, from, to);
    final fat = await source.read(MetricType.bodyFat, from, to);

    expect(breaths.single.value, 15);
    expect(fat.single.value, closeTo(22, 0.001));
  });

  test('floors, lean mass and skin temperature read as numbers', () async {
    final source = HealthConnectSource(
      health: _FakeHealth([
        _point(
          HealthDataType.FLIGHTS_CLIMBED,
          NumericHealthValue(numericValue: 4),
          9,
        ),
        _point(
          HealthDataType.LEAN_BODY_MASS,
          NumericHealthValue(numericValue: 58.2),
          7,
        ),
        _point(
          HealthDataType.SKIN_TEMPERATURE,
          NumericHealthValue(numericValue: -0.4),
          3,
        ),
      ]),
    );

    final floors = await source.read(MetricType.floorsClimbed, from, to);
    final lean = await source.read(MetricType.leanBodyMass, from, to);
    final skin = await source.read(MetricType.skinTemperature, from, to);

    expect(floors.single.value, 4);
    expect(lean.single.value, 58.2);
    expect(skin.single.value, -0.4); // a change, below the usual
  });

  test('time awake in bed counts as Awake', () async {
    DateTime at(int h) => DateTime(2026, 11, 2, h);
    final source = HealthConnectSource(
      health: _FakeHealth([
        HealthDataPoint(
          uuid: 'a',
          value: NumericHealthValue(numericValue: 20),
          type: HealthDataType.SLEEP_AWAKE_IN_BED,
          unit: HealthDataUnit.MINUTE,
          dateFrom: at(3),
          dateTo: at(3).add(const Duration(minutes: 20)),
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'watch',
          sourceId: 'com.watch',
          sourceName: 'Watch',
        ),
      ]),
    );

    final awake = await source.read(MetricType.sleepAwake, from, to);

    expect(awake.single.value, closeTo(20 / 60, 0.001));
  });

  test('menstruation flow becomes one period flow per day', () {
    MenstruationFlowHealthValue at(int day, int hour, MenstrualFlow flow) =>
        MenstruationFlowHealthValue(
          flow: flow,
          dateTime: DateTime(2026, 10, day, hour),
        );
    final days = HealthConnectSource.periodDays([
      at(1, 8, MenstrualFlow.light),
      at(1, 20, MenstrualFlow.heavy),
      at(2, 9, MenstrualFlow.unspecified),
      at(3, 9, MenstrualFlow.none),
      at(4, 9, MenstrualFlow.spotting),
    ]);
    expect(days, {
      DateTime(2026, 10, 1): PeriodFlow.heavy,
      DateTime(2026, 10, 2): PeriodFlow.medium,
      DateTime(2026, 10, 4): PeriodFlow.spotting,
    });
  });
}
