import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/screens/storage_locked_app.dart';

void main() {
  testWidgets('a key that can\'t be read offers no way to delete data', (
    tester,
  ) async {
    await tester.pumpWidget(const StorageLockedApp());

    expect(find.text('Health Is Locked'), findsOneWidget);
    expect(find.text('Start Fresh'), findsNothing);
  });

  testWidgets('a missing key offers to start fresh after confirming', (
    tester,
  ) async {
    var started = 0;
    await tester.pumpWidget(
      StorageLockedApp(onStartFresh: () async => started++),
    );

    await tester.tap(find.text('Start Fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(started, 0);

    await tester.tap(find.text('Start Fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete and Start Fresh'));
    await tester.pumpAndSettle();
    expect(started, 1);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });
}
