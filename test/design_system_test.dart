// The "Soft" rules from DESIGN.md that the shared components enforce.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<BuildContext> _pumpContext(
  WidgetTester tester,
  Brightness brightness,
) async {
  late BuildContext captured;
  await tester.pumpWidget(
    CupertinoApp(
      theme: AppTheme.theme(brightness),
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

ShapeDecoration _decorationOf(WidgetTester tester, Finder within) {
  final container = tester.widget<Container>(
    find.descendant(of: within, matching: find.byType(Container)).first,
  );
  return container.decoration! as ShapeDecoration;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('cards are plain with a soft lift only in light mode, in '
        '${brightness.name} mode', (tester) async {
      final context = await _pumpContext(tester, brightness);

      final surface = cardSurface(context);

      expect(surface.gradient, isNull);
      expect((surface.shape as RoundedRectangleBorder).side, BorderSide.none);
      expect(surface.color, context.cardBackground);
      expect(
        surface.shadows,
        brightness == Brightness.light ? AppTheme.cardShadow : isNull,
      );
    });

    testWidgets('secondary and tertiary text pass AA on cards in '
        '${brightness.name} mode', (tester) async {
      final context = await _pumpContext(tester, brightness);

      for (final text in [context.secondaryLabel, context.tertiaryLabel]) {
        for (final surface in [context.cardBackground, context.cardRaised]) {
          expect(_contrast(text, surface), greaterThanOrEqualTo(4.5));
        }
      }
    });
  }

  testWidgets('icon tiles sit on a soft pastel of their colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        theme: AppTheme.theme(Brightness.dark),
        home: const Center(
          child: IconTile(icon: Icons.favorite_rounded, color: Palette.pink),
        ),
      ),
    );
    final context = tester.element(find.byType(IconTile));

    final decoration = _decorationOf(tester, find.byType(IconTile));

    expect(decoration.gradient, isNull);
    expect(decoration.color, context.pastel(Palette.pink));
    final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded));
    expect(icon.color, context.resolve(Palette.pink));
  });

  testWidgets('a solid icon tile is one flat data colour', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        theme: AppTheme.theme(Brightness.dark),
        home: const Center(
          child: IconTile(
            icon: Icons.favorite_rounded,
            color: Palette.pink,
            solid: true,
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(IconTile));

    final decoration = _decorationOf(tester, find.byType(IconTile));

    expect(decoration.gradient, isNull);
    expect(decoration.color, context.resolve(Palette.pink));
  });

  test('a full staggered entrance finishes within 400 ms', () {
    final lastStart = Motion.stagger * Motion.staggerCount;

    expect(lastStart + Motion.medium, lessThanOrEqualTo(Motion.slow));
  });

  test('press feedback starts within 100 ms', () {
    expect(
      Motion.instant,
      lessThanOrEqualTo(const Duration(milliseconds: 100)),
    );
  });

  test('moving between screens takes under 400 ms', () {
    final route = AppRoute<void>(builder: (_) => const SizedBox());

    expect(route.transitionDuration, lessThan(Motion.slow));
  });
}
