import 'package:material_ui/material_ui.dart';

import '../../../../app/formatters.dart';
import '../../../../app/haptics.dart';
import '../../../../data/training/exercise_library.dart';
import '../../../../data/training/session_link.dart';
import '../../../../data/training/training_insights.dart';
import '../../data/mono_data.dart';
import '../../theme/mono_type.dart';
import '../../widgets/mono_blocks.dart';
import '../../widgets/mono_card.dart';
import '../../widgets/mono_category.dart';
import '../../widgets/mono_motion.dart';
import '../../widgets/mono_page.dart';
import '../../widgets/mono_sheet.dart';
import '../workout_page.dart';
import 'exercise_page.dart';
import 'exercise_picker.dart';
import 'live_page.dart';
import 'training_text.dart';

/// One finished training: how long and how much, the workout of the watch
/// it is linked to, what records fell, and every set.
class MonoSessionPage extends StatefulWidget {
  const MonoSessionPage({
    super.key,
    required this.sessionId,
    this.fresh = false,
    this.edit = false,
  });

  final String sessionId;

  /// Opened right after the training ended: the statement says well done.
  final bool fresh;

  /// Opens with the sets to correct, as for a training logged afterwards.
  final bool edit;

  @override
  State<MonoSessionPage> createState() => _MonoSessionPageState();
}

class _MonoSessionPageState extends State<MonoSessionPage> {
  late bool _editing = widget.edit;

  String get sessionId => widget.sessionId;
  bool get fresh => widget.fresh;

  Future<void> _addExercise(MonoCtx c) async {
    final id = await pickExercise(context);
    if (id == null) return;
    await c.scope.training.addExerciseToSession(id, session: sessionId);
  }

  Future<void> _delete(BuildContext context, MonoCtx c) async {
    final l10n = c.l10n;
    final navigator = Navigator.of(context);
    final yes = await showMonoSheet<bool>(
      context,
      title: l10n.trainingDeleteAsk,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoPrimaryButton(
            label: l10n.delete,
            danger: true,
            onTap: () => Navigator.of(sheet).pop(true),
          ),
          const SizedBox(height: 10),
          MonoPrimaryButton(
            label: l10n.cancel,
            tonal: true,
            onTap: () => Navigator.of(sheet).pop(false),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await c.scope.training.deleteSession(sessionId);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.training, scope.health]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final t = c.t;
        final l10n = c.l10n;
        final data = c.scope.training.data;
        final session = data.sessions
            .where((s) => s.id == sessionId)
            .firstOrNull;
        if (session == null) {
          return MonoSubPage(
            category: MonoCategory.workouts,
            categoryLabel: l10n.trainingSession,
            backLabel: l10n.back,
            statement: l10n.trainingGone,
            children: const [],
          );
        }
        final workout = linkedWorkoutOf(session, c.health.workouts);
        final records = [
          for (final r in recordsOf(data.sessions))
            if (r.session.id == session.id) r,
        ];
        final minutes = session.duration.inMinutes;
        final language = l10n.localeName;
        return MonoSubPage(
          category: MonoCategory.workouts,
          categoryLabel: session.name.isEmpty
              ? l10n.trainingSession
              : session.name,
          kicker: c.formats.relativeDay(session.start, c.today),
          backLabel: l10n.back,
          statement: fresh
              ? l10n.trainingWellDone
              : records.isNotEmpty
              ? l10n.trainingRecordsCount(records.length)
              : l10n.trainingSessionStatement(
                  c.formats.duration(minutes),
                  session.countingSets.length,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonoIconButton(
                icon: _editing ? Icons.check_rounded : Icons.edit_rounded,
                label: _editing ? l10n.done : l10n.trainingEditSets,
                onTap: () {
                  Haptics.tap();
                  FocusScope.of(context).unfocus();
                  setState(() => _editing = !_editing);
                },
              ),
              const SizedBox(width: 8),
              MonoIconButton(
                icon: Icons.delete_outline_rounded,
                label: l10n.delete,
                onTap: () => _delete(context, c),
              ),
            ],
          ),
          children: [
            MonoSurface(
              child: MonoGrid(
                cells: [
                  MonoStat(
                    label: l10n.trainingDuration,
                    value: c.formats.duration(minutes),
                    small: true,
                  ),
                  MonoStat(
                    label: l10n.trainingSetsLabel,
                    value: c.formats.integer(session.countingSets.length),
                    small: true,
                  ),
                  MonoStat(
                    label: l10n.trainingVolume,
                    value: c.formats.integer(session.volume.round()),
                    unit: 'kg',
                    small: true,
                  ),
                  MonoStat(
                    label: l10n.trainingAvgHeart,
                    value: workout?.avgBpm == null ? '–' : '${workout!.avgBpm}',
                    unit: 'bpm',
                    small: true,
                  ),
                ],
              ),
            ),
            _Link(c: c, sessionId: session.id, linked: workout != null),
            if (records.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonoSection(l10n.trainingRecords),
                  const SizedBox(height: 14),
                  MonoSurface(
                    color: t.recoveryBg,
                    child: Column(
                      children: [
                        for (final r in records)
                          MonoRow(
                            title:
                                exerciseById(
                                  r.exerciseId,
                                  data.customExercises,
                                )?.name(language) ??
                                r.exerciseId,
                            subtitle: recordKindLabel(l10n, r.kind),
                            value: r.kind == RecordKind.volume
                                ? c.formats.integer(r.value.round())
                                : kgText(c.formats, r.value),
                            unit: 'kg',
                            when: r.gain == null
                                ? null
                                : '+${kgText(c.formats, r.gain!)}',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            if (_editing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonoSection(l10n.trainingExercises),
                  if (widget.edit) ...[
                    const SizedBox(height: 6),
                    Text(l10n.trainingLoggedHint, style: MonoType.label(t)),
                  ],
                  const SizedBox(height: 14),
                  for (final (i, e) in session.exercises.indexed) ...[
                    MonoExerciseEditor(
                      key: ValueKey('${session.id}/$i/${e.exerciseId}'),
                      c: c,
                      sessionId: session.id,
                      index: i,
                      entry: e,
                      count: session.exercises.length,
                      exercise: exerciseById(
                        e.exerciseId,
                        data.customExercises,
                      ),
                      language: language,
                    ),
                    const SizedBox(height: 12),
                  ],
                  MonoPrimaryButton(
                    label: l10n.trainingAddExercise,
                    icon: Icons.add_rounded,
                    tonal: true,
                    onTap: () => _addExercise(c),
                  ),
                  const SizedBox(height: 10),
                  MonoPrimaryButton(
                    label: l10n.done,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _editing = false);
                    },
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonoSection(l10n.trainingExercises),
                  const SizedBox(height: 14),
                  for (final e in session.exercises) ...[
                    MonoSurface(
                      onTap: () =>
                          c.push(MonoExercisePage(exerciseId: e.exerciseId)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exerciseById(
                                  e.exerciseId,
                                  data.customExercises,
                                )?.name(language) ??
                                e.exerciseId,
                            style: MonoType.inter(
                              17,
                              22,
                              FontWeight.w600,
                              t.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final (i, s) in e.sets.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      setKindMark(l10n, s.kind).isEmpty
                                          ? '${i + 1}'
                                          : setKindMark(l10n, s.kind),
                                      style: MonoType.label(t),
                                    ),
                                  ),
                                  Text(
                                    setText(c.formats, s),
                                    style: MonoType.inter(
                                      15,
                                      20,
                                      FontWeight.w500,
                                      t.ink,
                                    ),
                                  ),
                                  if (epley(s.kg, s.reps) case final e?) ...[
                                    const Spacer(),
                                    Text(
                                      '1RM ${kgText(c.formats, e)}',
                                      style: MonoType.label(t),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

/// The workout of the watch the session is linked to, with its heart rate,
/// and the link to take back or make.
class _Link extends StatelessWidget {
  const _Link({required this.c, required this.sessionId, required this.linked});

  final MonoCtx c;
  final String sessionId;
  final bool linked;

  Future<void> _choose(BuildContext context) async {
    final l10n = c.l10n;
    final training = c.scope.training;
    final session = training.data.sessions.firstWhere((s) => s.id == sessionId);
    final taken = {
      for (final s in training.data.sessions)
        if (s.id != sessionId) ?s.linkedWorkout,
    };
    final day = DateTime(
      session.start.year,
      session.start.month,
      session.start.day,
    );
    final candidates = [
      for (final w in c.health.workouts)
        if (!taken.contains(w.key) &&
            !w.start.isBefore(day) &&
            w.start.isBefore(day.add(const Duration(days: 1))))
          w,
    ];
    await showMonoSheet<void>(
      context,
      title: l10n.trainingLinkTitle,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in candidates)
            MonoChoiceRow(
              icon: Icons.watch_rounded,
              label: c.formats.duration(w.minutes),
              subtitle: l10n.trainingFoundAt(
                c.formats.relativeDay(w.start, c.today),
                formatClock(w.start.hour * 60 + w.start.minute),
                formatClock(w.end.hour * 60 + w.end.minute),
              ),
              chosen: session.linkedWorkout == w.key,
              onTap: () {
                training.setLink(sessionId, w.key);
                Navigator.of(sheet).pop();
              },
            ),
          if (candidates.isEmpty)
            Text(l10n.trainingNoWorkoutThatDay, style: MonoType.sub(c.t)),
          if (session.linkedWorkout != null) ...[
            const SizedBox(height: 10),
            MonoPrimaryButton(
              label: l10n.trainingUnlink,
              tonal: true,
              onTap: () {
                training.setLink(sessionId, null);
                Navigator.of(sheet).pop();
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final session = c.scope.training.data.sessions.firstWhere(
      (s) => s.id == sessionId,
    );
    final workout = linkedWorkoutOf(session, c.health.workouts);
    return MonoSurface(
      onTap: workout == null ? () => _choose(context) : null,
      child: Row(
        children: [
          Icon(Icons.watch_rounded, size: 20, color: c.t.ink),
          const SizedBox(width: 12),
          Expanded(
            child: workout == null
                ? Text(l10n.trainingNotLinked, style: MonoType.sub(c.t))
                : MonoPress(
                    onTap: () => c.push(MonoWorkoutPage(workout: workout)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trainingLinked,
                          style: MonoType.inter(
                            16,
                            21,
                            FontWeight.w600,
                            c.t.ink,
                          ),
                        ),
                        Text(
                          [
                            if (workout.avgBpm != null)
                              l10n.searchAvgHeart('${workout.avgBpm}'),
                            if (workout.maxBpm != null) 'max ${workout.maxBpm}',
                            if (workout.kcal != null) '${workout.kcal} kcal',
                          ].join(' · '),
                          style: MonoType.label(c.t),
                        ),
                      ],
                    ),
                  ),
          ),
          Semantics(
            button: true,
            label: l10n.trainingLinkTitle,
            child: ExcludeSemantics(
              child: MonoPress(
                onTap: () {
                  Haptics.tap();
                  _choose(context);
                },
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.link_rounded, color: c.t.ink2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
