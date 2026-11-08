import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/body/progress_photos_screen.dart';
import 'package:health_app/state/photo_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_route.dart';

/// Before and after, with a slider to wipe between them.
class ComparePhotosScreen extends StatefulWidget {
  const ComparePhotosScreen({
    super.key,
    required this.before,
    required this.after,
  });

  final ProgressPhoto before;
  final ProgressPhoto after;

  static Future<void> open(
    BuildContext context, {
    required ProgressPhoto before,
    required ProgressPhoto after,
  }) => Navigator.of(context).push(
    AppRoute<void>(
      builder: (_) => ComparePhotosScreen(before: before, after: after),
    ),
  );

  @override
  State<ComparePhotosScreen> createState() => _ComparePhotosScreenState();
}

class _ComparePhotosScreenState extends State<ComparePhotosScreen> {
  double _split = 0.5;

  String _caption(ProgressPhoto p) {
    final kg = p.weightKg;
    return '${DateFormat.yMMMd().format(p.date)}${kg == null ? '' : ' · ${Units.weight(kg)}'}';
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.after.date.difference(widget.before.date).inDays;
    final b = widget.before.weightKg, a = widget.after.weightKg;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: Color(0xCC000000),
        middle: Text('Compare', style: TextStyle(color: CupertinoColors.white)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => GestureDetector(
                  onHorizontalDragUpdate: (d) => setState(
                    () => _split = (d.localPosition.dx / c.maxWidth).clamp(
                      0.0,
                      1.0,
                    ),
                  ),
                  child: Semantics(
                    label: 'Before and after comparison. Drag to compare.',
                    slider: true,
                    value: '${(_split * 100).round()}%',
                    // VoiceOver swipes up or down move the divider by 10%.
                    increasedValue:
                        '${((_split + 0.1).clamp(0.0, 1.0) * 100).round()}%',
                    decreasedValue:
                        '${((_split - 0.1).clamp(0.0, 1.0) * 100).round()}%',
                    onIncrease: () =>
                        setState(() => _split = (_split + 0.1).clamp(0.0, 1.0)),
                    onDecrease: () =>
                        setState(() => _split = (_split - 0.1).clamp(0.0, 1.0)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PhotoImage(id: widget.after.id, fit: BoxFit.contain),
                        ClipRect(
                          clipper: _LeftClip(_split),
                          child: PhotoImage(
                            id: widget.before.id,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          left: c.maxWidth * _split - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: CupertinoColors.white,
                          ),
                        ),
                        Positioned(
                          left: c.maxWidth * _split - 18,
                          top: c.maxHeight / 2 - 18,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          top: 12,
                          child: _Label('Before'),
                        ),
                        const Positioned(
                          right: 12,
                          top: 12,
                          child: _Label('After'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '$days days apart${a != null && b != null ? ' · ${(a - b) >= 0 ? '+' : ''}${Units.weight(a - b)}' : ''}',
                    style: context.headline.copyWith(
                      color: CupertinoColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_caption(widget.before)}  →  ${_caption(widget.after)}',
                    style: context.footnote.copyWith(
                      color: const Color(0x99FFFFFF),
                    ),
                  ),
                  CupertinoSlider(
                    value: _split,
                    onChanged: (v) {
                      if ((v * 10).round() != (_split * 10).round()) {
                        HapticFeedback.selectionClick();
                      }
                      setState(() => _split = v);
                    },
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

class _LeftClip extends CustomClipper<Rect> {
  _LeftClip(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClip old) => old.fraction != fraction;
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: const Color(0x99000000),
        shape: AppTheme.squircle(10),
      ),
      child: Text(
        text,
        style: context.footnote.copyWith(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
