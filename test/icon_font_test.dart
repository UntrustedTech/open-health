import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Cupertino widgets draw their chevrons and back arrows with this font.
  // Without it the phone falls back to another font and shows stray
  // characters (often Chinese) where the arrows should be.
  test('the CupertinoIcons font is bundled', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final families = [for (final f in manifest) (f as Map)['family']];
    expect(families, contains('packages/cupertino_icons/CupertinoIcons'));
  });
}
