import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/cupertino.dart' as widgets show Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Settings → Language: the phone's language, or one picked here.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Language', builder: (_) => const LanguageScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageController>();
    final phone = AppLanguage.closestTo(
      View.of(context).platformDispatcher.locale,
    );
    Widget? tick(AppLanguage l) => l == language.choice
        ? Icon(Icons.check_rounded, color: context.tint)
        : null;
    return LargeTitlePage(
      title: 'Language',
      children: [
        GroupedSection(
          hasLeading: false,
          footer:
              'The exercise library, food names from Open Food Facts and the '
              'Terms of Use stay in English.',
          children: [
            CupertinoListTile(
              title: const Text('System'),
              subtitle: widgets.Text(phone.nativeName),
              trailing: tick(AppLanguage.system),
              onTap: () => language.choose(AppLanguage.system),
            ),
            for (final l in AppLanguage.values.skip(1))
              CupertinoListTile(
                // Each language in itself, so it can be found from any.
                title: widgets.Text(l.nativeName, locale: l.locale),
                trailing: tick(l),
                onTap: () => language.choose(l),
              ),
          ],
        ),
      ],
    );
  }
}
