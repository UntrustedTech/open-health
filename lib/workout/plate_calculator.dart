/// Common plate sizes in kg, heaviest first.
const standardPlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

/// Bars and their weights in kg.
const barTypes = {
  'Olympic Bar': 20.0,
  'Women\'s Bar': 15.0,
  'EZ Bar': 10.0,
  'Trap Bar': 25.0,
  'Smith Machine': 15.0,
};

/// Pound plates and bars, for imperial users.
const standardPlatesLb = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];

const barTypesLb = {
  'Olympic Bar': 45.0,
  'Women\'s Bar': 35.0,
  'EZ Bar': 25.0,
  'Trap Bar': 55.0,
  'Smith Machine': 35.0,
};

typedef PlateLoad = ({List<double> perSide, double achievedKg, bool exact});

/// Plates to put on each side of a bar to reach [targetKg], heaviest first.
/// [owned] maps plate weight → pairs available (null: unlimited standard
/// plates). If the exact weight can't be made, the closest lighter load is
/// returned with `exact: false`.
PlateLoad platesFor(
  double targetKg, {
  required double barKg,
  Map<double, int>? owned,
}) {
  final load = _platesFor(targetKg, barKg: barKg, owned: owned);
  return (
    perSide: load.perSide,
    achievedKg: load.achievedKg,
    exact: (load.achievedKg - targetKg).abs() < 1e-6,
  );
}

PlateLoad _platesFor(
  double targetKg, {
  required double barKg,
  Map<double, int>? owned,
}) {
  var remaining = (targetKg - barKg) / 2;
  if (remaining <= 0) {
    return (perSide: const [], achievedKg: barKg, exact: false);
  }
  if (owned == null) {
    // Unlimited standard plates: heaviest first is always the best fit.
    final perSide = <double>[];
    for (final size in standardPlates) {
      while (remaining >= size - 1e-9) {
        perSide.add(size);
        remaining -= size;
      }
    }
    return _load(barKg, perSide);
  }
  return _load(barKg, _bestOwned(remaining, owned));
}

PlateLoad _load(double barKg, List<double> perSide) {
  final side = perSide.fold<double>(0, (a, b) => a + b);
  return (perSide: perSide, achievedKg: barKg + 2 * side, exact: false);
}

/// The heaviest load per side, up to [target], from [owned] plate pairs.
/// Heaviest-first can miss one (20 + nothing, where 15 + 15 fits 30), so
/// every reachable total is tried, in hundredths of a kilo.
List<double> _bestOwned(double target, Map<double, int> owned) {
  int units(double kg) => (kg * 100).round();
  final goal = units(target);
  final plates = [
    for (final MapEntry(key: size, value: pairs) in owned.entries)
      for (var i = 0; i < pairs; i++) size,
  ]..sort((a, b) => b.compareTo(a));
  // Each reachable total and the (fewest) plates that make it.
  final reach = <int, List<double>>{0: const []};
  for (final p in plates) {
    final u = units(p);
    for (final MapEntry(key: sum, value: used) in reach.entries.toList()) {
      final next = sum + u;
      if (next > goal) continue;
      final known = reach[next];
      if (known == null || known.length > used.length + 1) {
        reach[next] = [...used, p];
      }
    }
  }
  final best = reach.keys.reduce((a, b) => a > b ? a : b);
  return reach[best]!..sort((a, b) => b.compareTo(a));
}
