import 'package:health_app/export/backup.dart';
import 'package:health_app/export/data_export.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';

/// Everything a backup holds, as JSON (not yet encrypted), and how many
/// stored documents couldn't be read and were left out.
Future<({String json, int skipped})> buildBackupJson({
  required HealthStore health,
  required WorkoutStore workouts,
  required DateTime now,
}) async {
  final keys = [...Backup.documentKeys, ...Backup.routeKeys(workouts.all)];
  var skipped = 0;
  final documents = await health.loadDocuments(
    keys,
    onSkipped: (_) => skipped++,
  );
  final json = exportAllData(
    exportedAt: now,
    entries: health.allEntries,
    workouts: workouts.all,
    routines: workouts.routines.where((r) => !r.builtIn).toList(),
    documents: documents,
  );
  return (json: json, skipped: skipped);
}
