import 'package:flutter/foundation.dart' show listEquals;

import 'package:health_app/app_edition.dart';
import 'package:health_app/models/board.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/models/tab_layout.dart';

/// The trackers and insights that can be widgets on the Health tab.
enum Tracker {
  readiness,
  mood,
  habits,
  sleepSchedule,
  fasting,
  food,
  trends,
  medications,
  cycle,
  achievements,
  recap,
  report;

  /// The trackers this version has. The store version leaves out
  /// Medications: Google Play only lets organisations publish medication
  /// management apps.
  static final shown = [
    for (final t in values)
      if (!kStoreEdition || t != medications) t,
  ];
}

/// Ids of the widgets each tab can show, and the boards a tab starts with.
/// Every tab can also show any metric as a widget (`metric.<name>`).
abstract final class BoardIds {
  static const vitals = 'health.vitals';

  /// Trackers and insights as one list (the Health tab's default).
  static const healthMore = 'health.more';
  static const calories = 'food.calories';
  static const macros = 'food.macros';
  static const micros = 'food.micros';
  static const gym = 'fitness.gym';

  /// Plans, routines, records and the rest as one list (the Fitness
  /// tab's default).
  static const fitnessMore = 'fitness.more';

  /// The Summary tab's own widgets; it can also show any other tab's.
  static const score = 'summary.score';
  static const rings = 'summary.activity';
  static const sleep = 'summary.sleep';
  static const heart = 'summary.heart';
  static const nutrition = 'summary.nutrition';
  static const body = 'summary.body';
  static const water = 'summary.water';
  static const changes = 'summary.changes';
  static const summaryOwn = [
    score,
    rings,
    sleep,
    heart,
    nutrition,
    body,
    water,
    changes,
  ];

  /// Widgets added since boards could be saved, by tab: each joins a
  /// saved board once, at the top, so it can be found.
  static const introduced = {gym: BoardTab.fitness};

  static String metric(MetricType t) => 'metric.${t.name}';
  static String category(HealthCategory c) => 'category.${c.name}';
  static String tracker(Tracker t) => 'tracker.${t.name}';
  static String fitness(FitnessSection s) => 'fitness.${s.name}';
  static String meal(Meal m) => 'food.meal.${m.name}';

  /// The metric a `metric.` id stands for, if it is one.
  static MetricType? metricOf(String id) =>
      id.startsWith('metric.') ? MetricType.fromName(id.substring(7)) : null;

  /// The metric categories each tab offers as widgets.
  static Set<HealthCategory>? metricCategories(BoardTab tab) => switch (tab) {
    BoardTab.health || BoardTab.summary => null,
    BoardTab.fitness => const {HealthCategory.activity, HealthCategory.heart},
    BoardTab.food => const {HealthCategory.nutrition},
  };

  static Set<String> known(BoardTab tab) => {
    if (tab == BoardTab.summary) ...[
      ...summaryOwn,
      for (final other in BoardTab.values)
        if (other != BoardTab.summary) ...known(other),
    ],
    for (final t in MetricType.values)
      if (metricCategories(tab)?.contains(t.category) ?? true) metric(t),
    ...switch (tab) {
      BoardTab.health => [
        vitals,
        healthMore,
        for (final c in HealthCategory.values) category(c),
        for (final t in Tracker.shown) tracker(t),
      ],
      BoardTab.fitness => [
        gym,
        fitnessMore,
        for (final s in FitnessSection.values) fitness(s),
      ],
      BoardTab.food => [
        calories,
        macros,
        micros,
        for (final m in Meal.values) meal(m),
      ],
      BoardTab.summary => const <String>[],
    },
  };

  /// Whether the user kept the sections and pins the app came with, so
  /// the Health board can start as [healthLayout].
  static bool _standard(Personalization look, List<HealthWidget> pinned) =>
      listEquals(look.health.visible, HealthSection.values) &&
      listEquals([for (final w in pinned) metric(w.metric)], defaultPins);

  /// The metrics the app pins to All Health Data's favourites at first.
  static const defaultPins = [
    'metric.steps',
    'metric.heartRate',
    'metric.sleep',
    'metric.weight',
  ];

  /// The Health tab as it starts: the vitals, readiness, the body's areas
  /// in pairs, then every tracker and insight in one short list. Anything
  /// else can be added from the widget gallery.
  static const healthLayout = [
    BoardItem(vitals, WidgetSize.large),
    BoardItem('tracker.readiness', WidgetSize.medium),
    BoardItem('category.activity', WidgetSize.small),
    BoardItem('category.heart', WidgetSize.small),
    BoardItem('category.sleep', WidgetSize.small),
    BoardItem('category.vitals', WidgetSize.small),
    BoardItem('category.body', WidgetSize.small),
    BoardItem('category.nutrition', WidgetSize.small),
    BoardItem(healthMore, WidgetSize.large),
  ];

  /// The Health tab as build 99 and earlier started it: a tile for each
  /// tracker and the pinned metrics. Boards still like this move to
  /// [healthLayout].
  static const previousHealthLayout = [
    BoardItem(vitals, WidgetSize.large),
    BoardItem('tracker.readiness', WidgetSize.medium),
    BoardItem('category.activity', WidgetSize.small),
    BoardItem('category.heart', WidgetSize.small),
    BoardItem('category.sleep', WidgetSize.small),
    BoardItem('category.vitals', WidgetSize.small),
    BoardItem('category.body', WidgetSize.small),
    BoardItem('category.nutrition', WidgetSize.small),
    BoardItem('tracker.trends', WidgetSize.medium),
    BoardItem('tracker.mood', WidgetSize.small),
    BoardItem('category.mindfulness', WidgetSize.small),
    BoardItem('tracker.sleepSchedule', WidgetSize.small),
    BoardItem('tracker.fasting', WidgetSize.small),
    BoardItem('tracker.medications', WidgetSize.small),
    BoardItem('tracker.cycle', WidgetSize.small),
    BoardItem('tracker.achievements', WidgetSize.medium),
    BoardItem('tracker.recap', WidgetSize.small),
    BoardItem('tracker.report', WidgetSize.small),
    // The metrics it pins, as All Health Data's favourites.
    BoardItem('metric.steps', WidgetSize.large),
    BoardItem('metric.heartRate', WidgetSize.small),
    BoardItem('metric.sleep', WidgetSize.small),
    BoardItem('metric.weight', WidgetSize.small),
    BoardItem('tracker.food', WidgetSize.small),
  ];

  /// The Fitness tab as it starts: the week, today's suggestion, quick
  /// start, then everything else in one list.
  static const fitnessLayout = [
    BoardItem('fitness.week', WidgetSize.medium),
    BoardItem('fitness.suggestion', WidgetSize.large),
    BoardItem('fitness.start', WidgetSize.large),
    BoardItem(fitnessMore, WidgetSize.large),
  ];

  /// The Fitness board as build 99 and earlier started it: the gym, then
  /// every section the user kept, each a full card.
  static List<BoardItem> legacyFitness(Personalization look) => [
    const BoardItem(gym, WidgetSize.medium),
    for (final s in look.fitness.visible)
      BoardItem(fitness(s), WidgetSize.large),
  ];

  /// The Health board as versions before [healthLayout] made it: the
  /// sections the user had before boards, in their order, then pins.
  static List<BoardItem> legacyHealth(
    Personalization look,
    List<HealthWidget> pinned,
  ) => [
    for (final s in look.health.visible)
      ...switch (s) {
        HealthSection.vitals => [const BoardItem(vitals, WidgetSize.large)],
        HealthSection.categories => [
          for (final c in HealthCategory.values)
            BoardItem(category(c), WidgetSize.small),
        ],
        HealthSection.more => [
          for (final t in Tracker.shown)
            BoardItem(tracker(t), WidgetSize.small),
        ],
        HealthSection.allData => [
          for (final w in pinned) BoardItem(metric(w.metric), w.size),
        ],
      },
  ];

  /// The board [tab] starts with, following the sections the user had
  /// before boards (their order and hidden ones) and their pinned metrics.
  static Board initial(
    BoardTab tab, {
    required Personalization look,
    required List<HealthWidget> pinned,
  }) => Board(
    List.unmodifiable(switch (tab) {
      BoardTab.health when _standard(look, pinned) => healthLayout,
      BoardTab.health => legacyHealth(look, pinned),
      BoardTab.fitness
          when listEquals(look.fitness.visible, FitnessSection.values) =>
        fitnessLayout,
      BoardTab.fitness => legacyFitness(look),
      BoardTab.food => [
        const BoardItem(calories, WidgetSize.large),
        const BoardItem(macros, WidgetSize.large),
        for (final m in Meal.values) BoardItem(meal(m), WidgetSize.large),
        const BoardItem(micros, WidgetSize.large),
      ],
      BoardTab.summary => const [
        BoardItem(score, WidgetSize.large),
        BoardItem(rings, WidgetSize.large),
        BoardItem(sleep, WidgetSize.small),
        BoardItem(heart, WidgetSize.small),
        BoardItem(nutrition, WidgetSize.small),
        BoardItem(water, WidgetSize.small),
        BoardItem(changes, WidgetSize.large),
      ],
    }),
  );
}
