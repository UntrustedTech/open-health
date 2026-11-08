import 'package:flutter/foundation.dart';

import 'package:health_app/models/exercise_library.dart';

/// A ready-made programme: routines plus when to do them. Applying one
/// copies the routines, so they can be edited freely.
@immutable
class StarterPlan {
  const StarterPlan({
    required this.name,
    required this.summary,
    required this.routines,
    required this.days,
  });

  final String name;
  final String summary;
  final List<Routine> routines;

  /// Weekday → index into [routines].
  final Map<int, int> days;

  static const all = [pushPullLegs, upperLower, fullBody, fiveByFive];

  static const pushPullLegs = StarterPlan(
    name: 'Push / Pull / Legs',
    summary: 'Three focused days, each muscle trained once a week. Great for building muscle.',
    days: {DateTime.monday: 0, DateTime.wednesday: 1, DateTime.friday: 2},
    routines: [
      Routine(
        id: 'ppl_push',
        name: 'Push',
        items: [
          RoutineItem('0025', sets: 4, reps: 8),
          RoutineItem('ohp', reps: 8),
          RoutineItem('0314', reps: 10),
          RoutineItem('0334', reps: 15),
          RoutineItem('0201', reps: 12),
        ],
      ),
      Routine(
        id: 'ppl_pull',
        name: 'Pull',
        items: [
          RoutineItem('0032', reps: 5),
          RoutineItem('0652', reps: 8),
          RoutineItem('0027', reps: 8),
          RoutineItem('0203', reps: 15),
          RoutineItem('0294', reps: 12),
        ],
      ),
      Routine(
        id: 'ppl_legs',
        name: 'Legs',
        items: [
          RoutineItem('0043', sets: 4, reps: 6),
          RoutineItem('0085', reps: 8),
          RoutineItem('0739', reps: 12),
          RoutineItem('0586', reps: 12),
          RoutineItem('0605', reps: 15),
        ],
      ),
    ],
  );

  static const upperLower = StarterPlan(
    name: 'Upper / Lower',
    summary:
        'Four days, upper and lower body twice a week. A balanced classic.',
    days: {
      DateTime.monday: 0,
      DateTime.tuesday: 1,
      DateTime.thursday: 0,
      DateTime.friday: 1,
    },
    routines: [
      Routine(
        id: 'ul_upper',
        name: 'Upper Body',
        items: [
          RoutineItem('0025', sets: 4, reps: 8),
          RoutineItem('0027', sets: 4, reps: 8),
          RoutineItem('ohp', reps: 10),
          RoutineItem('2330', reps: 10),
          RoutineItem('0294', reps: 12),
          RoutineItem('0201', reps: 12),
        ],
      ),
      Routine(
        id: 'ul_lower',
        name: 'Lower Body',
        items: [
          RoutineItem('0043', sets: 4, reps: 6),
          RoutineItem('0085', reps: 8),
          RoutineItem('0739', reps: 12),
          RoutineItem('0586', reps: 12),
          RoutineItem('0605', reps: 15),
          RoutineItem('plank', reps: 45),
        ],
      ),
    ],
  );

  static const fullBody = StarterPlan(
    name: 'Full Body',
    summary:
        'Three whole-body sessions, alternating A and B. Ideal for beginners.',
    days: {DateTime.monday: 0, DateTime.wednesday: 1, DateTime.friday: 0},
    routines: [
      Routine(
        id: 'fb_a',
        name: 'Full Body A',
        items: [
          RoutineItem('0043', reps: 8),
          RoutineItem('0025', reps: 8),
          RoutineItem('0027', reps: 8),
          RoutineItem('plank', reps: 45),
        ],
      ),
      Routine(
        id: 'fb_b',
        name: 'Full Body B',
        items: [
          RoutineItem('0032', reps: 5),
          RoutineItem('ohp', reps: 8),
          RoutineItem('0652', reps: 8),
          RoutineItem('1460', reps: 10),
        ],
      ),
    ],
  );

  static const fiveByFive = StarterPlan(
    name: '5×5 Strength',
    summary:
        'Heavy compound lifts for 5 sets of 5, adding weight each session.',
    days: {DateTime.monday: 0, DateTime.wednesday: 1, DateTime.friday: 0},
    routines: [
      Routine(
        id: 'sl_a',
        name: '5×5 Workout A',
        items: [
          RoutineItem('0043', sets: 5, reps: 5),
          RoutineItem('0025', sets: 5, reps: 5),
          RoutineItem('0027', sets: 5, reps: 5),
        ],
      ),
      Routine(
        id: 'sl_b',
        name: '5×5 Workout B',
        items: [
          RoutineItem('0043', sets: 5, reps: 5),
          RoutineItem('ohp', sets: 5, reps: 5),
          RoutineItem('0032', sets: 1, reps: 5),
        ],
      ),
    ],
  );
}
