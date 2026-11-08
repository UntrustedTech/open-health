import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/app_chip.dart';
import 'package:health_app/models/cycle.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/reorder_section.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Log flow and symptoms for one day. Changes save as you tap.
class CycleDaySheet extends StatelessWidget {
  const CycleDaySheet({super.key, required this.day, required this.controller});

  final DateTime day;
  final ScrollController controller;

  static Future<void> show(BuildContext context, DateTime day) =>
      showCupertinoSheet<void>(
        context: context,
        scrollableBuilder: (context, controller) =>
            CycleDaySheet(day: day, controller: controller),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CycleStore>();
    final logged = store.dayOf(day);
    void set(CycleDay next) {
      HapticFeedback.selectionClick();
      store.log(day, next);
    }

    return CupertinoPageScaffold(
      navigationBar: sheetBar(context, DateFormat.MMMMEEEEd().format(day)),
      child: PageList(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          0,
          AppTheme.margin,
          32,
        ),
        children: [
          GroupedSection(
            header: 'Period Flow',
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: AppSegmented<int>(
                    groupValue: logged.flow == null ? -1 : logged.flow!.index,
                    children: {
                      -1: const Text('None'),
                      for (final f in PeriodFlow.values) f.index: Text(f.label),
                    },
                    onValueChanged: (i) => set(
                      CycleDay(
                        flow: i == null || i < 0 ? null : PeriodFlow.values[i],
                        symptoms: logged.symptoms,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          GroupedSection(
            header: 'Symptoms',
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: [
                    for (final s in Symptom.values)
                      AppChip(
                        label: s.label,
                        color: context.resolve(Palette.purple),
                        selected: logged.symptoms.contains(s),
                        onTap: () {
                          final next = {...logged.symptoms};
                          if (!next.remove(s)) next.add(s);
                          set(CycleDay(flow: logged.flow, symptoms: next));
                        },
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
