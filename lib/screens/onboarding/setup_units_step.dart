import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/screens/appearance_screen.dart' show AccentGrid;
import 'package:health_app/screens/onboarding/setup_page.dart';
import 'package:health_app/screens/onboarding/setup_steps.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/route_style_preview.dart';
import 'package:health_app/workout/location_source.dart';

/// Countries that mostly measure in pounds, miles and feet.
const _imperialCountries = {'US', 'LR', 'MM'};

/// The units a new user most likely expects, from their [countryCode].
UnitSystem unitsForCountry(String? countryCode) =>
    _imperialCountries.contains(countryCode?.toUpperCase())
    ? UnitSystem.imperial
    : UnitSystem.metric;

/// Units, how runs, walks and rides are tracked on a map, and the theme
/// colour. Each choice shows straight away.
class PreferencesStep extends StatefulWidget {
  const PreferencesStep({super.key, required this.nav, this.countryCode});

  final StepNav nav;

  /// Overrides the device's country, for tests.
  final String? countryCode;

  /// Set once units are saved, so coming back shows the choice made
  /// rather than the region's default.
  static bool _chosen = false;

  @override
  State<PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<PreferencesStep> {
  late UnitSystem _units = _initial();
  late MapStyle _mapStyle = context.read<WorkoutStore>().settings.mapStyle;
  late final AppAccent _startAccent = context
      .read<HealthStore>()
      .personalization
      .accent;
  late AppAccent _accent = _startAccent;
  bool _busy = false;

  /// A user who already chose imperial keeps it; otherwise the device's
  /// region suggests the default.
  UnitSystem _initial() {
    final current = context.read<HealthStore>().personalization.units;
    if (PreferencesStep._chosen || current == UnitSystem.imperial) {
      return current;
    }
    return unitsForCountry(
      widget.countryCode ??
          WidgetsBinding.instance.platformDispatcher.locale.countryCode,
    );
  }

  Future<void> _save() async {
    // A double tap mustn't ask for location twice at once.
    if (_busy) return;
    setState(() => _busy = true);
    var access = LocationAccess.denied;
    try {
      final store = context.read<HealthStore>();
      final workouts = context.read<WorkoutStore>();
      final look = store.personalization;
      if (look.units != _units || look.accent != _accent) {
        await store.setPersonalization(
          look.copyWith(units: _units, accent: _accent),
        );
      }
      if (workouts.settings.mapStyle != _mapStyle) {
        await workouts.updateSettings(
          workouts.settings.copyWith(mapStyle: _mapStyle),
        );
      }
      PreferencesStep._chosen = true;
      if (!mounted) return;
      // Asked here whichever style is chosen: both record the route by GPS.
      try {
        access = await context.read<LocationSource>().ensureAccess();
      } on Object catch (e) {
        logError('Setup: location permission failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      await showMessage(
        context,
        title: 'Location Is Off',
        message:
            'Without location, Health can\'t map your route or measure '
            'distance and pace for runs, walks, rides and other outdoor '
            'workouts. You can allow it later in your phone\'s Settings.',
      );
      if (!mounted) return;
    }
    widget.nav.onDone(false);
  }

  /// Skipping keeps nothing from this page, including the colour preview.
  Future<void> _skip() async {
    final store = context.read<HealthStore>();
    if (store.personalization.accent != _startAccent) {
      await store.setPersonalization(
        store.personalization.copyWith(accent: _startAccent),
      );
    }
    if (mounted) widget.nav.onDone(true);
  }

  /// The theme colour previews at once, so the page itself changes.
  Future<void> _pickAccent(AppAccent a) async {
    setState(() => _accent = a);
    final store = context.read<HealthStore>();
    await store.setPersonalization(store.personalization.copyWith(accent: a));
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    return SetupPage(
      icon: Icons.tune_rounded,
      color: Palette.indigo,
      title: 'Preferences',
      subtitle:
          'Make Health feel like yours. You can change all of this any '
          'time in Profile.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: _skip,
      onContinue: _save,
      busy: _busy,
      children: [
        const _Heading('Units'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, u) in UnitSystem.values.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: UnitsOption(
                  units: u,
                  selected: _units == u,
                  compact: true,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _units = u);
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        const _Heading('Run & Ride Tracking'),
        GroupedSection(
          hasLeading: false,
          footer: _mapStyle == MapStyle.street
              ? 'Routes are drawn on a street map, downloaded from '
                    'OpenStreetMap. Your route itself is never sent.'
              : 'Routes are drawn as a clean line with no map, so Health '
                    'stays fully offline and private.',
          children: [
            RouteStylePicker(
              value: _mapStyle,
              onChanged: (m) {
                HapticFeedback.selectionClick();
                setState(() => _mapStyle = m);
              },
            ),
          ],
        ),
        const _Heading('Theme Colour'),
        GroupedSection(
          hasLeading: false,
          footer: '${_accent.label} is selected.',
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: AccentGrid(selected: _accent, onSelect: _pickAccent),
            ),
          ],
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: context.overline.copyWith(color: context.secondaryLabel),
    ),
  );
}

/// Example readings in [units]: (label, icon, value).
List<(String, IconData, String)> unitExamples(UnitSystem units) =>
    switch (units) {
      UnitSystem.metric => const [
        ('Weight', Icons.monitor_weight_rounded, '72.5 kg'),
        ('Height', Icons.height_rounded, '178 cm'),
        ('Distance', Icons.route_rounded, '5.2 km'),
        ('Water', Icons.water_drop_rounded, '250 ml'),
      ],
      UnitSystem.imperial => const [
        ('Weight', Icons.monitor_weight_rounded, '160 lb'),
        ('Height', Icons.height_rounded, '5 ft 10 in'),
        ('Distance', Icons.route_rounded, '3.2 mi'),
        ('Water', Icons.water_drop_rounded, '8.5 fl oz'),
      ],
    };

/// A selectable card for one unit system.
class UnitsOption extends StatelessWidget {
  const UnitsOption({
    super.key,
    required this.units,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final UnitSystem units;

  /// Half-width: just the values, no labels.
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    final examples = unitExamples(units);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label:
          '${units.label}: '
          '${examples.map((e) => '${e.$1} ${e.$3}').join(', ')}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
          curve: Motion.curve,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: ShapeDecoration(
            color: selected
                ? Color.alphaBlend(
                    tint.withValues(alpha: 0.12),
                    context.cardBackground,
                  )
                : context.cardBackground,
            shape: AppTheme.squircle(
              20,
              side: BorderSide(
                color: selected ? tint : context.separatorColor,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      units.label,
                      style: context.headline.copyWith(fontSize: 18),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? tint : context.tertiaryLabel,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final (i, (label, icon, value)) in examples.indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: context.secondaryLabel),
                      const SizedBox(width: 8),
                      if (!compact)
                        Expanded(
                          child: Text(
                            label,
                            style: context.subheadline.copyWith(
                              color: context.secondaryLabel,
                            ),
                          ),
                        ),
                      // Half-width cards shrink long values to fit.
                      Flexible(
                        flex: compact ? 1 : 0,
                        fit: compact ? FlexFit.tight : FlexFit.loose,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            value,
                            style: context.subheadline.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
