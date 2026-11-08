import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/workout/plate_calculator.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Shows which plates to load on each side of the bar.
class PlateSheet extends StatefulWidget {
  const PlateSheet({super.key, required this.initialKg});

  final double initialKg;

  static Future<void> show(BuildContext context, double kg) =>
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => PlateSheet(initialKg: kg),
      );

  @override
  State<PlateSheet> createState() => _PlateSheetState();
}

class _PlateSheetState extends State<PlateSheet> {
  // Everything here is in the user's units: kg, or lb with pound plates.
  static bool get _lb => Units.imperial;
  static double get _stepBy => _lb ? 5 : 2.5;
  static Map<String, double> get _bars => _lb ? barTypesLb : barTypes;

  late double _target = _lb
      ? (Units.weightOut(widget.initialKg) / 5).round() * 5.0
      : widget.initialKg;
  late double _bar = _initialBar();

  double _initialBar() {
    final kg = context.read<WorkoutStore>().settings.barKg;
    if (!_lb) return kg;
    final name = barTypes.entries.where((e) => e.value == kg).firstOrNull?.key;
    return barTypesLb[name] ?? 45;
  }

  /// Heavier plates get the competition colours, lightest greys.
  static const _palette = [
    Palette.red,
    Palette.blue,
    Palette.yellow,
    Palette.green,
    CupertinoColors.white,
    Palette.grey,
    CupertinoColors.systemGrey2,
  ];

  Color _plateColor(double p) {
    final sizes = _lb ? standardPlatesLb : standardPlates;
    final i = sizes.indexOf(p);
    return _palette[i < 0 ? _palette.length - 1 : i];
  }

  void _step(double by) {
    HapticFeedback.selectionClick();
    setState(() => _target = (_target + by).clamp(0, _lb ? 1100 : 500));
  }

  String _fmt(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<WorkoutStore>().settings;
    final unit = Units.weightUnit;
    final load = platesFor(
      _target,
      barKg: _bar,
      // Owned plates are recorded in kg.
      owned: _lb ? {for (final p in standardPlatesLb) p: 99} : settings.plates,
    );
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: ShapeDecoration(
          color: context.cardBackground,
          shape: AppTheme.squircle(context.cardRadius(AppTheme.radius)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Plate Calculator', style: context.headline),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton(
                  onPressed: () => _step(-_stepBy),
                  child: Icon(
                    Icons.remove_circle_rounded,
                    size: 32,
                    semanticLabel: tr('Lighter'),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_fmt(_target)} $unit',
                      style: context.number(34),
                    ),
                  ),
                ),
                CupertinoButton(
                  onPressed: () => _step(_stepBy),
                  child: Icon(
                    Icons.add_circle_rounded,
                    size: 32,
                    semanticLabel: tr('Heavier'),
                  ),
                ),
              ],
            ),
            AppSegmented<double>(
              groupValue: _bars.containsValue(_bar) ? _bar : null,
              children: {
                for (final e in _bars.entries.take(4))
                  e.value: Text(
                    e.key.replaceAll(' Bar', ''),
                    style: context.footnote,
                  ),
              },
              onValueChanged: (v) {
                if (v != null) setState(() => _bar = v);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 10,
                    color: context.resolve(Palette.grey),
                  ),
                  for (final p in load.perSide)
                    Container(
                      width: Units.weightIn(p) >= 10 ? 18 : 12,
                      height: 40 + Units.weightIn(p) * 2.6,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: ShapeDecoration(
                        color: context.resolve(_plateColor(p)),
                        shape: AppTheme.squircle(4),
                      ),
                    ),
                  Container(
                    width: 14,
                    height: 10,
                    color: context.resolve(Palette.grey),
                  ),
                ],
              ),
            ),
            Text(
              load.perSide.isEmpty
                  ? 'Just the bar (${_fmt(_bar)} $unit).'
                  : 'Each side: ${load.perSide.map(_fmt).join(' + ')} $unit',
              style: context.body,
              textAlign: TextAlign.center,
            ),
            if (!load.exact)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Closest you can load: ${_fmt(load.achievedKg)} $unit',
                  style: context.footnote.copyWith(
                    color: context.resolve(Palette.orange),
                  ),
                ),
              ),
            CupertinoButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
