import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/workout.dart';
import 'package:health_app/platform/home_widgets.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';

void main() {
  test('pending water parses and skips bad items', () {
    final t = DateTime(2026, 10, 11, 9).millisecondsSinceEpoch;
    final items = HomeWidgets.parsePending('$t:250,junk,$t:x,$t:99999');

    expect(items.map((i) => i.$2), [250, 2000]);
    expect(items.first.$1, DateTime(2026, 10, 11, 9));
    expect(HomeWidgets.parsePending(null), isEmpty);
  });

  test('only allowed workout links are accepted', () {
    expect(
      HomeWidgets.startTypeFrom(Uri.parse('health://workout/start?type=run')),
      WorkoutType.run,
    );
    expect(
      HomeWidgets.startTypeFrom(Uri.parse('health://workout/start?type=yoga')),
      isNull,
    );
    expect(
      HomeWidgets.startTypeFrom(Uri.parse('https://evil.example/workout')),
      isNull,
    );
  });

  test('iPhone widget links carry the plugin\'s marker', () {
    expect(
      HomeWidgets.startTypeFrom(
        Uri.parse('health://workout/start?type=run&homeWidget'),
      ),
      WorkoutType.run,
    );
    expect(
      HomeWidgets.isFastingLink(Uri.parse('health://fasting?homeWidget')),
      isTrue,
    );
  });

  test('the Live Activity link goes back to the workout', () {
    expect(
      HomeWidgets.isWorkoutLink(Uri.parse('health://workout?homeWidget')),
      isTrue,
    );
    expect(
      HomeWidgets.isWorkoutLink(Uri.parse('health://workout/start?type=run')),
      isFalse,
    );
    expect(HomeWidgets.isWorkoutLink(Uri.parse('https://workout')), isFalse);
  });

  group('widget colours', () {
    const accent = CupertinoDynamicColor.withBrightness(
      color: Color(0xFF5B4BFF),
      darkColor: Color(0xFF8C7BFF),
    );
    const skin = Skin(
      id: 'paper',
      name: 'Paper',
      brightness: Brightness.light,
      light: SkinColors(
        background: Color(0xFFF5EBDD),
        card: Color(0xFFFFF8EE),
        label: Color(0xFF2B2118),
        accent: Color(0xFFC0392B),
      ),
      dark: SkinColors(
        background: Color(0xFF000000),
        card: Color(0xFF111111),
        label: Color(0xFFFFFFFF),
        accent: Color(0xFFFF0000),
      ),
    );

    test('follow the app: its surfaces, accent and light or dark', () {
      final c = HomeWidgets.themeColours(
        themed: true,
        accent: accent,
        mode: ThemeMode.dark,
      );
      expect(c['wBgD'], Palette.card.darkColor.toARGB32());
      expect(c['wLabelL'], Palette.label.color.toARGB32());
      expect(c['wAccentD'], 0xFF8C7BFF);
      expect(c['wMode'], 2);
    });

    test('wear a theme, with its own light or dark', () {
      final c = HomeWidgets.themeColours(
        themed: true,
        accent: accent,
        mode: ThemeMode.system,
        skin: skin,
      );
      expect(c['wBgL'], 0xFFFFF8EE);
      expect(c['wLabelL'], 0xFF2B2118);
      expect(c['wAccentL'], 0xFFC0392B);
      expect(c['wMode'], 1);
      // With My Colour on, the user's accent over the theme's surfaces.
      final mine = HomeWidgets.themeColours(
        themed: true,
        accent: accent,
        mode: ThemeMode.system,
        skin: skin,
        myColour: true,
      );
      expect(mine['wAccentL'], 0xFF5B4BFF);
      expect(mine['wBgL'], 0xFFFFF8EE);
    });

    test('unthemed widgets keep their own colours', () {
      final c = HomeWidgets.themeColours(
        themed: false,
        accent: accent,
        mode: ThemeMode.system,
        skin: skin,
      );
      expect(c['wAccentL'], isNull);
      expect(c['wBgL'], Palette.card.color.toARGB32());
      expect(c['wMode'], 0);
    });
  });
}
