import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/screens/startup_failed_app.dart';

void main() {
  testWidgets('shows what failed and copies it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const StartupFailedApp(details: 'storage key: TimeoutException'),
    );

    expect(find.text('Health Couldn\'t Start'), findsOneWidget);
    expect(find.text('storage key: TimeoutException'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    expect(copied, 'storage key: TimeoutException');
  });
}
