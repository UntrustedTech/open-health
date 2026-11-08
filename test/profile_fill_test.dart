import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/user_profile.dart';
import 'package:health_app/sync/profile_fill.dart';

void main() {
  const none = (birthDate: null, sex: null, bloodType: null, heightCm: null);
  final facts = (
    birthDate: DateTime(1990, 4, 12),
    sex: 'Female',
    bloodType: 'O−',
    heightCm: 168.0,
  );

  test('an empty profile gets every value, replacing nothing', () {
    final changes = profileChanges(const UserProfile(), facts);

    expect(changes.map((c) => c.label), [
      'Birthday',
      'Sex',
      'Height',
      'Blood Type',
    ]);
    expect(changes.any((c) => c.replaces), isFalse);

    final filled = fillProfile(const UserProfile(), facts);
    expect(filled.birthDate, DateTime(1990, 4, 12));
    expect(filled.sex, 'Female');
    expect(filled.bloodType, 'O−');
    expect(filled.heightCm, 168);
  });

  test('values that already match are not listed', () {
    final profile = UserProfile(
      birthDate: DateTime(1990, 4, 12),
      sex: 'female',
      bloodType: 'O-',
      heightCm: 168.2,
    );

    expect(profileChanges(profile, facts), isEmpty);
  });

  test('different values are marked as replacing and kept unless asked', () {
    const profile = UserProfile(sex: 'Male', heightCm: 180);

    final changes = profileChanges(profile, facts);
    expect(
      {for (final c in changes) c.label: c.replaces},
      {'Birthday': false, 'Sex': true, 'Height': true, 'Blood Type': false},
    );

    final kept = fillProfile(profile, facts);
    expect(kept.sex, 'Male');
    expect(kept.heightCm, 180);
    expect(kept.birthDate, DateTime(1990, 4, 12));

    final replaced = fillProfile(profile, facts, replace: true);
    expect(replaced.sex, 'Female');
    expect(replaced.heightCm, 168);
  });

  test('missing platform values change nothing', () {
    const profile = UserProfile(name: 'Sam', allergies: 'Penicillin');

    expect(profileChanges(profile, none), isEmpty);
    final same = fillProfile(profile, none, replace: true);
    expect(same.name, 'Sam');
    expect(same.allergies, 'Penicillin');
    expect(same.birthDate, isNull);
  });
}
