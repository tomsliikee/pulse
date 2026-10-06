import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_controller.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';

/// Goals, appearance and background refresh.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([health, settings, scope.systemPalette]),
        builder: (context, _) {
          final ready = health.status == HealthStatus.ready;
          final loadedAt = ready ? health.snapshot.loadedAt : null;
          final backfill = health.backfillReached;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Center(
                child: M3EContainer(
                  Shapes.c7SidedCookie,
                  width: 132,
                  height: 132,
                  color: scheme.tertiary,
                  child: Icon(
                    Icons.person_rounded,
                    size: 64,
                    color: scheme.onTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profil',
                textAlign: TextAlign.center,
                style: context.emphasizedTextTheme.headlineLarge,
              ),
              const SectionTitle('Ziele'),
              SurfaceCard(
                child: Column(
                  children: [
                    _GoalSlider(
                      label: 'Schritte',
                      display: formatInt(settings.stepGoal),
                      value: settings.stepGoal.toDouble(),
                      min: 4000,
                      max: 20000,
                      divisions: 16,
                      onChanged: (v) => settings.setStepGoal(v.round()),
                    ),
                    const SizedBox(height: 20),
                    _GoalSlider(
                      label: 'Schlaf',
                      display: '${formatDecimal(settings.sleepGoalHours)} h',
                      value: settings.sleepGoalHours,
                      min: 5,
                      max: 10,
                      divisions: 10,
                      onChanged: settings.setSleepGoalHours,
                    ),
                    const SizedBox(height: 20),
                    _GoalSlider(
                      label: 'Wasser',
                      display:
                          '${formatDecimal(settings.waterGoalMl / 1000)} l',
                      value: settings.waterGoalMl.toDouble(),
                      min: 1000,
                      max: 4000,
                      divisions: 15,
                      onChanged: (v) => settings.setWaterGoalMl(v.round()),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Darstellung'),
              Align(
                alignment: Alignment.centerLeft,
                child: M3EToggleButtonGroup(
                  type: M3EButtonGroupType.connected,
                  style: M3EButtonStyle.tonal,
                  size: M3EButtonSize.md,
                  haptic: M3EHapticFeedback.light,
                  selectedIndex: _modes.indexOf(settings.themeMode),
                  onSelectedIndexChanged: (index) {
                    if (index != null) settings.setThemeMode(_modes[index]);
                  },
                  actions: const [
                    M3EToggleButtonGroupAction(label: Text('System')),
                    M3EToggleButtonGroupAction(label: Text('Hell')),
                    M3EToggleButtonGroupAction(label: Text('Dunkel')),
                  ],
                ),
              ),
              // Only offered where the system has a wallpaper palette.
              if (scope.systemPalette.value != null) ...[
                const SizedBox(height: 12),
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Farben vom Hintergrundbild',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: settings.dynamicColor,
                        onChanged: (value) {
                          Haptics.selection();
                          settings.setDynamicColor(value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (ready) ...[
                const SectionTitle('Daten'),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zuletzt aktualisiert',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (loadedAt != null)
                        Text(
                          '${formatShortDate(loadedAt)} um '
                          '${formatClock(loadedAt.hour * 60 + loadedAt.minute)}',
                          style: muted,
                        ),
                      if (backfill != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Ältere Daten werden geladen',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Bisher bis ${formatShortDate(backfill)} '
                          '${backfill.year}',
                          style: muted,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        health.backgroundAccess
                            ? 'Pulse aktualisiert die Daten etwa stündlich '
                                  'im Hintergrund.'
                            : 'Ohne Hintergrundzugriff werden die Daten nur '
                                  'beim Öffnen der App aktualisiert.',
                        style: muted,
                      ),
                      if (!health.backgroundAccess) ...[
                        const SizedBox(height: 12),
                        M3EFilledButton.tonal(
                          onPressed: health.requestBackgroundAccess,
                          child: const Text('Im Hintergrund aktualisieren'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GoalSlider extends StatelessWidget {
  const _GoalSlider({
    required this.label,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String display;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
            Text(
              display,
              style: context.emphasizedTextTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        M3ESlider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: (next) {
            if (next != value) Haptics.selection();
            onChanged(next);
          },
        ),
      ],
    );
  }
}
