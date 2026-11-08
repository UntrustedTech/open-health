import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';

void main() {
  final now = DateTime(2026, 10, 11, 15, 30);
  late InMemoryHealthRepository repo;
  late HealthStore store;

  setUp(() async {
    repo = InMemoryHealthRepository();
    store = HealthStore(repo, clock: () => now);
    await store.load();
  });

  Future<HealthStore> reload() async {
    final reloaded = HealthStore(repo, clock: () => now);
    await reloaded.load();
    return reloaded;
  }

  group('health widgets', () {
    test('start with none pinned, so the Health tab stays short', () {
      expect(store.widgets, isEmpty);
      expect(store.pinned, isEmpty);
    });

    test('a widget can be added, resized and removed', () async {
      await store.addWidget(MetricType.water);
      expect(
        store.widgets.last,
        const HealthWidget(MetricType.water, WidgetSize.small),
      );

      await store.setWidgetSize(MetricType.water, WidgetSize.medium);
      expect(store.widgets.last.size, WidgetSize.medium);

      await store.removeWidget(MetricType.water);
      expect(
        store.widgets.map((w) => w.metric),
        isNot(contains(MetricType.water)),
      );
    });

    test('adding a widget twice keeps one', () async {
      await store.addWidget(MetricType.water);
      await store.addWidget(MetricType.water);

      expect(
        store.widgets.where((w) => w.metric == MetricType.water),
        hasLength(1),
      );
    });

    test('a removed widget comes back small', () async {
      await store.addWidget(MetricType.water);
      await store.setWidgetSize(MetricType.water, WidgetSize.medium);
      await store.removeWidget(MetricType.water);

      await store.addWidget(MetricType.water);

      expect(store.widgets.last.size, WidgetSize.small);
    });

    test('order and sizes survive a reload', () async {
      await store.addWidget(MetricType.water);
      await store.setWidgetSize(MetricType.water, WidgetSize.medium);
      await store.moveWidget(store.widgets.length - 1, 0);

      final reloaded = await reload();

      expect(reloaded.widgets, store.widgets);
      expect(
        reloaded.widgets.first,
        const HealthWidget(MetricType.water, WidgetSize.medium),
      );
    });

    test('pins saved before widgets had sizes load as small widgets', () async {
      await repo.saveDocument('settings', {
        'onboarded': true,
        'pinned': ['sleep', 'weight'],
      });

      final reloaded = await reload();

      expect(reloaded.widgets, const [
        HealthWidget(MetricType.sleep, WidgetSize.small),
        HealthWidget(MetricType.weight, WidgetSize.small),
      ]);
    });
  });

  group('widget layout', () {
    List<WidgetSlot> layout(List<WidgetSize> sizes) => WidgetSlot.layout([
      for (final (i, s) in sizes.indexed) HealthWidget(MetricType.values[i], s),
    ]);

    test('small widgets pair up two to a row', () {
      final slots = layout([
        WidgetSize.small,
        WidgetSize.small,
        WidgetSize.small,
      ]);

      expect(
        [for (final s in slots) (s.row, s.column)],
        [(0, 0), (0, 1), (1, 0)],
      );
    });

    test('a wide widget takes its own row', () {
      final slots = layout([
        WidgetSize.medium,
        WidgetSize.small,
        WidgetSize.small,
      ]);

      expect(
        [for (final s in slots) (s.row, s.column)],
        [(0, 0), (1, 0), (1, 1)],
      );
    });

    test('a wide widget after a lone small one starts a new row', () {
      final slots = layout([
        WidgetSize.small,
        WidgetSize.medium,
        WidgetSize.small,
      ]);

      expect(
        [for (final s in slots) (s.row, s.column)],
        [(0, 0), (1, 0), (2, 0)],
      );
      expect(WidgetSlot.rows(slots), 3);
    });
  });
}
