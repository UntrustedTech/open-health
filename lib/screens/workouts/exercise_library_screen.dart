import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/app_chip.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/muscles.dart';
import 'package:health_app/screens/workouts/custom_exercise_sheet.dart'
    show CustomExerciseSheet, capitalize;
import 'package:health_app/screens/workouts/exercise_detail_screen.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/body_map.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/exercise_figure.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Browse and search every exercise; in picker mode, tapping one returns it.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({
    super.key,
    this.picker = false,
    this.controller,
  });

  /// Returns the chosen exercise id instead of opening its details.
  final bool picker;
  final ScrollController? controller;

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Exercises',
      builder: (_) => const ExerciseLibraryScreen(),
    ),
  );

  /// Shows the library as a sheet; returns the chosen exercise id.
  static Future<String?> pick(BuildContext context) =>
      showCupertinoSheet<String>(
        context: context,
        scrollableBuilder: (context, controller) =>
            ExerciseLibraryScreen(picker: true, controller: controller),
      );

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

enum _Mode { list, body }

enum _View { list, grid }

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _query = '';
  String? _bodyPart;
  Muscle? _muscle;
  bool _ownedOnly = false;
  _Mode _mode = _Mode.list;
  _View _view = _View.grid;
  String? _equipment;
  BodySide _side = BodySide.front;

  static const _pageSize = 80;
  int _shown = _pageSize;

  void _choose(CatalogExercise e) {
    if (widget.picker) {
      Navigator.of(context).pop(e.id);
    } else {
      ExerciseDetailScreen.open(context, e.id);
    }
  }

  Future<void> _newExercise() async {
    final created = await CustomExerciseSheet.show(context);
    if (created != null && mounted && widget.picker) {
      Navigator.of(context).pop(created.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExerciseStore>();
    final catalog = store.catalog;
    final owned = store.ownedEquipment;
    final ownedFilter = _ownedOnly && owned.isNotEmpty ? owned : null;
    final equipment = switch (_equipment) {
      final e? when ownedFilter == null || ownedFilter.contains(e) => {e},
      final _? => <String>{},
      null => ownedFilter,
    };
    // The Body view hides search and chips, so they don't apply there.
    final body = _mode == _Mode.body;
    final results = catalog.search(
      query: body ? '' : _query,
      bodyPart: body ? null : _bodyPart,
      muscle: _muscle,
      equipment: body ? ownedFilter : equipment,
    );
    final visible = results.take(_shown).toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: !widget.picker,
        leading: widget.picker
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              )
            : null,
        middle: Text(widget.picker ? 'Add Exercise' : 'Exercises'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _newExercise,
          child: Icon(Icons.add_rounded, semanticLabel: tr('New exercise')),
        ),
      ),
      child: PageList(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          8,
          AppTheme.margin,
          32,
        ),
        children: [
          AppSegmented<_Mode>(
            groupValue: _mode,
            children: const {
              _Mode.list: Text('List'),
              _Mode.body: Text('Body'),
            },
            onValueChanged: (m) => setState(() => _mode = m ?? _Mode.list),
          ),
          const SizedBox(height: 12),
          if (_mode == _Mode.body)
            _bodyPicker(context)
          else ...[
            CupertinoSearchTextField(
              placeholder: tr('Search ${catalog.all.length} exercises'),
              onChanged: (v) => setState(() {
                _query = v;
                _shown = _pageSize;
              }),
            ),
            const SizedBox(height: 10),
            _chips(context, catalog.bodyParts),
            const SizedBox(height: 8),
            _equipmentChips(context, catalog.equipmentTypes),
          ],
          if (owned.isNotEmpty)
            CupertinoListTile(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Only Equipment I Own'),
              trailing: CupertinoSwitch(
                value: _ownedOnly,
                onChanged: (v) => setState(() => _ownedOnly = v),
              ),
            ),
          if (_muscle case final m?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text(m.label, style: context.title3)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => _muscle = null),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 0, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} EXERCISES',
                    style: context.footnote.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ),
                AppSegmented<_View>(
                  groupValue: _view,
                  children: {
                    _View.grid: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      semanticLabel: tr('Grid view'),
                    ),
                    _View.list: Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 18,
                      semanticLabel: tr('List view'),
                    ),
                  },
                  onValueChanged: (v) =>
                      setState(() => _view = v ?? _View.grid),
                ),
              ],
            ),
          ),
          if (_view == _View.grid) ...[
            if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text('No exercises found')),
              ),
            // One child per row, so only rows on screen are built (and
            // only their figures animate).
            for (var r = 0; r < visible.length; r += 2)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = r; c < r + 2; c++) ...[
                      if (c > r) const SizedBox(width: 10),
                      Expanded(
                        child: c < visible.length
                            ? _ExerciseCard(
                                exercise: visible[c],
                                onTap: () => _choose(visible[c]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            if (results.length > visible.length)
              CupertinoButton(
                onPressed: () => setState(() => _shown += _pageSize),
                child: const Text('Show More'),
              ),
          ] else
            GroupedSection(
              children: [
                if (results.isEmpty)
                  const CupertinoListTile(title: Text('No exercises found')),
                for (final e in visible)
                  _ExerciseRow(exercise: e, onTap: () => _choose(e)),
                if (results.length > visible.length)
                  InfoRow(
                    title: 'Show More',
                    titleColor: context.tint,
                    onTap: () => setState(() => _shown += _pageSize),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chips(BuildContext context, List<String> parts) {
    Widget chip(String label, String? value) => AppChip(
      label: label,
      selected: _bodyPart == value,
      onTap: () => setState(() {
        _bodyPart = value;
        _shown = _pageSize;
      }),
    );
    return ChipRow(
      children: [
        chip('All', null),
        for (final p in parts) chip(capitalize(p), p),
      ],
    );
  }

  Widget _equipmentChips(BuildContext context, List<String> types) {
    Widget chip(String label, String? value, IconData? icon) => AppChip(
      label: label,
      icon: icon,
      outlined: true,
      semanticLabel: value == null ? 'Any equipment' : label,
      selected: _equipment == value,
      onTap: () => setState(() {
        _equipment = value;
        _shown = _pageSize;
      }),
    );
    return ChipRow(
      children: [
        chip('Any Equipment', null, Icons.build_rounded),
        for (final t in types) chip(capitalize(t), t, null),
      ],
    );
  }

  Widget _bodyPicker(BuildContext context) {
    return Column(
      children: [
        AppSegmented<BodySide>(
          groupValue: _side,
          children: const {
            BodySide.front: Text('Front'),
            BodySide.back: Text('Back'),
          },
          onValueChanged: (s) => setState(() => _side = s ?? BodySide.front),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap a muscle to see its exercises.',
          style: context.footnote.copyWith(color: context.secondaryLabel),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 360,
          child: BodyMap(
            side: _side,
            intensity: {?_muscle: 1.0},
            selected: _muscle,
            onMuscleTap: (m) => setState(() {
              _muscle = m;
              _shown = _pageSize;
            }),
          ),
        ),
      ],
    );
  }
}

/// A grid card: the animated figure, name and what it works.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onTap});

  final CatalogExercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return Semantics(
      container: true,
      button: true,
      label: '${e.name}, ${capitalize(e.target)}, ${capitalize(e.equipment)}',
      onTap: onTap,
      excludeSemantics: true,
      child: IosCard(
        padding: const EdgeInsets.all(8),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRSuperellipse(
              borderRadius: BorderRadius.circular(
                context.innerRadius(AppTheme.radius, 8),
              ),
              child: ExerciseFigure(
                exerciseId: e.id,
                aspectRatio: 4 / 3,
                interactive: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    // Two lines, so cards in a row line up.
                    height: 40,
                    child: Text(
                      e.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.subheadline.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${capitalize(e.target)} · ${capitalize(e.equipment)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.caption1.copyWith(
                      color: context.secondaryLabel,
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

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.onTap});

  final CatalogExercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    return CupertinoListTile(
      leading: ExerciseThumb(exerciseId: e.id),
      leadingSize: 44,
      title: Text(e.name),
      subtitle: Text(
        [
          capitalize(e.equipment),
          capitalize(e.target),
          if (e.custom) 'My Exercise',
          if (e.timed) 'Timed',
        ].join(' · '),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}
