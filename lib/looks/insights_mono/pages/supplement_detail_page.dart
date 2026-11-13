import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../../../data/supplements.dart';
import '../../../features/supplements/supplement_detail_page.dart'
    show SupplementCalendar;
import '../../../features/supplements/supplement_edit_sheet.dart';
import '../../../features/supplements/supplement_format.dart';
import '../data/mono_actions.dart';
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_page.dart';
import '../widgets/mono_sheet.dart';

/// One supplement in the look: the days in a row as the statement, today's
/// tick, the rate of the last month, a calendar of six weeks and every time
/// it was taken.
class MonoSupplementDetailPage extends StatelessWidget {
  const MonoSupplementDetailPage({super.key, required this.supplementKey});

  final String supplementKey;

  Future<void> _untake(MonoCtx c, Intake intake, String name) async {
    final supplements = c.scope.supplements;
    final messenger = ScaffoldMessenger.of(c.context);
    await supplements.untake(intake);
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(c.l10n.supplementUntook(name)),
          action: SnackBarAction(
            label: c.l10n.undo,
            onPressed: () => supplements.restore(intake),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.supplements, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final t = c.t;
        final l10n = c.l10n;
        final data = c.scope.supplements.data;
        final supplement = data.byKey(supplementKey);
        final now = c.scope.supplements.now;
        final today = DateTime(now.year, now.month, now.day);
        final name = supplement?.title(l10n) ?? supplementKey;
        final rate = data.rate(supplementKey, today);
        final streak = data.streak(supplementKey, today);
        final takenToday = data.takenOn(supplementKey, now);
        final intakes = data
            .intakesOf(supplementKey)
            .reversed
            .take(30)
            .toList();
        return MonoSubPage(
          category: MonoCategory.supplements,
          categoryLabel: name,
          backLabel: l10n.supplements,
          statement: l10n.supplementStreakDays(streak),
          trailing: supplement == null || supplement.removed
              ? null
              : MonoIconButton(
                  icon: Icons.tune_rounded,
                  label: l10n.supplementEdit,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final key = supplement.key;
                    await showSupplementEditSheet(
                      context,
                      existing: supplement,
                    );
                    if (c.scope.supplements.data.byKey(key)?.removed ?? true) {
                      navigator.pop();
                    }
                  },
                ),
          children: [
            if (supplement != null && !supplement.removed)
              MonoPrimaryButton(
                label: takenToday == null
                    ? l10n.supplementTakeNow
                    : l10n.supplementTakenAt(clockOf(takenToday.at)),
                icon: takenToday == null
                    ? Icons.check_rounded
                    : Icons.check_circle_rounded,
                tonal: takenToday != null,
                onTap: () => monoToggleSupplement(context, supplement),
              ),
            MonoSurface(
              child: MonoGrid(
                cells: [
                  MonoStat(
                    label: l10n.supplementStreak,
                    value: l10n.supplementStreakDays(streak),
                    small: true,
                  ),
                  MonoStat(
                    label: l10n.supplementRate,
                    value: l10n.supplementRateDays(
                      c.formats.integer(rate.taken),
                      c.formats.integer(rate.of),
                    ),
                    small: true,
                  ),
                ],
              ),
            ),
            MonoSurface(
              child: SupplementCalendar(
                days: data.daysOf(supplementKey),
                today: today,
                weekdays: c.formats.weekdayShort,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoSection(l10n.supplementIntakes),
                const SizedBox(height: 14),
                if (intakes.isEmpty)
                  Text(l10n.supplementNoIntakes, style: MonoType.sub(t))
                else
                  MonoSurface(
                    child: Column(
                      children: [
                        for (final intake in intakes)
                          Row(
                            children: [
                              Expanded(
                                child: MonoRow(
                                  title:
                                      '${c.formats.relativeDay(intake.at, today)}, '
                                      '${clockOf(intake.at)}',
                                  subtitle:
                                      doseText(
                                        c.formats,
                                        intake.amount,
                                        intake.unit,
                                      ) ??
                                      l10n.supplementTaken,
                                ),
                              ),
                              MonoIconButton(
                                icon: Icons.delete_outline_rounded,
                                label: l10n.delete,
                                onTap: () => _untake(c, intake, name),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
