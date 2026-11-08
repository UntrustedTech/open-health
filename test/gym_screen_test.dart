import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/gym.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/screens/gym/check_in_pass.dart';
import 'package:health_app/screens/gym/gym_screen.dart';
import 'package:health_app/screens/gym/gym_widget.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/health_store.dart';

void main() {
  final now = DateTime(2026, 10, 14, 18, 5);
  late HealthStore health;
  late GymStore gym;

  setUp(() async {
    health = HealthStore(InMemoryHealthRepository(), clock: () => now);
    await health.load();
    gym = GymStore(health);
    await gym.load();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: health),
          ChangeNotifierProvider.value(value: gym),
        ],
        child: CupertinoApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  const card = GymMembership(
    gym: 'Iron Works',
    memberName: 'Sam Lee',
    code: 'IW0042',
  );

  testWidgets('without a membership, it asks for one', (tester) async {
    await pump(tester, const GymScreen());

    expect(find.text('Add Your Membership'), findsOneWidget);

    await tester.tap(find.text('Add Your Membership'));
    await tester.pumpAndSettle();
    expect(find.text('Add Membership'), findsOneWidget);
  });

  testWidgets('a membership is added in the editor', (tester) async {
    await pump(tester, const GymScreen());
    await tester.tap(find.text('Add Your Membership'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Gym (e.g. Iron Works Downtown)'),
      'Iron Works',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Or type the code'),
      'IW0042',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(gym.membership?.gym, 'Iron Works');
    expect(gym.membership?.code, 'IW0042');
    expect(gym.membership?.format, CardFormat.code128);
  });

  testWidgets('the editor won\'t save a code its format can\'t show', (
    tester,
  ) async {
    await tester.runAsync(
      () => gym.saveMembership(card.copyWith(format: CardFormat.ean13)),
    );
    await pump(tester, const GymScreen());
    await tester.tap(find.bySemanticsLabel('Edit Membership'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('can\'t be shown as EAN-13'), findsWidgets);
    expect(gym.membership?.format, CardFormat.ean13);
  });

  testWidgets('checking in shows the card and logs the visit once', (
    tester,
  ) async {
    await tester.runAsync(() => gym.saveMembership(card));
    await pump(tester, const GymScreen());

    await tester.tap(find.bySemanticsLabel('Check In'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckInPass), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Checked in at 6:05')), findsOneWidget);
    expect(gym.visits, [now]);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Show Card Again'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Already checked in at 6:05'), findsOneWidget);
    expect(gym.visits, hasLength(1));
  });

  testWidgets('the board widget shows the week and checks in', (tester) async {
    await tester.runAsync(() => gym.saveMembership(card));
    await tester.runAsync(gym.checkIn);
    await pump(
      tester,
      const Center(
        child: SizedBox(width: 380, child: GymWidget(size: WidgetSize.medium)),
      ),
    );

    expect(find.text('Iron Works'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^In at 6:05.*today')), findsOneWidget);

    await tester.tap(find.byType(GymWidget));
    await tester.pumpAndSettle();
    expect(find.byType(CheckInPass), findsOneWidget);
  });
}
