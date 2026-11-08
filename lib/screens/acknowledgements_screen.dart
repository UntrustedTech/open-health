import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/legal_screen.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// The app's legal terms, then licences for the fonts, data and packages
/// it uses.
class AcknowledgementsScreen extends StatefulWidget {
  const AcknowledgementsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Acknowledgements',
      builder: (_) => const AcknowledgementsScreen(),
    ),
  );

  @override
  State<AcknowledgementsScreen> createState() => _AcknowledgementsState();
}

class _AcknowledgementsState extends State<AcknowledgementsScreen> {
  late final _licenses = _load();

  static Future<Map<String, List<String>>> _load() async {
    final byPackage = <String, List<String>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final text = entry.paragraphs.map((p) => p.text).join('\n\n');
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).add(text);
      }
    }
    return Map.fromEntries(
      byPackage.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<String>>>(
      future: _licenses,
      builder: (context, snap) {
        final data = snap.data;
        return LargeTitlePage(
          title: 'Acknowledgements',
          children: [
            GroupedSection(
              children: [
                _legalRow(
                  context,
                  icon: Icons.gavel_rounded,
                  title: 'Terms of Use',
                  onTap: () => LegalScreen.openTerms(context),
                ),
                _legalRow(
                  context,
                  icon: Icons.copyright_rounded,
                  title: 'Copyright & DMCA',
                  onTap: () => LegalScreen.openCopyright(context),
                ),
              ],
            ),
            if (data == null)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: CupertinoActivityIndicator(),
              )
            else
              GroupedSection(
                header: 'Other',
                footer: 'Health is built with these open-source projects.',
                hasLeading: false,
                children: [
                  for (final MapEntry(key: name, value: texts) in data.entries)
                    CupertinoListTile(
                      title: Text(name),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => Navigator.of(context).push(
                        AppRoute<void>(
                          title: name,
                          builder: (_) =>
                              _LicenseText(name: name, texts: texts),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

Widget _legalRow(
  BuildContext context, {
  required IconData icon,
  required String title,
  required VoidCallback onTap,
}) => InfoRow(
  leading: IconTile(icon: icon, color: context.resolve(Palette.grey)),
  title: title,
  chevron: true,
  onTap: onTap,
);

class _LicenseText extends StatelessWidget {
  const _LicenseText({required this.name, required this.texts});

  final String name;
  final List<String> texts;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(name),
        previousPageTitle: tr('Acknowledgements'),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          for (final t in texts)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(t, style: context.footnote),
            ),
        ],
      ),
    );
  }
}
