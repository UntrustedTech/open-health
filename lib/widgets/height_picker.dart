import 'package:flutter/cupertino.dart' hide Text;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';

/// Heights offered, in centimetres (about 3 ft to 8 ft 2 in).
const minHeightCm = 91.0;
const maxHeightCm = 249.0;

/// Asks for a height with wheels: feet and inches for imperial users,
/// centimetres otherwise. Returns centimetres, or null if cancelled.
Future<double?> pickHeight(BuildContext context, double? currentCm) {
  final start = (currentCm ?? 170).clamp(minHeightCm, maxHeightCm);
  return showCupertinoModalPopup<double>(
    context: context,
    builder: (_) => _HeightSheet(startCm: start.toDouble()),
  );
}

class _HeightSheet extends StatefulWidget {
  const _HeightSheet({required this.startCm});

  final double startCm;

  @override
  State<_HeightSheet> createState() => _HeightSheetState();
}

class _HeightSheetState extends State<_HeightSheet> {
  static const _minFeet = 3, _maxFeet = 8;

  late int _cm = widget.startCm.round();
  late final FixedExtentScrollController _first;
  late final FixedExtentScrollController _second;

  /// Untouched wheels return the exact height passed in (no rounding).
  bool _moved = false;
  late int _feet;
  late int _inches;

  @override
  void initState() {
    super.initState();
    final totalInches = (widget.startCm / Units.cmPerInch).round();
    _feet = (totalInches ~/ 12).clamp(_minFeet, _maxFeet);
    _inches = totalInches - _feet * 12;
    if (_inches < 0 || _inches > 11) _inches = _inches.clamp(0, 11);
    _first = FixedExtentScrollController(
      initialItem: Units.imperial
          ? _feet - _minFeet
          : (_cm - minHeightCm.round()).clamp(0, _cmCount - 1),
    );
    _second = FixedExtentScrollController(initialItem: _inches);
  }

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  static final _cmCount = maxHeightCm.round() - minHeightCm.round() + 1;

  double get _resultCm => Units.imperial
      ? (_feet * 12 + _inches) * Units.cmPerInch
      : _cm.toDouble();

  Widget _wheel({
    required int count,
    required FixedExtentScrollController controller,
    required String Function(int i) label,
    required ValueChanged<int> onChanged,
    required String semantics,
  }) => Expanded(
    child: Semantics(
      label: semantics,
      child: CupertinoPicker(
        itemExtent: 38,
        scrollController: controller,
        onSelectedItemChanged: (i) {
          _moved = true;
          onChanged(i);
        },
        children: [
          for (var i = 0; i < count; i++)
            Center(child: Text(label(i), style: context.title3)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final minCm = minHeightCm.round();
    return Container(
      height: 320,
      color: context.cardBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Text(
                    'Height',
                    textAlign: TextAlign.center,
                    style: context.headline,
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _moved ? _resultCm : widget.startCm,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Row(
                children: Units.imperial
                    ? [
                        _wheel(
                          count: _maxFeet - _minFeet + 1,
                          controller: _first,
                          label: (i) => '${_minFeet + i} ft',
                          onChanged: (i) => _feet = _minFeet + i,
                          semantics: 'Feet',
                        ),
                        _wheel(
                          count: 12,
                          controller: _second,
                          label: (i) => '$i in',
                          onChanged: (i) => _inches = i,
                          semantics: 'Inches',
                        ),
                      ]
                    : [
                        _wheel(
                          count: _cmCount,
                          controller: _first,
                          label: (i) => '${minCm + i} cm',
                          onChanged: (i) => _cm = minCm + i,
                          semantics: 'Centimetres',
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
