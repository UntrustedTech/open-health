import 'package:flutter/services.dart';

/// Formatters for a field holding a number: digits and, with [decimal],
/// one `.` or `,`. So "1.2.3" can't be typed (and later read as 0), and
/// the length stays well inside what parses.
List<TextInputFormatter> numberInput({bool decimal = true}) => [
  FilteringTextInputFormatter.allow(
    decimal ? RegExp(r'^\d*[.,]?\d*') : RegExp(r'^\d*'),
  ),
  LengthLimitingTextInputFormatter(9),
];
