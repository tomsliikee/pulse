import 'package:material_ui/material_ui.dart';

import '../../../../app/formatters.dart';
import '../../../../data/models.dart';
import '../../../../data/training/exercise_library.dart';
import '../../../../data/training/session_link.dart';
import '../../../../data/training/training_insights.dart';
import '../../../../data/training/training_models.dart';
import '../../../../features/activity/workout_style.dart';
import '../../data/mono_data.dart';
import '../../theme/mono_type.dart';
import '../../widgets/mono_blocks.dart';
import '../../widgets/mono_card.dart';
import '../../widgets/mono_category.dart';
import '../../widgets/mono_controls.dart';
import '../../widgets/mono_motion.dart';
import '../../widgets/mono_page.dart';
import '../../widgets/mono_sheet.dart';
import '../list_pages.dart';
import 'live_page.dart';
import 'muscle_map.dart';
import 'session_page.dart';
import 'templates_page.dart';
import 'training_start.dart';
import 'training_text.dart';

/// The Training tab: what is next today, the week against its goal, a
/// training a watch saw without sets, the muscles of the week, the records
/// and the latest trainings of every kind.
class MonoTrainingPage extends StatelessWidget {
  const MonoTrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.training,
        scope.health,
        scope.settings,
      ]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final t = c.t;
        final data = c.scope.training.data;
        final today = c.today;
        final unmatched = unmatchedStrength(
          data.sessions,
          c.health.workouts,
          since: DateTime(today.year, today.month, today.day - 1),
        );
        final from = DateTime(today.year, today.month, today.day - 6);
        final muscles = setsPerMuscle(
          data.sessions,
          from: from,
          to: DateTime(today.year, today.month, today.day + 1),
          custom: data.customExercises,
        );
        final records = [
          for (final r in recordsOf(data.sessions))
            if (!r.session.start.isBefore(
                  DateTime(today.year, today.month, today.day - 30),
                ) &&
                r.kind == RecordKind.oneRepMax)
              r,
        ];
        final children = <Widget>[
          _TodayCard(c: c, data: data),
          for (final w in unmatched.take(1)) _MatchCard(c: c, workout: w),
          _WeekCard(c: c, data: data),
          MonoCard(
            category: MonoCategory.workouts,
            icon: Icons.accessibility_new_rounded,
            categoryLabel: l10n.trainingMuscles,
            statement: muscles.isEmpty
                ? l10n.trainingMusclesNone
                : l10n.trainingMusclesStatement(
                    muscleLabel(
                      l10n,
                      (muscles.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value)))
                          .first
                          .key,
                    ),
                  ),
            child: MuscleMap(sets: muscles, semantics: l10n.trainingMuscles),
          ),
          if (records.isNotEmpty)
            _RecordsCard(c: c, records: records.take(3).toList()),
          _RecentCard(c: c, data: data),
        ];
        return MonoPage(
          floatTitle: l10n.navTraining,
          floatActions: [_templatesButton(c, 36)],
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoSerif.title(l10n.navTraining),
                      const SizedBox(height: 8),
                      Text(c.dateText, style: MonoType.sub(t)),
                    ],
                  ),
                ),
                _templatesButton(c, 48),
              ],
            ),
            const SizedBox(height: 32),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              MonoRise(order: i, page: 'training', child: children[i]),
            ],
          ],
        );
      },
    );
  }

  static Widget _templatesButton(MonoCtx c, double size) => MonoCircleButton(
    icon: Icons.list_alt_rounded,
    label: c.l10n.trainingTemplates,
    fill: c.t.fill,
    color: c.t.ink,
    size: size,
    onTap: () => c.push(const MonoTemplatesPage()),
  );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.c, required this.data});

  final MonoCtx c;
  final TrainingData data;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final t = c.t;
    final training = c.scope.training;
    final active = data.active;
    final next = nextTemplate(data);
    final navigator = Navigator.of(context);
    if (active != null) {
      final minutes = training.now.difference(active.start).inMinutes;
      return MonoCard(
        category: MonoCategory.recovery,
        icon: Icons.fitness_center_rounded,
        categoryLabel: l10n.trainingLive,
        statement: active.name.isEmpty ? l10n.trainingSession : active.name,
        background: t.recoveryBg,
        onTap: () => navigator.push(MonoLiveRoute()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [
                c.formats.duration(minutes),
                l10n.trainingSetsCount(active.countingSets.length),
              ].join(' · '),
              style: MonoType.sub(t),
            ),
            const SizedBox(height: 16),
            MonoPrimaryButton(
              label: l10n.trainingContinue,
              icon: Icons.play_arrow_rounded,
              onTap: () => navigator.push(MonoLiveRoute()),
            ),
          ],
        ),
      );
    }
    if (next == null) {
      return MonoCard(
        category: MonoCategory.workouts,
        categoryLabel: l10n.trainingTodayTitle,
        statement: l10n.trainingNoPlan,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.trainingNoPlanHint, style: MonoType.sub(t)),
            const SizedBox(height: 16),
            MonoPrimaryButton(
              label: l10n.trainingChooseSplit,
              onTap: () => showSplitSheet(context),
            ),
            const SizedBox(height: 10),
            MonoPrimaryButton(
              label: l10n.trainingEmpty,
              tonal: true,
              onTap: () => startTraining(
                navigator,
                training: training,
                name: l10n.trainingSession,
              ),
            ),
          ],
        ),
      );
    }
    final names = [
      for (final e in next.exercises.take(4))
        exerciseById(
              e.exerciseId,
              data.customExercises,
            )?.name(l10n.localeName) ??
            e.exerciseId,
    ];
    final focus = <Muscle>{
      for (final e in next.exercises)
        ...?exerciseById(e.exerciseId, data.customExercises)?.primary,
    };
    return MonoCard(
      category: MonoCategory.workouts,
      categoryLabel: l10n.trainingToday(next.name),
      statement: focus.isEmpty
          ? next.name
          : [for (final m in focus.take(3)) muscleLabel(l10n, m)].join(', '),
      onTap: () => c.push(MonoTemplatePage(templateId: next.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoGrid(
            cells: [
              MonoStat(
                label: l10n.trainingExercises,
                value: '${next.exercises.length}',
                small: true,
              ),
              MonoStat(
                label: l10n.trainingSetsLabel,
                value: '${next.setCount}',
                small: true,
              ),
            ],
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              names.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MonoType.label(t),
            ),
          ],
          const SizedBox(height: 16),
          MonoPrimaryButton(
            label: l10n.trainingStart,
            icon: Icons.play_arrow_rounded,
            onTap: () => startTraining(
              navigator,
              training: training,
              template: next,
              name: next.name,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MonoPrimaryButton(
                  label: l10n.trainingEmptyShort,
                  tonal: true,
                  onTap: () => startTraining(
                    navigator,
                    training: training,
                    name: l10n.trainingSession,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MonoPrimaryButton(
                  label: l10n.trainingOther,
                  tonal: true,
                  onTap: () => showTrainingStartSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A strength training the watch recorded that has no sets: asks whether
/// to put them in now.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.c, required this.workout});

  final MonoCtx c;
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final t = c.t;
    final w = workout;
    final next = usualTemplate(c.scope.training.data, w.start);
    return MonoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.watch_rounded, size: 20, color: t.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.trainingFound,
                  style: MonoType.inter(16, 21, FontWeight.w600, t.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              l10n.trainingFoundAt(
                c.formats.relativeDay(w.start, c.today),
                formatClock(w.start.hour * 60 + w.start.minute),
                formatClock(w.end.hour * 60 + w.end.minute),
              ),
              if (w.avgBpm != null) l10n.searchAvgHeart('${w.avgBpm}'),
            ].join(' · '),
            style: MonoType.label(t),
          ),
          const SizedBox(height: 14),
          MonoPrimaryButton(
            label: next == null
                ? l10n.trainingLogAfter
                : l10n.trainingLogAs(next.name),
            tonal: true,
            onTap: () => logTrainingAfter(
              Navigator.of(context),
              training: c.scope.training,
              template: next,
              workout: w,
              name: l10n.trainingSession,
            ),
          ),
        ],
      ),
    );
  }
}

/// The days of this week with a training on them, against the goal.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.c, required this.data});

  final MonoCtx c;
  final TrainingData data;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final t = c.t;
    final today = c.today;
    final days = trainingDaysOfWeek(today, data.sessions, c.health.workouts);
    // By weekday, not by a difference of days: across the change of the
    // clocks a local day is 23 or 25 hours long.
    final done = {for (final d in days) d.weekday - 1};
    final names = l10n.weekdaysShort.split(',');
    final goal = data.weeklyGoal;
    final reached = days.length >= goal;
    return MonoCard(
      category: reached ? MonoCategory.recovery : MonoCategory.workouts,
      icon: Icons.calendar_view_week_rounded,
      categoryLabel: l10n.trainingThisWeek,
      statement: l10n.trainingWeekOf(days.length, goal),
      onTap: () => c.push(const MonoTemplatesPage()),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done.contains(i) ? t.recovery : t.fill,
                    border: i == today.weekday - 1
                        ? Border.all(color: t.ink, width: 2)
                        : null,
                  ),
                  child: done.contains(i)
                      ? Icon(Icons.check_rounded, size: 18, color: t.bg)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  i < names.length ? names[i] : '',
                  style: MonoType.label(t),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.c, required this.records});

  final MonoCtx c;
  final List<TrainingRecord> records;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final first = records.first;
    final custom = c.scope.training.data.customExercises;
    String name(String id) =>
        exerciseById(id, custom)?.name(l10n.localeName) ?? id;
    return MonoCard(
      category: MonoCategory.recovery,
      icon: Icons.emoji_events_rounded,
      categoryLabel: l10n.trainingRecords,
      statement: l10n.trainingRecordStatement(name(first.exerciseId)),
      background: c.t.recoveryBg,
      child: Column(
        children: [
          for (final r in records)
            MonoRow(
              title: name(r.exerciseId),
              subtitle: [
                c.formats.relativeDay(r.session.start, c.today),
                if (r.gain != null) '+${kgText(c.formats, r.gain!)} kg',
              ].join(' · '),
              value: kgText(c.formats, r.value),
              unit: 'kg 1RM',
              onTap: () => c.push(MonoSessionPage(sessionId: r.session.id)),
            ),
        ],
      ),
    );
  }
}

/// The latest trainings of every kind: sessions with their sets, and the
/// workouts of the health store that no session belongs to.
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.c, required this.data});

  final MonoCtx c;
  final TrainingData data;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final linked = {for (final s in data.sessions) ?s.linkedWorkout};
    final rows = <(DateTime, Widget)>[
      for (final s in data.sessions.reversed.take(8))
        (
          s.start,
          MonoRow(
            title: s.name.isEmpty ? l10n.trainingSession : s.name,
            subtitle: [
              c.formats.relativeDay(s.start, c.today),
              l10n.trainingSetsCount(s.countingSets.length),
            ].join(' · '),
            value: c.formats.duration(s.duration.inMinutes),
            leading: MonoScoreMark('', icon: WorkoutType.strength.icon),
            onTap: () => c.push(MonoSessionPage(sessionId: s.id)),
          ),
        ),
      for (final w in c.health.workouts.reversed.take(12))
        if (!linked.contains(w.key)) (w.start, monoWorkoutRow(c, w)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return MonoCard(
      category: MonoCategory.workouts,
      categoryLabel: l10n.trainingRecent,
      statement: rows.isEmpty ? l10n.trainingNoneYet : null,
      child: Column(
        children: [
          for (final (i, (_, row)) in rows.take(6).indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            row,
          ],
          if (c.health.workouts.isNotEmpty) ...[
            const SizedBox(height: 12),
            MonoRow(
              title: l10n.trainingAllWorkouts,
              onTap: () => c.push(const MonoWorkoutListPage()),
            ),
          ],
        ],
      ),
    );
  }
}
