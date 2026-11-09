import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/app_edition.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/onboarding/welcome_page.dart' show appMaker;
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Where legal notices are sent.
const legalContact = 'support@untrustedtech.dev';

/// A legal document in the app: the Terms of Use or the Copyright & DMCA
/// Policy. Short versions of `docs/EULA.md` and `docs/DMCA.md`, which have
/// the same sections and are the full text.
class LegalScreen extends StatelessWidget {
  const LegalScreen._({
    required this.title,
    required this.icon,
    required this.color,
    required this.headline,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String headline;
  final List<(String, String)> sections;

  static Future<void> openTerms(BuildContext context) =>
      Navigator.of(context).push(
        AppRoute<void>(
          title: 'Terms of Use',
          builder: (_) => const LegalScreen._(
            title: 'Terms of Use',
            icon: Icons.gavel_rounded,
            color: Palette.indigo,
            headline: 'Using Health',
            sections: termsSections,
          ),
        ),
      );

  static Future<void> openCopyright(BuildContext context) =>
      Navigator.of(context).push(
        AppRoute<void>(
          title: 'Copyright',
          builder: (_) => const LegalScreen._(
            title: 'Copyright',
            icon: Icons.copyright_rounded,
            color: Palette.teal,
            headline: '© 2026 $appMaker',
            sections: copyrightSections,
          ),
        ),
      );

  /// The Terms of Use, by section (the headings of `docs/EULA.md`).
  static const termsSections = [
    (
      'Source code license',
      'Health\'s source code is public under the PolyForm Noncommercial '
          'License 1.0.0. You may build, use, change and share it for '
          'non-commercial purposes only, with our copyright notice and the '
          'license kept with every copy. You may not sell it, use it '
          'commercially or present it as your own.',
    ),
    (
      'Who can use Health',
      'You must be at least 13 (or older where the law requires). Under '
          '18, a parent or guardian must agree to these Terms and supervise '
          'your use, especially of calorie, fasting and workout features.',
    ),
    (
      'Not medical advice',
      'Health is a wellness tracker, not a medical device, and isn\'t '
          'approved by any regulator. Scores, trends, estimates and '
          'suggestions may be wrong. Talk to a doctor before changing your '
          'exercise, diet, fasting or medication. In an emergency, call your '
          'local emergency number.',
    ),
    (
      'Feature-specific warnings',
      kStoreEdition
          ? 'Health can\'t detect heart or other conditions. Never use it to '
                'decide a dose of insulin or any medication. Food data can be '
                'wrong: always check the label for allergens. Cycle '
                'predictions must not be used for contraception. Never use '
                'Health while driving, and don\'t rely on GPS for navigation '
                'or safety.'
          : 'Health can\'t detect heart or other conditions. Never use it to '
                'decide a dose of insulin or any medication, and don\'t rely on '
                'medication reminders where a missed dose could harm you. Food '
                'data can be wrong: always check the label for allergens. Cycle '
                'predictions must not be used for contraception. Never use Health '
                'while driving, and don\'t rely on GPS for navigation or safety.',
    ),
    (
      'Exercise and assumption of risk',
      'Workouts and activities, including aerial, climbing, board, water '
          'and snow sports, carry risks of serious injury and death. Get '
          'proper instruction, equipment and supervision, and stop if '
          'something hurts. You take part entirely at your own risk.',
    ),
    (
      'Your data and responsibility',
      'Your data stays on this phone (see Privacy); we never receive it, '
          'so health-privacy laws like HIPAA don\'t cover it. Keep your phone '
          'secure, make backups, and take care with files you export: we '
          'can\'t recover lost data.',
    ),
    (
      'Acceptable use',
      'Don\'t use Health against the law or others\' rights, track someone '
          'without their consent, add content you have no right to, or pass '
          'off a modified version as ours.',
    ),
    (
      'Third-party services',
      'Food lookups (Open Food Facts), street maps (OpenStreetMap) and '
          'your phone\'s health data service are run by others under their '
          'own terms, only when you use them.',
    ),
    (
      'Names and branding',
      'The source license covers the code, not our names. "$appMaker" and Health\'s '
          'published name and icon mark our official releases; a modified '
          'version may say it\'s based on Health, but not that it\'s ours.',
    ),
    (
      'No warranty',
      'Health is provided "as is", with all faults and without any '
          'warranty, as in its source license.',
    ),
    (
      'Limitation of liability',
      'To the fullest extent the law allows, we and Health\'s contributors '
          'aren\'t liable for any injury, loss of data or other harm from '
          'using it, and you agree to cover claims caused by your misuse. '
          'Claims must be brought within a year. Consumer rights that can\'t '
          'be waived still apply.',
    ),
    (
      'Disputes',
      'Contact us first and give us 60 days to put things right. These '
          'Terms follow New Jersey law, and disputes go to the state or '
          'federal courts in New Jersey. Where the law allows, claims are '
          'brought individually, not in class actions, without a jury.',
    ),
    (
      'Changes, availability and ending',
      'We may change or stop Health, or update these Terms; using it after '
          'a change means you accept them. Questions: $legalContact.',
    ),
  ];

  /// The Copyright & DMCA Policy, by section (the headings of
  /// `docs/DMCA.md`).
  static const copyrightSections = [
    (
      'Your rights',
      'Health\'s source code is public under the PolyForm Noncommercial '
          'License 1.0.0: you may build, use, change and share it for '
          'non-commercial purposes only, keeping our copyright notice and the '
          'license. Selling it, using it commercially or removing our '
          'notices infringes our copyright.',
    ),
    (
      'Reporting infringement by Health',
      'If you believe something in Health infringes your copyright, email '
          'our copyright agent at $legalContact with the subject "DMCA '
          'Notice", including: your signature; the work infringed; where it '
          'is in Health; your contact details; a good-faith statement that '
          'the use isn\'t authorised; and a statement, under penalty of '
          'perjury, that your notice is accurate and you may act for the '
          'owner.',
    ),
    (
      'Counter-notice',
      'If material you contributed was removed by mistake, you can send a '
          'counter-notice to the same address, as described in the full '
          'policy.',
    ),
    (
      'Reporting infringement of Health',
      'Found Health being sold, used commercially, shared without our '
          'notices or passed off as someone else\'s? Send the link to '
          '$legalContact.',
    ),
    (
      'Others\' work in Health',
      'Health includes fonts, data and code by others under their own '
          'licenses; see Acknowledgements.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LargeTitlePage(
      title: title,
      children: [
        Center(
          child: IconTile(icon: icon, color: color, size: 64),
        ),
        const SizedBox(height: 12),
        Text(headline, textAlign: TextAlign.center, style: context.title2),
        for (final (heading, text) in sections)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: IosCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(heading, style: context.headline),
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: context.subheadline),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'The full text is in Health\'s source code. Contact: '
            '$legalContact',
            textAlign: TextAlign.center,
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ),
      ],
    );
  }
}
