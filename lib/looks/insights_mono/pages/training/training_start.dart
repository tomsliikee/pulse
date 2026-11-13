import 'package:material_ui/material_ui.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/formatters.dart';
import '../../../../data/models.dart';
import '../../../../data/training/session_link.dart';
import '../../../../data/training/training_controller.dart';
import '../../../../data/training/training_insights.dart';
import '../../../../data/training/training_models.dart';
import '../../widgets/mono_sheet.dart';
import 'live_page.dart';
import 'session_page.dart';

/// Asks what to train: the template that is next, another one, an empty
/// training, or the sets of a training a watch recorded without them. With
/// a training running, it leads back to that one.
Future<void> showTrainingStartSheet(BuildContext context) async {
  final scope = AppScope.of(context);
  final training = scope.training;
  final navigator = Navigator.of(context);
  if (training.active != null) {
    await navigator.push(MonoLiveRoute());
    return;
  }
  final formats = Formats.of(context);
  final l10n = formats.l10n;
  final data = training.data;
  final next = nextTemplate(data);
  final unmatched = unmatchedStrength(
    data.sessions,
    scope.health.workouts,
    since: DateTime(
      scope.health.today.year,
      scope.health.today.month,
      scope.health.today.day - 1,
    ),
  );
  final picked = await showMonoSheet<_Start>(
    context,
    title: l10n.trainingStartTitle,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null)
          MonoChoiceRow(
            icon: Icons.play_arrow_rounded,
            chosen: true,
            label: l10n.trainingToday(next.name),
            subtitle: l10n.trainingTemplateSummary(
              next.exercises.length,
              next.setCount,
              next.minutes,
            ),
            onTap: () => Navigator.of(sheet).pop(_Start(template: next)),
          ),
        for (final t in data.templates)
          if (t.id != next?.id)
            MonoChoiceRow(
              icon: Icons.list_alt_rounded,
              label: t.name,
              subtitle: l10n.trainingTemplateSummary(
                t.exercises.length,
                t.setCount,
                t.minutes,
              ),
              onTap: () => Navigator.of(sheet).pop(_Start(template: t)),
            ),
        MonoChoiceRow(
          icon: Icons.add_rounded,
          label: l10n.trainingEmpty,
          onTap: () => Navigator.of(sheet).pop(const _Start()),
        ),
        for (final w in unmatched.take(2))
          MonoChoiceRow(
            icon: Icons.watch_rounded,
            label: l10n.trainingLogAfter,
            subtitle: l10n.trainingFoundAt(
              formats.relativeDay(w.start, scope.health.today),
              formatClock(w.start.hour * 60 + w.start.minute),
              formatClock(w.end.hour * 60 + w.end.minute),
            ),
            onTap: () => Navigator.of(sheet).pop(_Start(workout: w)),
          ),
      ],
    ),
  );
  if (picked == null) return;
  if (picked.workout case final w?) {
    await logTrainingAfter(
      navigator,
      training: training,
      workout: w,
      name: l10n.trainingSession,
    );
    return;
  }
  await startTraining(
    navigator,
    training: training,
    template: picked.template,
    workout: picked.workout,
    name: l10n.trainingSession,
  );
}

/// Starts a training and opens its live screen. For [workout], the training
/// a watch recorded, the session takes its time and is linked to it.
Future<void> startTraining(
  NavigatorState navigator, {
  required TrainingController training,
  TrainingTemplate? template,
  Workout? workout,
  required String name,
}) async {
  await training.start(
    template: template,
    name: name,
    start: workout?.start,
    linked: workout?.key,
  );
  await navigator.push(MonoLiveRoute());
}

/// Puts in the training [workout] of the watch was, with the template
/// usually trained then and last time's weights, and opens it to correct.
/// No training is started.
Future<void> logTrainingAfter(
  NavigatorState navigator, {
  required TrainingController training,
  required Workout workout,
  required String name,
  TrainingTemplate? template,
}) async {
  final session = await training.logAfter(
    workout,
    template: template ?? usualTemplate(training.data, workout.start),
    name: name,
  );
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => MonoSessionPage(sessionId: session.id, edit: true),
    ),
  );
}

class _Start {
  const _Start({this.template, this.workout});

  final TrainingTemplate? template;
  final Workout? workout;
}
