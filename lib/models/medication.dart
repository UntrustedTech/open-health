import 'package:flutter/cupertino.dart';

import 'package:health_app/theme/app_theme.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';

/// What a medication looks like, for its icon.
enum MedForm {
  pill('Pill', Icons.medication_rounded),
  capsule('Capsule', Icons.medication_outlined),
  liquid('Liquid', Icons.water_drop_rounded),
  injection('Injection', Icons.healing_rounded),
  inhaler('Inhaler', Icons.air_rounded),
  drops('Drops', Icons.colorize_rounded),
  cream('Cream', Icons.back_hand_rounded),
  other('Other', Icons.add_box_rounded);

  const MedForm(this.label, this.icon);

  final String label;
  final IconData icon;

  static MedForm fromName(Object? n) =>
      values.firstWhere((f) => f.name == n, orElse: () => MedForm.pill);
}

/// Colours a medication can be shown in.
const medColors = [
  Palette.blue,
  Palette.teal,
  Palette.green,
  Palette.orange,
  Palette.pink,
  Palette.purple,
  Palette.red,
  Palette.indigo,
];

/// A time of day in minutes after midnight.
typedef DoseTime = int;

String formatDoseTime(DoseTime t) =>
    DateFormat.jm().format(DateTime(2000, 1, 1, t ~/ 60, t % 60));

/// A medication, vitamin or supplement and when to take it.
@immutable
class Medication {
  const Medication({
    required this.id,
    required this.name,
    this.dose = '',
    this.form = MedForm.pill,
    this.times = const [],
    this.days = const {},
    this.colorIndex = 0,
    this.notes = '',
    this.reminders = true,
    this.archived = false,
    this.created,
  });

  final String id;
  final String name;

  /// Free text such as "10 mg" or "2 tablets".
  final String dose;
  final MedForm form;

  /// Scheduled times, sorted. Empty means "as needed".
  final List<DoseTime> times;

  /// Weekdays (1 = Monday) it's taken; empty means every day.
  final Set<int> days;
  final int colorIndex;
  final String notes;
  final bool reminders;

  /// Kept for history but no longer scheduled.
  final bool archived;

  /// When it was added; doses before this don't count as missed.
  final DateTime? created;

  bool get asNeeded => times.isEmpty;

  Color get color => medColors[colorIndex % medColors.length];

  bool takenOn(DateTime day) =>
      !archived &&
      !asNeeded &&
      (days.isEmpty || days.contains(day.weekday)) &&
      switch (created) {
        final c? => !DateTime(
          day.year,
          day.month,
          day.day,
        ).isBefore(DateTime(c.year, c.month, c.day)),
        null => true,
      };

  /// "10 mg · Pill"
  String get subtitle => [if (dose.isNotEmpty) dose, form.label].join(' · ');

  /// "Every day at 8:00 AM, 8:00 PM", "Mon, Wed, Fri at 9:00 AM", "As needed".
  String get scheduleText {
    if (asNeeded) return 'As needed';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final when = days.isEmpty || days.length == 7
        ? 'Every day'
        : ([...days]..sort()).map((d) => names[d - 1]).join(', ');
    return '$when at ${times.map(formatDoseTime).join(', ')}';
  }

  Medication copyWith({
    String? name,
    String? dose,
    MedForm? form,
    List<DoseTime>? times,
    Set<int>? days,
    int? colorIndex,
    String? notes,
    bool? reminders,
    bool? archived,
    DateTime? created,
  }) => Medication(
    id: id,
    name: name ?? this.name,
    dose: dose ?? this.dose,
    form: form ?? this.form,
    times: times == null ? this.times : List.unmodifiable([...times]..sort()),
    days: days == null ? this.days : Set.unmodifiable(days),
    colorIndex: colorIndex ?? this.colorIndex,
    notes: notes ?? this.notes,
    reminders: reminders ?? this.reminders,
    archived: archived ?? this.archived,
    created: created ?? this.created,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (dose.isNotEmpty) 'dose': dose,
    'form': form.name,
    'times': times,
    'days': [...days]..sort(),
    'color': colorIndex,
    if (notes.isNotEmpty) 'notes': notes,
    'reminders': reminders,
    if (archived) 'archived': true,
    'created': ?created?.toIso8601String(),
  };

  static Medication? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'], name = json['name'];
    if (id is! String || name is! String || name.trim().isEmpty) return null;
    String text(String k, int max) => switch (json[k]) {
      final String s => s.length > max ? s.substring(0, max) : s,
      _ => '',
    };
    List<int> ints(Object? v) => v is List ? v.whereType<int>().toList() : [];
    return Medication(
      id: id,
      name: name.length > 60 ? name.substring(0, 60) : name,
      dose: text('dose', 40),
      form: MedForm.fromName(json['form']),
      times: List.unmodifiable(
        (ints(json['times']).where((t) => t >= 0 && t < 1440).toSet().toList()
          ..sort()),
      ),
      days: Set.unmodifiable(ints(json['days']).where((d) => d >= 1 && d <= 7)),
      colorIndex: switch (json['color']) {
        final int c when c >= 0 => c % medColors.length,
        _ => 0,
      },
      notes: text('notes', 300),
      reminders: json['reminders'] != false,
      archived: json['archived'] == true,
      created: DateTime.tryParse('${json['created']}'),
    );
  }
}

enum DoseStatus { taken, skipped }

/// A record of one dose: taken or skipped, for a scheduled time (or "as
/// needed", with no schedule).
@immutable
class DoseLog {
  const DoseLog({
    required this.medId,
    required this.at,
    required this.status,
    this.scheduled,
  });

  final String medId;

  /// When it was taken or skipped.
  final DateTime at;
  final DoseStatus status;

  /// The scheduled slot this answers, if any.
  final DateTime? scheduled;

  Map<String, Object?> toJson() => {
    'med': medId,
    'at': at.toIso8601String(),
    'status': status.name,
    if (scheduled case final s?) 'slot': s.toIso8601String(),
  };

  static DoseLog? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final med = json['med'];
    final at = DateTime.tryParse('${json['at']}');
    if (med is! String || at == null) return null;
    return DoseLog(
      medId: med,
      at: at,
      status: json['status'] == 'skipped'
          ? DoseStatus.skipped
          : DoseStatus.taken,
      scheduled: DateTime.tryParse('${json['slot']}'),
    );
  }
}

/// One scheduled dose today, and what happened to it.
typedef DoseSlot = ({Medication med, DateTime time, DoseLog? log});
