import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/screens/legal_screen.dart';

/// The headings of a Markdown document, lower case, without numbers or
/// emphasis.
Set<String> _headings(String path) => {
  for (final line in File(path).readAsLinesSync())
    if (line.startsWith('#'))
      line
          .replaceFirst(RegExp(r'^#+\s*(\d+\.\s*)?'), '')
          .replaceAll('*', '')
          .toLowerCase(),
};

void main() {
  test('every Terms section in the app is a section of the full EULA', () {
    final full = _headings('docs/EULA.md');
    for (final (title, _) in LegalScreen.termsSections) {
      expect(full, contains(title.toLowerCase()), reason: title);
    }
  });

  test('the legal documents name the publisher and contact', () {
    for (final path in [
      'docs/EULA.md',
      'docs/DMCA.md',
      'docs/PRIVACY_POLICY.md',
    ]) {
      final text = File(path).readAsStringSync();
      expect(text, contains('UntrustedTech'), reason: path);
      expect(text, contains(legalContact), reason: path);
    }
    expect(
      File('LICENSE').readAsStringSync(),
      contains('PolyForm Noncommercial License 1.0.0'),
    );
  });

  test('no placeholders are left in the legal documents', () {
    for (final path in [
      'docs/EULA.md',
      'docs/DMCA.md',
      'docs/PRIVACY_POLICY.md',
      'README.md',
    ]) {
      final text = File(path).readAsStringSync();
      expect(
        RegExp(r'\[(JURISDICTION|PUBLISHER|EMAIL|your [^\]]*)\]')
            .hasMatch(text),
        isFalse,
        reason: path,
      );
    }
  });
}
