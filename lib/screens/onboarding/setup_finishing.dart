import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/platform/device_profile.dart';
import 'package:health_app/widgets/progress_ring.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/ios.dart';

/// The last moment of setup: a short sequence while data is brought in
/// and the dashboard is prepared, then "All Set". Calls [onDone] once the
/// sequence has played and any import has finished.
class SetupFinishing extends StatefulWidget {
  const SetupFinishing({
    super.key,
    required this.sampleData,
    required this.onDone,
  });

  /// Whether sample data will be added (when nothing is connected).
  final bool sampleData;
  final Future<void> Function() onDone;

  /// How long the sequence plays, about five seconds in all.
  static const duration = Duration(milliseconds: 5200);

  /// Longest wait for an import after the sequence; the rest carries on
  /// in the background.
  static const maxSyncWait = Duration(seconds: 15);

  @override
  State<SetupFinishing> createState() => _SetupFinishingState();
}

class _SetupFinishingState extends State<SetupFinishing>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(
    vsync: this,
    duration: SetupFinishing.duration,
  );
  late final List<(IconData, String)> _phases = _plan();

  /// The last part of the sequence is the "All Set" moment.
  static const _doneAt = 0.86;

  @override
  void initState() {
    super.initState();
    _run();
  }

  List<(IconData, String)> _plan() {
    final sync = context.read<HealthSyncService>();
    final device = context.read<DeviceProfile>();
    if (sync.connected) {
      final from = device.isSamsung ? 'Samsung Health' : sync.sourceName;
      return [
        (Icons.sync_rounded, 'Connecting to ${sync.sourceName}'),
        (Icons.download_rounded, 'Gathering your data from $from'),
        (Icons.insights_rounded, 'Organizing steps, sleep and heart rate'),
        (Icons.space_dashboard_rounded, 'Building your dashboard'),
      ];
    }
    return [
      (Icons.tune_rounded, 'Saving your settings'),
      if (widget.sampleData)
        (Icons.auto_awesome_rounded, 'Adding sample data to explore')
      else
        (Icons.flag_rounded, 'Setting up your goals'),
      (Icons.insights_rounded, 'Preparing your trends'),
      (Icons.space_dashboard_rounded, 'Building your dashboard'),
    ];
  }

  Future<void> _run() async {
    final sync = context.read<HealthSyncService>();
    // The import runs alongside the sequence (it may already be under
    // way from connecting).
    // A failed import never holds up setup: it carries on in the
    // background and shows its own message on Summary.
    final imported = sync.connected
        ? sync
              .sync()
              .timeout(SetupFinishing.maxSyncWait, onTimeout: () {})
              .catchError((Object e) => logError('Setup: import failed: $e'))
        : Future<void>.value();
    try {
      await _progress.forward().orCancel;
    } on TickerCanceled {
      return; // Left the screen meanwhile.
    }
    await imported;
    if (mounted) await widget.onDone();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teal = context.tint;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000),
      child: Stack(
        children: [
          const Positioned.fill(child: PageBackground()),
          SafeArea(
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                final t = _progress.value;
                final done = t >= _doneAt;
                final phase = (t / _doneAt * _phases.length).floor().clamp(
                  0,
                  _phases.length - 1,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      ProgressRing(
                        progress: (t / _doneAt).clamp(0, 1),
                        color: teal,
                        size: 150,
                        stroke: 12,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: done
                              ? Icon(
                                  Icons.check_rounded,
                                  key: const ValueKey('done'),
                                  size: 64,
                                  color: teal,
                                )
                              : Text(
                                  '${(t / _doneAt * 100).clamp(0, 100).round()}%',
                                  key: const ValueKey('pct'),
                                  style: context.number(
                                    34,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          done ? 'All Set' : 'Setting Up Health',
                          textAlign: TextAlign.center,
                          style: context.largeTitle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        done
                            ? 'Your dashboard is ready.'
                            : 'This only takes a moment.',
                        textAlign: TextAlign.center,
                        style: context.body.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final (i, (icon, label)) in _phases.indexed)
                        _PhaseRow(
                          icon: icon,
                          label: label,
                          state: done || i < phase
                              ? _Phase.done
                              : i == phase
                              ? _Phase.active
                              : _Phase.waiting,
                        ),
                      const Spacer(flex: 3),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _Phase { waiting, active, done }

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.icon,
    required this.label,
    required this.state,
  });

  final IconData icon;
  final String label;
  final _Phase state;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    final color = switch (state) {
      _Phase.done => context.resolve(Palette.green),
      _Phase.active => tint,
      _Phase.waiting => context.tertiaryLabel,
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: state == _Phase.waiting ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            IconTile(
              icon: state == _Phase.done ? Icons.check_rounded : icon,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: context.subheadline.copyWith(
                  fontWeight: state == _Phase.active
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: state == _Phase.waiting
                      ? context.secondaryLabel
                      : context.labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
