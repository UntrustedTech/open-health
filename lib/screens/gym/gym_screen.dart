import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/gym/check_in_pass.dart';
import 'package:health_app/screens/gym/gym_card.dart';
import 'package:health_app/screens/gym/membership_editor.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// The gym: the membership card, checking in with it, and the visits made.
class GymScreen extends StatelessWidget {
  const GymScreen({super.key});

  /// Visits listed; older ones still count in the totals.
  static const _listed = 30;

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(AppRoute<void>(title: 'Gym', builder: (_) => const GymScreen()));

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymStore>();
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    final m = gym.membership;
    final last = gym.lastVisit;
    return LargeTitlePage(
      title: 'Gym',
      trailing: HeaderButton(
        icon: m == null ? Icons.add_rounded : Icons.edit_rounded,
        semanticLabel: m == null ? 'Add Membership' : 'Edit Membership',
        onTap: () => MembershipEditor.show(context),
      ),
      children: [
        if (m == null)
          const _AddMembership()
        else
          Pressable(
            semanticLabel: tr('Show ${m.gym} card to check in'),
            onTap: () => CheckInPass.open(context),
            child: MembershipCard(membership: m, today: today),
          ),
        const SizedBox(height: 14),
        CheckInButton(
          label: gym.checkedInToday ? 'Show Card Again' : 'Check In',
          onTap: () => CheckInPass.open(context),
        ),
        if (gym.checkedInToday && last != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Checked in today at ${formatTimeOfDay(last.hour, last.minute)}',
              textAlign: TextAlign.center,
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
        const SectionTitle('Visits'),
        Row(
          children: [
            _Stat(label: 'This Week', value: '${gym.thisWeek}'),
            const SizedBox(width: 10),
            _Stat(label: 'This Month', value: '${gym.thisMonth}'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Stat(
              label: 'Week Streak',
              value:
                  '${gym.weekStreak} ${gym.weekStreak == 1 ? 'week' : 'weeks'}',
            ),
            const SizedBox(width: 10),
            _Stat(label: 'All Time', value: '${gym.total}'),
          ],
        ),
        if (gym.visits.isNotEmpty)
          GroupedSection(
            header: 'Recent',
            hasLeading: false,
            footer: 'Tap a visit to remove it.',
            children: [
              for (final v in gym.visits.take(_listed))
                InfoRow(
                  title: formatDay(v, today),
                  value: formatTimeOfDay(v.hour, v.minute),
                  onTap: () => _removeVisit(context, v),
                ),
            ],
          ),
        if (m != null && m.notes.isNotEmpty)
          GroupedSection(
            header: 'Notes',
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(m.notes, style: context.body),
              ),
            ],
          ),
      ],
    );
  }

  static Future<void> _removeVisit(BuildContext context, DateTime at) async {
    final store = context.read<GymStore>();
    final ok = await confirmDestructive(
      context,
      title: 'Remove This Visit?',
      message:
          '${DateFormat.yMMMEd().format(at)} at '
          '${formatTimeOfDay(at.hour, at.minute)}.',
      action: 'Remove',
    );
    if (ok) await store.removeVisit(at);
  }
}

/// The big green button that shows the card and checks in.
class CheckInButton extends StatelessWidget {
  const CheckInButton({
    super.key,
    required this.onTap,
    this.label = 'Check In',
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(gymColor);
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: ShapeDecoration(shape: const StadiumBorder(), color: c),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded, color: context.onColor(c), size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: context.headline.copyWith(color: context.onColor(c)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMembership extends StatelessWidget {
  const _AddMembership();

  @override
  Widget build(BuildContext context) => IosCard(
    onTap: () => MembershipEditor.show(context),
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    child: Column(
      children: [
        IconTile(
          icon: Icons.card_membership_rounded,
          color: gymColor,
          size: 52,
        ),
        const SizedBox(height: 12),
        Text('Add Your Membership', style: context.headline),
        const SizedBox(height: 4),
        Text(
          'Scan your gym card\'s barcode once, then check in with your '
          'phone.',
          textAlign: TextAlign.center,
          style: context.footnote.copyWith(color: context.secondaryLabel),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: cardSurface(context, radius: AppTheme.listRadius),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: context.number(24)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.caption1.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    ),
  );
}
