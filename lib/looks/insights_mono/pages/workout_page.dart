import 'package:material_ui/material_ui.dart';

import '../../../app/formatters.dart';
import '../../../app/haptics.dart';
import '../../../data/models.dart';
import '../../../data/workout_archive.dart';
import '../../../data/workout_insights.dart';
import '../../../features/activity/route_view.dart';
import '../../../features/activity/workout_format.dart';
import '../../../features/activity/workout_style.dart';
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_page.dart';
import 'list_pages.dart';

/// One workout in the look: its figure and what it says, every number, the
/// route, each number against the one before and the usual one, the last
/// ones of the kind, how often, and what to do next.
class MonoWorkoutPage extends StatelessWidget {
  const MonoWorkoutPage({super.key, required this.workout});

  final Workout workout;

  /// Takes the workout out of the app and leaves the page; the health store
  /// keeps it, so the message can bring it back.
  Future<void> _remove(BuildContext context, MonoCtx c) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = c.l10n;
    final health = c.health;
    final RemovedWorkout removed;
    try {
      removed = await health.removeWorkout(workout);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
      return;
    }
    Haptics.confirm();
    navigator.maybePop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.workoutRemoved),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              try {
                await health.restoreWorkout(removed);
              } on Exception {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.restoreFailed)),
                );
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final formats = c.formats;
        final t = c.t;
        final health = c.health;
        final settings = c.settings;
        // The archive may hold a later reading, with the heart rate added.
        final current = health.workouts.firstWhere(
          (other) => other.key == workout.key,
          orElse: () => workout,
        );
        final insights = WorkoutInsights.of(
          current,
          health.workouts,
          maxHeartRate: health.maxHeartRate,
        );
        final route = health.routeOf(current);
        final shown = insights.measures.skip(1).toList();
        final rated = shown.any((m) => m.measure == WorkoutMeasure.intensity);
        final compared = [
          for (final m in insights.measures)
            if (m.previous != null) m,
        ];
        final averaged = insights.earlier.length < WorkoutInsights.averageOver
            ? insights.earlier.length
            : WorkoutInsights.averageOver;

        Widget delta(MeasureComparison m, double? other, Trend trend) {
          if (other == null) return const SizedBox.shrink();
          final diff = m.value - other;
          return MonoDelta(
            trend == Trend.same
                ? '±0'
                : '${diff < 0 ? '−' : '+'}'
                      '${m.measure.formatDifference(formats, current.type, diff)}',
            good: switch (trend) {
              Trend.better => true,
              Trend.worse => false,
              Trend.same || Trend.neutral => null,
            },
          );
        }

        return MonoSubPage(
          category: MonoCategory.workouts,
          icon: current.type.icon,
          categoryLabel: current.type.label(l10n),
          kicker: l10n.workoutAtTime(
            formats.longDate(current.start),
            formatClock(current.start.hour * 60 + current.start.minute),
          ),
          backLabel: l10n.workouts,
          statement: workoutFigure(formats, current),
          trailing: MonoGlassButton(
            icon: Icons.delete_outline_rounded,
            label: l10n.removeWorkout,
            onTap: () => _remove(context, c),
          ),
          children: [
            MonoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workoutHeadline(formats, insights),
                    style: MonoType.statement(t),
                  ),
                  if (insights.primary.isBest) ...[
                    const SizedBox(height: 8),
                    _Best(label: l10n.personalBest),
                  ],
                ],
              ),
            ),
            if (shown.isNotEmpty)
              MonoBlock(
                title: l10n.workoutNumbers,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MonoGrid(
                      cells: [
                        for (final m in shown)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonoStat(
                                label: m.measure.label(l10n),
                                small: true,
                                value: m.measure == WorkoutMeasure.intensity
                                    ? IntensityLevel.of(m.value).label(l10n)
                                    : m.measure.format(
                                        formats,
                                        current.type,
                                        m.value,
                                      ),
                              ),
                              if (m.measure == WorkoutMeasure.intensity)
                                Text(
                                  m.measure.format(
                                    formats,
                                    current.type,
                                    m.value,
                                  ),
                                  style: MonoType.time(t),
                                )
                              else if (m.isBest)
                                _Best(label: l10n.personalBest),
                            ],
                          ),
                      ],
                    ),
                    if (rated) ...[
                      const SizedBox(height: 10),
                      MonoNote(l10n.intensityNote),
                    ],
                  ],
                ),
              ),
            if (route == null && health.routesNeedConsent)
              RouteConsentSection(onAllow: health.requestRoutes),
            if (route != null) ...[
              RouteSection(route: route),
              if (settings.routeSplits && route.splits.isNotEmpty)
                SplitsSection(route: route, type: current.type),
              if (settings.routeClimb && route.hasAltitude)
                ElevationSection(route: route),
            ],
            MonoBlock(
              title: l10n.compareTitle,
              child: compared.isEmpty
                  ? MonoSurface(
                      child: Text(l10n.compareFirst, style: MonoType.sub(t)),
                    )
                  : MonoList(
                      children: [
                        Row(
                          children: [
                            const Expanded(child: SizedBox.shrink()),
                            SizedBox(
                              width: 84,
                              child: Text(
                                l10n.compareLast,
                                textAlign: TextAlign.end,
                                style: MonoType.label(t),
                              ),
                            ),
                            SizedBox(
                              width: 84,
                              child: Text(
                                l10n.compareAverage(averaged),
                                textAlign: TextAlign.end,
                                style: MonoType.label(t),
                              ),
                            ),
                          ],
                        ),
                        for (final m in compared)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.measure.label(l10n),
                                  style: MonoType.body(t),
                                ),
                              ),
                              SizedBox(
                                width: 84,
                                child: delta(m, m.previous, m.againstPrevious),
                              ),
                              SizedBox(
                                width: 84,
                                child: delta(m, m.average, m.againstAverage),
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
            if (insights.trend.length > 1)
              MonoBlock(
                title: l10n.trendTitle,
                child: _Progress(c: c, insights: insights),
              ),
            MonoBlock(
              title: l10n.frequencyTitle,
              child: MonoSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.frequencyRecent(
                        formats.decimal(insights.perWeekRecent),
                      ),
                      style: MonoType.inter(17, 23, FontWeight.w600, t.ink),
                    ),
                    if (insights.perWeekBefore case final before?) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.frequencyBefore(formats.decimal(before)),
                        style: MonoType.sub(t),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (insights.tips.isNotEmpty)
              MonoBlock(
                title: l10n.tipsTitle,
                child: MonoSentences(
                  icon: Icons.lightbulb_outline_rounded,
                  sentences: [
                    for (final tip in insights.tips) workoutTip(l10n, tip),
                  ],
                  note: l10n.tipsNote,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Best extends StatelessWidget {
  const _Best({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = MonoCtx.of(context).t;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.emoji_events_rounded, size: 14, color: t.recovery),
        const SizedBox(width: 4),
        Text(label, style: MonoType.inter(12, 16, FontWeight.w600, t.recovery)),
      ],
    );
  }
}

/// The last workouts of the kind as bars, this one marked, for one measure.
class _Progress extends StatefulWidget {
  const _Progress({required this.c, required this.insights});

  final MonoCtx c;
  final WorkoutInsights insights;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  int _shown = 0;

  /// Speed in km/h for every kind, so a taller bar is always the better one.
  static double? _value(Workout workout, WorkoutMeasure measure) {
    if (measure != WorkoutMeasure.speed) return measureOf(workout, measure);
    final km = workout.distanceKm;
    return km == null || km <= 0 || workout.minutes == 0
        ? null
        : km / workout.minutes * 60;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final l10n = c.l10n;
    final trend = widget.insights.trend;
    final offered = [
      for (final measure in switch (trend.last.type.focus) {
        WorkoutFocus.distance || WorkoutFocus.speed => const [
          WorkoutMeasure.distance,
          WorkoutMeasure.speed,
          WorkoutMeasure.duration,
        ],
        WorkoutFocus.effort => const [
          WorkoutMeasure.duration,
          WorkoutMeasure.energy,
          WorkoutMeasure.avgHeartRate,
        ],
        WorkoutFocus.calm => const [
          WorkoutMeasure.duration,
          WorkoutMeasure.avgHeartRate,
        ],
      })
        if (_value(trend.last, measure) != null) measure,
    ];
    final measure = offered[_shown < offered.length ? _shown : 0];
    final value = _value(trend.last, measure)!;
    return MonoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offered.length > 1) ...[
            MonoSegmented(
              labels: [for (final offer in offered) offer.label(l10n)],
              selected: offered.indexOf(measure),
              onChanged: (i) => setState(() => _shown = i),
            ),
            const SizedBox(height: 20),
          ],
          MonoStat(
            label: l10n.trendLast(trend.length),
            value: measure.format(c.formats, trend.last.type, value),
          ),
          const SizedBox(height: 18),
          MonoBars(
            key: ValueKey(measure),
            values: [for (final workout in trend) _value(workout, measure)],
            highlight: trend.length - 1,
            semantics: l10n.trendTitle,
            height: 130,
            radius: 6,
          ),
        ],
      ),
    );
  }
}
