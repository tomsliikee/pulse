import 'package:material_ui/material_ui.dart';

import '../../../data/metric_catalog.dart';
import '../../../features/detail/metric_spec.dart';
import '../../../features/entry/foods_page.dart';
import '../../../features/supplements/supplement_format.dart';
import '../data/mono_actions.dart';
import '../data/mono_data.dart';
import '../data/mono_statements.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_page.dart';
import 'insights_page.dart' show MonoSupplementButton;
import 'calories_page.dart';
import 'metric_page.dart';
import 'sleep_page.dart';
import 'body_age_page.dart';
import 'heart_page.dart';
import 'list_pages.dart';
import 'supplements_page.dart';

/// Opens the page of [category] in the look.
Future<void> openMonoCategory(
  BuildContext context,
  MonoCategory category, {
  String? backLabel,
}) {
  final label = backLabel ?? MonoCtx.of(context).l10n.monoInsights;
  final page = switch (category) {
    MonoCategory.sleep => MonoSleepPage(backLabel: label),
    _ => MonoCategoryPage(category: category, backLabel: label),
  };
  return monoPush(context, page);
}

/// The page of a category in the look: back pill, the statement as the title,
/// a chart card with D/W/M and then the numbers. Every category is built the
/// same way; only what it reads differs.
class MonoCategoryPage extends StatelessWidget {
  const MonoCategoryPage({
    super.key,
    required this.category,
    required this.backLabel,
  });

  final MonoCategory category;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.health,
        scope.settings,
        scope.supplements,
      ]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final spec = _specOf(c);
        return MonoSubPage(
          category: category,
          categoryLabel: category.label(l10n),
          backLabel: backLabel,
          statement: spec.statement,
          children: [
            if (spec.main != null)
              _RangeCard(
                c: c,
                metric: spec.main!,
                curve: category == MonoCategory.heart,
                goal: spec.goal,
                accent: category == MonoCategory.heart ? c.t.heart : null,
                lines: spec.lines,
                statement: spec.statement,
              ),
            ...spec.after(context),
          ],
        );
      },
    );
  }

  _Spec _specOf(MonoCtx c) {
    final l10n = c.l10n;
    List<Widget> metricRows(BuildContext context, List<Metric> metrics) => [
      MonoSurface(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Column(
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              MonoRow(
                title: metrics[i].title(l10n),
                value: metrics[i].format(c.formats, _latest(c, metrics[i])),
                unit: metrics[i].unitFor(l10n, _latest(c, metrics[i])),
                onTap: () => c.push(MonoMetricPage(metric: metrics[i])),
              ),
            ],
          ],
        ),
      ),
    ];
    switch (category) {
      case MonoCategory.activity:
        return _Spec(
          statement: c.activityStatement(),
          main: Metric.steps,
          goal: c.settings.stepGoal.toDouble(),
          after: (context) => [
            ...metricRows(context, [
              Metric.distance,
              Metric.floors,
              Metric.activeEnergy,
              Metric.intensityMinutes,
            ]),
            MonoSurface(
              onTap: () => c.push(const MonoWorkoutListPage()),
              child: MonoRow(title: l10n.workouts, chevron: true),
            ),
          ],
        );
      case MonoCategory.workouts:
        final list = c.health.workouts.reversed.take(12).toList();
        return _Spec(
          statement: list.isEmpty ? l10n.noWorkouts30 : l10n.lastWorkout,
          after: (context) => [
            MonoSurface(
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    monoWorkoutRow(c, list[i]),
                  ],
                  if (list.isNotEmpty) const SizedBox(height: 14),
                  MonoRow(
                    title: l10n.allActivities,
                    onTap: () => c.push(const MonoWorkoutListPage()),
                  ),
                ],
              ),
            ),
          ],
        );
      case MonoCategory.heart:
        return _Spec(
          statement: c.heartStatement(),
          main: Metric.restingHeartRate,
          after: (context) => [
            ...metricRows(context, [
              Metric.heartRate,
              Metric.heartRateVariability,
              Metric.restingHeartRate,
            ]),
            MonoSurface(
              onTap: () => c.push(MonoHeartPage(date: c.today)),
              child: MonoRow(title: l10n.heartInDetail),
            ),
          ],
        );
      case MonoCategory.vitals:
        return _Spec(
          statement: c.vitalsStatement(),
          main: Metric.heartRateVariability,
          after: (context) => metricRows(context, [
            Metric.heartRateVariability,
            Metric.restingHeartRate,
            Metric.respiratoryRate,
            Metric.oxygenSaturation,
            Metric.skinTemperature,
            Metric.systolic,
            Metric.diastolic,
            Metric.bloodGlucose,
            Metric.bodyTemperature,
          ]),
        );
      case MonoCategory.body:
        final weight = c.valueToday(Metric.weight);
        return _Spec(
          statement: weight == null && _latest(c, Metric.weight) == null
              ? l10n.noMeasurement
              : l10n.monoBodyKept,
          main: Metric.weight,
          goal: c.settings.targetWeightKg,
          lines: true,
          after: (context) => [
            ...metricRows(context, [
              Metric.weight,
              Metric.bodyMassIndex,
              Metric.bodyFat,
              Metric.leanMass,
              Metric.bodyWater,
            ]),
            MonoSurface(
              onTap: () => c.push(const MonoBodyAgePage()),
              child: MonoRow(title: l10n.bodyAge),
            ),
          ],
        );
      case MonoCategory.nutrition:
        return _Spec(
          statement: c.nutritionStatement(),
          main: Metric.energyIntake,
          after: (context) => [
            MonoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoStackBar(
                    parts: [
                      c.valueToday(Metric.carbs) ?? 0,
                      c.valueToday(Metric.protein) ?? 0,
                      c.valueToday(Metric.fat) ?? 0,
                    ],
                    colors: [c.t.ink, c.t.ink3, c.t.recovery],
                    semantics: c.nutritionStatement(),
                  ),
                  const SizedBox(height: 18),
                  for (final (m, color) in [
                    (Metric.carbs, c.t.ink),
                    (Metric.protein, c.t.ink3),
                    (Metric.fat, c.t.recovery),
                  ]) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.title(l10n),
                              style: MonoType.body(c.t),
                            ),
                          ),
                          Text(
                            m.formatWithUnit(c.formats, c.valueToday(m)),
                            style: MonoType.inter(
                              15,
                              21,
                              FontWeight.w600,
                              c.t.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...metricRows(context, [Metric.water, Metric.fiber, Metric.sugar]),
            MonoSurface(
              onTap: () =>
                  c.push(MonoCaloriesPage(backLabel: category.label(l10n))),
              child: MonoRow(title: l10n.caloriesInDetail),
            ),
            MonoSurface(
              onTap: () => c.push(const FoodsPage()),
              child: MonoRow(title: l10n.foodsTitle),
            ),
          ],
        );
      case MonoCategory.supplements:
      case MonoCategory.recovery:
      case MonoCategory.sleep:
        final data = c.scope.supplements.data;
        final mine = data.mine;
        final now = c.health.now;
        final taken = [for (final s in mine) data.takenOn(s.key, now) != null];
        final count = taken.where((v) => v).length;
        return _Spec(
          statement: mine.isEmpty
              ? l10n.supplementsNone
              : count == mine.length
              ? l10n.monoSuppAll
              : count == 0
              ? l10n.monoSuppNone
              : l10n.monoSuppSome,
          after: (context) => [
            MonoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mine.isNotEmpty)
                    MonoStat(
                      label: l10n.supplementTaken,
                      value: l10n.supplementsTakenOf(
                        c.formats.integer(count),
                        c.formats.integer(mine.length),
                      ),
                    ),
                  if (mine.isNotEmpty) const SizedBox(height: 20),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (var i = 0; i < mine.length; i++)
                        MonoSupplementButton(
                          label: mine[i].title(l10n),
                          taken: taken[i],
                          onTap: () => monoToggleSupplement(context, mine[i]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            MonoSurface(
              onTap: () => monoAddSupplement(context),
              child: MonoRow(title: l10n.supplementAdd),
            ),
            MonoSurface(
              onTap: () => c.push(const MonoSupplementsPage()),
              child: MonoRow(title: l10n.supplementsMine),
            ),
          ],
        );
    }
  }

  static double? _latest(MonoCtx c, Metric m) {
    for (var back = 0; back < 90; back++) {
      final v = c.health.valueOn(
        m,
        DateTime(c.today.year, c.today.month, c.today.day - back),
      );
      if (v != null) return v;
    }
    return null;
  }
}

class _Spec {
  const _Spec({
    required this.statement,
    this.main,
    this.goal,
    this.lines = false,
    required this.after,
  });

  final String statement;
  final Metric? main;
  final double? goal;

  /// Draw the week and month as a line instead of bars.
  final bool lines;
  final List<Widget> Function(BuildContext context) after;
}

/// The chart card with the D/W/M switch.
class _RangeCard extends StatefulWidget {
  const _RangeCard({
    required this.c,
    required this.metric,
    required this.statement,
    required this.curve,
    required this.lines,
    this.goal,
    this.accent,
  });

  final MonoCtx c;
  final Metric metric;
  final String statement;

  /// Whether the day is the heart-rate curve of the day.
  final bool curve;
  final bool lines;
  final double? goal;
  final Color? accent;

  @override
  State<_RangeCard> createState() => _RangeCardState();
}

class _RangeCardState extends State<_RangeCard> {
  int _range = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final l10n = c.l10n;
    final metric = widget.metric;
    final hours = c.hours(metric);
    final samples = c.health.snapshot.heart[c.health.todayIndex];
    final hasDay = widget.curve ? samples.isNotEmpty : hours != null;
    // Without a day view the first range is the week.
    final labels = [
      if (hasDay) l10n.monoRangeDay,
      l10n.monoRangeWeek,
      l10n.monoRangeMonth,
    ];
    final index = _range.clamp(0, labels.length - 1);
    final range = hasDay ? index : index + 1;
    final n = range == 2 ? 30 : 7;
    final values = range == 0 ? null : c.days(metric, n);
    final known = [?values].expand((v) => v).whereType<double>().toList();
    final average = known.isEmpty
        ? null
        : known.reduce((a, b) => a + b) / known.length;
    final shownValue = range == 0
        ? (widget.curve
              ? samples.last.bpm.toDouble()
              : hours!.whereType<double>().fold<double>(0, (a, b) => a + b))
        : (metric.rule == DayRule.sum ? average : average);
    final statement = widget.statement;
    return MonoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labels.length > 1)
            MonoSegmented(
              labels: labels,
              selected: index,
              onChanged: (i) => setState(() => _range = i),
            ),
          if (labels.length > 1) const SizedBox(height: 22),
          MonoStat(
            label: range == 0 ? metric.title(l10n) : l10n.averagePerDay,
            value: metric.format(c.formats, shownValue),
            unit: metric.unitFor(l10n, shownValue),
          ),
          const SizedBox(height: 22),
          KeyedSubtree(
            key: ValueKey(range),
            child: range == 0
                ? (widget.curve
                      ? MonoLine(
                          values: [for (final s in samples) s.bpm.toDouble()],
                          color: widget.accent,
                          semantics: statement,
                          height: 120,
                        )
                      : MonoBars(
                          values: hours!,
                          semantics: statement,
                          height: 120,
                          accent: widget.accent,
                        ))
                : widget.lines || widget.curve
                ? MonoLine(
                    values: values!,
                    color: widget.accent,
                    goal: widget.goal,
                    semantics: statement,
                    height: 120,
                  )
                : MonoBars(
                    values: values!,
                    goal: widget.goal,
                    accent: widget.accent,
                    semantics: statement,
                    height: 120,
                    radius: 6,
                    gap: range == 2 ? 2 : 6,
                  ),
          ),
        ],
      ),
    );
  }
}
