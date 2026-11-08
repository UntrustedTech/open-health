import 'package:health_app/export/backup.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/state/workout_store.dart';

enum RestoreMode {
  /// Adds what's missing; keeps everything already here, settings included.
  merge,

  /// Makes the app match the backup: data, workouts, routines and settings.
  replace,
}

/// What a restore added.
typedef RestoreResult = ({int entries, int workouts, int routines});

/// Some writes failed. After a failed Replace the previous data is put
/// back; [rolledBack] says whether that worked.
class RestoreException implements Exception {
  const RestoreException({required this.rolledBack});

  final bool rolledBack;

  @override
  String toString() => 'RestoreException(rolledBack: $rolledBack)';
}

/// Restores a [Backup] into the app's stores. Every write goes through the
/// shared write queue, then the stores reload from storage.
class BackupRestorer {
  BackupRestorer({
    required this.health,
    required this.workouts,
    required this.exercises,
    required this.notifications,
    this.reloadOthers,
  });

  final HealthStore health;
  final WorkoutStore workouts;
  final ExerciseStore exercises;
  final NotificationController notifications;

  /// Re-reads stores this class doesn't know about (medications, cycle…).
  final Future<void> Function()? reloadOthers;

  // Storage keys, as the stores save them.
  static const _workoutsKey = 'workouts';
  static const _routinesKey = 'routines';
  static const _customKey = 'customExercises';

  /// Throws [RestoreException] if anything couldn't be saved.
  Future<RestoreResult> restore(Backup backup, RestoreMode mode) async {
    final result = switch (mode) {
      RestoreMode.merge => await _merge(backup),
      RestoreMode.replace => await _replace(backup),
    };
    return result;
  }

  /// Whether any write failed since [since] (a [HealthStore.saveFailures]
  /// count). A later success doesn't hide an earlier failure.
  bool _failedSince(int since) => health.saveFailures != since;

  Future<RestoreResult> _merge(Backup backup) async {
    final since = health.saveFailures;
    // Read first: if either can't be read, stop before changing anything.
    final medsHere = await health.loadDocument('medications') ?? {};
    final cycleHere = await health.loadDocument('cycle') ?? {};
    final foodHere = await health.loadDocument('nutrition') ?? {};
    final moodHere = await health.loadDocument('mood') ?? {};
    final fastingHere = await health.loadDocument('fasting') ?? {};
    final gymHere = await health.loadDocument('gym') ?? {};
    final keepHere = {
      for (final key in ['sleepSchedule', 'program', 'themes'])
        key: await health.loadDocument(key),
    };
    final entries = await health.restoreEntries(backup.entries, replace: false);
    final known = {for (final w in workouts.all) w.id};
    final added = await workouts.importSessions(backup.workouts);
    await workouts.dropEntriesOfMissing(backup.workouts.map((w) => w.id));
    // Routes of the workouts that were new here.
    for (final key in Backup.routeKeys(
      backup.workouts.where((w) => !known.contains(w.id)),
    )) {
      if (backup.documents[key] case final doc?) {
        await health.saveDocument(key, doc);
      }
    }
    final have = {for (final r in workouts.routines) r.id};
    var routines = 0;
    for (final r in backup.routines) {
      if (have.contains(r.id)) continue;
      await workouts.saveRoutine(r);
      routines++;
    }
    await _mergeCustomExercises(backup.documents[_customKey]);
    await _mergeMedications(medsHere, backup.documents['medications']);
    await _mergeCycle(cycleHere, backup.documents['cycle']);
    await _mergeNutrition(foodHere, backup.documents['nutrition']);
    await _mergeMood(moodHere, backup.documents['mood']);
    await _mergeFasting(fastingHere, backup.documents['fasting']);
    await _mergeGym(gymHere, backup.documents['gym']);
    // Settings-like documents: kept here, or taken from the backup.
    for (final MapEntry(:key, :value) in keepHere.entries) {
      final doc = backup.documents[key];
      if (value == null && doc != null) await health.saveDocument(key, doc);
    }
    await reloadOthers?.call();
    if (_failedSince(since)) throw const RestoreException(rolledBack: false);
    return (entries: entries, workouts: added, routines: routines);
  }

  /// Adds the backup's own exercises that aren't here yet (by id).
  Future<void> _mergeCustomExercises(Map<String, Object?>? doc) async {
    final incoming = _items(doc);
    if (incoming.isEmpty) return;
    final have = {for (final e in exercises.custom) e.id};
    // `add` also drops ids repeated within the backup.
    final fresh = incoming.where((e) => have.add(e['id']! as String)).toList();
    if (fresh.isEmpty) return;
    await health.saveDocument(_customKey, {
      'items': [for (final e in exercises.custom) e.toJson(), ...fresh],
    });
    await exercises.load();
  }

  /// Adds medications (by id) and dose records the app doesn't have.
  Future<void> _mergeMedications(
    Map<String, Object?> here,
    Map<String, Object?>? doc,
  ) async {
    if (doc == null) return;
    List<Map<String, Object?>> list(Map<String, Object?> d, String k) =>
        switch (d[k]) {
          final List<Object?> l => l.whereType<Map<String, Object?>>().toList(),
          _ => [],
        };
    final ids = {for (final m in list(here, 'items')) m['id']};
    String logKey(Map<String, Object?> l) => '${l['med']}|${l['at']}';
    final logs = {for (final l in list(here, 'log')) logKey(l)};
    await health.saveDocument('medications', {
      'items': [
        ...list(here, 'items'),
        for (final m in list(doc, 'items'))
          if (m['id'] is String && ids.add(m['id'])) m,
      ],
      'log': [
        ...list(here, 'log'),
        for (final l in list(doc, 'log'))
          if (logs.add(logKey(l))) l,
      ],
    });
  }

  /// Adds logged cycle days the app doesn't have; days here win.
  Future<void> _mergeCycle(
    Map<String, Object?> here,
    Map<String, Object?>? doc,
  ) async {
    final incoming = doc?['days'];
    if (incoming is! Map<String, Object?>) return;
    final days = here['days'];
    await health.saveDocument('cycle', {
      'enabled': here['enabled'] == true || doc?['enabled'] == true,
      'days': {...incoming, if (days is Map<String, Object?>) ...days},
    });
  }

  /// Adds journal days the app doesn't have (days here win), and joins
  /// the habits and the days each was ticked off.
  Future<void> _mergeMood(
    Map<String, Object?> here,
    Map<String, Object?>? doc,
  ) async {
    if (doc == null) return;
    Map<String, Object?> map(Map<String, Object?> d, String k) =>
        d[k] is Map<String, Object?> ? d[k]! as Map<String, Object?> : {};
    List<Object?> list(Object? v) => v is List ? v : const [];
    final ticksHere = map(here, 'habitDays');
    final ticksThere = map(doc, 'habitDays');
    await health.saveDocument('mood', {
      'days': {...map(doc, 'days'), ...map(here, 'days')},
      'habits': {...list(here['habits']), ...list(doc['habits'])}.toList(),
      'habitDays': {
        for (final day in {...ticksHere.keys, ...ticksThere.keys})
          day: {...list(ticksHere[day]), ...list(ticksThere[day])}.toList(),
      },
    });
  }

  /// Joins the visits; the membership here is kept, or the backup's used
  /// when there isn't one.
  Future<void> _mergeGym(
    Map<String, Object?> here,
    Map<String, Object?>? doc,
  ) async {
    if (doc == null) return;
    List<String> visits(Map<String, Object?> d) => switch (d['visits']) {
      final List<Object?> l => l.whereType<String>().toList(),
      _ => [],
    };
    await health.saveDocument('gym', {
      'membership': ?(here['membership'] ?? doc['membership']),
      'visits': ({...visits(doc), ...visits(here)}.toList()..sort()),
    });
  }

  /// Adds past fasts (by start time); the running fast and preset here
  /// are kept.
  Future<void> _mergeFasting(
    Map<String, Object?> here,
    Map<String, Object?>? doc,
  ) async {
    if (doc == null) return;
    List<Map<String, Object?>> list(Map<String, Object?> d) =>
        switch (d['history']) {
          final List<Object?> l => l.whereType<Map<String, Object?>>().toList(),
          _ => [],
        };
    final seen = <Object?>{};
    await health.saveDocument('fasting', {
      // The running fast is only ever this device's: a fast that was
      // running when the backup was made mustn't "resume" here.
      'preset': here['preset'] ?? doc['preset'],
      'started': ?here['started'],
      'history': [
        for (final f in [...list(here), ...list(doc)])
          if (seen.add(f['s'])) f,
      ].take(400).toList(),
    });
  }

  /// Adds diary entries and saved foods (by id); goals here are kept.
  Future<void> _mergeNutrition(
    Map<String, Object?> here,
    Map<String, Object?>? doc,
  ) async {
    if (doc == null) return;
    List<Map<String, Object?>> list(Map<String, Object?> d, String k) =>
        switch (d[k]) {
          final List<Object?> l => l.whereType<Map<String, Object?>>().toList(),
          _ => [],
        };
    // Bounded, so a damaged backup can't balloon the diary.
    List<Map<String, Object?>> union(String key, int max) {
      final ids = <Object?>{};
      return [
        for (final item in [...list(here, key), ...list(doc, key)])
          if (item['id'] is String && ids.add(item['id'])) item,
      ].take(max).toList();
    }

    final favorites = {
      for (final d in [here, doc])
        if (d['favorites'] case final List<Object?> l) ...l.whereType<String>(),
    };
    await health.saveDocument('nutrition', {
      ...here,
      'entries': union('entries', 20000),
      'recent': union('recent', 40),
      'custom': union('custom', 2000),
      'templates': union('templates', 500),
      'recipes': union('recipes', 500),
      'favorites': favorites.toList()..sort(),
      if (here['goals'] == null && doc['goals'] != null) 'goals': doc['goals'],
    });
  }

  Future<RestoreResult> _replace(Backup backup) async {
    final before = await _snapshot();
    final since = health.saveFailures;
    await _write(backup, replaced: before.workouts);
    if (_failedSince(since)) {
      // Put the previous data back rather than leave a mix of both.
      final rollback = health.saveFailures;
      await _write(before, replaced: backup.workouts);
      await _reload();
      throw RestoreException(rolledBack: !_failedSince(rollback));
    }
    await _reload();
    final had = (
      entries: {for (final e in before.entries) e.id},
      workouts: {for (final w in before.workouts) w.id},
      routines: {for (final r in before.routines) r.id},
    );
    return (
      entries: backup.entries.where((e) => !had.entries.contains(e.id)).length,
      workouts: backup.workouts
          .where((w) => !had.workouts.contains(w.id))
          .length,
      routines: backup.routines
          .where((r) => !had.routines.contains(r.id))
          .length,
    );
  }

  /// Everything a backup holds, as the app has it now.
  Future<Backup> _snapshot() async => Backup(
    exportedAt: null,
    entries: health.allEntries,
    workouts: workouts.all,
    routines: workouts.routines.where((r) => !r.builtIn).toList(),
    documents: {
      // Strict: an unreadable document stops the restore before anything
      // is written, instead of being "rolled back" to nothing.
      for (final key in Backup.documentKeys)
        key: ?await health.loadDocument(key),
      // Lenient for routes: one damaged map shouldn't block a restore.
      ...await health.loadDocuments(Backup.routeKeys(workouts.all)),
    },
  );

  /// Makes storage hold exactly [state]. Documents it doesn't have are
  /// removed, so nothing from before (like a plan pointing at deleted
  /// routines) is left behind; so are the routes of [replaced] workouts
  /// that [state] doesn't have.
  Future<void> _write(
    Backup state, {
    Iterable<WorkoutSession> replaced = const [],
  }) async {
    // Each workout gets exactly the route [state] has for it, so a
    // workout whose route is missing never keeps another one's map.
    final routes = Backup.routeKeys(state.workouts);
    for (final key in {...routes, ...Backup.routeKeys(replaced)}) {
      if (state.documents[key] case final doc?) {
        await health.saveDocument(key, doc);
      } else {
        await health.deleteDocument(key);
      }
    }
    for (final key in Backup.documentKeys) {
      final doc = state.documents[key];
      if (key == 'settings') {
        // Restoring never sends the app back to onboarding.
        await health.saveDocument(key, {...?doc, 'onboarded': true});
      } else if (doc != null) {
        await health.saveDocument(key, doc);
      } else {
        await health.deleteDocument(key);
      }
    }
    await health.saveDocument(_workoutsKey, {
      'items': [for (final w in state.workouts) w.toJson()],
    });
    await health.saveDocument(_routinesKey, {
      'items': [for (final r in state.routines) r.toJson()],
    });
    await health.restoreEntries(state.entries, replace: true);
  }

  /// Re-reads everything; stores start from defaults so removed
  /// documents don't linger in memory.
  Future<void> _reload() async {
    await health.load();
    workouts.reset();
    await workouts.load();
    exercises.reset();
    await exercises.load();
    await notifications.reset();
    await notifications.load();
    await notifications.reschedule();
    await reloadOthers?.call();
  }

  static List<Map<String, Object?>> _items(Map<String, Object?>? doc) =>
      switch (doc?['items']) {
        final List<Object?> list =>
          list
              .whereType<Map<String, Object?>>()
              .where((e) => e['id'] is String)
              .toList(),
        _ => const [],
      };
}
