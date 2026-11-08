import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:health_app/export/health_report.dart' show ReportDesign;
import 'package:health_app/models/tab_layout.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/theme/app_theme.dart';

/// The app's tint colours, each adapting to light and dark mode. Iris is
/// the default.
enum AppAccent {
  iris('Iris', Palette.iris),
  lime('Lime', Palette.lime),
  aurora('Aurora', Palette.aurora),
  violet('Violet', Palette.violet),
  pink('Pink', Palette.pink),
  red('Red', Palette.red),
  orange('Orange', Palette.orange),
  green('Green', Palette.green),
  mint('Mint', Palette.mint),
  teal('Teal', Palette.teal),
  cyan('Cyan', Palette.cyan),
  blue('Blue', Palette.blue),
  indigo('Indigo', Palette.indigo),
  purple('Purple', Palette.purple),
  brown('Brown', Palette.brown),
  graphite('Graphite', Palette.grey);

  const AppAccent(this.label, this.color);

  final String label;
  final CupertinoDynamicColor color;

  static AppAccent fromName(Object? name) =>
      values.firstWhere((a) => a.name == name, orElse: () => AppAccent.iris);
}

/// Parts of the welcome setup. Skipped ones are listed on Summary until
/// they're done.
enum SetupStep {
  about('About You', 'Your name and age'),
  connect('Connect Your Data', 'Health Connect, a fresh start or demo data'),
  preferences('Preferences', 'Units, run tracking and theme colour'),
  profile('Health Details', 'Sex, height and weight for accurate numbers'),
  bodyGoal('Your Goal', 'Lose, keep or gain weight, or get fitter'),
  goals('Daily Goals', 'Move, exercise and step targets'),
  food('Food & Calories', 'Your calorie goal and macros'),
  fitness('Fitness', 'Your weekly activity goal'),
  reminders('Reminders', 'Water, meals, workouts and rings');

  const SetupStep(this.label, this.detail);

  final String label;
  final String detail;

  /// Names saved by earlier versions, mapped to the step that replaced them.
  static const _renamed = {'units': 'preferences'};

  static SetupStep? fromName(Object? name) {
    final n = _renamed[name] ?? name;
    return values.where((s) => s.name == n).firstOrNull;
  }
}

/// How charts draw their values. Saved by name, so the order is free.
enum ChartStyle {
  bars('Bars'),
  pills('Pills'),
  lines('Line'),
  curve('Curve'),
  dots('Dots'),
  stems('Stems'),
  dashes('Dashes');

  const ChartStyle(this.label);

  final String label;
}

/// Everything the user can personalise about the app's look and layout.
/// Immutable: change it with [copyWith].
@immutable
class Personalization {
  const Personalization({
    this.accent = AppAccent.iris,
    this.showGreeting = true,
    this.reduceMotion = false,
    this.units = UnitSystem.metric,
    this.themedWidgets = true,
    this.fitness = const TabLayout(FitnessSection.values),
    this.health = const TabLayout(HealthSection.values),
    this.setupLeft = const {},
    this.reportDesign = ReportDesign.classic,
    this.chartStyle = ChartStyle.curve,
  });

  final AppAccent accent;
  final bool showGreeting;

  /// Calms the app's own animations, whatever the system setting.
  final bool reduceMotion;

  /// Metric or imperial units for display and entry.
  final UnitSystem units;

  /// Home screen widgets use the theme colour.
  final bool themedWidgets;

  /// Order and visibility of the Fitness and Health tabs' sections.
  final TabLayout<FitnessSection> fitness;
  final TabLayout<HealthSection> health;

  /// Setup steps skipped during welcome, still to do.
  final Set<SetupStep> setupLeft;

  /// The Health Report design last chosen.
  final ReportDesign reportDesign;

  /// How the metric charts draw their values.
  final ChartStyle chartStyle;

  Personalization copyWith({
    AppAccent? accent,
    bool? showGreeting,
    bool? reduceMotion,
    UnitSystem? units,
    bool? themedWidgets,
    TabLayout<FitnessSection>? fitness,
    TabLayout<HealthSection>? health,
    Set<SetupStep>? setupLeft,
    ReportDesign? reportDesign,
    ChartStyle? chartStyle,
  }) => Personalization(
    accent: accent ?? this.accent,
    showGreeting: showGreeting ?? this.showGreeting,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    units: units ?? this.units,
    themedWidgets: themedWidgets ?? this.themedWidgets,
    fitness: fitness ?? this.fitness,
    health: health ?? this.health,
    setupLeft: setupLeft == null ? this.setupLeft : Set.unmodifiable(setupLeft),
    reportDesign: reportDesign ?? this.reportDesign,
    chartStyle: chartStyle ?? this.chartStyle,
  );

  /// Marks a setup step as done.
  Personalization withSetupDone(SetupStep step) =>
      copyWith(setupLeft: {...setupLeft}..remove(step));

  /// Version of the app's design these settings were saved under. Version
  /// 2 is the Aurora redesign.
  static const design = 2;

  /// Whether [json] was saved before the Aurora redesign.
  static bool isLegacy(Map<String, Object?> json) => json['design'] != design;

  /// Version of the visual style. Version 3 was the calm "Still" redesign
  /// (default accent lime); version 4 is the soft redesign, whose default
  /// accent is iris.
  static const style = 4;

  Map<String, Object?> toJson() => {
    'design': design,
    'style': style,
    'accent': accent.name,
    'showGreeting': showGreeting,
    'reduceMotion': reduceMotion,
    'units': units.name,
    'themedWidgets': themedWidgets,
    'fitness': fitness.toJson(),
    'health': health.toJson(),
    'setupLeft': [
      for (final st in SetupStep.values)
        if (setupLeft.contains(st)) st.name,
    ],
    'reportDesign': reportDesign.name,
    'chartStyle': chartStyle.name,
  };

  /// The saved accent, moving each earlier default (pink, then the Aurora
  /// teal, then lime) to the current one once. A colour picked under the
  /// current style is kept.
  static AppAccent _accentFrom(Map<String, Object?> json) {
    final saved = AppAccent.fromName(json['accent']);
    final savedStyle = json['style'];
    final oldDefault = isLegacy(json)
        ? json['accent'] == AppAccent.pink.name ||
              json['accent'] == AppAccent.aurora.name
        : savedStyle != style &&
              (saved == AppAccent.lime ||
                  (savedStyle != 3 && saved == AppAccent.aurora));
    return oldDefault ? AppAccent.iris : saved;
  }

  /// Reads saved settings, ignoring anything unknown or malformed.
  factory Personalization.fromJson(Map<String, Object?> json) {
    return Personalization(
      accent: _accentFrom(json),
      showGreeting: json['showGreeting'] != false,
      reduceMotion: json['reduceMotion'] == true,
      units: UnitSystem.fromName(json['units']),
      themedWidgets: json['themedWidgets'] != false,
      fitness: TabLayout.fromJson(json['fitness'], FitnessSection.values),
      health: TabLayout.fromJson(json['health'], HealthSection.values),
      setupLeft: Set.unmodifiable({
        for (final n in _list(json['setupLeft'])) ?SetupStep.fromName(n),
      }),
      reportDesign:
          ReportDesign.values
              .where((d) => d.name == json['reportDesign'])
              .firstOrNull ??
          ReportDesign.classic,
      chartStyle:
          ChartStyle.values
              .where((c) => c.name == json['chartStyle'])
              .firstOrNull ??
          ChartStyle.curve,
    );
  }

  static List<Object?> _list(Object? v) => v is List ? v : const [];

  @override
  bool operator ==(Object other) =>
      other is Personalization &&
      other.accent == accent &&
      other.showGreeting == showGreeting &&
      other.reduceMotion == reduceMotion &&
      other.units == units &&
      other.themedWidgets == themedWidgets &&
      other.fitness == fitness &&
      other.health == health &&
      setEquals(other.setupLeft, setupLeft) &&
      other.reportDesign == reportDesign &&
      other.chartStyle == chartStyle;

  @override
  int get hashCode => Object.hash(
    accent,
    showGreeting,
    reduceMotion,
    units,
    themedWidgets,
    fitness,
    health,
    Object.hashAllUnordered(setupLeft),
    reportDesign,
    chartStyle,
  );
}
