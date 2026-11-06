import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../../../data/day_insights.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../data/night_insights.dart';
import '../../../features/activity/removed_workouts_page.dart';
import '../../../features/activity/workout_style.dart';
import '../../../features/detail/metric_spec.dart';
import '../../../features/today/day_format.dart';
import '../data/mono_data.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_page.dart';
import 'day_page.dart';
import 'night_page.dart';
import 'workout_page.dart';

/// A long list in the look, built as it scrolls: the floating back pill, the
/// title, and month headings between the rows.
class MonoLazyList extends StatelessWidget {
  const MonoLazyList({
    super.key,
    required this.title,
    required this.rows,
    required this.row,
    this.header,
    this.trailing,
  });

  final String title;

  /// A [DateTime] for the heading of a month, anything else for a row.
  final List<Object> rows;
  final Widget Function(BuildContext context, Object row) row;
  final Widget? header;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = MonoCtx.of(context);
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: c.t.bg,
      body: MonoFloatingBack(
        title: title,
        trailing: trailing,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            padding.top + MonoFloatingBack.room,
            16,
            40 + padding.bottom,
          ),
          itemCount: rows.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonoSerif.title(title),
                  const SizedBox(height: 12),
                  ?header,
                ],
              );
            }
            final item = rows[index - 1];
            if (item is DateTime) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
                child: MonoSerif.heading(c.formats.month(item)),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                decoration: BoxDecoration(
                  color: c.t.card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: row(context, item),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A square with a number on the recovery tint, as in the rows of days.
class MonoScoreMark extends StatelessWidget {
  const MonoScoreMark(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.recoveryBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: icon != null
          ? Icon(icon, size: 22, color: t.recovery)
          : Text(
              text,
              style: MonoType.inter(17, 22, FontWeight.w600, t.recovery),
            ),
    );
  }
}

/// Every day the app knows, newest first and month by month.
class MonoDayListPage extends StatelessWidget {
  const MonoDayListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final goals = dayGoalsOf(c.settings);
        final rows = <Object>[];
        DateTime? month;
        for (final day in c.health.days.reversed) {
          final start = DateTime(day.year, day.month);
          if (start != month) rows.add(month = start);
          rows.add(day);
        }
        return MonoLazyList(
          title: c.l10n.allDays,
          rows: rows,
          row: (context, item) {
            final day = item as DateTime;
            final score = dayScore(
              day: day,
              valueOf: c.health.valueOn,
              nights: c.health.nights,
              goals: goals,
            ).total;
            final steps = c.health.valueOn(Metric.steps, day);
            return MonoRow(
              title: c.formats.relativeDay(day, c.today),
              subtitle: steps == null
                  ? null
                  : Metric.steps.formatWithUnit(c.formats, steps),
              leading: MonoScoreMark(score == null ? '–' : '$score'),
              onTap: () => c.push(MonoDayPage(date: day)),
            );
          },
        );
      },
    );
  }
}

/// Every night the app knows, newest first and month by month.
class MonoNightListPage extends StatelessWidget {
  const MonoNightListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final rows = <Object>[];
        DateTime? month;
        for (final night in c.health.nights.reversed) {
          final start = DateTime(night.date.year, night.date.month);
          if (start != month) rows.add(month = start);
          rows.add(night);
        }
        return MonoLazyList(
          title: c.l10n.allNights,
          rows: rows,
          row: (context, item) {
            final night = item as SleepNight;
            final score = sleepScore(
              night,
              c.settings.sleepGoalHours,
              c.health.nights,
            ).total;
            return MonoRow(
              title: c.formats.relativeDay(night.date, c.today),
              subtitle:
                  '${formatClockOf(night.bedtimeMinute)} – '
                  '${formatClockOf(night.bedtimeMinute + night.totalMinutes)}',
              value: c.formats.duration(night.totalMinutes),
              leading: MonoScoreMark(
                '$score',
                icon: c.simple ? Icons.bedtime_rounded : null,
              ),
              onTap: () => c.push(MonoNightPage(date: night.date)),
            );
          },
        );
      },
    );
  }
}

/// Every workout, newest first and month by month, with a filter for the
/// kind.
class MonoWorkoutListPage extends StatefulWidget {
  const MonoWorkoutListPage({super.key});

  @override
  State<MonoWorkoutListPage> createState() => _MonoWorkoutListPageState();
}

class _MonoWorkoutListPageState extends State<MonoWorkoutListPage> {
  WorkoutType? _only;

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final t = c.t;
        final all = c.health.workouts;
        final removed = c.health.removedWorkouts.length;
        final kinds = [
          for (final type in WorkoutType.values)
            if (all.any((w) => w.type == type)) type,
        ];
        final only = kinds.contains(_only) ? _only : null;
        final rows = <Object>[];
        DateTime? month;
        for (final workout in all.reversed) {
          if (only != null && workout.type != only) continue;
          final start = DateTime(workout.start.year, workout.start.month);
          if (start != month) rows.add(month = start);
          rows.add(workout);
        }
        Widget chip(WorkoutType? type) {
          final on = only == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                Haptics.selection();
                setState(() => _only = type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? t.solid : t.fill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type?.label(l10n) ?? l10n.filterAll,
                  style: MonoType.inter(
                    14,
                    18,
                    FontWeight.w600,
                    on ? t.onSolid : t.ink,
                  ),
                ),
              ),
            ),
          );
        }

        return MonoLazyList(
          title: l10n.allActivities,
          trailing: removed == 0
              ? null
              : MonoGlassButton(
                  icon: Icons.restore_from_trash_rounded,
                  label: l10n.removedActivities,
                  onTap: () => c.push(const RemovedWorkoutsPage()),
                ),
          header: kinds.length > 1
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(children: [chip(null), ...kinds.map(chip)]),
                )
              : null,
          rows: rows,
          row: (context, item) => monoWorkoutRow(c, item as Workout),
        );
      },
    );
  }
}

/// A workout as a row: its kind, when, and its time.
Widget monoWorkoutRow(MonoCtx c, Workout workout) => MonoRow(
  title: workout.type.label(c.l10n),
  subtitle: [
    c.formats.relativeDay(workout.start, c.today),
    if (workout.distanceKm case final km?) '${c.formats.decimal(km)} km',
  ].join(' · '),
  value: c.formats.duration(workout.minutes),
  leading: MonoScoreMark('', icon: workout.type.icon),
  onTap: () => c.push(MonoWorkoutPage(workout: workout)),
);

/// A round button on the glass of the bar, for the corner of a page.
class MonoGlassButton extends StatelessWidget {
  const MonoGlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      MonoIconButton(icon: icon, label: label, onTap: onTap);
}
