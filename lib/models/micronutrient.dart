/// A vitamin or mineral tracked in Food. Amounts are in [unit]; [key] is
/// how it's saved (and named in the Health food database,
/// github.com/UntrustedTech/health-foods).
enum Micronutrient {
  vitaminA('a', 'Vitamin A', 'µg', 900, 'vitamin-a'),
  vitaminC('c', 'Vitamin C', 'mg', 90, 'vitamin-c'),
  vitaminD('d', 'Vitamin D', 'µg', 20, 'vitamin-d'),
  vitaminE('e', 'Vitamin E', 'mg', 15, 'vitamin-e'),
  vitaminK('k', 'Vitamin K', 'µg', 120, 'vitamin-k'),
  thiamin('b1', 'Thiamin (B1)', 'mg', 1.2, 'vitamin-b1'),
  riboflavin('b2', 'Riboflavin (B2)', 'mg', 1.3, 'vitamin-b2'),
  niacin('b3', 'Niacin (B3)', 'mg', 16, 'vitamin-pp'),
  vitaminB6('b6', 'Vitamin B6', 'mg', 1.7, 'vitamin-b6'),
  folate('b9', 'Folate (B9)', 'µg', 400, 'vitamin-b9'),
  vitaminB12('b12', 'Vitamin B12', 'µg', 2.4, 'vitamin-b12'),
  calcium('ca', 'Calcium', 'mg', 1300, 'calcium'),
  iron('fe', 'Iron', 'mg', 18, 'iron'),
  magnesium('mg', 'Magnesium', 'mg', 420, 'magnesium'),
  potassium('k+', 'Potassium', 'mg', 4700, 'potassium'),
  zinc('zn', 'Zinc', 'mg', 11, 'zinc');

  const Micronutrient(
    this.key,
    this.label,
    this.unit,
    this.dailyValue,
    this.openFoodFactsKey,
  );

  final String key;
  final String label;

  /// µg or mg.
  final String unit;

  /// The US FDA Daily Value for adults, in [unit].
  final double dailyValue;

  /// Its name in Open Food Facts' nutriments, which are in grams.
  final String openFoodFactsKey;

  bool get isVitamin => index <= vitaminB12.index;

  /// [unit] in grams (to read Open Food Facts).
  double get gramsPerUnit => unit == 'mg' ? 1e-3 : 1e-6;

  /// The most it can be in a food per 100 g, in [unit] (bad data beyond).
  double get maxPer100g => dailyValue * 200;

  static Micronutrient? byKey(String key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return null;
  }

  /// [amount] as a share of the Daily Value, 0.5 for 50%.
  double share(double amount) => amount / dailyValue;
}
