import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/energy_balance.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../features/detail/energy_balance_card.dart';
import '../../../features/detail/metric_spec.dart';
import '../data/mono_data.dart';
import '../data/mono_energy.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_energy_rings.dart';
import '../widgets/mono_page.dart';
import '../widgets/mono_pair_bars.dart';
import 'category_page.dart';
import 'metric_page.dart';

/// The calories of the day: the two rings, where the burned ones came from
/// and how they went over the day, burned against eaten over a week, a
/// month or a year, what was eaten, and the real burn by food and weight.
class MonoCaloriesPage extends StatelessWidget {
  const MonoCaloriesPage({super.key, required this.backLabel});

  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final t = c.t;
        final e = MonoEnergy.of(c);
        String kcal(double v) => c.formats.integer(v.round());
        const unit = 'kcal';
        final balance = e.balance;
        final statement = e.burned == null && e.eaten == null
            ? l10n.monoCaloriesNone
            : e.bothReached
            ? l10n.monoCaloriesBoth
            : e.eaten == null
            ? l10n.monoCaloriesNoMeals
            : balance! >= 0
            ? l10n.monoCaloriesDeficit(kcal(balance))
            : l10n.monoCaloriesSurplus(kcal(-balance));
        final burnedColors = e.split
            ? [t.ink3, t.solid, t.ink2]
            : [t.ink3, t.solid];
        final burnedLabels = e.split
            ? [l10n.monoRest, l10n.finePartWorkouts, l10n.monoMovement]
            : [l10n.monoRest, l10n.monoActive];
        final eatenColors = [
          t.recovery,
          t.recovery.withValues(alpha: 0.62),
          t.recovery.withValues(alpha: 0.34),
        ];
        final hours =
            c.hours(Metric.activeEnergy) ?? c.hours(Metric.fineActiveEnergy);
        final index = c.health.todayIndex;
        final meals = c.health.snapshot.entriesOn(index, EntryKind.meal);
        final grams = [
          c.valueToday(Metric.protein),
          c.valueToday(Metric.carbs),
          c.valueToday(Metric.fat),
        ];
        final burnedSum = e.burnedParts.fold(0.0, (a, b) => a + b);

        return MonoSubPage(
          category: MonoCategory.nutrition,
          icon: Icons.local_fire_department_rounded,
          categoryLabel: l10n.monoCalories,
          backLabel: backLabel,
          statement: statement,
          children: [
            MonoSurface(
              child: Column(
                children: [
                  MonoEnergyRings(
                    day: c.today,
                    semantics: statement,
                    size: 220,
                    outer: MonoRingData(
                      parts: e.burnedParts,
                      colors: burnedColors,
                      goal: e.burnedGoal,
                      total: e.burned,
                    ),
                    inner: MonoRingData(
                      parts: e.eatenParts,
                      colors: [
                        ...eatenColors,
                        t.recovery.withValues(alpha: 0.18),
                      ],
                      goal: e.eatenGoal,
                      total: e.eaten,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: MonoStat(
                          label: l10n.monoBurned,
                          value: e.burned == null ? '–' : kcal(e.burned!),
                          unit: unit,
                          small: true,
                        ),
                      ),
                      Expanded(
                        child: MonoStat(
                          label: l10n.monoEaten,
                          value: e.eaten == null ? '–' : kcal(e.eaten!),
                          unit: unit,
                          small: true,
                          color: t.recovery,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.monoOfGoal(kcal(e.burnedGoal)),
                          style: MonoType.time(t),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l10n.monoOfGoal(kcal(e.eatenGoal)),
                          style: MonoType.time(t),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            MonoBlock(
              title: l10n.monoBurnedFrom,
              child: MonoList(
                gap: 18,
                children: [
                  for (var i = 0; i < burnedLabels.length; i++)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MonoPair(
                          label: burnedLabels[i],
                          dot: burnedColors[i],
                          value:
                              '${kcal(e.burnedParts[i])} $unit'
                              '${burnedSum <= 0 ? '' : ' · ${(e.burnedParts[i] / burnedSum * 100).round()} %'}',
                        ),
                        const SizedBox(height: 8),
                        MonoTrack(
                          value: burnedSum <= 0
                              ? 0
                              : e.burnedParts[i] / burnedSum,
                          color: burnedColors[i],
                        ),
                      ],
                    ),
                  Text(l10n.monoBurnedFromNote, style: MonoType.time(t)),
                ],
              ),
            ),
            if (hours != null)
              MonoBlock(
                title: l10n.caloriesOverDay,
                child: MonoSurface(
                  child: Column(
                    children: [
                      MonoBars(
                        values: hours,
                        semantics: l10n.caloriesOverDay,
                        height: 130,
                      ),
                      MonoAxis([
                        for (final hour in const [0, 6, 12, 18, 24]) '$hour',
                      ]),
                    ],
                  ),
                ),
              ),
            MonoBlock(
              title: l10n.monoBurnedVsEaten,
              child: _Compare(c: c),
            ),
            MonoBlock(
              title: l10n.caloriesMeals,
              child: MonoList(
                children: [
                  if (grams.any((g) => (g ?? 0) > 0)) ...[
                    MonoStackBar(
                      parts: [for (final g in grams) g ?? 0],
                      colors: eatenColors,
                      semantics: l10n.caloriesMeals,
                    ),
                    for (final (i, m) in [
                      Metric.protein,
                      Metric.carbs,
                      Metric.fat,
                    ].indexed)
                      MonoPair(
                        label: m.title(l10n),
                        dot: eatenColors[i],
                        value: m.formatWithUnit(c.formats, grams[i]),
                      ),
                  ],
                  for (final meal in meals)
                    MonoPair(
                      label: meal.draft.name ?? Metric.energyIntake.title(l10n),
                      value: Metric.energyIntake.formatWithUnit(
                        c.formats,
                        meal.draft.amount,
                      ),
                      sub: c.clock(meal.draft.time),
                    ),
                  MonoRow(
                    title: l10n.groupNutrition,
                    onTap: () => openMonoCategory(
                      context,
                      MonoCategory.nutrition,
                      backLabel: l10n.monoCalories,
                    ),
                  ),
                ],
              ),
            ),
            EnergyBalanceCard(
              balance: energyBalance(
                today: c.health.today,
                valueOn: c.health.readValueOn,
              ),
            ),
            if (Metric.totalEnergy.note(l10n, fine: c.health.fineValues)
                case final note?)
              MonoNote(note),
            MonoSurface(
              onTap: () =>
                  c.push(const MonoMetricPage(metric: Metric.totalEnergy)),
              child: MonoRow(title: l10n.caloriesHistory),
            ),
          ],
        );
      },
    );
  }
}

/// Burned against eaten, day by day over a week or a month, or month by
/// month over a year, with the means below.
class _Compare extends StatefulWidget {
  const _Compare({required this.c});

  final MonoCtx c;

  @override
  State<_Compare> createState() => _CompareState();
}

class _CompareState extends State<_Compare> {
  int _range = 0;

  double? _burnedOn(DateTime day) =>
      widget.c.health.valueOn(Metric.totalEnergy, day) ??
      widget.c.health.valueOn(Metric.fineTotalEnergy, day);

  double? _eatenOn(DateTime day) =>
      widget.c.health.valueOn(Metric.energyIntake, day);

  static double? _mean(Iterable<double?> values) {
    final known = values.whereType<double>().toList();
    return known.isEmpty ? null : known.reduce((a, b) => a + b) / known.length;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final l10n = c.l10n;
    final t = c.t;
    final today = c.today;
    List<DateTime> lastDays(int n) => [
      for (var back = n - 1; back >= 0; back--)
        DateTime(today.year, today.month, today.day - back),
    ];
    late final List<double?> burned;
    late final List<double?> eaten;
    late final List<String> axis;
    late final List<DateTime> days;
    if (_range < 2) {
      days = lastDays(_range == 0 ? 7 : 30);
      burned = [for (final d in days) _burnedOn(d)];
      eaten = [for (final d in days) _eatenOn(d)];
      axis = _range == 0
          ? [for (final d in days) c.formats.weekdayShort[d.weekday - 1]]
          : [
              for (var i = 0; i < days.length; i++)
                i % 7 == 0 ? '${days[i].day}.' : '',
            ];
    } else {
      // Twelve months, each as the mean of its days.
      final months = [
        for (var back = 11; back >= 0; back--)
          DateTime(today.year, today.month - back),
      ];
      days = [
        for (final m in months)
          for (var d = 1; d <= DateTime(m.year, m.month + 1, 0).day; d++)
            if (!DateTime(m.year, m.month, d).isAfter(today))
              DateTime(m.year, m.month, d),
      ];
      burned = [
        for (final m in months)
          _mean([
            for (final d in days)
              if (d.year == m.year && d.month == m.month) _burnedOn(d),
          ]),
      ];
      eaten = [
        for (final m in months)
          _mean([
            for (final d in days)
              if (d.year == m.year && d.month == m.month) _eatenOn(d),
          ]),
      ];
      axis = [for (final m in months) c.formats.monthInitials[m.month - 1]];
    }
    final dayBurned = [for (final d in days) _burnedOn(d)];
    final dayEaten = [for (final d in days) _eatenOn(d)];
    final meanBurned = _mean(dayBurned);
    final meanEaten = _mean(dayEaten);
    final both = [
      for (var i = 0; i < days.length; i++)
        if (dayBurned[i] != null && dayEaten[i] != null)
          dayBurned[i]! - dayEaten[i]!,
    ];
    final meanBalance = _mean(both);
    String kcal(double? v) =>
        v == null ? '–' : '${c.formats.integer(v.round())} kcal';
    final top = math.max(meanBurned ?? 0, meanEaten ?? 0);
    return MonoList(
      gap: 16,
      children: [
        MonoSegmented(
          labels: [l10n.periodWeek, l10n.periodMonth, l10n.periodYear],
          selected: _range,
          onChanged: (i) => setState(() => _range = i),
        ),
        const SizedBox(height: 4),
        Column(
          children: [
            MonoPairBars(
              key: ValueKey(_range),
              first: burned,
              second: eaten,
              firstColor: t.ink2,
              secondColor: t.recovery,
              semantics: l10n.monoBurnedVsEaten,
            ),
            MonoAxis(axis),
          ],
        ),
        MonoPair(
          label: l10n.monoAvgBurned,
          dot: t.ink2,
          value: kcal(meanBurned),
        ),
        MonoPair(
          label: l10n.monoAvgEaten,
          dot: t.recovery,
          value: kcal(meanEaten),
        ),
        if (top > 0 && meanBalance != null)
          MonoPair(
            label: l10n.monoAvgBalance,
            value: meanBalance >= 0
                ? '−${kcal(meanBalance)}'
                : '+${kcal(-meanBalance)}',
            sub: meanBalance >= 0 ? l10n.caloriesDeficit : l10n.caloriesSurplus,
          ),
      ],
    );
  }
}
