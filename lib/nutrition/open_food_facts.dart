import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:health_app/models/food.dart';
import 'package:health_app/models/micronutrient.dart';
import 'package:health_app/utils/log.dart';

/// Fetches a URL's body as text. Throws [FoodLookupException] on failure.
typedef Fetch = Future<String> Function(Uri url);

class FoodLookupException implements Exception {
  const FoodLookupException(this.message);

  final String message;

  @override
  String toString() => 'FoodLookupException: $message';
}

/// Reads food data from Open Food Facts (openfoodfacts.org): a free, open
/// database of food products (ODbL). Only the barcode or search words are
/// sent; no account or personal data.
class OpenFoodFacts {
  OpenFoodFacts({Fetch? fetch}) : _fetch = fetch ?? _httpGet;

  static const _userAgent = 'HealthApp/1.10 (Android)';
  static const _timeout = Duration(seconds: 12);
  static const _fields =
      'code,product_name,brands,nutriments,serving_size,serving_quantity,'
      'serving_quantity_unit,product_quantity_unit,nutrition_data_per,'
      'quantity';

  /// Largest response accepted (a product is a few kB).
  static const _maxBytes = 2 * 1024 * 1024;

  final Fetch _fetch;

  /// The product with this barcode, or null if Open Food Facts doesn't
  /// know it (or has no calories for it).
  Future<Food?> lookup(String barcode) async {
    if (!validBarcode(barcode)) return null;
    final url = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$barcode.json',
      {'fields': _fields},
    );
    final json = _decode(await _fetch(url));
    if (json['status'] != 1) return null;
    return parseProduct(json['product'], barcode: barcode);
  }

  /// Products matching [query], best first.
  Future<List<Food>> search(String query, {int limit = 25}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final url = Uri.https('search.openfoodfacts.org', '/search', {
      'q': q.length > 80 ? q.substring(0, 80) : q,
      'page_size': '$limit',
      'fields': _fields,
    });
    final json = _decode(await _fetch(url));
    final hits = json['hits'];
    if (hits is! List) return const [];
    // The same product is often listed under several barcodes; keep the first.
    final seen = <String>{};
    return [
      for (final h in hits)
        if (parseProduct(h) case final f?)
          if (seen.add(
            '${f.name.toLowerCase()}|${f.brand.toLowerCase()}|'
            '${f.servingLabel}|${f.perServing.kcal.round()}',
          ))
            f,
    ];
  }

  static Map<String, Object?> _decode(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, Object?>) return v;
    } on FormatException {
      // Falls through.
    }
    throw const FoodLookupException('Unexpected response');
  }

  /// A product as a [Food] per serving (per 100 g when the serving size is
  /// unknown). Null without a name or calories.
  static Food? parseProduct(Object? product, {String? barcode}) {
    if (product is! Map<String, Object?>) return null;
    // Only a real barcode is kept (it also becomes the food's id).
    final raw = product['code'];
    final code = raw is String && validBarcode(raw) ? raw : (barcode ?? '');
    final name = _text(product['product_name'], 100);
    if (name.isEmpty) return null;
    final n = product['nutriments'];
    if (n is! Map<String, Object?>) return null;
    double per100(String key, {double max = 1000}) {
      final v = switch (n['${key}_100g']) {
        final num v => v.toDouble(),
        final String s => double.tryParse(s) ?? 0,
        _ => 0.0,
      };
      // Crowd-edited data: "NaN", "Infinity" and the like count as unknown.
      return v.isFinite && v >= 0 && v <= max ? v : 0;
    }

    final protein = per100('proteins', max: 100);
    final carbs = per100('carbohydrates', max: 100);
    final fat = per100('fat', max: 100);
    final energyKj = per100('energy-kj', max: 4200);
    final kcal = checkedKcal(
      kcal: per100('energy-kcal', max: 1000),
      kj: energyKj > 0 ? energyKj : per100('energy', max: 4200),
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    if (kcal <= 0) return null;
    // Sodium, or worked out from salt (salt is 40% sodium).
    final sodiumG = per100('sodium', max: 100);
    final sodium = sodiumG > 0 ? sodiumG : per100('salt', max: 100) / 2.5;
    final per100g = Nutrients(
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: per100('fiber', max: 100),
      sugar: per100('sugars', max: 100),
      saturatedFat: per100('saturated-fat', max: 100),
      sodiumMg: sodium * 1000,
      micros: {
        for (final m in Micronutrient.values)
          if (per100(m.openFoodFactsKey, max: 10) / m.gramsPerUnit case final v
              when v > 0 && v <= m.maxPer100g)
            m: v,
      },
    );
    final liquid = isLiquid(product);
    final q = product['serving_quantity'];
    final rawGrams = switch (q) {
      final num v => v.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
    final grams =
        rawGrams != null &&
            rawGrams.isFinite &&
            rawGrams >= 1 &&
            rawGrams < 5000
        ? rawGrams
        : null;
    final servingText = _text(product['serving_size'], 40);
    final hasServing = grams != null && grams > 0;
    final perServing = hasServing ? per100g * (grams / 100) : per100g;
    if (!perServing.isFinite) return null;
    return Food(
      id: validBarcode(code) ? 'off:$code' : 'off:${name.hashCode}',
      name: name,
      brand: _brand(product['brands']),
      barcode: validBarcode(code) ? code : null,
      servingLabel: hasServing
          ? (servingText.isEmpty
                ? '${_g(grams)} ${liquid ? 'ml' : 'g'}'
                : servingText)
          : (liquid ? '100 ml' : '100 g'),
      servingGrams: hasServing ? grams : 100,
      perServing: perServing,
      source: FoodSource.openFoodFacts,
      liquid: liquid,
    );
  }

  /// Calories per 100 g, checked against the macros. Open Food Facts is
  /// crowd-edited: kJ sometimes lands in the kcal field, and some products
  /// list only kJ or only macros.
  static double checkedKcal({
    required double kcal,
    required double kj,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    // Atwater factors: 4 kcal/g protein and carbs, 9 kcal/g fat.
    final fromMacros = 4 * protein + 4 * carbs + 9 * fat;
    if (kcal <= 0 && kj > 0) return kj / _kjPerKcal;
    if (kcal <= 0) return fromMacros;
    // A kJ figure typed as kcal is about 4.2 times too big; if dividing
    // brings it in line with the macros, that's what happened.
    // Skipped when a separate kJ figure agrees with the kcal (then the
    // kcal is right, e.g. alcohol, which the macros leave out).
    final consistent = kj > 0 && (kj - kcal * _kjPerKcal).abs() / kj < 0.1;
    if (!consistent && fromMacros > 20 && kcal > fromMacros * 2.5) {
      final fixed = kcal / _kjPerKcal;
      if ((fixed - fromMacros).abs() / fromMacros < 0.25) return fixed;
    }
    return kcal;
  }

  static const _kjPerKcal = 4.184;

  static final _volume = RegExp(r'\d\s*(ml|cl|l)\b', caseSensitive: false);

  /// Drinks are measured by volume: Open Food Facts then gives nutrition
  /// per 100 ml and serving sizes in ml.
  static bool isLiquid(Map<String, Object?> product) {
    String field(String k) => '${product[k] ?? ''}'.toLowerCase().trim();
    if (field('nutrition_data_per') == '100ml') return true;
    for (final k in ['serving_quantity_unit', 'product_quantity_unit']) {
      final u = field(k);
      if (u == 'ml' || u == 'cl' || u == 'l') return true;
      if (u == 'g' || u == 'kg') return false;
    }
    final serving = field('serving_size');
    if (serving.isNotEmpty) {
      return _volume.hasMatch(serving) &&
          !RegExp(r'\d\s*g\b').hasMatch(serving);
    }
    final quantity = field('quantity');
    return _volume.hasMatch(quantity) &&
        !RegExp(r'\d\s*(g|kg)\b').hasMatch(quantity);
  }

  static String _g(double g) =>
      g == g.roundToDouble() ? '${g.round()}' : g.toStringAsFixed(1);

  static String _text(Object? v, int max) {
    final s = v is String ? v.trim() : '';
    return s.length > max ? s.substring(0, max) : s;
  }

  /// "Nutella, Ferrero" or ["Chobani"] → first brand.
  static String _brand(Object? v) {
    final first = switch (v) {
      final List<Object?> l when l.isNotEmpty => '${l.first}',
      final String s => s.split(',').first,
      _ => '',
    };
    return _text(first, 60);
  }

  /// The whole request, however the server drips data, is capped too.
  static const _totalTimeout = Duration(seconds: 20);

  static Future<String> _httpGet(Uri url) => _download(url).timeout(
    _totalTimeout,
    onTimeout: () => throw const FoodLookupException('Timed out'),
  );

  static Future<String> _download(Uri url) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(url).timeout(_timeout);
      // Answers come straight from the fixed HTTPS hosts; no redirects.
      req.followRedirects = false;
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode == 404) return '{"status":0}';
      if (res.statusCode != 200) {
        throw FoodLookupException('HTTP ${res.statusCode}');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(_timeout)) {
        bytes.add(chunk);
        if (bytes.length > _maxBytes) {
          throw const FoodLookupException('Response too large');
        }
      }
      return utf8.decode(bytes.takeBytes(), allowMalformed: true);
    } on SocketException catch (e) {
      logError('OpenFoodFacts: offline: $e');
      throw const FoodLookupException('No connection');
    } on TimeoutException {
      throw const FoodLookupException('Timed out');
    } on HttpException catch (e) {
      logError('OpenFoodFacts: $e');
      throw const FoodLookupException('Connection failed');
    } finally {
      client.close(force: true);
    }
  }
}
