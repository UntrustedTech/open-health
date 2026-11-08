import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/screens/acknowledgements_screen.dart';
import 'package:health_app/screens/legal_screen.dart';

void main() {
  testWidgets('legal terms come first, open-source licences under Other', (
    tester,
  ) async {
    await tester.pumpWidget(const CupertinoApp(home: AcknowledgementsScreen()));
    await tester.pumpAndSettle();

    final terms = tester.getTopLeft(find.text('Terms of Use')).dy;
    final dmca = tester.getTopLeft(find.text('Copyright & DMCA')).dy;
    final other = tester.getTopLeft(find.text('OTHER')).dy;
    expect(terms, lessThan(dmca));
    expect(dmca, lessThan(other));

    await tester.tap(find.text('Terms of Use'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
  });
}
