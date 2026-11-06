import 'package:material_ui/material_ui.dart';

import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../data/night_insights.dart';
import '../data/mono_data.dart';
import '../data/mono_statements.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_page.dart';
import 'list_pages.dart';
import 'night_page.dart';

/// The page of sleep: the template the other categories follow.
class MonoSleepPage extends StatefulWidget {
  const MonoSleepPage({super.key, required this.backLabel});

  final String backLabel;

  @override
  State<MonoSleepPage> createState() => _MonoSleepPageState();
}

class _MonoSleepPageState extends State<MonoSleepPage> {
  int _range = 0;

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final t = c.t;
        final raw = c.health.latestNight;
        final night = raw == null ? null : c.health.withCurve(raw);
        final goal = c.settings.sleepGoalHours;
        final all = c.health.nights;
        final insights = night == null
            ? null
            : NightInsights.of(night, all, goal);
        final plan = tonight(all, goal, c.today);
        final statement = c.sleepStatement(night);
        final values = _range == 0
            ? null
            : c.days(Metric.sleep, _range == 1 ? 7 : 30);
        return MonoSubPage(
          category: MonoCategory.sleep,
          categoryLabel: l10n.groupSleep,
          backLabel: widget.backLabel,
          statement: statement,
          children: [
            MonoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoSegmented(
                    labels: [
                      l10n.monoRangeDay,
                      l10n.monoRangeWeek,
                      l10n.monoRangeMonth,
                    ],
                    selected: _range,
                    onChanged: (i) => setState(() => _range = i),
                  ),
                  const SizedBox(height: 22),
                  if (night != null && _range == 0) ...[
                    MonoStat(
                      label: l10n.sleepDuration,
                      value: c.formats.duration(night.totalMinutes),
                    ),
                    const SizedBox(height: 22),
                    night.hasCurve
                        ? MonoHypnogram(
                            segments: night.segments,
                            totalMinutes: night.totalMinutes,
                            semantics: statement,
                            height: 120,
                          )
                        : MonoTrack(
                            value: night.totalMinutes / (goal * 60),
                            semantics: statement,
                          ),
                    if (night.hasCurve) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatClockOf(night.bedtimeMinute),
                            style: MonoType.label(t),
                          ),
                          Text(
                            formatClockOf(
                              night.bedtimeMinute + night.totalMinutes,
                            ),
                            style: MonoType.label(t),
                          ),
                        ],
                      ),
                    ],
                  ] else if (values != null) ...[
                    MonoStat(
                      label: l10n.averagePerDay,
                      value: _average(c, values),
                    ),
                    const SizedBox(height: 22),
                    MonoBars(
                      key: ValueKey(_range),
                      values: values,
                      goal: goal,
                      semantics: statement,
                      height: 120,
                      radius: 6,
                      gap: _range == 2 ? 2 : 6,
                    ),
                  ] else
                    Text(l10n.noSleepData, style: MonoType.sub(t)),
                ],
              ),
            ),
            if (insights != null)
              MonoSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.scoreTitle, style: MonoType.label(t)),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${insights.score.total}',
                            style: MonoType.number(t),
                          ),
                          TextSpan(text: ' / 100', style: MonoType.unit(t)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    for (final part in ScorePart.values)
                      if (insights.score.parts[part] case final earned?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _partName(c, part),
                                      style: MonoType.body(t),
                                    ),
                                  ),
                                  Text(
                                    '${earned.round()} / ${part.points}',
                                    style: MonoType.inter(
                                      15,
                                      21,
                                      FontWeight.w600,
                                      t.ink,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              MonoTrack(
                                value: earned / part.points,
                                semantics:
                                    '${_partName(c, part)}, ${earned.round()} / ${part.points}',
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            if (night != null && night.hasStages)
              MonoSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.sleepStages, style: MonoType.label(t)),
                    const SizedBox(height: 16),
                    for (final (stage, name, color) in [
                      (SleepStage.deep, l10n.stageDeep, t.ink),
                      (SleepStage.light, l10n.stageLight, t.ink3),
                      (SleepStage.rem, l10n.stageRem, t.heart),
                      (SleepStage.awake, l10n.stageAwake, t.ink2),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(name, style: MonoType.body(t)),
                            ),
                            Text(
                              c.formats.duration(night.minutesIn(stage)),
                              style: MonoType.inter(
                                15,
                                21,
                                FontWeight.w600,
                                t.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (plan != null)
              MonoSurface(
                color: t.recoveryBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tonightTitle,
                      style: MonoType.category(t.recovery),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.tonightBedtime(formatClockOf(plan.bedtimeMinute)),
                      style: MonoType.numberSmall(t),
                    ),
                  ],
                ),
              ),
            if (raw != null)
              MonoSurface(
                onTap: () => c.push(MonoNightPage(date: raw.date)),
                child: MonoRow(title: l10n.sleepInDetail),
              ),
            MonoSurface(
              onTap: () => c.push(const MonoNightListPage()),
              child: MonoRow(title: l10n.allNights),
            ),
          ],
        );
      },
    );
  }

  String _average(MonoCtx c, List<double?> values) {
    final known = values.whereType<double>().toList();
    if (known.isEmpty) return '–';
    final mean = known.reduce((a, b) => a + b) / known.length;
    return c.formats.duration((mean * 60).round());
  }

  String _partName(MonoCtx c, ScorePart part) => switch (part) {
    ScorePart.duration => c.l10n.sleepDuration,
    ScorePart.stages => c.l10n.scorePartStages,
    ScorePart.efficiency => c.l10n.efficiency,
    ScorePart.regularity => c.l10n.regularity,
  };
}
