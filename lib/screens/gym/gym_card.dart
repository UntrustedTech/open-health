import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/gym/card_code.dart';
import 'package:health_app/models/gym.dart';
import 'package:health_app/screens/workouts/fitness_hub.dart' show fitnessGreen;
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';

/// The gym's colour: the Fitness green.
const gymColor = fitnessGreen;

/// A membership's code drawn black on white, as scanners read best: a strip
/// for barcodes, a square for QR and similar codes. Says so if the code
/// can't be drawn in its format.
class CardBarcode extends StatelessWidget {
  const CardBarcode({
    super.key,
    required this.membership,
    this.height = 96,
    this.showText = true,
  });

  final GymMembership membership;

  /// Height of a strip barcode; square codes are this tall and wide too,
  /// at least 140.
  final double height;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final m = membership;
    final square = m.format.isSquare;
    final side = square ? (height < 140 ? 140.0 : height) : height;
    return Semantics(
      label: '${m.format.label} for ${m.code}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          height: side + (showText && !square ? 20 : 0),
          width: square ? side : double.infinity,
          child: BarcodeWidget(
            barcode: CardCode.barcodeFor(m.format),
            data: m.code,
            color: const Color(0xFF000000),
            drawText: showText && !square,
            style: const TextStyle(
              color: Color(0xFF000000),
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
            errorBuilder: (context, error) => Center(
              child: Text(
                'This code can\'t be shown as ${m.format.label}. Edit the '
                'membership to choose another format.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B6F80), fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A membership as a card, like one in a wallet: the gym, the member and
/// their number and plan, with the code underneath.
class MembershipCard extends StatelessWidget {
  const MembershipCard({
    super.key,
    required this.membership,
    required this.today,
    this.showCode = true,
  });

  final GymMembership membership;
  final DateTime today;
  final bool showCode;

  @override
  Widget build(BuildContext context) {
    final m = membership;
    final c = context.resolve(gymColor);
    final expired = m.isExpired(today);
    final expires = m.expires;
    final light = Color.lerp(c, const Color(0xFF000000), 0.35)!;
    final dark = Color.lerp(c, const Color(0xFF000000), 0.78)!;
    const onCard = Color(0xFFFFFFFF);
    const faint = Color(0xB3FFFFFF);
    Widget detail(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.caption2.copyWith(
            color: faint,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.subheadline.copyWith(
            color: onCard,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final details = [
      if (m.memberNumber.isNotEmpty) ('Member No.', m.memberNumber),
      if (m.plan.isNotEmpty) ('Plan', m.plan),
      if (expires != null)
        (
          expired ? 'Expired' : 'Valid Until',
          DateFormat.yMMMd().format(expires),
        ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: context.cardBorderRadius(AppTheme.heroRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, dark],
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x33FFFFFF),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: onCard,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m.gym.isEmpty ? 'Gym Membership' : m.gym,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title3.copyWith(color: onCard),
                ),
              ),
              if (expired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    color: context.resolve(Palette.red),
                  ),
                  child: Text(
                    'Expired',
                    style: context.caption1.copyWith(
                      color: onCard,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (m.memberName.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              m.memberName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.headline.copyWith(color: onCard),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 22,
              runSpacing: 10,
              children: [for (final (l, v) in details) detail(l, v)],
            ),
          ],
          if (showCode && m.hasCode) ...[
            const SizedBox(height: 16),
            Center(child: CardBarcode(membership: m, height: 72)),
          ],
        ],
      ),
    );
  }
}
