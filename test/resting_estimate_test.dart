import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/daily_import.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_sync_service.dart';

import 'fake_health_source.dart';

HealthSample _hr(double bpm, DateTime at) =>
    HealthSample(type: MetricType.heartRate, value: bpm, start: at, end: at);

/// A day of heart rate: mostly calm readings in the 50s and 60s, with
/// some activity spikes.
List<HealthSample> _day(DateTime day, {double calm = 55}) => [
  for (var i = 0; i < 40; i++)
    _hr(calm + (i % 10), DateTime(day.year, day.month, day.day, 0, i * 30)),
  for (var i = 0; i < 10; i++)
    _hr(130 + i.toDouble(), DateTime(day.year, day.month, day.day, 18, i)),
];

void main() {
  group('resting heart rate from heart rate', () {
    test('takes the calm low end of the day', () {
      final entries = restingFromHeartRate(_day(DateTime(2026, 10, 10)));

      expect(entries, hasLength(1));
      final e = entries.single;
      expect(e.type, MetricType.restingHeartRate);
      expect(e.value, inInclusiveRange(55, 58));
      expect(e.isEstimate, isTrue);
    });

    test('needs enough readings in a day', () {
      final few = [
        for (var i = 0; i < 5; i++) _hr(60, DateTime(2026, 10, 10, 9, i)),
      ];

      expect(restingFromHeartRate(few), isEmpty);
    });
  });

  group('syncing heart rate only', () {
    final now = DateTime(2026, 10, 11, 15, 30);
    late HealthStore store;
    late FakeHealthSource source;
    late HealthSyncService sync;

    setUp(() async {
      final repo = InMemoryHealthRepository();
      store = HealthStore(repo, clock: () => now);
      await store.load();
      source = FakeHealthSource(
        grant: {MetricType.heartRate, MetricType.restingHeartRate},
      );
      sync = HealthSyncService(
        source: source,
        store: store,
        repo: repo,
        clock: () => now,
      );
      await sync.init();
    });

    test(
      'estimates resting heart rate when there are no records of it',
      () async {
        source.samples.addAll(_day(DateTime(2026, 10, 10)));

        await sync.connect();
        await sync.sync();

        final rhr = store.dailyValue(
          MetricType.restingHeartRate,
          DateTime(2026, 10, 10),
        );
        expect(rhr, inInclusiveRange(55, 58));
        expect(store.latestReading(MetricType.restingHeartRate)?.value, rhr);
      },
    );

    test('a real resting heart rate record wins over the estimate', () async {
      source.samples
        ..addAll(_day(DateTime(2026, 10, 10)))
        ..add(
          HealthSample(
            type: MetricType.restingHeartRate,
            value: 49,
            start: DateTime(2026, 10, 10, 7),
            end: DateTime(2026, 10, 10, 7),
          ),
        );

      await sync.connect();
      await sync.sync();

      expect(
        store.dailyValue(MetricType.restingHeartRate, DateTime(2026, 10, 10)),
        49,
      );
    });

    test('estimates go when heart rate is no longer shared', () async {
      source.samples.addAll(_day(DateTime(2026, 10, 10)));
      await sync.connect();
      await sync.sync();

      source.grant = {MetricType.restingHeartRate};
      await sync.changePermissions();
      await sync.sync(force: true);

      expect(
        store.dailyValue(MetricType.restingHeartRate, DateTime(2026, 10, 10)),
        isNull,
      );
    });
  });
}
