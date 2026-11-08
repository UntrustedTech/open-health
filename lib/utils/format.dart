import 'package:intl/intl.dart';

import 'package:health_app/models/metric_type.dart';
import 'package:health_app/utils/units.dart';

final _formats = <(String?, String), NumberFormat>{};

/// [make]'s number format in the app's language, made once per language:
/// numbers are formatted for every row of a list.
NumberFormat cachedFormat(String name, NumberFormat Function() make) =>
    _formats[(Intl.defaultLocale, name)] ??= make();

NumberFormat get _grouped =>
    cachedFormat('grouped', NumberFormat.decimalPattern);

/// Formats a value for display using the metric's precision, e.g. "8,421".
/// Values are converted to the user's units (see [Units]).
String formatValue(MetricType type, double value) {
  if (type.isDuration) return formatHours(value);
  final shown = Units.toDisplay(type, value);
  final decimals = Units.decimalsFor(type);
  final fixed = NumberFormat.decimalPatternDigits(decimalDigits: decimals);
  return decimals == 0 ? _grouped.format(shown.round()) : fixed.format(shown);
}

/// "7 hr 30 min" style formatting for durations given in hours.
String formatHours(double hours) {
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '$m\u00A0min';
  if (m == 0) return '$h\u00A0hr';
  return '$h\u00A0hr $m\u00A0min';
}

/// Unit label shown after a value. Sleep embeds its unit in the value text.
String unitLabel(MetricType type) => type.isDuration ? '' : Units.unitFor(type);

String formatDay(DateTime date, DateTime today) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final t = DateTime.utc(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat.EEEE().format(date);
  if (date.year == today.year) return DateFormat.MMMd().format(date);
  return DateFormat.yMMMd().format(date);
}

String formatTime(DateTime date) => DateFormat.jm().format(date);

/// A time of day in the user's locale ("10:30 PM").
String formatTimeOfDay(int hour, int minute) =>
    DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));

/// "1:05:09" or "05:09".
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "1 hr 5 min" or "42 min" for summaries.
String formatMinutes(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m\u00A0min';
  return m == 0 ? '$h\u00A0hr' : '$h\u00A0hr $m\u00A0min';
}

/// Running pace per km or mile (the user's units), e.g. 5'12". Pair with
/// [Units.paceUnit]. Returns "--" without a value.
String formatPace(double? secondsPerKm) {
  final pace = Units.paceOut(secondsPerKm);
  if (pace == null || !pace.isFinite || pace <= 0) {
    return "--'--\"";
  }
  final total = pace.round();
  return "${total ~/ 60}'${(total % 60).toString().padLeft(2, '0')}\"";
}

/// "27.4" km/h or mph (the user's units); pair with [Units.speedUnit].
/// Returns "--" without a value.
String formatSpeed(double? metersPerSecond) =>
    metersPerSecond == null || !metersPerSecond.isFinite
    ? '--'
    : Units.speedOut(metersPerSecond).toStringAsFixed(1);

/// "5.24 km" or "3.26 mi" (or metres/feet for short distances when
/// [allowMeters]).
/// Made once: distances are formatted for every row of a list.
NumberFormat get _twoDecimals =>
    cachedFormat('0.00', () => NumberFormat('0.00'));

String formatDistance(double meters, {bool allowMeters = false}) {
  if (Units.imperial) {
    if (allowMeters && meters < 160.9) {
      return '${(meters * 3.28084).round()}\u00A0ft';
    }
    return '${_twoDecimals.format(Units.distanceOut(meters / 1000))}\u00A0mi';
  }
  if (allowMeters && meters < 1000) return '${meters.round()}\u00A0m';
  return '${_twoDecimals.format(meters / 1000)}\u00A0km';
}

String formatKcal(double kcal) =>
    '${NumberFormat.decimalPattern().format(kcal.round())}\u00A0Cal';
