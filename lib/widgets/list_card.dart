import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// One row of a [ListCard]: what it is, how it stands, where it goes.
typedef ListCardItem = ({
  IconData icon,
  Color color,
  String title,
  String subtitle,
  VoidCallback onTap,
});

/// Rows in one card, as an inset grouped list: an icon, a title with how
/// it stands under it, and a chevron. Keeps a tab short where a tile for
/// each would make it long.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.items});

  final List<ListCardItem> items;

  @override
  Widget build(BuildContext context) => IosCard(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0)
            Container(
              height: 0.6,
              margin: const EdgeInsets.only(left: 58),
              color: context.separatorColor,
            ),
          ListCardRow(item: item),
        ],
      ],
    ),
  );
}

class ListCardRow extends StatelessWidget {
  const ListCardRow({super.key, required this.item});

  final ListCardItem item;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${tr(item.title)}, ${tr(item.subtitle)}',
    excludeSemantics: true,
    onTap: item.onTap,
    child: Pressable(
      onTap: item.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTheme.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
          child: Row(
            children: [
              IconTile(icon: item.icon, color: item.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: context.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.subheadline.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.tertiaryLabel,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
