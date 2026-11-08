import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/health_snapshot.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/screens/achievements_screen.dart';
import 'package:health_app/screens/body/progress_photos_screen.dart';
import 'package:health_app/screens/edit_profile_screen.dart';
import 'package:health_app/screens/goals_screen.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/screens/settings_screen.dart';
import 'package:health_app/screens/summary/goal_card.dart';
import 'package:health_app/screens/health_report_screen.dart';
import 'package:health_app/screens/recap/recap_screen.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/photo_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/glow_tile.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// You: who you are, your body, your progress and your Medical ID. App
/// settings live behind the cog.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final workouts = context.watch<WorkoutStore>();
    final profile = store.profile;
    var i = 0;
    return LargeTitlePage(
      title: 'Profile',
      trailing: HeaderButton(
        icon: Icons.settings_rounded,
        semanticLabel: tr('Settings'),
        onTap: () => SettingsScreen.open(context),
      ),
      children: [
        Appear(
          index: i++,
          child: _IdentityCard(profile: profile, today: store.today),
        ),
        const SizedBox(height: 12),
        Appear(index: i++, child: const _BodyCard()),
        const SizedBox(height: 12),
        Appear(
          index: i++,
          child: _StatsStrip(
            workouts: workouts.all.length,
            streak: workouts.streak,
            days: store.daysLogged,
          ),
        ),
        const SectionTitle('Your Goal'),
        Appear(index: i++, child: const GoalCard()),
        const SectionTitle('Your Health'),
        Appear(index: i++, child: const _Shortcuts()),
        Appear(
          index: i++,
          child: _MedicalIdCard(profile: profile),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Center(
            child: CupertinoButton(
              onPressed: () => SettingsScreen.open(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'App Settings',
                    style: context.subheadline.copyWith(
                      color: context.tint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar with an aurora ring, name and details, and an Edit button.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.today});

  final UserProfile profile;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final age = profile.ageOn(today);
    final details = [
      if (age != null) '$age years',
      if (profile.sex.isNotEmpty) profile.sex,
      if (profile.heightCm case final cm?) Units.height(cm),
    ].join(' · ');
    final tint = context.tint;
    return IosCard(
      onTap: () => EditProfileScreen.open(context),
      tint: tint,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        children: [
          // The avatar in a ring of the theme colour, with a soft glow.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  tint,
                  Color.lerp(tint, const Color(0xFFFFFFFF), 0.45)!,
                  tint,
                ],
              ),
              boxShadow: [
                BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 24),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.cardBackground,
              ),
              child: Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.labelColor,
                ),
                child: profile.initials.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        size: 40,
                        color: context.onLabel,
                      )
                    : Text(
                        profile.initials,
                        style: context.title1.copyWith(
                          color: context.onLabel,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.name.isEmpty ? 'Add Your Name' : profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.title1.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            details.isEmpty ? 'Tap to add your details' : details,
            textAlign: TextAlign.center,
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: tint.withValues(alpha: 0.16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 15, color: tint),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Edit Profile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.footnote.copyWith(
                      color: context.isDark ? tint : context.labelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Weight, height, BMI and age in one card.
class _BodyCard extends StatelessWidget {
  const _BodyCard();

  static String _bmiNote(double bmi) => switch (bmi) {
    < 18.5 => 'Below range',
    < 25 => 'Healthy range',
    < 30 => 'Above range',
    _ => 'Well above range',
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final profile = store.profile;
    final weight = store.latestReading(MetricType.weight)?.value;
    final height = profile.heightCm;
    final bmi = HealthSnapshot.bmi(weight, height);
    final age = profile.ageOn(store.today);
    final cells = [
      (
        Icons.monitor_weight_rounded,
        Palette.purple,
        'Weight',
        weight == null ? 'Not Set' : Units.weight(weight),
        null as String?,
        () => MetricDetailScreen.open(context, MetricType.weight),
      ),
      (
        Icons.height_rounded,
        Palette.blue,
        'Height',
        height == null ? 'Not Set' : Units.height(height),
        null,
        () => EditProfileScreen.open(context),
      ),
      (
        Icons.speed_rounded,
        Palette.teal,
        'BMI',
        bmi == null ? 'Not Set' : bmi.toStringAsFixed(1),
        bmi == null ? null : _bmiNote(bmi),
        () => MetricDetailScreen.open(context, MetricType.weight),
      ),
      (
        Icons.cake_rounded,
        Palette.orange,
        'Age',
        age == null ? 'Not Set' : '$age',
        profile.birthDate == null
            ? null
            : DateFormat.MMMd().format(profile.birthDate!),
        () => EditProfileScreen.open(context),
      ),
    ];
    Widget cell(int i) {
      final (icon, color, label, value, note, onTap) = cells[i];
      final c = context.resolve(color);
      return Expanded(
        child: Semantics(
          button: true,
          label: '$label $value${note == null ? '' : ', $note'}',
          excludeSemantics: true,
          onTap: onTap,
          child: IosCard(
            onTap: onTap,
            tint: color,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconTile(icon: icon, color: c, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.footnote.copyWith(
                          color: context.secondaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: context.number(22, weight: FontWeight.w800),
                  ),
                ),
                Text(
                  note ?? ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.caption1.copyWith(
                    color: c,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const gap = SizedBox(width: 12, height: 12);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cell(0), gap, cell(1)],
          ),
        ),
        gap,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cell(2), gap, cell(3)],
          ),
        ),
      ],
    );
  }
}

/// Workouts, streak and days logged in one strip.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.workouts,
    required this.streak,
    required this.days,
  });

  final int workouts;
  final int streak;
  final int days;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        Icons.local_fire_department_rounded,
        Palette.green,
        workouts,
        workouts == 1 ? 'Workout' : 'Workouts',
      ),
      (Icons.whatshot_rounded, Palette.orange, streak, 'Day Streak'),
      (
        Icons.calendar_month_rounded,
        Palette.blue,
        days,
        days == 1 ? 'Day Logged' : 'Days Logged',
      ),
    ];
    return Row(
      children: [
        for (final (i, (icon, color, value, label)) in stats.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: '$value $label',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                decoration: cardSurface(context, tint: color),
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context
                            .resolve(color)
                            .withValues(alpha: context.isDark ? 0.2 : 0.15),
                      ),
                      child: Icon(
                        icon,
                        color: context.resolve(color),
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedNumber(
                      value: value.toDouble(),
                      format: (v) =>
                          NumberFormat.decimalPattern().format(v.round()),
                      style: context.number(22, weight: FontWeight.w800),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption1.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Health Details, Daily Goals, Progress Photos, Achievements, the
/// monthly recap and the health report.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final photos = context.watch<PhotoStore>().photos.length;
    final badges = context.watch<AchievementStore>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlowGrid(
        children: [
          GlowTile(
            icon: Icons.person_rounded,
            color: Palette.blue,
            title: 'Health Details',
            value: store.profile.heightCm == null ? null : 'Up to date',
            placeholder: tr('Add your details'),
            onTap: () => EditProfileScreen.open(context),
          ),
          GlowTile(
            icon: Icons.track_changes_rounded,
            color: Palette.orange,
            title: 'Daily Goals',
            value: '${formatValue(MetricType.steps, store.goals.steps)} steps',
            onTap: () => GoalsScreen.open(context),
          ),
          GlowTile(
            icon: Icons.photo_camera_rounded,
            color: Palette.purple,
            title: 'Progress Photos',
            value: photos == 0 ? null : '$photos photos',
            placeholder: tr('Track how you change'),
            onTap: () => ProgressPhotosScreen.open(context),
          ),
          GlowTile(
            icon: Icons.workspace_premium_rounded,
            color: Palette.yellow,
            title: 'Achievements',
            value: '${badges.medals} medals',
            onTap: () => AchievementsScreen.open(context),
          ),
          GlowTile(
            icon: Icons.auto_graph_rounded,
            color: Palette.purple,
            title: 'Monthly Recap',
            value: DateFormat.MMMM().format(store.today),
            onTap: () => RecapScreen.open(context),
          ),
          GlowTile(
            icon: Icons.description_rounded,
            color: Palette.blue,
            title: 'Health Report',
            value: 'Share a PDF',
            onTap: () => HealthReportScreen.open(context),
          ),
        ],
      ),
    );
  }
}

/// Medical ID: a red header, then the details filled in (or an
/// invitation to set it up).
class _MedicalIdCard extends StatelessWidget {
  const _MedicalIdCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final birth = profile.birthDate;
    final rows = [
      ('Date of Birth', birth == null ? '' : DateFormat.yMMMd().format(birth)),
      ('Blood Type', profile.bloodType),
      ('Allergies & Reactions', profile.allergies),
      ('Medical Conditions', profile.conditions),
      if (!kStoreEdition) ('Medications', profile.medications),
      (
        'Emergency Contact',
        [
          profile.emergencyName,
          profile.emergencyPhone,
        ].where((s) => s.isNotEmpty).join(' · '),
      ),
    ].where((r) => r.$2.isNotEmpty).toList();
    final red = context.resolve(Palette.red);
    return IosCard(
      padding: EdgeInsets.zero,
      onTap: () => EditProfileScreen.open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: ShapeDecoration(
              color: red,
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radius),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emergency_rounded,
                  color: CupertinoColors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Medical ID',
                    style: context.headline.copyWith(
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
                Text(
                  rows.isEmpty ? 'Set Up' : 'Edit',
                  style: context.subheadline.copyWith(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: CupertinoColors.white,
                  size: 14,
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                kStoreEdition
                    ? 'Add allergies and an emergency contact so they\'re '
                          'ready when it matters.'
                    : 'Add allergies, medications and an emergency contact so '
                          'they\'re ready when it matters.',
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                ),
              ),
            )
          else
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.footnote.copyWith(
                        color: red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: context.body),
                  ],
                ),
              ),
          if (rows.isNotEmpty) const SizedBox(height: 14),
        ],
      ),
    );
  }
}
