import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/achievements.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// All achievements: earned ones in colour, the rest with progress.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Achievements',
      builder: (_) => const AchievementsScreen(),
    ),
  );

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the list counts as seeing new badges.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<AchievementStore>();
      unawaited(store.recordNew().then((_) => store.markAllSeen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AchievementStore>();
    final all = store.all;
    return LargeTitlePage(
      title: 'Achievements',
      children: [
        _MedalSummary(store: store),
        for (final group in AchievementGroup.values) ...[
          SectionTitle(group.label),
          LayoutBuilder(
            builder: (context, c) {
              const perRow = 3;
              final w = (c.maxWidth - 2 * 12) / perRow;
              final items = all.where((a) => a.group == group).toList();
              return Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  for (final (i, a) in items.indexed)
                    SizedBox(
                      width: w,
                      child: Appear(
                        index: i,
                        child: _BadgeTile(
                          achievement: a,
                          earnedOn: store.earnedOn(a.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.achievement, this.earnedOn});

  final Achievement achievement;
  final DateTime? earnedOn;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final tier = a.tier;
    return Pressable(
      semanticLabel:
          '${a.title}, ${tier == null ? 'not earned' : tier.label}'
          '${a.maxed ? '' : ', ${(a.progress * 100).round()}% to ${a.nextTier!.label}'}',
      onTap: () => _showDetail(context, a, earnedOn),
      child: Column(
        children: [
          Medal(achievement: a, size: 76),
          const SizedBox(height: 8),
          Text(
            a.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: context.footnote.copyWith(
              fontWeight: FontWeight.w700,
              color: a.earned ? context.labelColor : context.secondaryLabel,
            ),
          ),
          const SizedBox(height: 2),
          TierPips(tier: tier),
        ],
      ),
    );
  }

  static Future<void> _showDetail(
    BuildContext context,
    Achievement a,
    DateTime? on,
  ) {
    if (a.earned) unawaited(HapticFeedback.mediumImpact());
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => _BadgeDetail(achievement: a, earnedOn: on),
    );
  }
}

class _BadgeDetail extends StatelessWidget {
  const _BadgeDetail({required this.achievement, this.earnedOn});

  final Achievement achievement;
  final DateTime? earnedOn;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final reduce = Motion.reduced(context);
    final on = earnedOn;
    final medal = Medal(achievement: a, size: 130);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        decoration: ShapeDecoration(
          color: context.cardBackground,
          shape: context.cardShape(AppTheme.radius + 6),
          shadows: context.skinShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reduce)
              medal
            else
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY((1 - t) * math.pi)
                    ..scaleByDouble(0.6 + 0.4 * t, 0.6 + 0.4 * t, 1, 1),
                  child: child,
                ),
                child: medal,
              ),
            const SizedBox(height: 20),
            Text(a.title, style: context.title2),
            const SizedBox(height: 4),
            Text(
              a.tier == null
                  ? 'Not earned yet'
                  : on == null
                  ? a.tier!.label
                  : '${a.tier!.label} · ${DateFormat.yMMMd().format(on)}',
              style: context.subheadline.copyWith(
                color: a.tier == null
                    ? context.secondaryLabel
                    : _tierText(context, a.tier!),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final t in Tier.values)
              _TierRow(
                achievement: a,
                tier: t,
                earnedOn: context.read<AchievementStore>().tierEarnedOn(
                  a.id,
                  t,
                ),
              ),
            CupertinoButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Readable text colour for [tier] (the metals are pale).
Color _tierText(BuildContext context, Tier tier) =>
    context.isDark ? tier.light : tier.dark;

/// Colours of a medal's metal rim for [tier], light to dark.
List<Color> _metal(Tier tier) => tier == Tier.diamond
    ? const [
        Color(0xFFB8F0FF),
        Color(0xFFC9B6FF),
        Color(0xFFFFB8E4),
        Color(0xFFB8F0FF),
      ]
    : [tier.light, tier.dark, tier.light];

/// A round medal: the achievement's colour inside a rim of the tier's
/// metal once earned; grey with progress toward bronze before that.
class Medal extends StatelessWidget {
  const Medal({super.key, required this.achievement, this.size = 64});

  final Achievement achievement;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final color = context.resolve(a.color);
    final tier = a.tier;
    final grey = context.resolve(Palette.grey);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MedalRim(
          tier: tier,
          // Before bronze, the rim fills toward it.
          progress: tier == null ? a.progress : 1,
          track: context.fillColor,
          glow: tier?.dark,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.13),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tier != null
                    ? [
                        Color.lerp(color, CupertinoColors.white, 0.3)!,
                        color,
                        Color.lerp(color, CupertinoColors.black, 0.4)!,
                      ]
                    : [
                        grey.withValues(alpha: 0.35),
                        grey.withValues(alpha: 0.18),
                      ],
              ),
            ),
            child: Icon(
              a.icon,
              size: size * 0.36,
              color: tier != null
                  ? CupertinoColors.white
                  : context.secondaryLabel.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalRim extends CustomPainter {
  _MedalRim({
    required this.tier,
    required this.progress,
    required this.track,
    required this.glow,
  });

  final Tier? tier;
  final double progress;
  final Color track;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final t = tier;
    if (t == null) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
      if (progress > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * progress,
          false,
          paint..color = Tier.bronze.light.withValues(alpha: 0.8),
        );
      }
      return;
    }
    final shader = SweepGradient(
      colors: _metal(t),
      transform: const GradientRotation(-math.pi / 4),
    ).createShader(rect);
    if (glow case final g?) {
      canvas.drawCircle(
        rect.center,
        rect.width / 2,
        Paint()
          ..color = g.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.06),
      );
    }
    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      paint
        ..shader = shader
        ..color = const Color(0xFFFFFFFF),
    );
    // A thin bright edge, like polished metal.
    canvas.drawCircle(
      rect.center,
      rect.width / 2 - stroke / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_MedalRim old) =>
      old.tier != tier || old.progress != progress || old.track != track;
}

/// Five small pips, filled up to [tier] in each tier's metal.
class TierPips extends StatelessWidget {
  const TierPips({super.key, required this.tier, this.size = 7});

  final Tier? tier;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in Tier.values)
          Container(
            width: size,
            height: size,
            margin: EdgeInsets.symmetric(horizontal: size * 0.25),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: tier != null && t.index <= tier!.index
                  ? LinearGradient(colors: [t.light, t.dark])
                  : null,
              color: tier != null && t.index <= tier!.index
                  ? null
                  : context.fillColor,
            ),
          ),
      ],
    ),
  );
}

/// One tier in a medal's detail: what it takes, and when it was earned or
/// how close it is.
class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.achievement,
    required this.tier,
    required this.earnedOn,
  });

  final Achievement achievement;
  final Tier tier;
  final DateTime? earnedOn;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final reached = a.tier != null && tier.index <= a.tier!.index;
    final isNext = a.nextTier == tier;
    final on = earnedOn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: reached
                  ? LinearGradient(colors: _metal(tier).take(2).toList())
                  : null,
              border: reached
                  ? null
                  : Border.all(color: _tierText(context, tier), width: 1.5),
            ),
            child: reached
                ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Color(0xFF1A1A1A),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: context.footnote.copyWith(
                    color: _tierText(context, tier),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  a.describe(a.targetOf(tier)),
                  style: context.footnote.copyWith(
                    color: reached
                        ? context.labelColor
                        : context.secondaryLabel,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(height: 4),
                  CapsuleProgress(
                    value: a.progress,
                    color: _tierText(context, tier),
                    height: 5,
                  ),
                ],
              ],
            ),
          ),
          if (reached && on != null)
            Text(
              DateFormat.yMMMd().format(on),
              style: context.caption1.copyWith(color: context.secondaryLabel),
            )
          else if (isNext)
            Text(
              '${(a.progress * 100).round()}%',
              style: context.caption1.copyWith(
                color: context.secondaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// Medals earned in all, and how many of each tier.
class _MedalSummary extends StatelessWidget {
  const _MedalSummary({required this.store});

  final AchievementStore store;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final t in Tier.values)
        t: store.all.where((a) => (a.tier?.index ?? -1) >= t.index).length,
    };
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${store.medals} of ${store.totalMedals} medals',
            style: context.headline,
          ),
          const SizedBox(height: 4),
          Text(
            'Each achievement has five ranks, from Bronze to Diamond.',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final t in Tier.values)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _metal(t).take(2).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${counts[t]}',
                        style: context.number(17, weight: FontWeight.w700),
                      ),
                      Text(
                        t.label,
                        maxLines: 1,
                        style: context.caption2.copyWith(
                          color: _tierText(context, t),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Summary card: latest badges and the next one to go for.
class AchievementsCard extends StatefulWidget {
  const AchievementsCard({super.key});

  @override
  State<AchievementsCard> createState() => _AchievementsCardState();
}

class _AchievementsCardState extends State<AchievementsCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<AchievementStore>().recordNew());
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AchievementStore>();
    // The closest next rank to go for.
    final next =
        (store.all.where((a) => !a.maxed).toList()
              ..sort((a, b) => b.progress.compareTo(a.progress)))
            .firstOrNull;
    // Room for the next badge's name when there is one.
    final recent = store.recent.take(next == null ? 4 : 2).toList();
    final fresh = store.unseen.length;
    final gold = context.resolve(Palette.yellow);
    return IosCard(
      onTap: () => AchievementsScreen.open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: gold, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Achievements',
                  style: context.subheadline.copyWith(
                    color: context.labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (fresh > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: ShapeDecoration(
                    color: context.tint,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    '$fresh New',
                    style: context.caption1.copyWith(
                      color: context.onColor(context.tint),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  '${store.medals} of ${store.totalMedals}',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final a in recent) ...[
                Medal(achievement: a, size: 52),
                const SizedBox(width: 10),
              ],
              if (next != null) ...[
                if (recent.isNotEmpty)
                  Container(
                    width: 0.5,
                    height: 44,
                    color: context.separatorColor,
                    margin: const EdgeInsets.only(right: 10),
                  ),
                Medal(achievement: next, size: 52),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next: ${next.nextTier!.label} ${next.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.subheadline.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(next.progress * 100).round()}% there',
                        style: context.footnote.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
