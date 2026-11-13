import 'package:material_ui/material_ui.dart';

import '../../../../data/training/exercise_library.dart';
import '../../../../data/training/training_insights.dart';
import '../../data/mono_data.dart';
import '../../theme/mono_type.dart';
import '../../widgets/mono_blocks.dart';
import '../../widgets/mono_card.dart';
import '../../widgets/mono_category.dart';
import '../../widgets/mono_charts.dart';
import '../../widgets/mono_page.dart';
import 'session_page.dart';
import 'training_text.dart';

/// One exercise: its best estimated maximum as the statement, how that
/// went over the sessions, its records and every time it was done.
class MonoExercisePage extends StatelessWidget {
  const MonoExercisePage({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: scope.training,
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final t = c.t;
        final l10n = c.l10n;
        final data = c.scope.training.data;
        final exercise = exerciseById(exerciseId, data.customExercises);
        final name = exercise?.name(l10n.localeName) ?? exerciseId;
        final sessions = [
          for (final s in data.sessions)
            if (s.exercises.any((e) => e.exerciseId == exerciseId)) s,
        ];
        final best = bestOf(exerciseId, sessions);
        final history = oneRepMaxHistory(exerciseId, sessions);
        final muscles = [
          for (final m in exercise?.primary ?? const []) muscleLabel(l10n, m),
        ];
        final helpers = [
          for (final m in exercise?.secondary ?? const []) muscleLabel(l10n, m),
        ];
        return MonoSubPage(
          category: MonoCategory.workouts,
          categoryLabel: name,
          backLabel: l10n.back,
          statement: best.oneRepMax == null
              ? l10n.trainingNoHistory
              : l10n.trainingBestEstimate(kgText(c.formats, best.oneRepMax!)),
          children: [
            MonoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoGrid(
                    cells: [
                      MonoStat(
                        label: l10n.trainingOneRepMax,
                        value: best.oneRepMax == null
                            ? '–'
                            : kgText(c.formats, best.oneRepMax!),
                        unit: 'kg',
                        small: true,
                      ),
                      MonoStat(
                        label: l10n.trainingHeaviest,
                        value: best.heaviest == null
                            ? '–'
                            : kgText(c.formats, best.heaviest!),
                        unit: 'kg',
                        small: true,
                      ),
                      MonoStat(
                        label: l10n.trainingVolumeBest,
                        value: best.volume == null
                            ? '–'
                            : c.formats.integer(best.volume!.round()),
                        unit: 'kg',
                        small: true,
                      ),
                      MonoStat(
                        label: l10n.trainingTimes,
                        value: c.formats.integer(sessions.length),
                        small: true,
                      ),
                    ],
                  ),
                  if (history.length >= 2) ...[
                    const SizedBox(height: 22),
                    MonoLine(
                      values: [for (final (_, v) in history) v],
                      color: t.recovery,
                      height: 96,
                      semantics: l10n.trainingOneRepMax,
                    ),
                    const SizedBox(height: 8),
                    MonoAxis([
                      c.formats.shortDate(history.first.$1),
                      c.formats.shortDate(history.last.$1),
                    ]),
                  ],
                ],
              ),
            ),
            if (muscles.isNotEmpty)
              MonoSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonoPair(
                      label: l10n.trainingMainMuscles,
                      value: muscles.join(', '),
                    ),
                    if (helpers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      MonoPair(
                        label: l10n.trainingHelperMuscles,
                        value: helpers.join(', '),
                      ),
                    ],
                    if (exercise != null) ...[
                      const SizedBox(height: 12),
                      MonoPair(
                        label: l10n.trainingEquipment,
                        value: equipmentLabel(l10n, exercise.equipment),
                      ),
                    ],
                  ],
                ),
              ),
            if (sessions.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonoSection(l10n.trainingHistory),
                  const SizedBox(height: 14),
                  MonoSurface(
                    child: Column(
                      children: [
                        for (final s in sessions.reversed.take(20))
                          MonoRow(
                            title: c.formats.relativeDay(s.start, c.today),
                            subtitle: [
                              for (final e in s.exercises)
                                if (e.exerciseId == exerciseId)
                                  for (final set in e.sets)
                                    if (set.done) setText(c.formats, set),
                            ].join(' · '),
                            onTap: () =>
                                c.push(MonoSessionPage(sessionId: s.id)),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Text(l10n.trainingNoHistoryHint, style: MonoType.sub(t)),
          ],
        );
      },
    );
  }
}
