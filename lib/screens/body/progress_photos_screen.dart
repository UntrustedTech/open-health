import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/body/compare_photos_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/photo_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/utils/units.dart';

/// Progress photos on a timeline; pick two to compare.
class ProgressPhotosScreen extends StatefulWidget {
  const ProgressPhotosScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Photos',
      builder: (_) => const ProgressPhotosScreen(),
    ),
  );

  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  bool _selecting = false;
  final _selected = <String>[];
  bool _busy = false;

  Future<void> _add() async {
    if (_busy) return;
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add Progress Photo'),
        message: const Text(
          'Photos are stored encrypted on this phone only. Location and camera details are removed.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Choose from Library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final pose = await showCupertinoModalPopup<PhotoPose>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Pose'),
        actions: [
          for (final p in PhotoPose.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, p),
              child: Text(p.label),
            ),
        ],
      ),
    );
    if (pose == null || !mounted) return;
    final store = context.read<PhotoStore>();
    final weight = context
        .read<HealthStore>()
        .latestReading(MetricType.weight, lookbackDays: 7)
        ?.value;
    XFile? file;
    setState(() => _busy = true);
    try {
      file = await ImagePicker().pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final added = await store.add(
        await file.readAsBytes(),
        pose: pose,
        weightKg: weight,
      );
      if (added == null && mounted) {
        await showMessage(
          context,
          title: 'Couldn\'t Add Photo',
          message: 'That file isn\'t a supported image.',
        );
      } else {
        unawaited(HapticFeedback.mediumImpact());
      }
    } on PlatformException catch (e) {
      logError('Photos: picker failed: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Camera Unavailable',
          message: 'Allow camera or photo access for Health in Settings.',
        );
      }
    } finally {
      // The picker's temporary copy is unencrypted: remove it.
      final path = file?.path;
      if (path != null) {
        try {
          await File(path).delete();
        } on FileSystemException {
          // Already gone.
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  void _tap(ProgressPhoto p) {
    if (!_selecting) {
      Navigator.of(context)
          .push(AppRoute<void>(builder: (_) => _PhotoViewer(photo: p)));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(p.id)) {
        _selected.add(p.id);
        if (_selected.length > 2) _selected.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = context.watch<PhotoStore>().photos;
    final byMonth = <DateTime, List<ProgressPhoto>>{};
    for (final p in photos) {
      byMonth.putIfAbsent(DateTime(p.date.year, p.date.month), () => []).add(p);
    }
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Progress Photos'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photos.length >= 2)
              CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                onPressed: () => setState(() {
                  _selecting = !_selecting;
                  _selected.clear();
                }),
                child: Text(_selecting ? 'Cancel' : 'Compare'),
              ),
            if (!_selecting)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _busy ? null : _add,
                child: _busy
                    ? const CupertinoActivityIndicator()
                    : Icon(Icons.add_rounded, semanticLabel: tr('Add photo')),
              ),
          ],
        ),
      ),
      child: Stack(
        children: [
          PageList(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.margin,
              8,
              AppTheme.margin,
              96,
            ),
            children: [
              if (photos.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_camera_rounded,
                        size: 48,
                        color: context.tertiaryLabel,
                      ),
                      const SizedBox(height: 12),
                      Text('No Photos Yet', style: context.title3),
                      const SizedBox(height: 6),
                      Text(
                        'Take a photo every few weeks to see how your body changes.',
                        textAlign: TextAlign.center,
                        style: context.subheadline.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                      CupertinoButton(
                        onPressed: _busy ? null : _add,
                        child: const Text('Add First Photo'),
                      ),
                    ],
                  ),
                ),
              if (_selecting)
                Text(
                  'Choose two photos to compare.',
                  style: context.subheadline.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              for (final MapEntry(key: month, value: list)
                  in byMonth.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    DateFormat.yMMMM().format(month),
                    style: context.title3,
                  ),
                ),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 3 / 4,
                  children: [
                    for (final p in list)
                      _Thumb(
                        photo: p,
                        selected: _selected.contains(p.id),
                        selecting: _selecting,
                        onTap: () => _tap(p),
                      ),
                  ],
                ),
              ],
            ],
          ),
          if (_selecting && _selected.length == 2)
            Positioned(
              left: AppTheme.margin,
              right: AppTheme.margin,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: CupertinoButton.filled(
                onPressed: () {
                  final chosen = [
                    for (final id in _selected)
                      photos.firstWhere((p) => p.id == id),
                  ]..sort((a, b) => a.date.compareTo(b.date));
                  setState(() {
                    _selecting = false;
                    _selected.clear();
                  });
                  ComparePhotosScreen.open(
                    context,
                    before: chosen.first,
                    after: chosen.last,
                  );
                },
                child: const Text('Compare'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.selected,
    required this.selecting,
    required this.onTap,
  });

  final ProgressPhoto photo;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '${photo.pose.label} photo, ${DateFormat.yMMMd().format(photo.date)}',
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PhotoImage(id: photo.id),
              Positioned(
                left: 6,
                bottom: 6,
                child: Text(
                  DateFormat.MMMd().format(photo.date),
                  style: context.caption1.copyWith(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [Shadow(blurRadius: 4)],
                  ),
                ),
              ),
              if (selecting)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? context.tint : CupertinoColors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decrypts and shows one stored photo.
class PhotoImage extends StatelessWidget {
  const PhotoImage({super.key, required this.id, this.fit = BoxFit.cover});

  final String id;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: context.read<PhotoStore>().image(id),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return ColoredBox(
            color: context.fillColor,
            child: snap.connectionState == ConnectionState.done
                ? Icon(
                    Icons.warning_amber_rounded,
                    color: context.tertiaryLabel,
                  )
                : const CupertinoActivityIndicator(),
          );
        }
        // Decode at display size: full photos would fill memory.
        return LayoutBuilder(
          builder: (context, c) => Image.memory(
            bytes,
            fit: fit,
            gaplessPlayback: true,
            cacheWidth: c.maxWidth.isFinite
                ? (c.maxWidth * MediaQuery.devicePixelRatioOf(context)).round()
                : null,
          ),
        );
      },
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});

  final ProgressPhoto photo;

  @override
  Widget build(BuildContext context) {
    final kg = photo.weightKg;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xCC000000),
        middle: Text(
          '${photo.pose.label} · ${DateFormat.yMMMd().format(photo.date)}${kg == null ? '' : ' · ${Units.weight(kg)}'}',
          style: const TextStyle(color: CupertinoColors.white),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final ok = await confirmDestructive(
              context,
              message: 'This photo will be deleted.',
              action: 'Delete Photo',
            );
            if (!ok || !context.mounted) return;
            await context.read<PhotoStore>().delete(photo.id);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Icon(
            Icons.delete_outline_rounded,
            color: context.destructive,
            semanticLabel: tr('Delete photo'),
          ),
        ),
      ),
      child: InteractiveViewer(
        maxScale: 4,
        child: Center(
          child: PhotoImage(id: photo.id, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
