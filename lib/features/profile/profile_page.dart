import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_controller.dart';
import '../../data/models.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';
import 'birth_date_sheet.dart';
import 'language_sheet.dart';

/// Goals, appearance and background refresh.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
  static const _sexes = [Sex.female, Sex.male];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
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
        listenable: Listenable.merge([
          health,
          settings,
          scope.language,
          scope.systemPalette,
        ]),
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
                l10n.profile,
                textAlign: TextAlign.center,
                style: context.emphasizedTextTheme.headlineLarge,
              ),
              SectionTitle(l10n.aboutYou),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => showBirthDateSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.birthDate,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          switch (settings.birthDate) {
                            final date? => formats.birthDate(date),
                            null => l10n.notGiven,
                          },
                          style: context.emphasizedTextTheme.titleMedium
                              ?.copyWith(color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: M3EToggleButtonGroup(
                  type: M3EButtonGroupType.connected,
                  style: M3EButtonStyle.tonal,
                  size: M3EButtonSize.md,
                  haptic: M3EHapticFeedback.light,
                  selectedIndex: switch (settings.sex) {
                    final sex? => _sexes.indexOf(sex),
                    null => null,
                  },
                  onSelectedIndexChanged: (index) =>
                      settings.setSex(index == null ? null : _sexes[index]),
                  actions: [
                    M3EToggleButtonGroupAction(label: Text(l10n.female)),
                    M3EToggleButtonGroupAction(label: Text(l10n.male)),
                  ],
                ),
              ),
              SectionTitle(l10n.goals),
              SurfaceCard(
                child: Column(
                  children: [
                    _GoalSlider(
                      label: l10n.metricSteps,
                      display: formats.integer(settings.stepGoal),
                      value: settings.stepGoal.toDouble(),
                      min: 4000,
                      max: 20000,
                      divisions: 16,
                      onChanged: (v) => settings.setStepGoal(v.round()),
                    ),
                    const SizedBox(height: 20),
                    _GoalSlider(
                      label: l10n.groupSleep,
                      display: '${formats.decimal(settings.sleepGoalHours)} h',
                      value: settings.sleepGoalHours,
                      min: 5,
                      max: 10,
                      divisions: 10,
                      onChanged: settings.setSleepGoalHours,
                    ),
                    const SizedBox(height: 20),
                    _GoalSlider(
                      label: l10n.metricWater,
                      display:
                          '${formats.decimal(settings.waterGoalMl / 1000)} l',
                      value: settings.waterGoalMl.toDouble(),
                      min: 1000,
                      max: 4000,
                      divisions: 15,
                      onChanged: (v) => settings.setWaterGoalMl(v.round()),
                    ),
                    const SizedBox(height: 20),
                    _GoalSlider(
                      label: l10n.metricActiveEnergy,
                      display:
                          '${formats.integer(settings.activeEnergyGoal)} kcal',
                      value: settings.activeEnergyGoal.toDouble(),
                      min: 200,
                      max: 1500,
                      divisions: 26,
                      onChanged: (v) => settings.setActiveEnergyGoal(v.round()),
                    ),
                  ],
                ),
              ),
              SectionTitle(l10n.appearance),
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
                  actions: [
                    M3EToggleButtonGroupAction(label: Text(l10n.themeSystem)),
                    M3EToggleButtonGroupAction(label: Text(l10n.themeLight)),
                    M3EToggleButtonGroupAction(label: Text(l10n.themeDark)),
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
                          l10n.wallpaperColors,
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
              const SizedBox(height: 12),
              SurfaceCard(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Liquid Glass',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Switch(
                      value: settings.liquidGlass,
                      onChanged: (value) {
                        Haptics.selection();
                        settings.setLiquidGlass(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => showLanguageSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.language,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          switch (scope.language.choice) {
                            final code? => languageName(code),
                            null => l10n.languageSystem,
                          },
                          style: context.emphasizedTextTheme.titleMedium
                              ?.copyWith(color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (ready) ...[
                SectionTitle(l10n.data),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.lastUpdated,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (loadedAt != null)
                        Text(
                          l10n.dateAtTime(
                            formats.shortDate(loadedAt),
                            formatClock(loadedAt.hour * 60 + loadedAt.minute),
                          ),
                          style: muted,
                        ),
                      if (backfill != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.loadingOlderData,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          l10n.reachedSoFar(
                            '${formats.shortDate(backfill)} ${backfill.year}',
                          ),
                          style: muted,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        health.backgroundAccess
                            ? l10n.backgroundOn
                            : l10n.backgroundOff,
                        style: muted,
                      ),
                      if (!health.backgroundAccess) ...[
                        const SizedBox(height: 12),
                        M3EFilledButton.tonal(
                          onPressed: health.requestBackgroundAccess,
                          child: Text(l10n.refreshInBackground),
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
