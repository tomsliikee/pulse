import 'package:material_ui/material_ui.dart';

import '../../../../app/haptics.dart';
import '../../../../data/training/exercise_library.dart';
import '../../../../data/training/training_insights.dart';
import '../../../../data/training/training_models.dart';
import '../../../../data/training/training_splits.dart';
import '../../data/mono_data.dart';
import '../../theme/mono_type.dart';
import '../../widgets/mono_blocks.dart';
import '../../widgets/mono_card.dart';
import '../../widgets/mono_category.dart';
import '../../widgets/mono_page.dart';
import '../../widgets/mono_sheet.dart';
import 'exercise_picker.dart';
import 'training_text.dart';

/// The templates in the order they come round, the weekly goal, and the
/// way to make, change or remove a template.
class MonoTemplatesPage extends StatelessWidget {
  const MonoTemplatesPage({super.key});

  static Map<String, String> starterNames(MonoCtx c) =>
      splitTemplateNames(c.l10n);

  Future<void> _new(BuildContext context, MonoCtx c) async {
    final name = TextEditingController();
    final ok = await showMonoSheet<bool>(
      context,
      title: c.l10n.trainingNewTemplate,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoField(
            controller: name,
            label: c.l10n.trainingName,
            hint: c.l10n.trainingTemplateHint,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          MonoPrimaryButton(
            label: c.l10n.save,
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ],
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true || text.isEmpty) return;
    final training = c.scope.training;
    final template = await training.saveTemplate(training.newTemplate(text));
    if (context.mounted) {
      await c.push(MonoTemplatePage(templateId: template.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: scope.training,
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final t = c.t;
        final l10n = c.l10n;
        final training = c.scope.training;
        final data = training.data;
        final order = [
          for (final id in data.rotation) ?data.template(id),
          for (final tpl in data.templates)
            if (!data.rotation.contains(tpl.id)) tpl,
        ];
        final next = nextTemplate(data);
        return MonoSubPage(
          category: MonoCategory.workouts,
          icon: Icons.list_alt_rounded,
          categoryLabel: l10n.trainingTemplates,
          backLabel: l10n.navTraining,
          statement: l10n.trainingTemplatesStatement,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoSection(l10n.trainingSplit),
                const SizedBox(height: 6),
                Text(l10n.trainingSplitHint, style: MonoType.label(t)),
                const SizedBox(height: 14),
                _SplitChoices(c: c, chosen: data.split),
              ],
            ),
            MonoSurface(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.trainingWeeklyGoal,
                          style: MonoType.inter(16, 22, FontWeight.w600, t.ink),
                        ),
                        Text(
                          l10n.trainingPerWeek(data.weeklyGoal),
                          style: MonoType.label(t),
                        ),
                      ],
                    ),
                  ),
                  MonoIconButton(
                    icon: Icons.remove_rounded,
                    label: l10n.trainingLess,
                    onTap: data.weeklyGoal > 1
                        ? () {
                            Haptics.selection();
                            training.setWeeklyGoal(data.weeklyGoal - 1);
                          }
                        : null,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${data.weeklyGoal}',
                      textAlign: TextAlign.center,
                      style: MonoType.inter(20, 24, FontWeight.w600, t.ink),
                    ),
                  ),
                  MonoIconButton(
                    icon: Icons.add_rounded,
                    label: l10n.trainingMoreGoal,
                    onTap: data.weeklyGoal < 14
                        ? () {
                            Haptics.selection();
                            training.setWeeklyGoal(data.weeklyGoal + 1);
                          }
                        : null,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoSection(l10n.trainingRotation),
                const SizedBox(height: 6),
                Text(l10n.trainingRotationHint, style: MonoType.label(t)),
                const SizedBox(height: 14),
                if (order.isEmpty)
                  MonoSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.trainingNoTemplates, style: MonoType.sub(t)),
                        const SizedBox(height: 14),
                        MonoPrimaryButton(
                          label: l10n.trainingChooseSplit,
                          onTap: () => showSplitSheet(context),
                        ),
                      ],
                    ),
                  )
                else
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    onReorderStart: (_) => Haptics.lift(),
                    onReorderItem: (from, to) {
                      final ids = [for (final o in order) o.id];
                      final id = ids.removeAt(from);
                      ids.insert(to, id);
                      Haptics.selection();
                      training.setRotation(ids);
                    },
                    children: [
                      for (var i = 0; i < order.length; i++)
                        Padding(
                          key: ValueKey(order[i].id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MonoSurface(
                            padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
                            onTap: () => c.push(
                              MonoTemplatePage(templateId: order[i].id),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order[i].name,
                                        style: MonoType.inter(
                                          16,
                                          22,
                                          FontWeight.w600,
                                          t.ink,
                                        ),
                                      ),
                                      Text(
                                        [
                                          if (order[i].id == next?.id)
                                            l10n.trainingNext,
                                          l10n.trainingTemplateSummary(
                                            order[i].exercises.length,
                                            order[i].setCount,
                                            order[i].minutes,
                                          ),
                                        ].join(' · '),
                                        style: MonoType.label(t),
                                      ),
                                    ],
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: Semantics(
                                    label: l10n.monoMoveCard,
                                    child: SizedBox(
                                      width: 48,
                                      height: 52,
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: t.ink2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            MonoPrimaryButton(
              label: l10n.trainingNewTemplate,
              icon: Icons.add_rounded,
              tonal: true,
              onTap: () => _new(context, c),
            ),
          ],
        );
      },
    );
  }
}

/// The splits to choose from; the one chosen carries a check. Choosing
/// one makes its templates the rotation.
class _SplitChoices extends StatelessWidget {
  const _SplitChoices({required this.c, required this.chosen, this.onDone});

  final MonoCtx c;
  final String? chosen;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final split in TrainingSplit.values)
          MonoChoiceRow(
            label: splitText(c.l10n, split).$1,
            subtitle: splitText(c.l10n, split).$2,
            chosen: split.name == chosen,
            onTap: () async {
              await c.scope.training.applySplit(
                split,
                splitTemplateNames(c.l10n),
              );
              Haptics.confirm();
              onDone?.call();
            },
          ),
      ],
    );
  }
}

/// Lets the splits be chosen from a sheet, as from an empty Training tab.
Future<void> showSplitSheet(BuildContext context) {
  final c = MonoCtx.of(context);
  return showMonoSheet<void>(
    context,
    title: c.l10n.trainingChooseSplit,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(c.l10n.trainingSplitHint, style: MonoType.label(c.t)),
        const SizedBox(height: 14),
        _SplitChoices(
          c: c,
          chosen: c.scope.training.data.split,
          onDone: () => Navigator.of(sheet).pop(),
        ),
      ],
    ),
  );
}

/// One template: its name and its exercises with sets, reps and rest.
class MonoTemplatePage extends StatelessWidget {
  const MonoTemplatePage({super.key, required this.templateId});

  final String templateId;

  Future<void> _rename(
    BuildContext context,
    MonoCtx c,
    TrainingTemplate tpl,
  ) async {
    final name = TextEditingController(text: tpl.name);
    final ok = await showMonoSheet<bool>(
      context,
      title: c.l10n.trainingRename,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoField(controller: name, autofocus: true),
          const SizedBox(height: 16),
          MonoPrimaryButton(
            label: c.l10n.save,
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ],
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok == true && text.isNotEmpty) {
      await c.scope.training.saveTemplate(tpl.copyWith(name: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: scope.training,
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final t = c.t;
        final l10n = c.l10n;
        final training = c.scope.training;
        final tpl = training.data.template(templateId);
        if (tpl == null) {
          return MonoSubPage(
            category: MonoCategory.workouts,
            categoryLabel: l10n.trainingTemplates,
            backLabel: l10n.back,
            statement: l10n.trainingGone,
            children: const [],
          );
        }
        void put(List<TemplateExercise> list) =>
            training.saveTemplate(tpl.copyWith(exercises: list));
        return MonoSubPage(
          category: MonoCategory.workouts,
          icon: Icons.list_alt_rounded,
          categoryLabel: tpl.name,
          backLabel: l10n.trainingTemplates,
          statement: l10n.trainingTemplateSummary(
            tpl.exercises.length,
            tpl.setCount,
            tpl.minutes,
          ),
          trailing: MonoIconButton(
            icon: Icons.edit_rounded,
            label: l10n.trainingRename,
            onTap: () => _rename(context, c, tpl),
          ),
          children: [
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              onReorderStart: (_) => Haptics.lift(),
              onReorderItem: (from, to) {
                final list = [...tpl.exercises];
                final e = list.removeAt(from);
                list.insert(to.clamp(0, list.length), e);
                Haptics.selection();
                put(list);
              },
              children: [
                for (final (i, e) in tpl.exercises.indexed)
                  Padding(
                    key: ObjectKey(e),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MonoSurface(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  exerciseById(
                                        e.exerciseId,
                                        training.data.customExercises,
                                      )?.name(l10n.localeName) ??
                                      e.exerciseId,
                                  style: MonoType.inter(
                                    16,
                                    22,
                                    FontWeight.w600,
                                    t.ink,
                                  ),
                                ),
                              ),
                              MonoIconButton(
                                icon: Icons.delete_outline_rounded,
                                label: l10n.trainingRemoveExercise,
                                onTap: () =>
                                    put([...tpl.exercises]..removeAt(i)),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: Semantics(
                                  label: l10n.monoMoveCard,
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: t.ink2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _Stepper(
                            label: l10n.trainingSetsLabel,
                            value: '${e.sets}',
                            onLess: e.sets > 1
                                ? () => put(_with(tpl, i, sets: e.sets - 1))
                                : null,
                            onMore: () => put(_with(tpl, i, sets: e.sets + 1)),
                          ),
                          _Stepper(
                            label: l10n.trainingReps,
                            value: '${e.reps}',
                            onLess: e.reps > 1
                                ? () => put(_with(tpl, i, reps: e.reps - 1))
                                : null,
                            onMore: () => put(_with(tpl, i, reps: e.reps + 1)),
                          ),
                          _Stepper(
                            label: l10n.trainingRestTime,
                            value: clockText(Duration(seconds: e.restSeconds)),
                            onLess: e.restSeconds > 15
                                ? () => put(
                                    _with(tpl, i, rest: e.restSeconds - 15),
                                  )
                                : null,
                            onMore: () =>
                                put(_with(tpl, i, rest: e.restSeconds + 15)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            MonoPrimaryButton(
              label: l10n.trainingAddExercise,
              icon: Icons.add_rounded,
              tonal: true,
              onTap: () async {
                final id = await pickExercise(context);
                if (id == null) return;
                final now = training.data.template(templateId);
                if (now == null) return;
                await training.saveTemplate(
                  now.copyWith(
                    exercises: [
                      ...now.exercises,
                      TemplateExercise(exerciseId: id),
                    ],
                  ),
                );
              },
            ),
            MonoPrimaryButton(
              label: l10n.trainingDuplicate,
              icon: Icons.copy_rounded,
              tonal: true,
              onTap: () async {
                final copy = await training.duplicateTemplate(
                  templateId,
                  l10n.trainingCopyName(tpl.name),
                );
                Haptics.confirm();
                if (copy != null && context.mounted) {
                  await Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => MonoTemplatePage(templateId: copy.id),
                    ),
                  );
                }
              },
            ),
            MonoPrimaryButton(
              label: l10n.trainingDeleteTemplate,
              danger: true,
              onTap: () {
                training.removeTemplate(templateId);
                Navigator.of(context).maybePop();
              },
            ),
          ],
        );
      },
    );
  }

  static List<TemplateExercise> _with(
    TrainingTemplate tpl,
    int index, {
    int? sets,
    int? reps,
    int? rest,
  }) {
    final list = [...tpl.exercises];
    final e = list[index];
    list[index] = TemplateExercise(
      exerciseId: e.exerciseId,
      sets: sets ?? e.sets,
      reps: reps ?? e.reps,
      restSeconds: rest ?? e.restSeconds,
    );
    return list;
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onLess,
    required this.onMore,
  });

  final String label;
  final String value;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = MonoCtx.of(context);
    final t = c.t;
    return Row(
      children: [
        Expanded(child: Text(label, style: MonoType.label(t))),
        MonoIconButton(
          icon: Icons.remove_rounded,
          label: '${c.l10n.trainingLess}: $label',
          onTap: onLess == null
              ? null
              : () {
                  Haptics.selection();
                  onLess!();
                },
        ),
        SizedBox(
          width: 56,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: MonoType.inter(16, 22, FontWeight.w600, t.ink),
          ),
        ),
        MonoIconButton(
          icon: Icons.add_rounded,
          label: '${c.l10n.trainingMoreGoal}: $label',
          onTap: onMore == null
              ? null
              : () {
                  Haptics.selection();
                  onMore!();
                },
        ),
      ],
    );
  }
}
