import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/number_input.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/micronutrient.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/sheet_scaffold.dart';

/// Create a food from its label, or quick-add calories. Returns the food.
class CustomFoodSheet extends StatefulWidget {
  const CustomFoodSheet({
    super.key,
    required this.controller,
    this.quickAdd = false,
    this.barcode,
  });

  final ScrollController controller;

  /// Just calories (and optional macros) without saving a food.
  final bool quickAdd;
  final String? barcode;

  static Future<Food?> show(
    BuildContext context, {
    bool quickAdd = false,
    String? barcode,
  }) => showCupertinoSheet<Food>(
    context: context,
    scrollableBuilder: (context, controller) => CustomFoodSheet(
      controller: controller,
      quickAdd: quickAdd,
      barcode: barcode,
    ),
  );

  @override
  State<CustomFoodSheet> createState() => _CustomFoodSheetState();
}

class _CustomFoodSheetState extends State<CustomFoodSheet> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _serving = TextEditingController(text: tr('1 serving'));
  final _grams = TextEditingController();

  /// A drink: its serving is a volume (ml, or fl oz for imperial users).
  bool _liquid = false;
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _satFat = TextEditingController();
  final _sodium = TextEditingController();

  /// Vitamins and minerals, shown once "Add Vitamins & Minerals" is tapped.
  final _micros = {
    for (final m in Micronutrient.values) m: TextEditingController(),
  };
  bool _showMicros = false;
  String? _error;

  List<TextEditingController> get _all => [
    _name,
    _brand,
    _serving,
    _grams,
    _kcal,
    _protein,
    _carbs,
    _fat,
    _fiber,
    _sugar,
    _satFat,
    _sodium,
    ..._micros.values,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  static double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  /// Set once saving starts, so a double tap saves and closes once.
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final quick = widget.quickAdd;
    final name = _name.text.trim();
    final kcal = _num(_kcal);
    final error = !quick && name.isEmpty
        ? 'Enter a name.'
        : kcal <= 0 || kcal > 10000
        ? 'Enter the calories (up to 10,000).'
        : null;
    if (error != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = error);
      return;
    }
    _saving = true;
    final store = context.read<NutritionStore>();
    final navigator = Navigator.of(context);
    // Drinks are kept in ml; imperial users enter fluid ounces.
    final grams = _liquid && Units.imperial
        ? _num(_grams) * Units.mlPerFlOz
        : _num(_grams);
    final food = Food(
      id: store.newId(quick ? 'q' : 'c'),
      name: name.isEmpty ? 'Quick Add' : name,
      brand: _brand.text.trim(),
      barcode: widget.barcode,
      servingLabel: quick
          ? '1 serving'
          : (_serving.text.trim().isEmpty
                ? tr('1 serving')
                : _serving.text.trim()),
      servingGrams: grams >= 1 && grams < 5000 ? grams : null,
      perServing: Nutrients(
        kcal: kcal,
        protein: _num(_protein).clamp(0, 2000),
        carbs: _num(_carbs).clamp(0, 2000),
        fat: _num(_fat).clamp(0, 2000),
        fiber: _num(_fiber).clamp(0, 2000),
        sugar: _num(_sugar).clamp(0, 2000),
        saturatedFat: _num(_satFat).clamp(0, 2000),
        sodiumMg: _num(_sodium).clamp(0, 100000),
        micros: {
          for (final MapEntry(key: m, value: c) in _micros.entries)
            if (_num(c) case final v when v > 0) m: v.clamp(0, m.maxPer100g),
        },
      ),
      source: quick ? FoodSource.quickAdd : FoodSource.custom,
      liquid: !quick && _liquid,
    );
    if (!quick) await store.saveCustom(food);
    navigator.pop(food);
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? unit,
    bool number = false,
    String? placeholder,
    Color? dot,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        if (dot != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: context.resolve(dot),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: dot == null ? 130 : 114,
          child: Text(label, style: context.body),
        ),
        Expanded(
          child: CupertinoTextField.borderless(
            controller: c,
            textAlign: TextAlign.end,
            placeholder: placeholder ?? (number ? '0' : ''),
            keyboardType: number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            textCapitalization: number
                ? TextCapitalization.none
                : TextCapitalization.sentences,
            inputFormatters: number
                ? numberInput()
                : [LengthLimitingTextInputFormatter(60)],
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: Text(
              unit,
              style: context.body.copyWith(color: context.secondaryLabel),
            ),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final quick = widget.quickAdd;
    final color = quick ? Palette.yellow : Palette.violet;
    return SheetScaffold(
      title: quick ? 'Quick Add' : 'New Food',
      controller: widget.controller,
      leading: SheetAction(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      trailing: SheetAction(label: 'Next', primary: true, onPressed: _save),
      children: [
        IosCard(
          child: Row(
            children: [
              IconTile(
                icon: quick ? Icons.bolt_rounded : Icons.edit_note_rounded,
                color: color,
                size: 44,
                solid: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  quick
                      ? 'Log calories without the details. Macros are '
                            'optional.'
                      : 'Enter the values per serving from the label. It '
                            'is saved to My Foods.',
                  style: context.subheadline.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.barcode case final b?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Barcode $b — enter the values from the label.',
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
        GroupedSection(
          hasLeading: false,
          footer: _error,
          children: [
            _field(
              _name,
              'Name',
              placeholder: quick ? 'Optional' : 'e.g. Oat Bar',
            ),
            if (!quick) ...[
              _field(_brand, 'Brand', placeholder: tr('Optional')),
              CupertinoListTile(
                title: const Text('Drink'),
                subtitle: const Text('Measured by volume'),
                trailing: CupertinoSwitch(
                  value: _liquid,
                  // A number typed as grams isn't a volume.
                  onChanged: (v) => setState(() {
                    _liquid = v;
                    _grams.clear();
                  }),
                ),
              ),
              _field(_serving, 'Serving'),
              _field(
                _grams,
                _liquid ? 'Serving Size' : 'Serving Weight',
                unit: !_liquid
                    ? 'g'
                    : Units.imperial
                    ? 'fl oz'
                    : 'ml',
                number: true,
                placeholder: tr('Optional'),
              ),
            ],
            _field(_kcal, 'Calories', unit: 'Cal', number: true),
          ],
        ),
        GroupedSection(
          header: quick ? 'Macros (Optional)' : 'Per Serving',
          hasLeading: false,
          children: [
            _field(
              _protein,
              'Protein',
              unit: 'g',
              number: true,
              dot: proteinColor,
            ),
            _field(
              _carbs,
              'Carbohydrates',
              unit: 'g',
              number: true,
              dot: carbsColor,
            ),
            _field(_fat, 'Fat', unit: 'g', number: true, dot: fatColor),
            if (!quick) ...[
              _field(_satFat, 'Saturated Fat', unit: 'g', number: true),
              _field(_fiber, 'Fiber', unit: 'g', number: true),
              _field(_sugar, 'Sugars', unit: 'g', number: true),
              _field(_sodium, 'Sodium', unit: 'mg', number: true),
            ],
          ],
        ),
        if (!quick)
          if (_showMicros)
            GroupedSection(
              header: 'Vitamins & Minerals',
              footer: 'Optional. Fill in any the label lists.',
              hasLeading: false,
              children: [
                for (final m in Micronutrient.values)
                  _field(_micros[m]!, m.label, unit: m.unit, number: true),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CupertinoButton(
                onPressed: () => setState(() => _showMicros = true),
                child: const Text('Add Vitamins & Minerals'),
              ),
            ),
      ],
    );
  }
}
