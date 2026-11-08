import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/workout.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/screens/workouts/set_row.dart';
import 'package:health_app/theme/app_theme.dart';

/// Rows keyed by position, like the live workout's strength panel.
class _Sets extends StatefulWidget {
  const _Sets();

  @override
  State<_Sets> createState() => _SetsState();
}

class _SetsState extends State<_Sets> {
  var sets = const [
    SetLog(reps: 5, weightKg: 100),
    SetLog(reps: 6, weightKg: 110),
    SetLog(reps: 7, weightKg: 120),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, s) in sets.indexed)
          SetRow(
            key: ValueKey('row-$i'),
            number: i + 1,
            set: s,
            previous: null,
            color: Palette.orange,
            timed: false,
            effort: EffortMode.off,
            onChanged: (_) {},
            onToggle: () {},
            onCopy: () {},
            onDelete: () => setState(() => sets = [...sets]..removeAt(i)),
          ),
      ],
    );
  }
}

void main() {
  testWidgets('swipe-deleting the first set leaves the other two visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(home: CupertinoPageScaffold(child: _Sets())),
    );

    // Swipe from the set number, clear of the text fields.
    final row = tester.getRect(find.byKey(const ValueKey('row-0')));
    await tester.flingFrom(
      Offset(row.left + 20, row.center.dy),
      const Offset(-500, 0),
      2000,
    );
    await tester.pumpAndSettle();

    expect(find.byType(SetRow), findsNWidgets(2));
    expect(find.text('110'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('100'), findsNothing);
  });
}
