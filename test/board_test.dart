import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/board.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/tab_layout.dart';
import 'package:health_app/state/health_store.dart';

void main() {
  const a = BoardItem('a', WidgetSize.small);
  const b = BoardItem('b', WidgetSize.medium);
  const c = BoardItem('c', WidgetSize.small);

  group('Board', () {
    const board = Board([a, b, c]);

    test('adds an item once, at the end', () {
      final added = board.withAdded('d', WidgetSize.small);
      expect(added.items.last, const BoardItem('d', WidgetSize.small));
      expect(added.withAdded('d', WidgetSize.medium).items, added.items);
    });

    test('removes, resizes and moves items', () {
      expect(board.withRemoved('b').ids, ['a', 'c']);
      expect(
        board.withSize('a', WidgetSize.medium).items.first.size,
        WidgetSize.medium,
      );
      expect(board.withMoved(2, 0).ids, ['c', 'a', 'b']);
    });

    test('ignores moves and edits for items it does not have', () {
      expect(board.withMoved(5, 0), board);
      expect(board.withSize('zz', WidgetSize.medium), board);
      expect(board.withRemoved('zz'), board);
    });

    test('reads back what it writes, dropping unknown and repeated ids', () {
      expect(Board.fromJson(board.toJson(), known: {'a', 'b', 'c'}), board);
      final read = Board.fromJson(
        [
          {'id': 'a', 'size': 'medium'},
          {'id': 'gone'},
          {'id': 'a'},
          'junk',
        ],
        known: {'a'},
      );
      expect(read.items, const [BoardItem('a', WidgetSize.medium)]);
    });
  });

  group('three sizes', () {
    test('small, medium and large, with names to show', () {
      expect(WidgetSize.values, [
        WidgetSize.small,
        WidgetSize.medium,
        WidgetSize.large,
      ]);
      expect(
        [for (final s in WidgetSize.values) s.label],
        ['Small', 'Medium', 'Large'],
      );
      expect(WidgetSize.small.fullWidth, isFalse);
      expect(WidgetSize.medium.fullWidth, isTrue);
      expect(WidgetSize.large.fullWidth, isTrue);
    });

    test('resizing steps through the sizes a widget comes in', () {
      const all = {WidgetSize.small, WidgetSize.medium, WidgetSize.large};
      expect(WidgetSize.small.nextIn(all), WidgetSize.medium);
      expect(WidgetSize.medium.nextIn(all), WidgetSize.large);
      expect(WidgetSize.large.nextIn(all), WidgetSize.small);
      const two = {WidgetSize.small, WidgetSize.large};
      expect(WidgetSize.small.nextIn(two), WidgetSize.large);
      expect(WidgetSize.large.nextIn(two), WidgetSize.small);
    });

    test('a saved "wide" widget reads as large, the size it looked like', () {
      final json = [
        {'id': 'a', 'size': 'wide'},
      ];
      expect(
        Board.fromJson(json, known: {'a'}).items.single.size,
        WidgetSize.large,
      );
    });
  });

  group('tab boards', () {
    final now = DateTime(2026, 10, 11, 15, 30);
    late InMemoryHealthRepository repo;
    late HealthStore store;

    setUp(() async {
      repo = InMemoryHealthRepository();
      store = HealthStore(repo, clock: () => now);
      await store.load();
    });

    Future<HealthStore> reload() async {
      final s = HealthStore(repo, clock: () => now);
      await s.load();
      return s;
    }

    test('Health starts with vitals, categories and the tracker list', () {
      final ids = store.board(BoardTab.health).ids;
      expect(ids.first, 'health.vitals');
      expect(ids, contains('category.sleep'));
      expect(ids, contains('tracker.readiness'));
      // Trackers are rows of one list, not a tile each.
      expect(ids, contains(BoardIds.healthMore));
      expect(ids, isNot(contains('tracker.mood')));
    });

    test('Fitness starts short and Food with every section', () {
      expect(store.board(BoardTab.fitness).ids, [
        'fitness.week',
        'fitness.suggestion',
        'fitness.start',
        BoardIds.fitnessMore,
      ]);
      expect(store.board(BoardTab.food).ids, [
        'food.calories',
        'food.macros',
        'food.meal.breakfast',
        'food.meal.lunch',
        'food.meal.dinner',
        'food.meal.snack',
        'food.micros',
      ]);
    });

    test('boards survive a reload', () async {
      await store.updateBoard(
        BoardTab.fitness,
        store.board(BoardTab.fitness).withRemoved('fitness.today'),
      );
      await store.updateBoard(
        BoardTab.food,
        store.board(BoardTab.food).withAdded('metric.water', WidgetSize.small),
      );

      final reloaded = await reload();

      expect(reloaded.board(BoardTab.fitness), store.board(BoardTab.fitness));
      expect(reloaded.board(BoardTab.food).ids.last, 'metric.water');
    });

    test(
      'earlier layouts carry over: order, hidden sections and pins',
      () async {
        await repo.saveDocument('settings', {
          'onboarded': true,
          'pinned': ['sleep'],
          'widgetSizes': {'sleep': 'wide'},
          'personalization': {
            'design': 2,
            'style': 4,
            'fitness': {
              'order': [
                'progress',
                for (final s in FitnessSection.values)
                  if (s != FitnessSection.progress) s.name,
              ],
              'hidden': ['today'],
            },
            'health': {
              'order': ['allData', 'vitals', 'categories', 'more'],
              'hidden': ['more'],
            },
          },
        });

        final s = await reload();

        final fitness = s.board(BoardTab.fitness).ids;
        expect(fitness.take(2), ['fitness.gym', 'fitness.progress']);
        expect(fitness, isNot(contains('fitness.today')));
        final health = s.board(BoardTab.health);
        expect(
          health.items.first,
          const BoardItem('metric.sleep', WidgetSize.large),
        );
        expect(health.ids, isNot(contains('tracker.mood')));
        expect(health.ids, contains('category.heart'));
      },
    );

    test('widgets saved as wide keep their look as large', () async {
      await repo.saveDocument('settings', {
        'onboarded': true,
        'boards': {
          'health': [
            {'id': 'metric.steps', 'size': 'wide'},
          ],
          'fitness': [
            {'id': 'fitness.week', 'size': 'wide'},
          ],
          'food': [
            {'id': 'food.calories', 'size': 'wide'},
          ],
        },
      });

      final s = await reload();

      expect(s.board(BoardTab.health).items.single.size, WidgetSize.large);
      expect(s.board(BoardTab.fitness).items.last.size, WidgetSize.large);
      expect(s.board(BoardTab.food).items.single.size, WidgetSize.large);
    });

    test('new widgets join saved boards once, at the top', () async {
      await repo.saveDocument('settings', {
        'onboarded': true,
        'boards': {
          'fitness': [
            {'id': 'fitness.week', 'size': 'large'},
          ],
        },
      });

      final s = await reload();
      expect(s.board(BoardTab.fitness).ids, ['fitness.gym', 'fitness.week']);

      // Removed by the user, it stays removed.
      await s.updateBoard(
        BoardTab.fitness,
        s.board(BoardTab.fitness).withRemoved('fitness.gym'),
      );
      expect((await reload()).board(BoardTab.fitness).ids, ['fitness.week']);
    });

    test('a Health board still in the old layout gets the tidy one', () async {
      final old = BoardIds.legacyHealth(const Personalization(), [
        const HealthWidget(MetricType.steps, WidgetSize.large),
        for (final m in [
          MetricType.heartRate,
          MetricType.sleep,
          MetricType.weight,
        ])
          HealthWidget(m, WidgetSize.small),
      ]);
      await repo.saveDocument('settings', {
        'onboarded': true,
        // As the previous version saved it: pins, but no sizes.
        'pinned': ['steps', 'heartRate', 'sleep', 'weight'],
        'boards': {'health': Board(old).toJson()},
      });

      final s = await reload();
      expect(s.board(BoardTab.health).items, BoardIds.healthLayout);
    });

    test('a Health board in the build 99 layout gets the short one', () async {
      await repo.saveDocument('settings', {
        'onboarded': true,
        'boards': {
          'health': const Board(BoardIds.previousHealthLayout).toJson(),
        },
      });

      final s = await reload();
      expect(s.board(BoardTab.health).items, BoardIds.healthLayout);
      expect(s.board(BoardTab.health).ids, contains(BoardIds.healthMore));
    });

    test('a Health board the user arranged is kept', () async {
      await repo.saveDocument('settings', {
        'onboarded': true,
        'boards': {
          'health': [
            {'id': 'tracker.mood', 'size': 'medium'},
            {'id': 'health.vitals', 'size': 'large'},
          ],
        },
      });

      final s = await reload();
      expect(s.board(BoardTab.health).ids, ['tracker.mood', 'health.vitals']);
    });

    test('a new Health board has every small widget paired', () {
      var smalls = 0;
      for (final i in store.board(BoardTab.health).items) {
        if (i.size == WidgetSize.small) {
          smalls++;
        } else {
          expect(smalls.isEven, isTrue, reason: 'a lone small before ${i.id}');
          smalls = 0;
        }
      }
      expect(smalls.isEven, isTrue);
    });

    test('a Fitness board as it came gets the short one', () async {
      await repo.saveDocument('settings', {
        'onboarded': true,
        'boards': {
          'fitness': Board(BoardIds.legacyFitness(const Personalization()))
              .toJson(),
        },
        'introduced': [BoardIds.gym],
      });

      final s = await reload();
      expect(s.board(BoardTab.fitness).items, BoardIds.fitnessLayout);
    });

    test('pinned metrics are the Health board metric widgets', () async {
      await store.addWidget(MetricType.water);

      expect(store.board(BoardTab.health).ids, contains('metric.water'));
      expect(store.pinned, contains(MetricType.water));
      await store.updateBoard(
        BoardTab.health,
        store.board(BoardTab.health).withRemoved('metric.water'),
      );
      expect(store.isPinned(MetricType.water), isFalse);
    });
  });
}
