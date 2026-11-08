import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/workout_edit_screen.dart';
import 'package:health_app/screens/workouts/workout_insights.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/bar_chart.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/route_map.dart';
import 'package:health_app/workout/calories.dart';
import 'package:health_app/workout/geo.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/sync/health_sync_service.dart';

/// A workout's full breakdown. In review mode (right after finishing) the
/// user rates the effort, adds notes and saves or discards it.
class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key, required this.session})
    : route = null,
      isReview = false;

  const WorkoutDetailScreen.review({
    super.key,
    required this.session,
    required List<GeoPoint> this.route,
  }) : isReview = true;

  final WorkoutSession session;

  /// Known route (review mode); otherwise loaded from storage.
  final List<GeoPoint>? route;
  final bool isReview;

  static Future<void> open(BuildContext context, WorkoutSession session) =>
      Navigator.of(context).push(
        AppRoute<void>(
          title: session.type.label,
          builder: (_) => WorkoutDetailScreen(session: session),
        ),
      );

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late WorkoutSession _session = widget.session;
  late final _notes = TextEditingController(text: widget.session.notes);
  List<GeoPoint> _route = const [];
  bool _saving = false;

  late final WorkoutStore _store = context.read<WorkoutStore>();

  /// Saves the notes if they changed. Called when the field is left and
  /// when the screen closes, since a multi-line field has no "done".
  void _saveNotes() {
    if (widget.isReview || _session.isImported) return;
    final text = _notes.text.trim();
    if (text == _session.notes.trim()) return;
    _session = _session.copyWith(notes: text);
    unawaited(_store.update(_session));
  }

  @override
  void initState() {
    super.initState();
    _store; // Read now; it's needed again in dispose.
    final known = widget.route;
    if (known != null) {
      _route = known;
    } else if (_session.hasRoute) {
      unawaited(
        _store.routeOf(_session.id).then((r) {
          if (mounted) setState(() => _route = r);
        }),
      );
    }
  }

  @override
  void dispose() {
    _saveNotes();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    unawaited(HapticFeedback.mediumImpact());
    final session = _session.copyWith(notes: _notes.text.trim());
    final health = context.read<HealthStore>();
    final failures = health.saveFailures;
    await _store.save(session, route: _route);
    // A failed write only shows the app's save banner, so keep the
    // recovery copy and stay here to try again.
    if (health.saveFailures != failures) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    await _store.clearCheckpoint();
    if (_store.settings.saveToHealthConnect && mounted) {
      await _writeToHealthConnect(session);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _writeToHealthConnect(WorkoutSession s) async {
    final health = context.read<HealthStore>();
    final source = context.read<HealthSource>();
    final weight =
        health.latestReading(MetricType.weight)?.value ?? defaultWeightKg;
    try {
      final ok = await source.writeWorkout(
        s,
        // The app's own active calories plus resting energy (1 MET), so
        // the total never comes out below what the app showed.
        totalKcal:
            s.activeKcal +
            totalCalories(met: 1, weightKg: weight, duration: s.activeDuration),
      );
      if (!ok) logError('Workout: Health Connect did not accept the workout');
    } on Exception catch (e) {
      logError('Workout: saving to Health Connect failed: $e');
    }
  }

  Future<void> _discard() async {
    final ok = await confirmDestructive(
      context,
      message: 'This workout will not be saved.',
      action: 'Discard Workout',
    );
    if (!ok || !mounted) return;
    await _store.clearCheckpoint();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDestructive(
      context,
      message: 'This workout and its activity data will be deleted.',
      action: 'Delete Workout',
    );
    if (!ok || !mounted) return;
    await _store.delete(_session.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _setRpe(int? rpe) {
    setState(
      () => _session = rpe == null
          ? _session.copyWith(clearRpe: true)
          : _session.copyWith(rpe: rpe),
    );
    if (!widget.isReview) {
      unawaited(_store.update(_session));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final review = widget.isReview;
    return PopScope(
      canPop: !review,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_discard());
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          automaticallyImplyLeading: !review,
          leading: review
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _discard,
                  child: Text(
                    'Discard',
                    style: TextStyle(color: context.destructive),
                  ),
                )
              : null,
          middle: Text(review ? 'Workout Summary' : s.type.label),
          trailing: review
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _saving ? null : _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              : s.isImported
              ? null
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await WorkoutEditScreen.open(context, session: _session);
                    if (!context.mounted) return;
                    final fresh = context.read<WorkoutStore>().byId(
                      _session.id,
                    );
                    if (fresh != null) {
                      setState(() {
                        _session = fresh;
                        _notes.text = fresh.notes;
                      });
                    }
                  },
                  child: const Text('Edit'),
                ),
        ),
        child: PageList(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.margin,
            12,
            AppTheme.margin,
            32,
          ),
          children: [
            Appear(child: _Header(session: s)),
            const SizedBox(height: 16),
            Appear(
              index: 1,
              child: _StatsGrid(session: s, top: topSpeed(_route)),
            ),
            if (_route.length >= 2) ...[
              const SizedBox(height: 16),
              Appear(
                index: 2,
                child: ClippedCard(
                  radius: AppTheme.radius,
                  child: SizedBox(
                    height: 240,
                    child: ColoredBox(
                      color: context.cardBackground,
                      child: RouteMap(
                        points: _route,
                        style: context.watch<WorkoutStore>().settings.mapStyle,
                        color: s.type.color,
                        interactive: true,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (rollingSpeeds(_route) case final speeds when speeds.length >= 2)
              _SpeedSection(speeds: speeds, color: s.type.color),
            if (s.splits.isNotEmpty) _SplitsSection(session: s),
            if (s.laps.isNotEmpty)
              GroupedSection(
                header: 'Laps',
                hasLeading: false,
                children: [
                  for (final (i, lap) in s.laps.indexed)
                    InfoRow(
                      title: 'Lap ${i + 1}',
                      value:
                          '${formatClock(Duration(seconds: lap.seconds))}'
                          '${lap.meters >= 10 ? ' · ${formatDistance(lap.meters, allowMeters: true)}' : ''}',
                    ),
                ],
              ),
            Appear(index: 3, child: ComparisonCard(session: s)),
            if (s.exercises.isNotEmpty) ...[
              SessionMuscles(session: s),
              ExerciseBreakdown(session: s),
            ],
            _EffortSection(
              rpe: s.rpe,
              onChanged: s.isImported ? null : _setRpe,
            ),
            if (!s.isImported)
              GroupedSection(
                header: 'Notes',
                hasLeading: false,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: CupertinoTextField.borderless(
                      controller: _notes,
                      placeholder: tr('How did it feel?'),
                      maxLines: 4,
                      minLines: 2,
                      maxLength: 500,
                      onTapOutside: (_) {
                        FocusScope.of(context).unfocus();
                        _saveNotes();
                      },
                    ),
                  ),
                ],
              ),
            if (review)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: CupertinoButton.filled(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save Workout'),
                ),
              )
            else if (!s.isImported)
              GroupedSection(
                hasLeading: false,
                children: [
                  InfoRow(
                    title: 'Delete Workout',
                    titleColor: context.destructive,
                    onTap: _delete,
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Recorded by ${s.notes.isEmpty ? 'another app' : s.notes} and '
                  'imported from '
                  '${context.read<HealthSyncService>().sourceName}.',
                  textAlign: TextAlign.center,
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final when =
        '${DateFormat.yMMMEd().format(s.start)} · '
        '${DateFormat.jm().format(s.start)} – ${DateFormat.jm().format(s.end)}';
    return Row(
      children: [
        IconTile(icon: s.type.icon, color: s.type.color, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.type.label, style: context.title2),
              Text(
                when,
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.session, this.top});

  final WorkoutSession session;

  /// Top speed from the route, in m/s.
  final double? top;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final tiles = <(String, String)>[
      ('Workout Time', formatClock(s.activeDuration)),
      if (s.distanceMeters >= 10)
        ('Distance', formatDistance(s.distanceMeters)),
      if (s.distanceMeters >= 10)
        s.type.showsSpeed
            ? (
                'Avg Speed',
                '${formatSpeed(switch (s.speedKmh) {
                  final kmh? => kmh / 3.6,
                  null => null,
                })} ${Units.speedUnit}',
              )
            : (
                'Avg Pace',
                '${formatPace(s.paceSecondsPerKm)} ${Units.paceUnit}',
              ),
      if (top case final t?)
        ('Top Speed', '${formatSpeed(t)} ${Units.speedUnit}'),
      ('Active Energy', formatKcal(s.activeKcal)),
      if (s.elevationGainMeters >= 1)
        ('Elevation Gain', Units.elevation(s.elevationGainMeters)),
      if (s.completedSets > 0) ('Sets', '${s.completedSets}'),
      if (s.volumeKg > 0) ('Volume', Units.weight(s.volumeKg, decimals: 0)),
      if (s.intervalProgram case final p?) ('Program', p),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, value) in tiles)
              SizedBox(
                width: w,
                child: IosCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: context.footnote.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: context.title3.copyWith(
                            color: s.type.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Speed through the workout, averaged into equal stretches of time; tap
/// one to read it.
class _SpeedSection extends StatefulWidget {
  const _SpeedSection({required this.speeds, required this.color});

  final List<({DateTime time, double mps})> speeds;
  final Color color;

  /// Stretches the workout is split into.
  static const _bars = 30;

  @override
  State<_SpeedSection> createState() => _SpeedSectionState();
}

class _SpeedSectionState extends State<_SpeedSection> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final speeds = widget.speeds;
    final start = speeds.first.time;
    final span = speeds.last.time.difference(start).inSeconds + 1;
    final bars = speedBars(speeds, _SpeedSection._bars);
    String minuteAt(int i) =>
        '${(span * i / bars.length / 60).round()}\u00A0min';
    final pick = _selected;
    final picked = pick == null ? null : bars[pick];
    return GroupedSection(
      header: 'Speed',
      hasLeading: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                picked == null
                    ? 'Tap the chart to read the speed.'
                    : '${formatSpeed(picked)} ${Units.speedUnit} at '
                          '${minuteAt(pick!)}',
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                ),
              ),
              const SizedBox(height: 8),
              BarChart(
                values: [
                  for (final b in bars) b == null ? null : Units.speedOut(b),
                ],
                color: widget.color,
                height: 160,
                selected: _selected,
                onSelect: (i) => setState(() => _selected = i),
                axisLabel: (v) => '${v.round()}',
                labels: [
                  for (var i = 0; i < bars.length; i++)
                    i % 10 == 0 ? minuteAt(i) : '',
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [speeds] averaged into [count] equal stretches of time, in m/s; null
/// where there's none (a pause).
@visibleForTesting
List<double?> speedBars(List<({DateTime time, double mps})> speeds, int count) {
  final start = speeds.first.time;
  final span = speeds.last.time.difference(start).inMilliseconds + 1;
  final sums = List<double>.filled(count, 0);
  final counts = List<int>.filled(count, 0);
  for (final s in speeds) {
    final i = (s.time.difference(start).inMilliseconds * count ~/ span).clamp(
      0,
      count - 1,
    );
    sums[i] += s.mps;
    counts[i]++;
  }
  return [
    for (var i = 0; i < count; i++) counts[i] == 0 ? null : sums[i] / counts[i],
  ];
}

/// Horizontal pace bars per kilometre; the fastest is highlighted.
class _SplitsSection extends StatelessWidget {
  const _SplitsSection({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final splits = session.splits;
    final fastest = splits.reduce(min);
    final slowest = splits.reduce(max);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Splits', style: context.headline),
            const SizedBox(height: 8),
            for (final (i, s) in splits.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text('${i + 1}', style: context.subheadline),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          // Faster splits draw longer bars.
                          final span = max(slowest - fastest, 1);
                          final f = 0.45 + 0.55 * (slowest - s) / span;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: f),
                              duration: Motion.slow,
                              curve: Motion.curve,
                              builder: (context, v, _) => Container(
                                width: c.maxWidth * v,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: s == fastest
                                      ? session.type.color
                                      : session.type.color.withValues(
                                          alpha: 0.45,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        formatPace(s.toDouble()),
                        textAlign: TextAlign.end,
                        style: context.subheadline.copyWith(
                          fontWeight: s == fastest ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rate of perceived exertion picker (1–10), like Apple's Effort rating.
class _EffortSection extends StatelessWidget {
  const _EffortSection({required this.rpe, required this.onChanged});

  final int? rpe;
  final ValueChanged<int?>? onChanged;

  static const _labels = {1: 'Easy', 4: 'Moderate', 7: 'Hard', 9: 'All Out'};

  String _label(int v) => _labels.entries.lastWhere((e) => v >= e.key).value;

  @override
  Widget build(BuildContext context) {
    final value = rpe;
    final change = onChanged;
    if (change == null && value == null) return const SizedBox.shrink();
    return GroupedSection(
      header: 'Effort',
      footer: change == null ? null : 'How hard did this workout feel?',
      hasLeading: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Text(
                value == null ? 'Not Rated' : '$value · ${_label(value)}',
                style: context.headline,
              ),
              CupertinoSlider(
                value: (value ?? 5).toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: Color.lerp(
                  Palette.green,
                  Palette.red,
                  ((value ?? 5) - 1) / 9,
                ),
                onChanged: change == null
                    ? null
                    : (v) {
                        if (v.round() != value) HapticFeedback.selectionClick();
                        change(v.round());
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
