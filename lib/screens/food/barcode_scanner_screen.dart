import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/nutrition/open_food_facts.dart';
import 'package:health_app/screens/food/custom_food_sheet.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Looks a barcode up and, if Open Food Facts doesn't know it, offers to
/// create the food. Returns the food, or null if cancelled.
Future<Food?> foodForBarcode(BuildContext context, String code) async {
  final off = context.read<OpenFoodFacts>();
  Food? found;
  try {
    found = await off.lookup(code);
  } on FoodLookupException catch (e) {
    logError('Barcode lookup failed: $e');
    if (context.mounted) {
      await showMessage(
        context,
        title: 'Couldn\'t Look It Up',
        message:
            'Open Food Facts can\'t be reached. Check your connection, or '
            'add the food yourself.',
      );
    }
    return null;
  }
  if (found != null || !context.mounted) return found;
  final create = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Product Not Found'),
      content: Text(
        'Barcode $code isn\'t in Open Food Facts yet. Enter its nutrition '
        'from the label?',
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Add Food'),
        ),
      ],
    ),
  );
  if (create != true || !context.mounted) return null;
  return CustomFoodSheet.show(context, barcode: code);
}

/// Asks for a barcode typed from the package.
Future<String?> askBarcode(BuildContext context) async {
  final code = await showTextPrompt(
    context,
    title: 'Enter Barcode',
    confirm: 'Look Up',
    placeholder: tr('e.g. 5000159484695'),
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(14),
    ],
  );
  if (code == null) return null;
  if (!validBarcode(code)) {
    if (context.mounted) {
      await showMessage(
        context,
        title: 'Check the Barcode',
        message: 'Barcodes have 8 to 14 digits.',
      );
    }
    return null;
  }
  return code;
}

/// A full-screen camera that reads barcodes: food barcodes (EAN and UPC)
/// by default, or whatever [formats] are given. Each code read goes to
/// [resolve]; a result closes the camera with it, and null keeps scanning.
class BarcodeScannerScreen<T> extends StatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    required this.resolve,
    required this.manual,
    this.formats = foodFormats,
    this.prompt = 'Point at a food barcode',
    this.hint = 'It\'s looked up on Open Food Facts.',
    this.manualLabel = 'Enter Barcode',
  });

  static const foodFormats = [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
  ];

  final List<BarcodeFormat> formats;
  final String prompt;
  final String hint;
  final String manualLabel;

  /// What a code read stands for, or null to keep scanning.
  final Future<T?> Function(BuildContext context, Barcode code) resolve;

  /// Asks for the code by hand instead; null keeps scanning.
  final Future<T?> Function(BuildContext context) manual;

  /// Scans a barcode and returns its food, or null.
  static Future<Food?> scan(BuildContext context) =>
      Navigator.of(context).push<Food>(
        AppRoute<Food>(
          fullscreenDialog: true,
          builder: (_) => BarcodeScannerScreen<Food>(
            resolve: (context, code) {
              final value = code.rawValue;
              return value != null && validBarcode(value)
                  ? foodForBarcode(context, value)
                  : Future.value();
            },
            manual: (context) async {
              final code = await askBarcode(context);
              if (code == null || !context.mounted) return null;
              return foodForBarcode(context, code);
            },
          ),
        ),
      );

  @override
  State<BarcodeScannerScreen<T>> createState() =>
      _BarcodeScannerScreenState<T>();
}

class _BarcodeScannerScreenState<T> extends State<BarcodeScannerScreen<T>> {
  late final _controller = MobileScannerController(
    formats: widget.formats,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _busy = false;
  bool _torch = false;

  /// The camera failed (no permission, or unavailable): the scan frame
  /// and hints aren't shown over the error.
  bool _cameraFailed = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  /// Pauses the camera while [find] works out what was read, then closes
  /// with it, or carries on scanning.
  Future<void> _settle(Future<T?> Function() find, {bool haptic = true}) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (haptic) unawaited(HapticFeedback.mediumImpact());
    T? result;
    try {
      await _controller.stop();
      if (!mounted) return;
      result = await find();
    } on Object catch (e) {
      logError('Scanner: could not use the code: $e');
    }
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
      return;
    }
    // Nothing (or it failed): carry on scanning.
    setState(() => _busy = false);
    try {
      await _controller.start();
    } on Object catch (e) {
      logError('Scanner: could not restart the camera: $e');
    }
  }

  Future<void> _manual() =>
      _settle(() => widget.manual(context), haptic: false);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final code = capture.barcodes
                  .where((b) => b.rawValue != null)
                  .firstOrNull;
              if (code != null) {
                unawaited(_settle(() => widget.resolve(context, code)));
              }
            },
            errorBuilder: (context, error) {
              // The scan frame and hints are hidden over the error.
              if (!_cameraFailed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _cameraFailed = true);
                });
              }
              return _CameraError(
                denied:
                    error.errorCode == MobileScannerErrorCode.permissionDenied,
                onManual: _manual,
              );
            },
          ),
          if (!_cameraFailed)
            IgnorePointer(
              child: CustomPaint(
                painter: _FramePainter(
                  colors: [
                    context.resolve(Palette.orange),
                    context.resolve(Palette.pink),
                  ],
                ),
              ),
            ),
          if (!_busy && !_cameraFailed) const IgnorePointer(child: _ScanLine()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _GlassButton(
                        icon: Icons.close_rounded,
                        label: 'Cancel',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        'Scan Barcode',
                        style: context.headline.copyWith(
                          color: CupertinoColors.white,
                        ),
                      ),
                      const Spacer(),
                      // Kept as a spacer over a camera error, so the
                      // title stays centred.
                      Opacity(
                        opacity: _cameraFailed ? 0 : 1,
                        child: IgnorePointer(
                          ignoring: _cameraFailed,
                          child: _GlassButton(
                            icon: _torch
                                ? Icons.flashlight_off_rounded
                                : Icons.flashlight_on_rounded,
                            label: _torch ? 'Torch off' : 'Torch on',
                            onTap: () async {
                              await _controller.toggleTorch();
                              if (mounted) setState(() => _torch = !_torch);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (!_cameraFailed)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                          decoration: BoxDecoration(
                            color: const Color(0x8C0B1020),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0x26FFFFFF)),
                          ),
                          child: Column(
                            children: [
                              if (_busy)
                                const CupertinoActivityIndicator(
                                  color: CupertinoColors.white,
                                  radius: 12,
                                )
                              else
                                Text(
                                  widget.prompt,
                                  textAlign: TextAlign.center,
                                  style: context.headline.copyWith(
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                widget.hint,
                                textAlign: TextAlign.center,
                                style: context.footnote.copyWith(
                                  color: const Color(0xB3FFFFFF),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: CupertinoButton(
                                  color: const Color(0x26FFFFFF),
                                  borderRadius: BorderRadius.circular(24),
                                  onPressed: _busy ? null : _manual,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.keyboard_rounded,
                                        color: CupertinoColors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.manualLabel,
                                        style: context.subheadline.copyWith(
                                          color: CupertinoColors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scan window, centred in [size].
Rect _window(Size size) {
  final w = size.width * 0.8;
  return Rect.fromCenter(
    center: size.center(Offset.zero),
    width: w,
    height: w * 0.55,
  );
}

/// Darkens around a central window and marks its corners with glowing
/// brackets.
class _FramePainter extends CustomPainter {
  const _FramePainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _window(size);
    final window = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(window),
      ),
      Paint()..color = const Color(0xA6060910),
    );
    // Corner brackets: the outline with the middle of each side removed.
    const arm = 34.0;
    final brackets = Path();
    for (final (corner, dx, dy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      brackets
        ..moveTo(corner.dx, corner.dy + dy * arm)
        ..lineTo(corner.dx, corner.dy + dy * 12)
        ..quadraticBezierTo(
          corner.dx,
          corner.dy,
          corner.dx + dx * 12,
          corner.dy,
        )
        ..lineTo(corner.dx + dx * arm, corner.dy);
    }
    final shader = LinearGradient(colors: colors).createShader(rect);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..shader = shader;
    canvas
      ..drawPath(
        brackets,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(brackets, stroke);
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.colors.first != colors.first || old.colors.last != colors.last;
}

/// A glowing line that sweeps up and down the scan window.
class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _sweep
        ..stop()
        ..value = 0.5;
    } else if (!_sweep.isAnimating) {
      unawaited(_sweep.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.resolve(Palette.orange);
    return LayoutBuilder(
      builder: (context, c) {
        final rect = _window(c.biggest);
        return AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_sweep.value);
            return Stack(
              children: [
                Positioned(
                  left: rect.left + 18,
                  width: rect.width - 36,
                  top: rect.top + 14 + (rect.height - 28) * t,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0),
                          color,
                          color.withValues(alpha: 0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.7),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// A round frosted button for use over the camera.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.square(AppTheme.minTapTarget),
    onPressed: onTap,
    child: ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0x590B1020),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Icon(
            icon,
            color: CupertinoColors.white,
            size: 22,
            semanticLabel: label,
          ),
        ),
      ),
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.denied, required this.onManual});

  final bool denied;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CupertinoColors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_rounded,
              color: CupertinoColors.white,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              denied
                  ? 'Allow camera access for Health in your phone\'s Settings '
                        'to scan barcodes.'
                  : 'The camera isn\'t available right now.',
              textAlign: TextAlign.center,
              style: context.body.copyWith(color: CupertinoColors.white),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(24),
              onPressed: onManual,
              child: const Text('Enter Barcode Instead'),
            ),
            const SizedBox(height: AppTheme.margin),
          ],
        ),
      ),
    ),
  );
}
