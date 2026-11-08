/// How active someone is day to day, with the usual activity multipliers
/// (total energy as a multiple of resting energy).
enum ActivityLevel {
  sedentary('Sedentary', 'Mostly sitting, little or no exercise', 1.2),
  low('Lightly Active', 'Light exercise 1–3 days a week', 1.375),
  moderate('Moderately Active', 'Exercise 3–5 days a week', 1.465),
  active('Active', 'Exercise 6–7 days a week', 1.55),
  veryActive('Very Active', 'Hard daily exercise or a physical job', 1.725);

  const ActivityLevel(this.label, this.detail, this.factor);

  final String label;
  final String detail;

  /// Total energy as a multiple of resting energy (BMR).
  final double factor;

  /// From average daily steps (Tudor-Locke step bands).
  static ActivityLevel fromSteps(double averageSteps) => switch (averageSteps) {
    < 5000 => sedentary,
    < 7500 => low,
    < 10000 => moderate,
    < 12500 => active,
    _ => veryActive,
  };

  static ActivityLevel? fromName(Object? name) =>
      values.where((l) => l.name == name).firstOrNull;
}
