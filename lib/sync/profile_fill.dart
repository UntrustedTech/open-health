import 'package:intl/intl.dart';

import 'package:health_app/models/user_profile.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/utils/units.dart';

/// One profile value the health platform would add, as shown to the user.
typedef ProfileChange = ({
  String label,
  String shown,

  /// Whether it differs from a value the user already entered.
  bool replaces,
});

/// The values in [facts] that would change [profile], in the editor's
/// order. Values that already match (ignoring case, the minus sign and
/// under a centimetre of height) are left out.
List<ProfileChange> profileChanges(UserProfile profile, ProfileFacts facts) => [
  if (facts.birthDate case final d? when !_sameDay(profile.birthDate, d))
    (
      label: 'Birthday',
      shown: DateFormat.yMMMd().format(d),
      replaces: profile.birthDate != null,
    ),
  if (facts.sex case final s? when !_sameText(profile.sex, s))
    (label: 'Sex', shown: s, replaces: profile.sex.trim().isNotEmpty),
  if (facts.heightCm case final cm? when !_sameHeight(profile.heightCm, cm))
    (
      label: 'Height',
      shown: Units.height(cm),
      replaces: profile.heightCm != null,
    ),
  if (facts.bloodType case final b? when !_sameText(profile.bloodType, b))
    (
      label: 'Blood Type',
      shown: b,
      replaces: profile.bloodType.trim().isNotEmpty,
    ),
];

/// [profile] with the values from [facts] added: only where it has none,
/// or over the user's own with [replace].
UserProfile fillProfile(
  UserProfile profile,
  ProfileFacts facts, {
  bool replace = false,
}) {
  T? pick<T>(T? fact, bool isEmpty) =>
      fact != null && (replace || isEmpty) ? fact : null;
  return profile.copyWith(
    birthDate: pick(facts.birthDate, profile.birthDate == null),
    sex: pick(facts.sex, profile.sex.trim().isEmpty),
    heightCm: pick(facts.heightCm, profile.heightCm == null),
    bloodType: pick(facts.bloodType, profile.bloodType.trim().isEmpty),
  );
}

bool _sameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameText(String a, String b) {
  String norm(String s) => s.trim().toLowerCase().replaceAll('-', '−');
  return norm(a) == norm(b);
}

bool _sameHeight(double? a, double b) => a != null && (a - b).abs() < 1;
