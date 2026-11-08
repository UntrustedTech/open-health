import 'package:flutter/cupertino.dart';

import 'package:health_app/models/metric_type.dart';
import 'package:health_app/theme/app_theme.dart';

/// A metric's icon in a round pastel chip. It flies into the metric's
/// detail screen when one opens.
class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.type,
    this.size = 28,
    this.hero = false,
  });

  final MetricType type;
  final double size;

  /// Flies to the chip on [type]'s detail screen. Only one chip per
  /// metric on a screen may set it.
  final bool hero;

  static Object heroTag(MetricType type) => 'metric-chip-${type.name}';

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(type.color);
    final chip = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.pastel(c),
      ),
      // Scales with the chip as it flies between sizes.
      child: FittedBox(
        child: Padding(
          padding: EdgeInsets.all(size * 0.22),
          child: Icon(type.icon, color: c),
        ),
      ),
    );
    return hero ? Hero(tag: heroTag(type), child: chip) : chip;
  }
}
