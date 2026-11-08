import 'package:flutter/foundation.dart';

import 'package:health_app/insights/achievements.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/medication.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/utils/log.dart';

/// Works out achievements from your data and remembers when each tier was
/// first earned (and whether you've seen it yet).
class AchievementStore extends ChangeNotifier {
  AchievementStore(
    this._health,
    this._workouts, {
    this.nutrition,
    this.medications,
    this.cycle,
    this.gym,
    this.mood,
    this.fasting,
  }) {
    for (final l in _sources) {
      l.addListener(_invalidate);
    }
  }

  static const docKey = 'achievements';

  final HealthStore _health;
  final WorkoutStore _workouts;

  /// Optional sources for food, medication and cycle achievements.
  final NutritionStore? nutrition;
  final MedicationStore? medications;
  final CycleStore? cycle;

  /// Optional sources for gym, mood and fasting achievements.
  final GymStore? gym;
  final MoodStore? mood;
  final FastingStore? fasting;

  List<Listenable> get _sources => [
    _health,
    _workouts,
    ?nutrition,
    ?medications,
    ?cycle,
    ?gym,
    ?mood,
    ?fasting,
  ];

  /// When each tier was first earned, by [keyOf].
  Map<String, DateTime> _earnedOn = {};
  Set<String> _seen = {};
  bool _readable = true;
  List<Achievement>? _all;

  /// Storage key of one tier of one achievement.
  static String keyOf(String id, Tier tier) => '$id@${tier.name}';

  /// Badges from before tiers, and the tier each became.
  static const _legacy = {
    'steps10k': ('steps', Tier.bronze),
    'steps20k': ('steps', Tier.gold),
    'perfectDay': ('perfectDays', Tier.bronze),
    'perfectWeek': ('ringStreak', Tier.silver),
    'moveStreak30': ('moveStreak', Tier.gold),
    'doubleMove': ('overachiever', Tier.silver),
    'marathonWeek': ('distanceWeek', Tier.silver),
    'firstWorkout': ('workouts', Tier.bronze),
    'workouts100': ('workouts', Tier.gold),
    'workoutStreak7': ('workoutStreak', Tier.silver),
    'run5k': ('longestRun', Tier.bronze),
    'run10k': ('longestRun', Tier.silver),
    'runHalf': ('longestRun', Tier.gold),
    'volume10t': ('volume', Tier.gold),
    'waterWeek': ('water', Tier.silver),
    'sleepWeek': ('sleep', Tier.silver),
    'mindful30': ('mindful', Tier.gold),
    'logged100': ('logged', Tier.gold),
  };

  /// A stored key in today's form (old badge ids become tiers).
  static String? _upgrade(String key) {
    if (key.contains('@')) return key;
    final (id, tier) = _legacy[key] ?? (null, null);
    return id == null || tier == null ? null : keyOf(id, tier);
  }

  @override
  void dispose() {
    for (final l in _sources) {
      l.removeListener(_invalidate);
    }
    super.dispose();
  }

  void _invalidate() {
    _all = null;
    notifyListeners();
  }

  /// Every achievement with its current progress.
  List<Achievement> get all => _all ??= evaluateAchievements(
    AchievementInputs(
      dailyValue: _health.dailyValue,
      today: _health.today,
      goals: _health.goals,
      workouts: _workouts.all,
      daysLogged: _health.daysLogged,
      food: nutrition?.all ?? const [],
      foodGoals: nutrition?.goals ?? const NutritionGoals(),
      dosesTaken:
          medications?.log.where((l) => l.status == DoseStatus.taken).length ??
          0,
      periods: cycle?.forecast.periods.length ?? 0,
      bodyGoal: _health.bodyGoal.copyWith(startKg: _health.goalStartKg),
      latestWeightKg: _health.latestReading(MetricType.weight)?.value,
      firstDay: _health.firstEntryDate,
      gymVisits: gym?.visits ?? const [],
      moodDays: mood?.days.keys.toSet() ?? const {},
      fastsReached: fasting?.history.where((f) => f.reachedGoal).length ?? 0,
    ),
  );

  /// Achievements with at least one tier.
  List<Achievement> get earned => all.where((a) => a.earned).toList();

  /// Tiers earned across all achievements, and how many there are.
  int get medals => all.fold(0, (n, a) => n + (a.tier?.index ?? -1) + 1);
  int get totalMedals => all.length * Tier.values.length;

  /// Earned tiers not yet looked at.
  List<Achievement> get unseen =>
      earned.where((a) => !_seen.contains(keyOf(a.id, a.tier!))).toList();

  /// When the highest tier reached was first earned.
  DateTime? earnedOn(String id) {
    final a = all.where((x) => x.id == id).firstOrNull;
    final t = a?.tier;
    return t == null ? null : _earnedOn[keyOf(id, t)];
  }

  /// When [tier] of [id] was first earned.
  DateTime? tierEarnedOn(String id, Tier tier) => _earnedOn[keyOf(id, tier)];

  /// Earned ones, most recently ranked up first.
  List<Achievement> get recent => earned.toList()
    ..sort((a, b) {
      final da = earnedOn(a.id), db = earnedOn(b.id);
      if (da == null) return db == null ? 0 : 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

  Future<void> load() async {
    _earnedOn = {};
    _seen = {};
    _readable = true;
    try {
      final doc = (await _health.loadDocuments([docKey]))[docKey];
      final earned = doc?['earned'];
      if (earned is Map<String, Object?>) {
        for (final MapEntry(:key, :value) in earned.entries) {
          final k = _upgrade(key);
          final when = DateTime.tryParse('$value');
          if (k == null || when == null) continue;
          final had = _earnedOn[k];
          if (had == null || when.isBefore(had)) _earnedOn[k] = when;
        }
      }
      final seen = doc?['seen'];
      if (seen is List) {
        _seen = {for (final s in seen.whereType<String>()) ?_upgrade(s)};
      }
    } on Exception catch (e) {
      _readable = false;
      logError('Achievements: could not load: $e');
    }
    _invalidate();
  }

  /// Notes the date of any newly earned tiers. Returns the achievements
  /// that ranked up. Not while sample data is loaded, so demo badges are
  /// never kept.
  Future<List<Achievement>> recordNew() async {
    if (_health.hasSampleData) return const [];
    final now = _health.now;
    final fresh = <Achievement>[];
    final next = {..._earnedOn};
    for (final a in earned) {
      var ranked = false;
      for (final t in Tier.values.take(a.tier!.index + 1)) {
        if (next.putIfAbsent(keyOf(a.id, t), () => now) == now &&
            !_earnedOn.containsKey(keyOf(a.id, t))) {
          ranked = true;
        }
      }
      if (ranked) fresh.add(a);
    }
    if (fresh.isEmpty) return const [];
    _earnedOn = next;
    notifyListeners();
    await _save();
    return fresh;
  }

  Future<void> markAllSeen() async {
    final keys = {for (final a in earned) keyOf(a.id, a.tier!)};
    if (_seen.containsAll(keys)) return;
    _seen = {..._seen, ...keys};
    notifyListeners();
    await _save();
  }

  /// Clears memory after "Erase All".
  void reset() {
    _earnedOn = {};
    _seen = {};
    _readable = true;
    _invalidate();
  }

  Future<void> _save() async {
    if (!_readable) {
      logError('Achievements: not saving over data that could not be read');
      return;
    }
    await _health.saveDocument(docKey, {
      'earned': {
        for (final MapEntry(:key, :value) in _earnedOn.entries)
          key: value.toIso8601String(),
      },
      'seen': _seen.toList()..sort(),
    });
  }
}
