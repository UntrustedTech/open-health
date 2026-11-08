import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:health_app/models/board.dart';
import 'package:health_app/screens/food/food_diary_screen.dart';
import 'package:health_app/screens/health_screen.dart';
import 'package:health_app/screens/workouts/workouts_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/widgets/widget_board.dart';

/// Chooses what each tab shows: opens the tab's widget gallery. Arranging
/// and resizing happen on the tab itself, under Edit.
abstract final class CustomizeTabSheet {
  static Future<void> health(BuildContext context) => BoardGallery.show(
    context,
    tab: BoardTab.health,
    catalog: HealthScreen.catalog(),
  );

  static Future<void> fitness(BuildContext context) => BoardGallery.show(
    context,
    tab: BoardTab.fitness,
    catalog: WorkoutsScreen.catalog(),
  );

  static Future<void> food(BuildContext context) => BoardGallery.show(
    context,
    tab: BoardTab.food,
    catalog: FoodDiaryScreen.catalog(context.read<HealthStore>().today),
  );
}
