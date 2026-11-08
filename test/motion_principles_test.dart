import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/movement.dart';
import 'package:health_app/demo/movements.dart';

/// The near wrist's height in [m] at [t] (smaller is higher).
double wristY(Movement m, double t) => m.skeletonAt(t)[J.wristN].dy;
double hipY(Movement m, double t) => m.skeletonAt(t)[J.pelvis].dy;

void main() {
  group('timing: a rep pauses at each end', () {
    test('still at the start, then moving', () {
      final m = Movements.curl;
      // Only breathing moves it while paused.
      expect(wristY(m, 0.02), closeTo(wristY(m, 0), 0.002));
      expect(wristY(m, 0.3), isNot(closeTo(wristY(m, 0), 0.01)));
    });
  });

  group('anticipation', () {
    test('a squat jump dips before it drives up', () {
      final m = Movements.jumpSquat;
      // Find the start of the drive (the second step: up from the crouch,
      // or the first, whichever goes up).
      final up = m.lowersFirst ? 1 : 0;
      final start = m.timeOf(up), end = m.timeOf(up + 1);
      final rest = hipY(m, start);
      final early = [
        for (var i = 1; i < 12; i++)
          hipY(m, start + (end - start) * (0.18 + 0.82 * i / 40)),
      ];
      // The hips go down (y grows) a little before going up.
      expect(early.reduce((a, b) => a > b ? a : b), greaterThan(rest));
    });

    test('a slow lowering has no counter-move', () {
      final m = Movements.squat;
      final start = m.timeOf(0), end = m.timeOf(1);
      final rest = hipY(m, start);
      for (var i = 0; i <= 20; i++) {
        // Going down: the hips never rise above where they started.
        expect(
          hipY(m, start + (end - start) * i / 20),
          greaterThanOrEqualTo(rest - 1e-6),
        );
      }
    });
  });

  group('arcs: loops flow without stopping', () {
    test('a run never pauses', () {
      final m = Movements.run;
      for (var i = 0; i < 60; i++) {
        final a = m.skeletonAt(i / 60)[J.ankleN];
        final b = m.skeletonAt((i + 1) / 60)[J.ankleN];
        expect((a - b).distance, greaterThan(1e-4), reason: 'frame $i');
      }
    });

    test('the body bobs: higher passing than at contact', () {
      final m = Movements.run;
      expect(hipY(m, m.timeOf(1)), lessThan(hipY(m, m.timeOf(0))));
    });

    test('loops pass through their keyframes', () {
      final m = Movements.cycling;
      final key = Skeleton.solve(m.poses[2], front: false);
      expect(
        (m.skeletonAt(m.timeOf(2))[J.kneeN] - key[J.kneeN]).distance,
        lessThan(1e-6),
      );
    });
  });

  group('follow-through and overlap', () {
    test('the head trails the body and settles past the end', () {
      final m = Movements.squat;
      // Partway down, the head has turned less than the torso has moved.
      final mid = m.timeOf(0) + (m.timeOf(1) - m.timeOf(0)) * 0.45;
      final p = m.poseAt(mid);
      final a = m.poses.first, b = m.poses.last;
      final body = (p.torso - a.torso) / (b.torso - a.torso);
      final head =
          ((p.head ?? p.torso) - (a.head ?? a.torso)) /
          ((b.head ?? b.torso) - (a.head ?? a.torso));
      expect(head, lessThan(body));
    });
  });

  test('breathing lifts the shoulders a little through the cycle', () {
    final m = Movements.plank;
    final lifts = [for (var i = 0; i < 10; i++) m.poseAt(i / 10).lift];
    final range =
        lifts.reduce((a, b) => a > b ? a : b) -
        lifts.reduce((a, b) => a < b ? a : b);
    expect(range, greaterThan(0.002));
    expect(range, lessThan(0.01));
  });
}
