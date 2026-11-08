import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/micronutrient.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/board_tiles.dart';

/// Vitamins and minerals' colour on the Food tab.
const microColor = Palette.green;

/// "12 mg", "0.4 µg": to two significant figures under 10.
String microAmount(Micronutrient m, double v) {
  final text = v >= 10
      ? '${v.round()}'
      : v >= 1
      ? v.toStringAsFixed(1)
      : v.toStringAsFixed(v >= 0.1 ? 2 : 3);
  return '$text ${m.unit}';
}

/// "13%" of the Daily Value.
String microPercent(Micronutrient m, double v) =>
    '${(m.share(v) * 100).round()}%';

/// Each known vitamin and mineral with its amount and share of the Daily
/// Value: vitamins first, then minerals.
class MicronutrientList extends StatelessWidget {
  const MicronutrientList({super.key, required this.amounts});

  final Map<Micronutrient, double> amounts;

  @override
  Widget build(BuildContext context) {
    final vitamins = [
      for (final m in Micronutrient.values)
        if (m.isVitamin && (amounts[m] ?? 0) > 0) m,
    ];
    final minerals = [
      for (final m in Micronutrient.values)
        if (!m.isVitamin && (amounts[m] ?? 0) > 0) m,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, list) in [
          ('Vitamins', vitamins),
          ('Minerals', minerals),
        ])
          if (list.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                title,
                style: context.footnote.copyWith(
                  color: context.secondaryLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final m in list) _MicroRow(m: m, amount: amounts[m]!),
          ],
      ],
    );
  }
}

class _MicroRow extends StatelessWidget {
  const _MicroRow({required this.m, required this.amount});

  final Micronutrient m;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final color = context.resolve(microColor);
    return Semantics(
      label:
          '${tr(m.label)}, ${microAmount(m, amount)}, '
          '${tr('{0} of the daily value').replaceFirst('{0}', microPercent(m, amount))}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(m.label, style: context.subheadline)),
                Text(
                  microAmount(m, amount),
                  style: context.subheadline.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    microPercent(m, amount),
                    textAlign: TextAlign.end,
                    style: context.subheadline.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            CapsuleProgress(value: m.share(amount), color: color, height: 4),
          ],
        ),
      ),
    );
  }
}

/// A food's vitamins and minerals, in the food's details.
class MicronutrientCard extends StatelessWidget {
  const MicronutrientCard({super.key, required this.amounts});

  final Map<Micronutrient, double> amounts;

  @override
  Widget build(BuildContext context) => IosCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vitamins & Minerals', style: context.headline),
        MicronutrientList(amounts: amounts),
        const SizedBox(height: 6),
        Text(
          '% of the Daily Value for adults.',
          style: context.caption1.copyWith(color: context.tertiaryLabel),
        ),
      ],
    ),
  );
}

/// The day's vitamins and minerals on the Food tab, from the foods that
/// list them.
class DayMicronutrientsCard extends StatelessWidget {
  const DayMicronutrientsCard({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    final amounts = store.totalOn(day).micros;
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.eco_rounded, color: microColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Vitamins & Minerals', style: context.headline),
              ),
            ],
          ),
          if (amounts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Log foods from the food list or with a barcode to see '
                'vitamins and minerals here.',
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            MicronutrientList(amounts: amounts),
            const SizedBox(height: 6),
            Text(
              'From foods that list them. % of the Daily Value for adults.',
              style: context.caption1.copyWith(color: context.tertiaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small and medium: how many of the 16 reach their Daily Value.
class MicronutrientsSmall extends StatelessWidget {
  const MicronutrientsSmall({
    super.key,
    required this.day,
    this.size = WidgetSize.small,
  });

  final DateTime day;
  final WidgetSize size;

  @override
  Widget build(BuildContext context) {
    final amounts = context.watch<NutritionStore>().totalOn(day).micros;
    final met = [
      for (final e in amounts.entries)
        if (e.key.share(e.value) >= 1) e.key,
    ];
    final lowest = [
      for (final m in Micronutrient.values) (m, m.share(amounts[m] ?? 0)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final total = Micronutrient.values.length;
    return StatWidget(
      size: size,
      icon: Icons.eco_rounded,
      color: microColor,
      title: 'Vitamins',
      semanticLabel:
          'Vitamins and minerals: ${met.length} of $total at the daily value',
      value: StatValue('${met.length}', unit: 'of $total', size: size),
      caption: amounts.isEmpty ? 'None logged yet' : 'At the daily value',
      smallVisual: CapsuleProgress(
        value: met.length / total,
        color: context.resolve(microColor),
        height: 5,
      ),
      facts: [
        for (final (m, share) in lowest.take(3))
          (label: m.label, value: '${(share * 100).round()}%'),
      ],
    );
  }
}
