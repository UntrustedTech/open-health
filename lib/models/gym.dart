import 'package:flutter/foundation.dart';

/// How a membership card's code is drawn, so the gym's scanner can read it
/// off the screen.
enum CardFormat {
  code128('Code 128'),
  code39('Code 39'),
  code93('Code 93'),
  qr('QR Code'),
  ean13('EAN-13'),
  ean8('EAN-8'),
  upcA('UPC-A'),
  upcE('UPC-E'),
  itf('ITF'),
  codabar('Codabar'),
  pdf417('PDF417'),
  dataMatrix('Data Matrix'),
  aztec('Aztec');

  const CardFormat(this.label);

  final String label;

  /// Square codes, drawn as a square rather than a strip.
  bool get isSquare => this == qr || this == dataMatrix || this == aztec;

  static CardFormat fromName(Object? name) =>
      values.firstWhere((f) => f.name == name, orElse: () => code128);
}

/// A gym membership: who and where, and the card's code to scan in with.
@immutable
class GymMembership {
  const GymMembership({
    required this.gym,
    required this.code,
    this.format = CardFormat.code128,
    this.memberName = '',
    this.memberNumber = '',
    this.plan = '',
    this.expires,
    this.notes = '',
  });

  final String gym;

  /// What the card's barcode holds.
  final String code;
  final CardFormat format;
  final String memberName;

  /// The number printed on the card, when it differs from [code].
  final String memberNumber;

  /// "Monthly", "Off-Peak"...
  final String plan;

  /// The last day it's valid, if it ends.
  final DateTime? expires;
  final String notes;

  bool get hasCode => code.trim().isNotEmpty;

  /// Whether it ended before [today].
  bool isExpired(DateTime today) {
    final e = expires;
    return e != null &&
        DateTime(
          e.year,
          e.month,
          e.day,
        ).isBefore(DateTime(today.year, today.month, today.day));
  }

  GymMembership copyWith({
    String? gym,
    String? code,
    CardFormat? format,
    String? memberName,
    String? memberNumber,
    String? plan,
    DateTime? expires,
    bool clearExpires = false,
    String? notes,
  }) => GymMembership(
    gym: gym ?? this.gym,
    code: code ?? this.code,
    format: format ?? this.format,
    memberName: memberName ?? this.memberName,
    memberNumber: memberNumber ?? this.memberNumber,
    plan: plan ?? this.plan,
    expires: clearExpires ? null : expires ?? this.expires,
    notes: notes ?? this.notes,
  );

  Map<String, Object?> toJson() => {
    'gym': gym,
    'code': code,
    'format': format.name,
    'memberName': memberName,
    'memberNumber': memberNumber,
    'plan': plan,
    'expires': ?expires?.toIso8601String(),
    'notes': notes,
  };

  /// Reads a saved membership, or null if it isn't one.
  static GymMembership? fromJson(Object? json) {
    if (json is! Map) return null;
    String text(String key) => json[key] is String ? json[key] as String : '';
    final expires = json['expires'];
    return GymMembership(
      gym: text('gym'),
      code: text('code'),
      format: CardFormat.fromName(json['format']),
      memberName: text('memberName'),
      memberNumber: text('memberNumber'),
      plan: text('plan'),
      expires: expires is String ? DateTime.tryParse(expires) : null,
      notes: text('notes'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GymMembership &&
      other.gym == gym &&
      other.code == code &&
      other.format == format &&
      other.memberName == memberName &&
      other.memberNumber == memberNumber &&
      other.plan == plan &&
      other.expires == expires &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    gym,
    code,
    format,
    memberName,
    memberNumber,
    plan,
    expires,
    notes,
  );
}
