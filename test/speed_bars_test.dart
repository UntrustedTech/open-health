import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/screens/workouts/workout_detail_screen.dart';

void main() {
  test('speed is averaged into stretches, with gaps left empty', () {
    final start = DateTime(2026, 11, 7, 8);
    final speeds = [
      (time: start, mps: 2.0),
      (time: start.add(const Duration(seconds: 10)), mps: 4.0),
      // Nothing in the middle stretch: a pause.
      (time: start.add(const Duration(seconds: 59)), mps: 6.0),
    ];
    expect(speedBars(speeds, 3), [3.0, null, 6.0]);
  });
}
