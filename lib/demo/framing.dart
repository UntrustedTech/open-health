import 'dart:ui';

import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/movement.dart';

/// Who the demonstrating figure looks like, from the user's profile.
enum BodyStyle {
  /// Broader shoulders, more muscle.
  male,

  /// Narrower shoulders, wider hips, a ponytail and a sports top.
  female,

  /// In between: for "Other" or not set.
  neutral;

  /// From the profile's sex ("Female", "Male", "Other" or empty).
  static BodyStyle fromSex(String sex) => switch (sex.trim().toLowerCase()) {
    'male' => male,
    'female' => female,
    _ => neutral,
  };
}

/// What a movement's drawing covers, so it can be framed without ever
/// jumping or clipping as it moves.
abstract final class Framing {
  static final _bounds = <(String, Hold), Rect>{};

  /// Everything the cycle touches: the body, what's held, the scenery.
  static Rect boundsOf(Movement m, Hold hold) =>
      _bounds.putIfAbsent((m.id, hold), () {
        var r = const Rect.fromLTRB(-0.1, -0.1, 0.1, 0);
        void add(Offset p, [double pad = 0]) {
          r = r.expandToInclude(Rect.fromCircle(center: p, radius: pad));
        }

        for (var i = 0; i < 24; i++) {
          final s = m.skeletonAt(i / 24);
          for (final p in s.points) {
            add(p, 0.07);
          }
          add(s[J.head], Body.headRadius + 0.03);
          for (final (p, radius) in _held(m, hold, s)) {
            add(p, radius);
          }
        }
        for (final sc in m.scenery) {
          for (final p in sc.points) {
            add(p, 0.035);
          }
        }
        if (m.anchor case final a?) add(a, 0.04);
        return r;
      });

  /// Where held equipment sits: in the hands, or across the shoulders.
  static Offset heldAt(Movement m, Skeleton s) => m.slot == Slot.shoulders
      ? s[J.neck] + const Offset(-0.035, 0.03)
      : s[J.wristN];

  static List<(Offset, double)> _held(Movement m, Hold h, Skeleton s) {
    final at = heldAt(m, s);
    return switch (h) {
      Hold.barbell when m.front => [
        (Offset(s[J.pelvis].dx - 0.36, at.dy), 0.11),
        (Offset(s[J.pelvis].dx + 0.36, at.dy), 0.11),
      ],
      Hold.barbell => [(at, 0.1)],
      Hold.dumbbells => [(s[J.wristN], 0.06), (s[J.wristF], 0.06)],
      Hold.kettlebell => [(at + const Offset(0, 0.06), 0.06)],
      Hold.ball => [(at, 0.08)],
      Hold.platform => [(s[J.toeN], 0.11)],
      Hold.pad => [(s[J.ankleN], 0.04)],
      Hold.cable || Hold.band || Hold.none => const [],
    };
  }
}
