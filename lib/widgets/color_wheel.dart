import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';

/// [c] as "#RRGGBB".
String colourHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// "#RRGGBB", "RRGGBB" or "#RGB" as an opaque colour, or null.
Color? parseColourHex(String text) {
  var t = text.trim().replaceFirst('#', '');
  if (t.length == 3) t = t.split('').map((c) => '$c$c').join();
  if (t.length != 6) return null;
  final v = int.tryParse(t, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// Shows a colour wheel, a brightness slider and a hex field, starting at
/// [initial]. Returns the chosen colour, or null if cancelled.
Future<Color?> pickColour(
  BuildContext context, {
  required Color initial,
  required String title,
}) => showCupertinoModalPopup<Color>(
  context: context,
  builder: (_) => _ColourSheet(initial: initial, title: title),
);

class _ColourSheet extends StatefulWidget {
  const _ColourSheet({required this.initial, required this.title});

  final Color initial;
  final String title;

  @override
  State<_ColourSheet> createState() => _ColourSheetState();
}

class _ColourSheetState extends State<_ColourSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial.withValues(alpha: 1));
  late final _hex = TextEditingController(text: colourHex(widget.initial));

  Color get _colour => _hsv.toColor();

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    _hex.text = colourHex(_colour);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: context.headline,
                  ),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(_colour),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: ColourWheel(
                  value: _hsv,
                  // A very dark colour picked on the wheel brightens up, so
                  // what's picked shows.
                  onChanged: (v) =>
                      _set(_hsv.value < 0.25 ? v.withValue(0.85) : v),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.sun_min,
                    size: 20,
                    color: context.secondaryLabel,
                  ),
                  Expanded(
                    child: Semantics(
                      label: tr('Brightness'),
                      child: CupertinoSlider(
                        value: _hsv.value,
                        min: 0.05,
                        onChanged: (v) => _set(_hsv.withValue(v)),
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.sun_max_fill,
                    size: 20,
                    color: context.secondaryLabel,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _colour,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.separatorColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _hex,
                      placeholder: '#RRGGBB',
                      maxLength: 7,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[#0-9a-fA-F]'),
                        ),
                      ],
                      onChanged: (t) {
                        final c = parseColourHex(t);
                        if (c != null) {
                          setState(() => _hsv = HSVColor.fromColor(c));
                        }
                      },
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

/// A round colour picker: hue around the edge, from white in the middle
/// to full colour at the rim. Brightness is set separately.
class ColourWheel extends StatelessWidget {
  const ColourWheel({super.key, required this.value, required this.onChanged});

  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;

  static const _hueStep = 15.0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest.shortestSide;
          void pick(Offset local) {
            final c = Offset(size / 2, size / 2);
            final d = local - c;
            final hue = (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) % 360;
            final sat = (d.distance / (size / 2)).clamp(0.0, 1.0);
            onChanged(value.withHue(hue).withSaturation(sat));
          }

          HSVColor turned(double by) =>
              value.withHue((value.hue + by + 360) % 360);
          return Semantics(
            label: tr('Colour wheel'),
            value: colourHex(value.toColor()),
            increasedValue: colourHex(turned(_hueStep).toColor()),
            decreasedValue: colourHex(turned(-_hueStep).toColor()),
            onIncrease: () => onChanged(turned(_hueStep)),
            onDecrease: () => onChanged(turned(-_hueStep)),
            child: GestureDetector(
              onPanDown: (d) => pick(d.localPosition),
              onPanUpdate: (d) => pick(d.localPosition),
              child: CustomPaint(
                size: Size.square(size),
                painter: _WheelPainter(value),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.value);

  final HSVColor value;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(r, r);
    final circle = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [
            for (var h = 0; h <= 360; h += 60)
              HSVColor.fromAHSV(1, h % 360, 1, 1).toColor(),
          ],
        ).createShader(circle),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(circle),
    );
    // Drawn at full brightness, so the colours can always be seen; the
    // slider below sets how dark the picked one is.
    final a = value.hue * math.pi / 180;
    final thumb = c + Offset(math.cos(a), math.sin(a)) * (value.saturation * r);
    canvas.drawCircle(thumb, 13, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(thumb, 10, Paint()..color = value.withValue(1).toColor());
    canvas.drawCircle(
      thumb,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x33000000),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.value != value;
}
