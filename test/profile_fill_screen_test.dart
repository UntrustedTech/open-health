import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/screens/edit_profile_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/utils/units.dart';

import 'fake_health_source.dart';

void main() {
  final now = DateTime(2026, 10, 24, 12);
  late HealthStore store;
  late FakeHealthSource source;

  setUp(() async {
    final repo = InMemoryHealthRepository();
    store = HealthStore(repo, clock: () => now);
    await store.load();
    source = FakeHealthSource();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sync = HealthSyncService(
      source: source,
      store: store,
      repo: InMemoryHealthRepository(),
      clock: () => now,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: sync),
        ],
        child: const CupertinoApp(home: EditProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapFill(WidgetTester tester) async {
    await tester.tap(find.text('Fill from Health Connect'));
    await tester.pumpAndSettle();
  }

  testWidgets('found values are shown first, then added to the profile', (
    tester,
  ) async {
    source.profile = (
      birthDate: null,
      sex: null,
      bloodType: null,
      heightCm: 168.0,
    );
    await pump(tester);

    await tapFill(tester);
    expect(find.text('Add from Health Connect?'), findsOneWidget);
    final height = Units.height(168);
    expect(find.text('Height: $height', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text(height), findsOneWidget);

    // Nothing is saved until Done.
    expect(store.profile.heightCm, isNull);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(store.profile.heightCm, 168);
  });

  testWidgets('values the user entered are only replaced when asked', (
    tester,
  ) async {
    // Saving waits on real timers, which the test's fake clock never runs.
    await tester.runAsync(
      () => store.updateProfile(const UserProfile(sex: 'Male')),
    );
    source.profile = (
      birthDate: DateTime(1990, 4, 12),
      sex: 'Female',
      bloodType: null,
      heightCm: null,
    );
    await pump(tester);

    await tapFill(tester);
    await tester.tap(find.text('Only Add Missing'));
    await tester.pumpAndSettle();
    expect(find.text('Male'), findsOneWidget);
    expect(find.textContaining('Apr 12, 1990'), findsOneWidget);

    await tapFill(tester);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(find.text('Female'), findsOneWidget);
  });

  testWidgets('says so when there is nothing new or reading fails', (
    tester,
  ) async {
    await pump(tester);

    await tapFill(tester);
    expect(find.text('Nothing to Add'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    source.profile = null;
    await tapFill(tester);
    expect(find.text("Couldn't Read Health Connect"), findsOneWidget);
  });
}
