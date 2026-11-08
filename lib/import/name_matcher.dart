import 'package:health_app/models/exercise_catalog.dart';

/// Matches exercise names from other apps to the library.
///
/// Names like "Bench Press (Barbell)" become "barbell bench press"; a few
/// common names are mapped directly; otherwise the library entry sharing
/// the most words wins, but only if it's a close match (no forced guesses).
class NameMatcher {
  NameMatcher(this.catalog);

  final ExerciseCatalog catalog;

  /// Common names that don't match the library's wording.
  static const _known = {
    'barbell bench press': '0025',
    'bench press': '0025',
    'barbell squat': '0043',
    'squat': '0043',
    'back squat': '0043',
    'barbell back squat': '0043',
    'barbell deadlift': '0032',
    'deadlift': '0032',
    'overhead press': 'ohp',
    'barbell overhead press': 'ohp',
    'military press': 'ohp',
    'barbell military press': 'ohp',
    'pull up': '0652',
    'pull-up': '0652',
    'pullup': '0652',
    'chin up': '1326',
    'plank': 'plank',
    'push up': '0662',
    'pushup': '0662',
    'cable lat pulldown': '2330',
    'lat pulldown': '2330',
    'barbell row': '0027',
    'bent over row': '0027',
    'barbell bent over row': '0027',
    'dumbbell bicep curl': '0294',
    'bicep curl': '0294',
    'dumbbell biceps curl': '0294',
    'leg press': '0739',
    'barbell romanian deadlift': '0085',
    'romanian deadlift': '0085',
    'barbell hip thrust': '1409',
    'hip thrust': '1409',
    'cable triceps pushdown': '0201',
    'triceps pushdown': '0201',
    'dumbbell lateral raise': '0334',
    'lateral raise': '0334',
  };

  /// For tests: every library id the shortcuts use.
  static Iterable<String> get knownIds => _known.values.toSet();

  static final _paren = RegExp(r'^(.*?)\s*\((.+)\)\s*$');

  /// "Bench Press (Barbell)" → "barbell bench press".
  static String normalise(String name) {
    var n = name.toLowerCase().trim();
    final m = _paren.firstMatch(n);
    if (m != null) n = '${m.group(2)} ${m.group(1)}';
    return n
        // Letters of any script, so names in Chinese or Japanese aren't
        // all reduced to nothing (and so all "match").
        .replaceAll(RegExp(r'[^\p{L}\p{N}\- ]', unicode: true), ' ')
        .replaceAll('biceps', 'bicep')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Set<String> _words(String s) =>
      s.split(RegExp(r'[\s\-]+')).where((w) => w.length > 1).toSet();

  CatalogExercise? match(String name) {
    final n = normalise(name);
    if (n.isEmpty) return null;
    final known = _known[n];
    if (known != null) return catalog.byId(known);
    final words = _words(n);
    CatalogExercise? best;
    var bestScore = 0.0;
    for (final e in catalog.all) {
      final en = normalise(e.name);
      if (en == n) return e;
      final ew = _words(en);
      final common = words.intersection(ew).length;
      if (common == 0) continue;
      // Similarity, slightly preferring shorter (more basic) names.
      final score = common / words.union(ew).length - ew.length * 0.001;
      if (score > bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return bestScore >= 0.6 ? best : null;
  }
}
