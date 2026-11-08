import 'package:flutter/foundation.dart';

import 'package:health_app/models/metric_type.dart';

/// Where an entry came from.
enum EntrySource {
  /// Logged by the user in this app.
  manual,

  /// Demo data, removable without touching real entries.
  sample,

  /// Imported from Health Connect (Android) or Apple Health (iOS).
  healthConnect,

  /// Added automatically for a workout recorded in this app.
  workout,

  /// Totals of a food logged in the food diary; managed with the diary.
  food,

  /// Read live from a device (kept so data from earlier versions opens).
  plugin,
}

/// A single recorded measurement, e.g. 250 ml of water at 09:30.
@immutable
class HealthEntry {
  const HealthEntry({
    required this.id,
    required this.type,
    required this.value,
    required this.date,
    this.note,
    this.source = EntrySource.manual,
  });

  final String id;
  final MetricType type;
  final double value;
  final DateTime date;
  final String? note;

  final EntrySource source;

  /// True for demo data, so it can be removed without touching real entries.
  bool get isSample => source == EntrySource.sample;

  /// True for data read from the phone's health platform.
  bool get isImported => source == EntrySource.healthConnect;

  /// Ids of values the app worked out from other imported data (resting
  /// heart rate from heart rate readings) start with this.
  static const estimatePrefix = 'hc-est:';

  /// True for a value worked out by the app rather than recorded. A
  /// recorded value for the same day always takes its place.
  bool get isEstimate => id.startsWith(estimatePrefix);

  /// True for entries created by a workout; managed with the workout.
  bool get isFromWorkout => source == EntrySource.workout;

  /// True for entries made by the food diary; managed there.
  bool get isFromFood => source == EntrySource.food;

  /// Read live from a device.
  bool get isFromPlugin => source == EntrySource.plugin;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'value': value,
    'date': date.toIso8601String(),
    if (note != null) 'note': note,
    if (source != EntrySource.manual) 'source': source.name,
  };

  /// Returns null for malformed or unknown records instead of throwing, so one
  /// bad row never prevents the rest of the data from loading.
  static HealthEntry? tryFromJson(Map<String, Object?> json) {
    final rawType = json['type'];
    final rawDate = json['date'];
    final value = json['value'];
    final id = json['id'];
    final note = json['note'];
    final type = rawType is String ? MetricType.fromName(rawType) : null;
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (type == null || value is! num || date == null || id is! String) {
      return null;
    }
    // Infinity or NaN (e.g. "1e999" in a damaged backup) can't be saved
    // again: one such entry would make every later save of entries fail.
    if (!value.isFinite || date.year < 1900 || date.year > 9999) return null;
    return HealthEntry(
      id: id,
      type: type,
      value: value.toDouble(),
      date: date,
      note: note is String ? note : null,
      source: _sourceFrom(json),
    );
  }

  static EntrySource _sourceFrom(Map<String, Object?> json) {
    // Older versions stored demo data as `"sample": true`.
    if (json['sample'] == true) return EntrySource.sample;
    final raw = json['source'];
    return EntrySource.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => EntrySource.manual,
    );
  }
}
