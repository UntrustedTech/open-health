import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/screens/habits/habits_screen.dart';

void main() {
  test('a habit gets an icon from its name and keeps its colour', () {
    expect(habitLook('Drink 2L water').icon, Icons.water_drop_rounded);
    expect(habitLook('Morning run').icon, Icons.directions_run_rounded);
    expect(habitLook('Floss').icon, Icons.task_alt_rounded);
    expect(habitLook('Floss').color, habitLook('Floss').color);
    // A chosen look wins; an unknown name falls back to the guess.
    expect(
      habitLook('Floss', (icon: 'pet', color: null)).icon,
      Icons.pets_rounded,
    );
    expect(
      habitLook('Read', (icon: 'gone', color: 'gone')).icon,
      Icons.menu_book_rounded,
    );
  });
}
