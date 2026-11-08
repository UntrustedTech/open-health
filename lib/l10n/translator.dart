/// Turns the app's English text into the chosen language.
///
/// Every string literal shown in the app is a key in
/// `assets/l10n/<code>.json` (see `tool/l10n_extract.py`), with
/// interpolations written as `{0}`, `{1}`, … So a string built at runtime,
/// like "3 reminders on", is found by matching it against the template
/// "{0} reminders on", and the parts filled in ("3") are translated too
/// when they are themselves known strings.
class Translator {
  Translator(Map<String, String> table) {
    for (final MapEntry(:key, :value) in table.entries) {
      if (value.isEmpty) continue;
      if (_hole.hasMatch(key)) {
        final t = _Template.parse(key, value);
        if (t != null) _templates.add(t);
      } else {
        _exact[key] = value;
      }
    }
    // The most specific template wins.
    _templates.sort((a, b) => b.literal.compareTo(a.literal));
  }

  /// English: everything as written.
  static final english = Translator(const {});

  static final _hole = RegExp(r'\{\d+\}');

  final _exact = <String, String>{};
  final _templates = <_Template>[];
  late final _upper = {
    for (final MapEntry(:key, :value) in _exact.entries)
      key.toUpperCase(): value.toUpperCase(),
  };

  /// Recent results, as text that changes every second (timers, live
  /// heart rate) would otherwise be matched against every template.
  final _cache = <String, String>{};
  static const _cacheSize = 3000;

  bool get isEnglish => _exact.isEmpty && _templates.isEmpty;

  /// [text] in this language, or [text] when it isn't known.
  String call(String text) {
    if (isEnglish || text.isEmpty) return text;
    final hit = _exact[text];
    if (hit != null) return hit;
    final cached = _cache.remove(text);
    if (cached != null) return _cache[text] = cached;
    final out = _lookup(text);
    if (_cache.length >= _cacheSize) _cache.remove(_cache.keys.first);
    return _cache[text] = out;
  }

  String _lookup(String text) {
    // Titles a theme shows in capitals, e.g. "SETTINGS".
    if (text == text.toUpperCase()) {
      final up = _upper[text];
      if (up != null) return up;
    }
    // Leading or trailing space or punctuation around a known string.
    final core = _edges.firstMatch(text);
    if (core != null && core.group(2)!.length != text.length) {
      final inner = _exact[core.group(2)!];
      if (inner != null) return '${core.group(1)}$inner${core.group(3)}';
    }
    for (final t in _templates) {
      final filled = t.fill(text, _part, _known);
      if (filled != null) return filled;
    }
    // Sentences joined at runtime: each on its own, keeping the line
    // breaks between them.
    final gaps = _sentenceEnd.allMatches(text).toList();
    if (gaps.isNotEmpty) {
      final out = StringBuffer();
      var start = 0;
      var changed = false;
      for (final gap in [...gaps, null]) {
        final sentence = text.substring(start, gap?.start ?? text.length);
        final translated = call(sentence);
        changed |= translated != sentence;
        out.write(translated);
        if (gap != null) {
          out.write(gap[0]);
          start = gap.end;
        }
      }
      if (changed) return out.toString();
    }
    return text;
  }

  static final _sentenceEnd = RegExp(r'(?<=[.!?])\s+(?=[A-Z])');

  static final _edges = RegExp(r'^([\s•·:]*)(.*?)([\s•·:.…]*)$', dotAll: true);

  bool _known(String s) =>
      _exact.containsKey(s) ||
      _upper.containsKey(s) ||
      (s.contains(', ') && s.split(', ').every(_known));

  /// A filled-in part: translated when it is a known string.
  String _part(String s) {
    final hit = _exact[s];
    if (hit != null) return hit;
    if (s == s.toUpperCase()) return _upper[s] ?? s;
    // A list, e.g. "Full Body, Outdoor Run".
    if (s.contains(', ')) return s.split(', ').map(_part).join(', ');
    return s;
  }
}

class _Template {
  _Template(
    this.pattern,
    this.target,
    this.anchor,
    this.literal,
    this.letters,
    this.order,
  );

  static final _numeric = RegExp(r'\d');

  /// How many letters the template's fixed text has.
  final int letters;

  /// The template as a pattern, each hole a group.
  final RegExp pattern;
  final String target;

  /// The template's longest piece of fixed text, which a match must contain.
  final String anchor;

  /// How many fixed characters the template has.
  final int literal;

  /// The hole numbers, in the order they appear in the English.
  final List<int> order;

  /// Below this many letters of fixed text, a template is so general
  /// ("{0} and {1}", "Day {0}") that it would also match the user's own
  /// text, like a food called "Salt and Pepper".
  static const _general = 8;

  static _Template? parse(String key, String target) {
    final parts = key.split(Translator._hole);
    final holes = [
      for (final m in Translator._hole.allMatches(key))
        int.parse(m[0]!.substring(1, m[0]!.length - 1)),
    ];
    final fixed = parts.join();
    // "{0} {1}" would match anything.
    if (!RegExp('[A-Za-z]{2}').hasMatch(fixed)) return null;
    final source = StringBuffer('^');
    for (var i = 0; i < parts.length; i++) {
      source.write(RegExp.escape(parts[i]));
      if (i < holes.length) source.write('(.*?)');
    }
    source.write(r'$');
    final anchor = parts.reduce((a, b) => b.length > a.length ? b : a);
    return _Template(
      RegExp(source.toString(), dotAll: true),
      target,
      anchor,
      fixed.length,
      RegExp('[A-Za-z]').allMatches(fixed).length,
      holes,
    );
  }

  String? fill(
    String text,
    String Function(String) part,
    bool Function(String) known,
  ) {
    if (!text.contains(anchor)) return null;
    final m = pattern.firstMatch(text);
    if (m == null) return null;
    // A general template only fills in numbers and the app's own words.
    if (letters < _general) {
      for (var i = 1; i <= m.groupCount; i++) {
        final v = m[i]!;
        if (v.isNotEmpty && !_numeric.hasMatch(v) && !known(v)) return null;
      }
    }
    final values = <int, String>{
      for (var i = 0; i < order.length; i++) order[i]: part(m[i + 1]!),
    };
    return target.replaceAllMapped(
      Translator._hole,
      (h) => values[int.parse(h[0]!.substring(1, h[0]!.length - 1))] ?? h[0]!,
    );
  }
}
