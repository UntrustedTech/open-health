import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' hide Text;
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/l10n/translator.dart';

final _hole = RegExp(r'\{\d+\}');

void main() {
  group('Translator', () {
    final t = Translator({
      'Settings': 'Ajustes',
      'Imperial': 'Imperial (EE. UU.)',
      '{0} reminders on': '{0} recordatorios activos',
      'From {0} to {1}': '{1} から {0}',
      'Units: {0}': 'Unidades: {0}',
      'Off': '',
      '{0} and {1}': '{0} y {1}',
      'Done.{0}': 'Hecho.{0}',
    });

    test('leaves English as it is', () {
      expect(Translator.english('Settings'), 'Settings');
    });

    test('translates known strings and keeps unknown ones', () {
      expect(t('Settings'), 'Ajustes');
      expect(t('Alex'), 'Alex');
      // An empty translation is treated as missing.
      expect(t('Off'), 'Off');
    });

    test('fills templates, in the translation\'s order', () {
      expect(t('3 reminders on'), '3 recordatorios activos');
      expect(t('From 5 to 9'), '9 から 5');
    });

    test('translates parts that are known strings', () {
      expect(t('Units: Imperial'), 'Unidades: Imperial (EE. UU.)');
      expect(
        t('Units: Settings, Imperial'),
        'Unidades: Ajustes, Imperial (EE. UU.)',
      );
    });

    test('matches capitals and surrounding punctuation', () {
      expect(t('SETTINGS'), 'AJUSTES');
      expect(t('Settings:'), 'Ajustes:');
    });

    test('translates sentences joined at runtime one by one', () {
      expect(
        t('Settings. Units: Imperial'),
        'Ajustes. Unidades: Imperial (EE. UU.)',
      );
    });

    test('fills a template whose last part is empty', () {
      expect(t('Done.'), 'Hecho.');
      expect(t('Done. Settings'), 'Hecho. Ajustes');
    });

    test('keeps line breaks between sentences', () {
      expect(
        t('Settings.\n\nUnits: Imperial'),
        'Ajustes.\n\nUnidades: Imperial (EE. UU.)',
      );
    });

    test('leaves the user\'s own text alone', () {
      expect(t('Salt and Pepper'), 'Salt and Pepper');
      expect(t('Settings and Imperial'), 'Ajustes y Imperial (EE. UU.)');
    });

    test('gives the same answer from its cache', () {
      expect(t('5 reminders on'), '5 recordatorios activos');
      expect(t('5 reminders on'), '5 recordatorios activos');
    });
  });

  group('language files', () {
    for (final l in AppLanguage.values.where(
      (l) => l.code != null && l.code != 'en',
    )) {
      test('${l.code} keeps every placeholder', () {
        final table = (jsonDecode(
          File('assets/l10n/${l.code}.json').readAsStringSync(),
        ) as Map<String, dynamic>).cast<String, String>();
        expect(table.length, greaterThan(2000));
        for (final MapEntry(:key, :value) in table.entries) {
          final a = _hole.allMatches(key).map((m) => m[0]).toList()..sort();
          final b = _hole.allMatches(value).map((m) => m[0]).toList()..sort();
          expect(b, a, reason: '"$key" → "$value"');
        }
        // The basics a user sees first.
        for (final key in ['Settings', 'Summary', 'Cancel', 'Language']) {
          expect(table[key], isNotNull, reason: key);
        }
      });
    }
  });

  // New text needs translating: run tool/l10n_extract.py and add what's
  // missing to assets/l10n/*.json.
  test('every string in the app has a translation', () {
    final run = Process.runSync('python3', ['tool/l10n_extract.py']);
    if (run.exitCode != 0) {
      markTestSkipped('python3 is not available: ${run.stderr}');
      return;
    }
    final source = (jsonDecode(run.stdout as String) as Map).keys
        .cast<String>()
        // Error details for the Error Log, not shown as UI text.
        .where((k) => !k.contains('Exception') && !k.startsWith('ErrorLog'));
    for (final l in AppLanguage.values.where(
      (l) => l.code != null && l.code != 'en',
    )) {
      final table = jsonDecode(
        File('assets/l10n/${l.code}.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final missing = source.where((k) => !table.containsKey(k)).toList();
      expect(missing, isEmpty, reason: '${l.code} is missing these');
    }
  });

  testWidgets('Text shows the chosen language', (tester) async {
    debugUseTranslations({
      'Settings': 'Einstellungen',
      '{0} steps': '{0} Schritte',
    });
    addTearDown(() => debugUseTranslations(const {}));
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Text('Settings'),
            Text('10,000 steps'),
            Text.rich(TextSpan(text: 'Settings')),
          ],
        ),
      ),
    );
    expect(find.text('Einstellungen'), findsNWidgets(2));
    expect(find.text('10,000 Schritte'), findsOneWidget);
    expect(tr('Settings'), 'Einstellungen');
  });

  // Flutter's own Text would stay in English, so every file that draws
  // text hides it and uses the app's.
  test('every screen uses the translating Text', () {
    final flutter = RegExp(
      r"^import 'package:flutter/(cupertino|widgets|material)\.dart'"
      r"(?! (hide|show|as) )",
      multiLine: true,
    );
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.contains('/l10n/') &&
            RegExp(r'\bText(\.rich)?\(').hasMatch(f.readAsStringSync()) &&
            flutter.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('picks the closest supported language', () {
    expect(AppLanguage.closestTo(const Locale('de', 'AT')), AppLanguage.de);
    expect(
      AppLanguage.closestTo(const Locale.fromSubtags(languageCode: 'zh')),
      AppLanguage.zh,
    );
    expect(AppLanguage.closestTo(const Locale('ko')), AppLanguage.en);
    expect(AppLanguage.named('ja'), AppLanguage.ja);
    expect(AppLanguage.named('nonsense'), AppLanguage.system);
  });
}
