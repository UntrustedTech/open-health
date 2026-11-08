import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/export/health_report.dart' show ReportDesign;
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/state/health_store.dart';

void main() {
  group('Personalization', () {
    test('skipped setup steps round-trip and unknown ones are ignored', () {
      final look = const Personalization().copyWith(
        setupLeft: {SetupStep.food, SetupStep.reminders},
      );
      final back = Personalization.fromJson(look.toJson());
      expect(back.setupLeft, {SetupStep.food, SetupStep.reminders});
      expect(back, look);
      expect(back.withSetupDone(SetupStep.food).setupLeft, {
        SetupStep.reminders,
      });
      final odd = Personalization.fromJson({
        'setupLeft': ['goals', 'nope', 3],
      });
      expect(odd.setupLeft, {SetupStep.goals});
    });

    test('the chosen report design is kept; an unknown one is Classic', () {
      final look = const Personalization().copyWith(
        reportDesign: ReportDesign.bold,
      );
      expect(Personalization.fromJson(look.toJson()), look);
      expect(
        Personalization.fromJson({'reportDesign': 'fancy'}).reportDesign,
        ReportDesign.classic,
      );
    });

    test('the chart style is kept; an unknown or missing one is Curve', () {
      final look = const Personalization().copyWith(
        chartStyle: ChartStyle.dashes,
      );
      expect(Personalization.fromJson(look.toJson()), look);
      expect(
        Personalization.fromJson({'chartStyle': 'pie'}).chartStyle,
        ChartStyle.curve,
      );
      expect(Personalization.fromJson({}).chartStyle, ChartStyle.curve);
    });

    test('round-trips through JSON', () {
      final look = const Personalization().copyWith(
        accent: AppAccent.indigo,
        showGreeting: false,
        reduceMotion: true,
      );

      expect(Personalization.fromJson(look.toJson()), look);
    });

    test('defaults to the iris accent', () {
      expect(const Personalization().accent, AppAccent.iris);
    });

    test('unknown or malformed values fall back to defaults', () {
      final look = Personalization.fromJson({
        'accent': 'neon',
        'showGreeting': 'yes',
      });

      expect(look.accent, AppAccent.iris);
      expect(look.showGreeting, isTrue);
    });
  });

  group('HealthStore personalization', () {
    final now = DateTime(2026, 10, 11, 15, 30);
    late InMemoryHealthRepository repo;
    late HealthStore store;

    setUp(() async {
      repo = InMemoryHealthRepository();
      store = HealthStore(repo, clock: () => now);
      await store.load();
    });

    test('is saved and loaded with the settings', () async {
      final look = const Personalization().copyWith(accent: AppAccent.mint);
      await store.setPersonalization(look);

      final reloaded = HealthStore(repo, clock: () => now);
      await reloaded.load();
      expect(reloaded.personalization, look);
    });

    test('Erase All resets it', () async {
      await store.setPersonalization(
        const Personalization().copyWith(accent: AppAccent.red),
      );
      await store.eraseAll();
      expect(store.personalization, const Personalization());
    });

    test('pinned data can be reordered', () async {
      await store.addWidget(MetricType.steps);
      await store.addWidget(MetricType.water);
      final first = store.pinned.first;
      await store.movePinned(0, store.pinned.length - 1);
      expect(store.pinned.last, first);

      final reloaded = HealthStore(repo, clock: () => now);
      await reloaded.load();
      expect(reloaded.pinned.last, first);
    });

    test('days logged counts distinct days, ignoring samples', () async {
      await store.addEntry(MetricType.water, 250, date: DateTime(2026, 10, 1));
      await store.addEntry(MetricType.steps, 10, date: DateTime(2026, 10, 1));
      await store.addEntry(MetricType.water, 250, date: DateTime(2026, 10, 2));
      await store.loadSampleData();
      expect(store.daysLogged, 2);
    });

    test('restoring entries merges by id or replaces', () async {
      final kept = await store.addEntry(MetricType.water, 100);
      final backup = [
        kept,
        HealthEntry(
          id: 'b1',
          type: MetricType.steps,
          value: 900,
          date: DateTime(2026, 10, 3),
        ),
      ];

      expect(await store.restoreEntries(backup, replace: false), 1);
      expect(store.allEntries, hasLength(2));

      await store.addEntry(MetricType.weight, 70);
      await store.restoreEntries(backup, replace: true);
      expect({for (final e in store.allEntries) e.id}, {kept.id, 'b1'});
    });
  });

  group('Still redesign migration', () {
    test('the old Aurora default moves to the current default once', () {
      final look = Personalization.fromJson({
        'design': Personalization.design,
        'accent': 'aurora',
      });
      expect(look.accent, AppAccent.iris);
    });

    test('Aurora chosen after the Still redesign is kept', () {
      final saved = const Personalization()
          .copyWith(accent: AppAccent.aurora)
          .toJson();
      expect(saved['style'], Personalization.style);
      expect(Personalization.fromJson(saved).accent, AppAccent.aurora);
    });

    test('other accents are kept', () {
      final look = Personalization.fromJson({
        'design': Personalization.design,
        'accent': 'blue',
      });
      expect(look.accent, AppAccent.blue);
    });
  });

  group('Aurora redesign migration', () {
    test('settings saved before the redesign move from pink to iris', () {
      final look = Personalization.fromJson({'accent': 'pink'});
      expect(look.accent, AppAccent.iris);
    });

    test('a pink accent chosen after the redesign is kept', () {
      final saved = const Personalization()
          .copyWith(accent: AppAccent.pink)
          .toJson();
      expect(Personalization.fromJson(saved).accent, AppAccent.pink);
    });

    test('other accents survive the migration', () {
      final look = Personalization.fromJson({'accent': 'indigo'});
      expect(look.accent, AppAccent.indigo);
    });
  });

  group('Soft redesign migration', () {
    test('the Still default, lime, moves to iris once', () {
      final look = Personalization.fromJson({
        'design': Personalization.design,
        'style': 3,
        'accent': 'lime',
      });
      expect(look.accent, AppAccent.iris);
    });

    test('Aurora chosen under the Still style is kept', () {
      final look = Personalization.fromJson({
        'design': Personalization.design,
        'style': 3,
        'accent': 'aurora',
      });
      expect(look.accent, AppAccent.aurora);
    });

    test('lime chosen after the Soft redesign is kept', () {
      final saved = const Personalization()
          .copyWith(accent: AppAccent.lime)
          .toJson();
      expect(Personalization.fromJson(saved).accent, AppAccent.lime);
    });
  });
}
