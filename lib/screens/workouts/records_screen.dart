import 'package:flutter/cupertino.dart' hide Text;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/utils/units.dart';

/// Personal bests across all workouts.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Records', builder: (_) => const RecordsScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final r = context.watch<WorkoutStore>().records;
    String? clock(int? s) =>
        s == null ? null : formatClock(Duration(seconds: s));
    final endurance = <(String, String?)>[
      ('Fastest 5K', clock(r.fastest5kSeconds)),
      // The kilometre's time, the same in miles or km.
      ('Fastest Kilometre', clock(r.fastestKmSeconds)),
      (
        'Longest Run',
        r.longestRunMeters == null || r.longestRunMeters == 0
            ? null
            : formatDistance(r.longestRunMeters!),
      ),
      (
        'Longest Ride',
        r.longestRideMeters == null || r.longestRideMeters == 0
            ? null
            : formatDistance(r.longestRideMeters!),
      ),
      ('Longest Workout', clock(r.longestWorkoutSeconds)),
      (
        'Most Volume Lifted',
        r.biggestVolumeKg == null
            ? null
            : Units.weight(r.biggestVolumeKg!, decimals: 0),
      ),
    ];
    final lifts = r.bestLifts.entries.toList()
      ..sort(
        (a, b) =>
            b.value.estimatedOneRepMax.compareTo(a.value.estimatedOneRepMax),
      );
    return LargeTitlePage(
      title: 'Personal Records',
      children: [
        GroupedSection(
          header: 'Endurance',
          hasLeading: false,
          children: [
            for (final (label, value) in endurance)
              InfoRow(title: label, value: value ?? '—'),
          ],
        ),
        GroupedSection(
          header: 'Strength',
          footer: lifts.isEmpty
              ? 'Complete sets in a strength workout to see your best lifts.'
              : 'Estimated one-rep max (Epley formula) from your best set.',
          hasLeading: false,
          children: [
            for (final MapEntry(key: id, value: lift) in lifts)
              CupertinoListTile(
                title: Text(ExerciseLibrary.nameOf(id)),
                subtitle: Text(
                  '${Units.weight(lift.weightKg)} × ${lift.reps} · ${DateFormat.yMMMd().format(lift.date)}',
                ),
                additionalInfo: Text(
                  Units.weight(lift.estimatedOneRepMax, decimals: 0),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
