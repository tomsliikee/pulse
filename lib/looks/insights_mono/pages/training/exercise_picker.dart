import 'package:material_ui/material_ui.dart';

import '../../../../app/haptics.dart';
import '../../../../data/training/exercise_library.dart';
import '../../../../data/training/training_models.dart';
import '../../data/mono_data.dart';
import '../../search/search_index.dart';
import '../../theme/mono_type.dart';
import '../../widgets/mono_card.dart';
import '../../widgets/mono_category.dart';
import '../../widgets/mono_page.dart';
import '../../widgets/mono_sheet.dart';
import 'live_page.dart' show MonoChip;
import 'training_text.dart';

/// Lets the user pick an exercise, from the library or their own, and make
/// a new one. Gives its id, or null.
Future<String?> pickExercise(BuildContext context) =>
    monoPush<String>(context, const _PickerPage());

class _PickerPage extends StatefulWidget {
  const _PickerPage();

  @override
  State<_PickerPage> createState() => _PickerPageState();
}

class _PickerPageState extends State<_PickerPage> {
  final TextEditingController _query = TextEditingController();
  Muscle? _muscle;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _create(MonoCtx c) async {
    final l10n = c.l10n;
    final name = TextEditingController(text: _query.text.trim());
    var muscle = _muscle ?? Muscle.chest;
    var equipment = Equipment.other;
    final made = await showMonoSheet<bool>(
      context,
      title: l10n.trainingOwnExercise,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonoField(
              controller: name,
              label: l10n.trainingName,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(l10n.trainingMuscle, style: MonoType.label(c.t)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in Muscle.values)
                  MonoChip(
                    label: muscleLabel(l10n, m),
                    chosen: muscle == m,
                    onTap: () => setSheet(() => muscle = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.trainingEquipment, style: MonoType.label(c.t)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in Equipment.values)
                  MonoChip(
                    label: equipmentLabel(l10n, e),
                    chosen: equipment == e,
                    onTap: () => setSheet(() => equipment = e),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            MonoPrimaryButton(
              label: l10n.save,
              onTap: () => Navigator.of(sheet).pop(true),
            ),
          ],
        ),
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (made != true || text.isEmpty || !mounted) return;
    final exercise = await c.scope.training.addExercise(
      name: text,
      primary: [muscle],
      equipment: equipment,
    );
    if (mounted) Navigator.of(context).pop(exercise.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = MonoCtx.of(context);
    final t = c.t;
    final l10n = c.l10n;
    final language = l10n.localeName;
    final all = [...c.scope.training.data.customExercises, ...exerciseLibrary];
    final q = normalizeSearch(_query.text);
    final shown = [
      for (final e in all)
        if ((_muscle == null ||
                e.primary.contains(_muscle) ||
                e.secondary.contains(_muscle)) &&
            (q.isEmpty ||
                e.names.values.any((n) => normalizeSearch(n).contains(q))))
          e,
    ]..sort((a, b) => a.name(language).compareTo(b.name(language)));
    final used = <String, int>{};
    for (final s in c.scope.training.data.sessions) {
      for (final e in s.exercises) {
        used[e.exerciseId] = (used[e.exerciseId] ?? 0) + 1;
      }
    }
    final often = [
      for (final e in shown)
        if ((used[e.id] ?? 0) > 0) e,
    ]..sort((a, b) => (used[b.id] ?? 0).compareTo(used[a.id] ?? 0));
    Widget row(Exercise e) => MonoRow(
      title: e.name(language),
      subtitle: [
        if (e.muscle case final m?) muscleLabel(l10n, m),
        equipmentLabel(l10n, e.equipment),
      ].join(' · '),
      onTap: () {
        Haptics.tap();
        Navigator.of(context).pop(e.id);
      },
    );
    return MonoSubPage(
      category: MonoCategory.workouts,
      categoryLabel: l10n.trainingAddExercise,
      backLabel: l10n.back,
      children: [
        MonoField(
          controller: _query,
          hint: l10n.monoSearch,
          onChanged: (_) => setState(() {}),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              MonoChip(
                label: l10n.trainingAllMuscles,
                chosen: _muscle == null,
                onTap: () => setState(() => _muscle = null),
              ),
              for (final m in Muscle.values) ...[
                const SizedBox(width: 8),
                MonoChip(
                  label: muscleLabel(l10n, m),
                  chosen: _muscle == m,
                  onTap: () => setState(() => _muscle = m),
                ),
              ],
            ],
          ),
        ),
        if (often.isNotEmpty && q.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MonoSection(l10n.trainingOften),
              const SizedBox(height: 14),
              MonoSurface(
                child: Column(
                  children: [for (final e in often.take(5)) row(e)],
                ),
              ),
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonoSection(l10n.trainingExercises),
            const SizedBox(height: 14),
            MonoSurface(
              child: Column(
                children: [
                  for (final e in shown) row(e),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l10n.searchNothing, style: MonoType.sub(t)),
                    ),
                ],
              ),
            ),
          ],
        ),
        MonoPrimaryButton(
          label: l10n.trainingOwnExercise,
          icon: Icons.add_rounded,
          tonal: true,
          onTap: () => _create(c),
        ),
      ],
    );
  }
}
