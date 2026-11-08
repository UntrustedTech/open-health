import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/screens/food/micronutrient_widgets.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/screens/food/food_settings_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/models/board.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/screens/health/metric_widget.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/widget_board.dart';
import 'package:health_app/widgets/shell_tabs.dart';

export 'package:health_app/screens/food/food_cards.dart'
    show
        CalorieBudgetCard,
        carbsColor,
        fatColor,
        foodOrange,
        kcalText,
        proteinColor;

/// Tells the Food tab to show today when another screen opens it.
class _ShowToday extends ChangeNotifier {
  void fire() => notifyListeners();
}

final _showToday = _ShowToday();

/// The food diary for one day: calories left, macros and each meal.
class FoodDiaryScreen extends StatefulWidget {
  const FoodDiaryScreen({super.key});

  /// Switches to the Food tab (or pushes the diary outside the tabs).
  static Future<void> open(BuildContext context) async {
    final tabs = ShellTabs.maybeOf(context);
    if (tabs != null) {
      _showToday.fire();
      tabs.select(ShellTabs.food);
      return;
    }
    await Navigator.of(context).push(
      AppRoute<void>(title: 'Food', builder: (_) => const FoodDiaryScreen()),
    );
  }

  /// Everything the Food board can show for [day]: the calorie budget,
  /// macros, each meal, and nutrition data as metric widgets.
  static List<BoardEntry> catalog(DateTime day) => [
    BoardEntry(
      id: BoardIds.calories,
      label: 'Calories',
      icon: Icons.local_fire_department_rounded,
      color: foodOrange,
      group: 'Food',
      detail: 'Your budget, food and workouts',
      preferred: WidgetSize.large,
      builder: (context, size) => size == WidgetSize.large
          ? CalorieBudgetCard(day: day)
          : CaloriesSmall(day: day, size: size),
    ),
    BoardEntry(
      id: BoardIds.macros,
      label: 'Macros',
      icon: Icons.donut_small_rounded,
      color: proteinColor,
      group: 'Food',
      detail: 'Protein, carbs and fat',
      preferred: WidgetSize.large,
      builder: (context, size) => size == WidgetSize.large
          ? MacrosCard(day: day)
          : MacrosSmall(day: day, size: size),
    ),
    BoardEntry(
      id: BoardIds.micros,
      label: 'Vitamins & Minerals',
      icon: Icons.eco_rounded,
      color: microColor,
      group: 'Food',
      detail: '16 vitamins and minerals against the Daily Value',
      preferred: WidgetSize.large,
      builder: (context, size) => size == WidgetSize.large
          ? DayMicronutrientsCard(day: day)
          : MicronutrientsSmall(day: day, size: size),
    ),
    for (final meal in Meal.values)
      BoardEntry(
        id: BoardIds.meal(meal),
        label: meal.label,
        icon: meal.icon,
        color: meal.color,
        group: 'Meals',
        preferred: WidgetSize.large,
        builder: (context, size) => size != WidgetSize.large
            ? MealSmall(meal: meal, day: day, size: size)
            : MealCard(
                meal: meal,
                day: day,
                entries: [
                  for (final e in context.watch<NutritionStore>().entriesOn(
                    day,
                  ))
                    if (e.meal == meal) e,
                ],
              ),
      ),
    ...metricEntries(categories: BoardIds.metricCategories(BoardTab.food)),
  ];

  @override
  State<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends State<FoodDiaryScreen> {
  final _board = BoardController();
  late DateTime _day = context.read<HealthStore>().today;

  /// The last "today" seen, to follow the date past midnight.
  late DateTime _today = _day;

  @override
  void initState() {
    super.initState();
    _showToday.addListener(_goToToday);
  }

  @override
  void dispose() {
    _showToday.removeListener(_goToToday);
    _board.dispose();
    super.dispose();
  }

  void _goToToday() {
    if (!mounted) return;
    setState(() => _day = context.read<HealthStore>().today);
  }

  void _move(int days) {
    HapticFeedback.selectionClick();
    _select(DateTime(_day.year, _day.month, _day.day + days));
  }

  void _select(DateTime day) => setState(() => _day = day);

  @override
  Widget build(BuildContext context) {
    context.watch<NutritionStore>();
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    if (today != _today) {
      // A new day began while the diary showed today: show the new today.
      if (_day == _today) _day = today;
      _today = today;
    }
    final isToday = _day == today;
    return LargeTitlePage(
      title: 'Food',
      trailing: BoardEditControls(
        controller: _board,
        tab: BoardTab.food,
        catalog: () => FoodDiaryScreen.catalog(_day),
        label: 'Edit Food',
        trailing: HeaderButton(
          icon: Icons.settings_rounded,
          semanticLabel: tr('Food Settings'),
          onTap: () => FoodSettingsScreen.open(context),
        ),
      ),
      children: [
        // One compact row: previous, the week, next; the day above.
        IosCard(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Column(
            children: [
              Text(
                '${isToday
                    ? 'TODAY'
                    : formatDay(_day, today) == 'Yesterday'
                    ? 'YESTERDAY'
                    : DateFormat.EEEE().format(_day).toUpperCase()}'
                ' · ${DateFormat.MMMMd().format(_day).toUpperCase()}',
                textAlign: TextAlign.center,
                style: context.overline,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _Chevron(
                    icon: Icons.chevron_left_rounded,
                    label: 'Previous day',
                    onTap: () => _move(-1),
                  ),
                  Expanded(
                    child: DayStrip(day: _day, today: today, onSelect: _select),
                  ),
                  _Chevron(
                    icon: Icons.chevron_right_rounded,
                    label: 'Next day',
                    onTap: isToday ? null : () => _move(1),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Keyed, so it isn't rebuilt (and faded in again) when content above
        // it comes and goes.
        Appear(
          key: const ValueKey('board'),
          child: WidgetBoard(
            tab: BoardTab.food,
            catalog: FoodDiaryScreen.catalog(_day),
            controller: _board,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Food data from Open Food Facts (openfoodfacts.org), available '
            'under the Open Database License. Values can be wrong; check '
            'the label.',
            style: context.caption1.copyWith(color: context.tertiaryLabel),
          ),
        ),
      ],
    );
  }
}

/// A round previous/next button.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.square(AppTheme.minTapTarget),
    onPressed: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: ShapeDecoration(
        color: context.fillColor,
        shape: const CircleBorder(),
      ),
      child: Icon(
        icon,
        size: 20,
        semanticLabel: label,
        color: onTap == null ? context.tertiaryLabel : context.labelColor,
      ),
    ),
  );
}
