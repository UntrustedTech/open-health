import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons, ThemeMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/screens/app_icon_picker.dart';
import 'package:health_app/screens/customize_tab_sheet.dart';
import 'package:health_app/screens/health_settings_screen.dart'
    show UnitsPicker;
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/bar_chart.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Light/dark mode, accent colour, motion and Summary layout.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Appearance',
      builder: (_) => const AppearanceScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final look = store.personalization;
    Widget toggle(
      IconData icon,
      Color color,
      String title,
      bool value,
      Personalization Function(bool) next,
    ) => CupertinoListTile(
      leading: IconTile(icon: icon, color: color),
      title: Text(title),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: (v) => store.setPersonalization(next(v)),
      ),
    );
    return LargeTitlePage(
      title: 'Appearance',
      children: [
        GroupedSection(
          header: 'Mode',
          hasLeading: false,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
              child: Row(
                children: [
                  for (final mode in const [
                    ThemeMode.light,
                    ThemeMode.dark,
                    ThemeMode.system,
                  ])
                    Expanded(
                      child: _ModeOption(
                        mode: mode,
                        selected: store.themeMode == mode,
                        onTap: () => store.setThemeMode(mode),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const AppIconSection(),
        GroupedSection(
          header: 'Theme Colour',
          footer:
              'Used for buttons, highlights and the glow behind titles. '
              '${look.accent.label} is selected.',
          hasLeading: false,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: AccentGrid(
                selected: look.accent,
                onSelect: (a) =>
                    store.setPersonalization(look.copyWith(accent: a)),
              ),
            ),
          ],
        ),
        GroupedSection(
          header: 'Units',
          footer: look.units.examples,
          hasLeading: false,
          children: [const UnitsPicker()],
        ),
        GroupedSection(
          header: 'Home Screen Widgets',
          footer:
              'Water and workout widgets use your theme colour. Activity '
              'rings keep their own colours.',
          children: [
            toggle(
              Icons.grid_view_rounded,
              context.tint,
              'Match Theme Colour',
              look.themedWidgets,
              (v) => look.copyWith(themedWidgets: v),
            ),
          ],
        ),
        GroupedSection(
          header: 'Motion',
          footer:
              'Replaces sliding and springing animations with simple '
              'fades, and keeps exercise demos paused until tapped.',
          children: [
            toggle(
              Icons.air_rounded,
              context.resolve(Palette.teal),
              'Reduce Motion',
              look.reduceMotion,
              (v) => look.copyWith(reduceMotion: v),
            ),
          ],
        ),
        GroupedSection(
          header: 'Charts',
          footer: 'How the charts on each metric page draw their values.',
          hasLeading: false,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChartStylePicker(
                    value: look.chartStyle,
                    onChanged: (c) {
                      HapticFeedback.selectionClick();
                      store.setPersonalization(look.copyWith(chartStyle: c));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        GroupedSection(
          header: 'Summary',
          children: [
            toggle(
              Icons.back_hand_rounded,
              context.resolve(Palette.orange),
              'Greeting',
              look.showGreeting,
              (v) => look.copyWith(showGreeting: v),
            ),
          ],
        ),
        GroupedSection(
          header: 'Tabs',
          footer:
              'Choose the widgets each tab shows. To reorder or resize '
              'them, tap Edit on the tab, or touch and hold a widget.',
          children: [
            for (final (title, icon, open) in [
              (
                'Customize Health',
                Icons.favorite_rounded,
                CustomizeTabSheet.health,
              ),
              (
                'Customize Fitness',
                Icons.local_fire_department_rounded,
                CustomizeTabSheet.fitness,
              ),
              (
                'Customize Food',
                Icons.restaurant_rounded,
                CustomizeTabSheet.food,
              ),
            ])
              InfoRow(
                leading: IconTile(icon: icon, color: context.tint),
                title: title,
                chevron: true,
                onTap: () => open(context),
              ),
          ],
        ),
      ],
    );
  }
}

/// A miniature screen in light or dark (or half and half for Automatic),
/// with a selection circle underneath, as in iOS Display settings.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  static const _light = (Color(0xFFF4F4F1), Color(0xFFFFFFFF));
  static const _dark = (Color(0xFF0B0B0C), Color(0xFF17171A));

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Automatic',
    };
    final tint = context.tint;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      excludeSemantics: true,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
              width: 64,
              height: 112,
              padding: const EdgeInsets.all(2),
              decoration: ShapeDecoration(
                shape: AppTheme.squircle(
                  14,
                  side: BorderSide(
                    color: selected ? tint : context.separatorColor,
                    width: selected ? 2.5 : 1,
                  ),
                ),
              ),
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(11),
                child: switch (mode) {
                  ThemeMode.light => _screen(_light, tint),
                  ThemeMode.dark => _screen(_dark, tint),
                  ThemeMode.system => Row(
                    children: [
                      Expanded(child: _screen(_light, tint)),
                      Expanded(child: _screen(_dark, tint)),
                    ],
                  ),
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: context.subheadline),
            const SizedBox(height: 6),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? tint : context.tertiaryLabel,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _screen((Color, Color) colors, Color tint) {
    final (background, card) = colors;
    Widget bar(Color color, {double? width, double? height}) => Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: bar(tint, width: 24, height: 6),
            ),
            bar(card, height: 24),
            bar(card, height: 16),
            Expanded(child: bar(card)),
          ],
        ),
      ),
    );
  }
}

/// The theme colours as round swatches, six to a row. With a style on,
/// its own colour comes first ([styleColor]).
class AccentGrid extends StatelessWidget {
  const AccentGrid({
    super.key,
    required this.selected,
    required this.onSelect,
    this.styleColor,
    this.styleName,
    this.onStyle,
  });

  /// The chosen colour, or null while the style's own is used.
  final AppAccent? selected;
  final ValueChanged<AppAccent> onSelect;
  final Color? styleColor;
  final String? styleName;
  final VoidCallback? onStyle;

  static const _size = AppTheme.minTapTarget;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Six to a row, spaced evenly.
        final gap = ((c.maxWidth - 6 * _size) / 5).clamp(8.0, 40.0);
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            if (styleColor case final c?)
              _Swatch(
                color: c,
                label: '${styleName ?? 'Style'} colour',
                selected: selected == null,
                size: _size,
                ring: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onStyle?.call();
                },
              ),
            // Mint is too close to Aurora's teal to offer both; anyone
            // who chose it keeps it.
            for (final a in AppAccent.values)
              if (a != AppAccent.mint || a == selected)
                _Swatch(
                  color: context.resolve(a.color),
                  label: a.label,
                  selected: a == selected,
                  size: _size,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(a);
                  },
                ),
          ],
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.size,
    required this.onTap,
    this.ring = false,
  });

  final Color color;
  final String label;
  final bool selected;
  final double size;
  final VoidCallback onTap;

  /// Marks the style's own colour with a ring of the page's text colour.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.reduced(context) ? Duration.zero : Motion.medium;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          // Not a spring: overshooting would make the padding negative.
          curve: Motion.curve,
          width: size,
          height: size,
          padding: EdgeInsets.all(selected ? 4 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? color : const Color(0x00000000),
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: ring
                  ? Border.all(color: context.labelColor, width: 2)
                  : null,
            ),
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: duration,
              curve: Motion.spring,
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: context.onColor(color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every chart style as a small tile drawing a sample week in that style.
class _ChartStylePicker extends StatelessWidget {
  const _ChartStylePicker({required this.value, required this.onChanged});

  final ChartStyle value;
  final ValueChanged<ChartStyle> onChanged;

  static const _sample = [6.2, 8.4, 7.1, null, 9.3, 5.8, 7.6];

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        // Three across, or two when large text makes the labels wide.
        final across = MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 2 : 3;
        final width = (box.maxWidth - gap * (across - 1)) / across;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in ChartStyle.values)
              Semantics(
                button: true,
                selected: c == value,
                label: tr(c.label),
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onChanged(c),
                  child: AnimatedContainer(
                    duration: Motion.reduced(context)
                        ? Duration.zero
                        : Motion.fast,
                    width: width,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    decoration: ShapeDecoration(
                      color: c == value
                          ? tint.withValues(alpha: 0.12)
                          : context.groupedBackground,
                      shape: AppTheme.squircle(
                        12,
                        side: BorderSide(
                          color: c == value ? tint : context.separatorColor,
                          width: c == value ? 2 : 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        IgnorePointer(
                          child: BarChart(
                            values: _sample,
                            color: MetricType.steps.color,
                            height: 52,
                            style: c,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.footnote.copyWith(
                            fontWeight: c == value
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: c == value ? tint : context.labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
