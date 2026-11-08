import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/meal_template.dart';
import 'package:health_app/screens/food/add_food_sheet.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/screens/food/food_detail_sheet.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/sheet_scaffold.dart';

Widget _nameField(
  BuildContext context,
  TextEditingController controller,
  String placeholder,
) => CupertinoTextField(
  controller: controller,
  placeholder: placeholder,
  maxLength: 60,
  padding: const EdgeInsets.all(14),
  textCapitalization: TextCapitalization.words,
  decoration: BoxDecoration(
    color: context.cardBackground,
    borderRadius: context.cardBorderRadius(AppTheme.listRadius),
  ),
);

/// Ingredients or items as a list, each removable, with an Add button.
class _PortionList extends StatelessWidget {
  const _PortionList({
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.addLabel,
  });

  final List<FoodPortion> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final String addLabel;

  @override
  Widget build(BuildContext context) => GroupedSection(
    hasLeading: false,
    children: [
      for (final (i, p) in items.indexed)
        InfoRow(
          title: p.food.name,
          subtitle: _amount(p),
          value: '${kcalText(p.nutrients.kcal)} Cal',
          trailing: CupertinoButton(
            padding: const EdgeInsets.only(left: 8),
            minimumSize: const Size.square(AppTheme.minTapTarget),
            onPressed: () => onRemove(i),
            child: Icon(
              Icons.remove_circle_rounded,
              color: context.destructive,
              semanticLabel: tr('Remove ${p.food.name}'),
            ),
          ),
        ),
      InfoRow(
        title: addLabel,
        titleColor: context.tint,
        leading: Icon(Icons.add_rounded, color: context.tint),
        onTap: onAdd,
      ),
    ],
  );

  static String _amount(FoodPortion p) => FoodEntry(
    id: '',
    food: p.food,
    amount: p.amount,
    inGrams: p.inGrams,
    date: DateTime(2000),
    meal: Meal.snack,
  ).amountLabel;
}

/// Creates or edits a saved meal ("My usual breakfast").
class MealTemplateEditor extends StatefulWidget {
  const MealTemplateEditor({
    super.key,
    required this.controller,
    this.template,
    this.items = const [],
  });

  final ScrollController controller;
  final MealTemplate? template;

  /// Starting items for a new meal (e.g. from a diary meal).
  final List<FoodPortion> items;

  static Future<void> show(
    BuildContext context, {
    MealTemplate? template,
    List<FoodPortion> items = const [],
  }) => showCupertinoSheet<void>(
    context: context,
    scrollableBuilder: (context, controller) => MealTemplateEditor(
      controller: controller,
      template: template,
      items: items,
    ),
  );

  @override
  State<MealTemplateEditor> createState() => _MealTemplateEditorState();
}

class _MealTemplateEditorState extends State<MealTemplateEditor> {
  late final _name = TextEditingController(text: widget.template?.name ?? '');
  late final List<FoodPortion> _items = [
    ...?widget.template?.items,
    if (widget.template == null) ...widget.items,
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final p = await AddFoodSheet.pick(context);
    if (p != null && mounted) setState(() => _items.add(p));
  }

  Future<void> _save() async {
    final store = context.read<NutritionStore>();
    final navigator = Navigator.of(context);
    final template = MealTemplate(
      id: widget.template?.id ?? store.newId('t'),
      name: _name.text.trim().isEmpty ? 'My Meal' : _name.text.trim(),
      items: List.unmodifiable(_items.take(MealTemplate.maxItems)),
    );
    HapticFeedback.mediumImpact();
    // Closed first, so a quick second tap can't save a second copy.
    navigator.pop();
    await store.saveTemplate(template);
  }

  Future<void> _delete() async {
    final t = widget.template;
    if (t == null) return;
    final store = context.read<NutritionStore>();
    final navigator = Navigator.of(context);
    final ok = await confirmDestructive(
      context,
      message: 'Delete "${t.name}"? Foods already logged stay.',
      action: 'Delete Meal',
    );
    if (!ok) return;
    await store.deleteTemplate(t.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold(Nutrients.zero, (s, i) => s + i.nutrients);
    return SheetScaffold(
      title: widget.template == null ? 'New Meal' : 'Edit Meal',
      controller: widget.controller,
      leading: SheetAction(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
      trailing: SheetAction(
        label: 'Save',
        primary: true,
        onPressed: _items.isEmpty ? null : _save,
      ),
      children: [
        _nameField(context, _name, tr('Name, e.g. My Usual Breakfast')),
        const BlockLabel('Foods'),
        _PortionList(
          items: _items,
          addLabel: 'Add Food',
          onAdd: _add,
          onRemove: (i) => setState(() => _items.removeAt(i)),
        ),
        if (_items.isNotEmpty) ...[
          const BlockLabel('Total'),
          NutritionFacts(nutrients: total, accent: context.resolve(foodOrange)),
        ],
        if (widget.template != null)
          CupertinoButton(
            onPressed: _delete,
            child: Text(
              'Delete Meal',
              style: context.subheadline.copyWith(color: context.destructive),
            ),
          ),
      ],
    );
  }
}
