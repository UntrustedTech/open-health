import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/gym.dart';
import 'package:health_app/screens/gym/gym_card.dart';
import 'package:health_app/screens/gym/membership_editor.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/motion.dart';

/// The membership card's code, big and bright, to scan in at the gym. The
/// screen turns its brightness up and stays on while it's shown, and the
/// visit is checked in as it opens.
class CheckInPass extends StatefulWidget {
  const CheckInPass({super.key, required this.membership});

  final GymMembership membership;

  /// Shows the pass and checks in; without a card to show, asks for the
  /// membership first.
  static Future<void> open(BuildContext context) async {
    final m = context.read<GymStore>().membership;
    if (m == null || !m.hasCode) {
      await MembershipEditor.show(context);
      return;
    }
    // Over the tab bar too: nothing but the card.
    await Navigator.of(context, rootNavigator: true).push<void>(
      AppRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CheckInPass(membership: m),
      ),
    );
  }

  @override
  State<CheckInPass> createState() => _CheckInPassState();
}

class _CheckInPassState extends State<CheckInPass> {
  /// What checking in did, once it's been tried.
  _CheckIn? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_brighten(true));
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
    // After the first frame: the store tells its listeners straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIn());
  }

  @override
  void dispose() {
    unawaited(_brighten(false));
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  /// Shows the result straight away; the visit saves behind it.
  void _checkIn() {
    if (!mounted) return;
    final store = context.read<GymStore>();
    final result = !store.readable
        ? _CheckIn.notSaved
        : store.justCheckedIn
        ? _CheckIn.already
        : _CheckIn.logged;
    if (result == _CheckIn.logged) {
      unawaited(
        store.checkIn().then<void>(
          (_) {},
          onError: (Object e) {
            logError('Check-in: could not save the visit: $e');
            if (mounted) setState(() => _result = _CheckIn.notSaved);
          },
        ),
      );
      unawaited(HapticFeedback.mediumImpact());
    }
    setState(() => _result = result);
  }

  /// Full brightness while shown, so the gym's scanner reads the screen;
  /// back to the phone's own setting after.
  static Future<void> _brighten(bool on) async {
    try {
      final screen = ScreenBrightness.instance;
      if (on) {
        await screen.setApplicationScreenBrightness(1);
      } else {
        await screen.resetApplicationScreenBrightness();
      }
    } on Exception catch (e) {
      logError('Check-in: could not change brightness: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.membership;
    final gym = context.watch<GymStore>();
    final last = gym.lastVisit;
    const ink = Color(0xFF101828);
    const muted = Color(0xFF6B6F80);
    final green = context.resolve(gymColor);
    final status = switch (_result) {
      null => null,
      _CheckIn.logged => 'Checked in at ${_time(last)}',
      _CheckIn.already => 'Already checked in at ${_time(last)}',
      _CheckIn.notSaved =>
        'Your card is ready, but this visit couldn\'t be saved.',
    };
    // Always light: scanners read dark codes on a white screen.
    return CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.light),
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Done',
                      style: context.body.copyWith(
                        color: green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  m.gym.isEmpty ? 'Gym Membership' : m.gym,
                  textAlign: TextAlign.center,
                  style: context.title2.copyWith(color: ink),
                ),
                if (m.memberName.isNotEmpty)
                  Text(
                    m.memberName,
                    textAlign: TextAlign.center,
                    style: context.subheadline.copyWith(color: muted),
                  ),
                const SizedBox(height: 28),
                Center(
                  child: CardBarcode(
                    membership: m,
                    height: m.format.isSquare ? 240 : 150,
                  ),
                ),
                if (m.memberNumber.isNotEmpty && m.memberNumber != m.code)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Member No. ${m.memberNumber}',
                      textAlign: TextAlign.center,
                      style: context.subheadline.copyWith(color: muted),
                    ),
                  ),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: Motion.reduced(context)
                      ? Duration.zero
                      : Motion.medium,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: CurvedAnimation(parent: a, curve: Motion.spring),
                      child: child,
                    ),
                  ),
                  child: status == null
                      ? const SizedBox(height: 56)
                      : Column(
                          key: ValueKey(status),
                          children: [
                            Icon(
                              _result == _CheckIn.notSaved
                                  ? Icons.error_rounded
                                  : Icons.check_circle_rounded,
                              color: _result == _CheckIn.notSaved
                                  ? context.resolve(Palette.orange)
                                  : green,
                              size: 34,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              status,
                              textAlign: TextAlign.center,
                              style: context.headline.copyWith(color: ink),
                            ),
                          ],
                        ),
                ),
                const Spacer(),
                Text(
                  'Hold the screen up to the gym\'s scanner.',
                  textAlign: TextAlign.center,
                  style: context.footnote.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _time(DateTime? t) =>
      t == null ? '' : formatTimeOfDay(t.hour, t.minute);
}

enum _CheckIn { logged, already, notSaved }
