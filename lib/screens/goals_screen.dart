import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/number_input.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Daily targets that drive the activity rings, water and sleep.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(AppRoute<void>(title: 'Goals', builder: (_) => const GoalsScreen()));

  @override
  Widget build(BuildContext context) {
    return LargeTitlePage(
      title: 'Goals',
      children: [
        GroupedSection(
          header: 'Daily Goals',
          footer:
              'Move, Exercise and Steps set your activity rings. Tap a goal '
              'to change it.',
          children: [for (final t in Goals.goalMetrics) _GoalTile(type: t)],
        ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.type});

  final MetricType type;

  @override
  Widget build(BuildContext context) {
    final goal = context.watch<HealthStore>().goals.forMetric(type) ?? 0;
    return InfoRow(
      leading: IconTile(icon: type.icon, color: type.color),
      title: type.label,
      value: '${formatValue(type, goal)} ${unitLabel(type)}'.trim(),
      chevron: true,
      onTap: () => _edit(context, goal),
    );
  }

  Future<void> _edit(BuildContext context, double current) async {
    final store = context.read<HealthStore>();
    final result = await showCupertinoDialog<double>(
      context: context,
      builder: (_) => _GoalDialog(type: type, current: current),
    );
    if (result != null) await store.updateGoal(type, result);
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.type, required this.current});

  final MetricType type;
  final double current;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _controller = TextEditingController(
    text: Units.toDisplay(
      widget.type,
      widget.current,
    ).toStringAsFixed(Units.decimalsFor(widget.type)),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final type = widget.type;
    final shown = double.tryParse(_controller.text.replaceAll(',', '.'));
    final v = shown == null ? null : Units.fromDisplay(type, shown);
    if (v == null || v <= 0 || v > type.max) {
      HapticFeedback.heavyImpact();
      setState(
        () => _error =
            'Enter a value up to '
            '${Units.toDisplay(type, type.max).round()}.',
      );
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final error = _error;
    return CupertinoAlertDialog(
      title: Text('${type.label} Goal'),
      content: Column(
        children: [
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            suffix: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(type.isDuration ? 'hours' : Units.unitFor(type)),
            ),
            keyboardType: TextInputType.numberWithOptions(
              decimal: type.decimals > 0,
            ),
            inputFormatters: numberInput(),
            onSubmitted: (_) => _submit(),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: TextStyle(color: context.destructive)),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
