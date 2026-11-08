import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/screens/workouts/custom_exercise_sheet.dart'
    show capitalize;
import 'package:health_app/l10n/text.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Pick the equipment you have, so the library can hide the rest.
class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Equipment', builder: (_) => const EquipmentScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExerciseStore>();
    final owned = store.ownedEquipment;
    final all = store.catalog.equipmentTypes;
    return LargeTitlePage(
      title: 'Equipment I Own',
      children: [
        GroupedSection(
          footer: owned.isEmpty
              ? 'Nothing selected: the library shows every exercise.'
              : 'Turn on "Only Equipment I Own" in the library to hide the rest.',
          hasLeading: false,
          children: [
            for (final e in all)
              CupertinoListTile(
                title: Text(capitalize(e)),
                trailing: owned.contains(e)
                    ? Icon(Icons.check_rounded, color: context.tint)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final next = {...owned};
                  if (!next.remove(e)) next.add(e);
                  store.setOwnedEquipment(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}
