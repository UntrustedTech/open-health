import 'dart:math';

import 'package:flutter/painting.dart';

/// Draws a dashed line from [a] to [b]: [on] long, then a gap of [off].
void drawDashedLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  double on = 3.5,
  double off = 3.5,
}) {
  final len = (b - a).distance;
  if (len <= 0) return;
  final dir = (b - a) / len;
  for (var d = 0.0; d < len; d += on + off) {
    canvas.drawLine(a + dir * d, a + dir * min(d + on, len), paint);
  }
}
