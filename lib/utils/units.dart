import 'package:intl/intl.dart';

import 'package:health_app/models/metric_type.dart';

/// Measurement system for display and entry. Data is always stored in
/// metric units; only what the user sees and types is converted.
enum UnitSystem {
  metric('Metric', 'kg, km, cm, ml'),
  imperial('Imperial', 'lb, mi, ft & in, fl oz');

  const UnitSystem(this.label, this.examples);

  final String label;
  final String examples;

  static UnitSystem fromName(Object? name) =>
      values.firstWhere((u) => u.name == name, orElse: () => UnitSystem.metric);
}

/// Conversions between stored metric values and the units shown.
/// [system] is kept in step with the user's setting by the HealthStore.
abstract final class Units {
  static UnitSystem system = UnitSystem.metric;

  static bool get imperial => system == UnitSystem.imperial;

  static const lbPerKg = 2.2046226218;
  static const kmPerMile = 1.609344;
  static const mlPerFlOz = 29.5735295625;
  static const cmPerInch = 2.54;

  // ------------------------------------------------------------ weight

  static String get weightUnit => imperial ? 'lb' : 'kg';

  static double weightOut(double kg) => imperial ? kg * lbPerKg : kg;
  static double weightIn(double shown) => imperial ? shown / lbPerKg : shown;

  /// "72.5 kg" / "159.8 lb". Whole numbers lose their ".0".
  static String weight(double kg, {int decimals = 1}) =>
      '${_trim(weightOut(kg), decimals)} $weightUnit';

  // ---------------------------------------------------------- distance

  static String get distanceUnit => imperial ? 'mi' : 'km';

  static double distanceOut(double km) => imperial ? km / kmPerMile : km;
  static double distanceIn(double shown) =>
      imperial ? shown * kmPerMile : shown;

  /// Pace per kilometre or per mile, from seconds per kilometre.
  static double? paceOut(double? secondsPerKm) => secondsPerKm == null
      ? null
      : (imperial ? secondsPerKm * kmPerMile : secondsPerKm);

  static String get paceUnit => imperial ? '/mi' : '/km';

  static String get speedUnit => imperial ? 'mph' : 'km/h';

  /// Speed in km/h or mph, from metres per second.
  static double speedOut(double metersPerSecond) =>
      distanceOut(metersPerSecond * 3.6);

  // ------------------------------------------------------------ volume

  static String get waterUnit => imperial ? 'fl oz' : 'ml';
  static double waterOut(double ml) => imperial ? ml / mlPerFlOz : ml;
  static double waterIn(double shown) => imperial ? shown * mlPerFlOz : shown;

  // ------------------------------------------------------------ height

  /// "178 cm" / "5 ft 10 in".
  static String height(double cm) {
    if (!imperial) return '${cm.round()} cm';
    final inches = (cm / cmPerInch).round();
    return '${inches ~/ 12} ft ${inches % 12} in';
  }

  // --------------------------------------------------------- elevation

  static const feetPerMeter = 3.28084;

  /// "120 m" / "394 ft".
  static String elevation(double meters) => imperial
      ? '${_trim(meters * feetPerMeter, 0)} ft'
      : '${_trim(meters, 0)} m';

  // ----------------------------------------------------------- glucose

  /// mg/dL per mmol/L of glucose.
  static const mgPerMmol = 18.016;

  /// Blood glucose is stored in mg/dL and shown in mmol/L for metric.
  static String get glucoseUnit => imperial ? 'mg/dL' : 'mmol/L';
  static double glucoseOut(double mgDl) => imperial ? mgDl : mgDl / mgPerMmol;
  static double glucoseIn(double shown) => imperial ? shown : shown * mgPerMmol;

  // ------------------------------------------------------- temperature

  /// Body temperature is stored in °C and shown in °F for imperial.
  static String get temperatureUnit => imperial ? '°F' : '°C';
  static double temperatureOut(double c) => imperial ? c * 9 / 5 + 32 : c;
  static double temperatureIn(double shown) =>
      imperial ? (shown - 32) * 5 / 9 : shown;

  /// Skin temperature is a change from the wearer's own baseline, so
  /// °F is only scaled, not offset.
  static double deltaOut(double c) => imperial ? c * 9 / 5 : c;
  static double deltaIn(double shown) => imperial ? shown * 5 / 9 : shown;

  // ----------------------------------------------------------- metrics

  /// The unit shown for [type].
  static String unitFor(MetricType type) => switch (type) {
    MetricType.weight ||
    MetricType.leanBodyMass ||
    MetricType.bodyWaterMass => weightUnit,
    MetricType.distance => distanceUnit,
    MetricType.water => waterUnit,
    MetricType.bloodGlucose => glucoseUnit,
    MetricType.bodyTemperature || MetricType.skinTemperature => temperatureUnit,
    MetricType.activeEnergy ||
    MetricType.restingEnergy ||
    MetricType.dietaryEnergy => calorieUnit,
    _ => type.unit,
  };

  /// Calories as shown on screen. Exports keep "kcal", the standard unit.
  static const calorieUnit = 'Cal';

  /// Decimal places shown for [type] (fluid ounces need one).
  static int decimalsFor(MetricType type) => switch (type) {
    MetricType.water when imperial => 1,
    MetricType.bloodGlucose when !imperial => 1,
    _ => type.decimals,
  };

  /// Stored value → shown value.
  static double toDisplay(MetricType type, double value) => switch (type) {
    MetricType.weight ||
    MetricType.leanBodyMass ||
    MetricType.bodyWaterMass => weightOut(value),
    MetricType.distance => distanceOut(value),
    MetricType.water => waterOut(value),
    MetricType.bloodGlucose => glucoseOut(value),
    MetricType.bodyTemperature => temperatureOut(value),
    MetricType.skinTemperature => deltaOut(value),
    _ => value,
  };

  /// Shown value → stored value.
  static double fromDisplay(MetricType type, double value) => switch (type) {
    MetricType.weight ||
    MetricType.leanBodyMass ||
    MetricType.bodyWaterMass => weightIn(value),
    MetricType.distance => distanceIn(value),
    MetricType.water => waterIn(value),
    MetricType.bloodGlucose => glucoseIn(value),
    MetricType.bodyTemperature => temperatureIn(value),
    MetricType.skinTemperature => deltaIn(value),
    _ => value,
  };

  static String _trim(double v, int decimals) {
    final f = NumberFormat.decimalPatternDigits(decimalDigits: decimals);
    final s = f.format(v);
    final point = f.symbols.DECIMAL_SEP;
    return decimals > 0 && s.endsWith('$point${'0' * decimals}')
        ? s.substring(0, s.length - decimals - 1)
        : s;
  }
}
