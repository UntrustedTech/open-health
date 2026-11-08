import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Favorites and foods you created, with a way to remove them.
class SavedFoodsScreen extends StatelessWidget {
  const SavedFoodsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Saved Foods',
      builder: (_) => const SavedFoodsScreen(),
    ),
  );

  Future<void> _deleteCustom(BuildContext context, Food food) async {
    final store = context.read<NutritionStore>();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete ${food.name}?'),
        content: const Text('Entries already in your diary are kept.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) await store.deleteCustom(food.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    final favorites = store.favorites;
    final custom = store.custom;
    Widget tile(Food f, Widget trailing) => CupertinoListTile(
      leading: FoodAvatar(name: f.name, color: foodOrange),
      leadingSize: 34,
      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${f.perServing.kcal.round()} Cal · ${f.displayServing}',
        maxLines: 1,
      ),
      trailing: trailing,
    );
    return LargeTitlePage(
      title: 'Saved Foods',
      children: [
        if (favorites.isEmpty && custom.isEmpty)
          IosCard(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(
              children: [
                IconTile(
                  icon: Icons.star_rounded,
                  color: Palette.yellow,
                  size: 52,
                ),
                const SizedBox(height: 12),
                Text(
                  'Star a food or create your own and it will appear here.',
                  textAlign: TextAlign.center,
                  style: context.subheadline.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        if (favorites.isNotEmpty)
          GroupedSection(
            header: 'Favorites',
            children: [
              for (final f in favorites)
                tile(
                  f,
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(AppTheme.minTapTarget),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      store.toggleFavorite(f);
                    },
                    child: Icon(
                      Icons.star_rounded,
                      color: context.resolve(Palette.yellow),
                      semanticLabel: tr('Remove ${f.name} from favorites'),
                    ),
                  ),
                ),
            ],
          ),
        if (custom.isNotEmpty)
          GroupedSection(
            header: 'My Foods',
            children: [
              for (final f in custom)
                tile(
                  f,
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(AppTheme.minTapTarget),
                    onPressed: () => _deleteCustom(context, f),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: context.destructive,
                      semanticLabel: tr('Delete ${f.name}'),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
