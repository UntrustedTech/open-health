import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/widgets/number_input.dart';

/// What a field holding [before] shows after the user types to [after].
String _type(String before, String after, {bool decimal = true}) {
  var value = TextEditingValue(
    text: after,
    selection: TextSelection.collapsed(offset: after.length),
  );
  for (final f in numberInput(decimal: decimal)) {
    value = f.formatEditUpdate(TextEditingValue(text: before), value);
  }
  return value.text;
}

void main() {
  test('a number field takes one decimal point and nothing else', () {
    expect(_type('12', '12.5'), '12.5');
    expect(_type('12,5', '12,5'), '12,5');
    expect(_type('1.2', '1.2.'), '1.2');
    expect(_type('1', '1a'), '1');
    expect(_type('5', '5.', decimal: false), '5');
    expect(_type('', '1234567890123'), '123456789');
  });
}
