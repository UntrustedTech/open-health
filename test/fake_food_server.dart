import 'dart:io';

import 'package:health_app/nutrition/open_food_facts.dart';

/// Open Food Facts answering from saved responses (no network).
OpenFoodFacts fakeOpenFoodFacts({List<Uri>? calls}) => OpenFoodFacts(
  fetch: (url) async {
    calls?.add(url);
    if (url.host == 'search.openfoodfacts.org') {
      return File('test/fixtures/off_search.json').readAsStringSync();
    }
    if (url.path.contains('3017620422003')) {
      return File('test/fixtures/off_product.json').readAsStringSync();
    }
    return '{"status":0}';
  },
);
