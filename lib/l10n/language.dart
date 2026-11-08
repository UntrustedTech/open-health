import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter/widgets.dart' hide Text;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_app/l10n/translator.dart';
import 'package:health_app/utils/log.dart';

/// A language the app can be shown in.
enum AppLanguage {
  system(null, 'System'),
  en('en', 'English'),
  es('es', 'Español'),
  zh('zh', '中文（简体）'),
  ja('ja', '日本語'),
  fr('fr', 'Français'),
  de('de', 'Deutsch');

  const AppLanguage(this.code, this.nativeName);

  /// Null for [system].
  final String? code;

  /// The language's name in itself, as language pickers show it.
  final String nativeName;

  Locale? get locale => switch (this) {
    system => null,
    zh => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    _ => Locale(code!),
  };

  static AppLanguage named(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => system);

  /// The supported language closest to [locale], or English.
  static AppLanguage closestTo(Locale locale) => values.firstWhere(
    (l) => l.code != null && l.code == locale.languageCode,
    orElse: () => en,
  );

  static List<Locale> get supportedLocales => [
    for (final l in values) ?l.locale,
  ];
}

/// The current translation, read by every [Text] in the app.
Translator _current = Translator.english;

/// [text] in the app's language. Text widgets do this themselves; use it
/// for strings Flutter draws itself, like a text field's placeholder.
String tr(String text) => _current(text);

/// The app's language: chosen in Settings → Language, or the phone's.
class LanguageController extends ChangeNotifier {
  LanguageController(this._prefs, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final SharedPreferencesAsync? _prefs;
  final AssetBundle _bundle;

  static const prefsKey = 'app_language';

  AppLanguage _choice = AppLanguage.system;
  AppLanguage _shown = AppLanguage.en;

  /// What the user picked (possibly [AppLanguage.system]).
  AppLanguage get choice => _choice;

  /// The language actually shown.
  AppLanguage get shown => _shown;

  Locale get locale => _shown.locale ?? const Locale('en');

  Future<void> load() async {
    String? saved;
    try {
      saved = await _prefs?.getString(prefsKey);
    } on Exception catch (e) {
      logError('Language: could not read the setting: $e');
    }
    _choice = AppLanguage.named(saved);
    await _apply();
  }

  Future<void> choose(AppLanguage language) async {
    if (language == _choice) return;
    _choice = language;
    try {
      await _prefs?.setString(prefsKey, language.code ?? 'system');
    } on Exception catch (e) {
      logError('Language: could not save the setting: $e');
    }
    await _apply();
    notifyListeners();
    _refreshAll();
  }

  /// The phone's language changed: follow it when set to System.
  Future<void> systemChanged() async {
    if (_choice != AppLanguage.system) return;
    final before = _shown;
    await _apply();
    if (_shown == before) return;
    notifyListeners();
    _refreshAll();
  }

  Future<void> _apply() async {
    _shown = _choice == AppLanguage.system
        ? AppLanguage.closestTo(PlatformDispatcher.instance.locale)
        : _choice;
    final code = _shown.code!;
    final table = code == 'en' ? Translator.english : await _table(code);
    // Dates and numbers in the language's own style, ready before the
    // words switch so a frame never mixes the two.
    final intlLocale = code == 'zh' ? 'zh_CN' : code;
    try {
      await initializeDateFormatting(intlLocale);
      Intl.defaultLocale = intlLocale;
    } on Exception catch (e) {
      logError('Language: no date formats for $intlLocale: $e');
      Intl.defaultLocale = 'en';
    }
    _current = table;
  }

  Future<Translator> _table(String code) async {
    try {
      final json = await _bundle.loadString('assets/l10n/$code.json');
      return Translator({
        for (final MapEntry(:key, :value)
            in (jsonDecode(json) as Map<String, dynamic>).entries)
          if (value is String) key: value,
      });
    } on Object catch (e) {
      // Even a damaged file mustn't stop the app from opening.
      logError('Language: could not load $code: $e');
      return Translator.english;
    }
  }

  /// Rebuilds every widget, so text that was already on screen (including
  /// screens kept behind the current one) switches language without
  /// losing where the user is.
  static void _refreshAll() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    mark(root);
  }
}

/// For tests and screenshots: show [table] (English → translation)
/// without assets.
void debugUseTranslations(Map<String, String> table) =>
    _current = table.isEmpty ? Translator.english : Translator(table);
