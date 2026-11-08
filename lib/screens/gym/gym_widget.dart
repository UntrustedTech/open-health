import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/screens/gym/check_in_pass.dart';
import 'package:health_app/screens/gym/gym_card.dart';
import 'package:health_app/screens/gym/gym_screen.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/board_tiles.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// The gym on the Fitness board. Small and medium: this week's visits and a
/// Check In button, which shows the card (medium adds the month, streak
/// and total). Large: the membership card itself, ready to scan.
class GymWidget extends StatelessWidget {
  const GymWidget({super.key, required this.size});

  final WidgetSize size;

  @override
  Widget build(BuildContext context) {
    if (size == WidgetSize.large) return const _GymLarge();
    final gym = context.watch<GymStore>();
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    final m = gym.membership;
    final c = context.resolve(gymColor);
    final last = gym.lastVisit;
    final caption = m == null
        ? null
        : gym.checkedInToday && last != null
        ? 'In at ${formatTimeOfDay(last.hour, last.minute)} today'
        : last == null
        ? 'No visits yet'
        : 'Last visit ${formatDay(last, today)}';
    return StatWidget(
      size: size,
      icon: Icons.fitness_center_rounded,
      color: gymColor,
      title: m == null || m.gym.isEmpty ? 'Gym' : m.gym,
      semanticLabel: m == null
          ? 'Gym. Add your membership'
          : 'Gym, ${gym.thisWeek} visits this week. Check in',
      onTap: () => CheckInPass.open(context),
      value: m == null
          ? StatValue('Add your card', size: size, placeholder: true)
          : StatValue('${gym.thisWeek}', unit: 'this week', size: size),
      caption: caption,
      smallVisual: Container(
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: context.pastel(c),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 16, color: c),
            const SizedBox(width: 4),
            Text(
              m == null ? 'Set Up' : 'Check In',
              style: context.footnote.copyWith(
                fontWeight: FontWeight.w700,
                color: context.labelColor,
              ),
            ),
          ],
        ),
      ),
      facts: m == null
          ? const []
          : [
              (label: 'This Month', value: '${gym.thisMonth}'),
              (label: 'Week Streak', value: '${gym.weekStreak}'),
              (label: 'All Time', value: '${gym.total}'),
            ],
    );
  }
}

class _GymLarge extends StatelessWidget {
  const _GymLarge();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymStore>();
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    final m = gym.membership;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionTitle(
          'Gym',
          top: 0,
          action: 'Visits',
          onAction: () => GymScreen.open(context),
        ),
        if (m == null)
          IosCard(
            onTap: () => CheckInPass.open(context),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const IconTile(
                  icon: Icons.card_membership_rounded,
                  color: gymColor,
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Your Membership', style: context.headline),
                      Text(
                        'Scan your gym card once, then check in with your '
                        'phone.',
                        style: context.footnote.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          Pressable(
            semanticLabel: tr('Show ${m.gym} card to check in'),
            onTap: () => CheckInPass.open(context),
            child: MembershipCard(membership: m, today: today),
          ),
          const SizedBox(height: 12),
          CheckInButton(
            label: gym.checkedInToday ? 'Show Card Again' : 'Check In',
            onTap: () => CheckInPass.open(context),
          ),
        ],
      ],
    );
  }
}
