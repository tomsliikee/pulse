import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../data/step_counting.dart';
import '../../l10n/generated/app_localizations.dart';

extension StepCountingText on StepCounting {
  String label(AppLocalizations l10n) => switch (this) {
    StepCounting.store => l10n.stepsStore,
    StepCounting.dayMean => l10n.stepsDayMean,
    StepCounting.hourMean => l10n.stepsHourMean,
    StepCounting.wearable => l10n.stepsWearable,
  };

  String note(AppLocalizations l10n) => switch (this) {
    StepCounting.store => l10n.stepsStoreNote,
    StepCounting.dayMean => l10n.stepsDayMeanNote,
    StepCounting.hourMean => l10n.stepsHourMeanNote,
    StepCounting.wearable => l10n.stepsWearableNote,
  };
}

/// Lets the user pick how steps are counted where a watch and the phone
/// both wrote them.
Future<void> showStepCountingSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      // Four rows with their notes are taller than half the screen.
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StepCountingSheet(),
    );

class _StepCountingSheet extends StatelessWidget {
  const _StepCountingSheet();

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.stepCounting,
                  style: context.emphasizedTextTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                M3ESegmentedColumn(
                  color: scheme.surfaceBright,
                  haptic: M3EHapticFeedback.light,
                  onTap: (i) =>
                      settings.setStepCounting(StepCounting.values[i]),
                  children: [
                    for (final way in StepCounting.values)
                      M3EListItem(
                        headline: Text(way.label(l10n)),
                        // The item gives its second line one row; the notes need more.
                        supportingText: Text(
                          way.note(l10n),
                          maxLines: 4,
                          overflow: TextOverflow.visible,
                        ),
                        trailing: way == settings.stepCounting
                            ? Icon(Icons.check_rounded, color: scheme.primary)
                            : null,
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
                  child: Text(
                    l10n.stepCountingNote,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
