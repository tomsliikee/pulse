import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_controller.dart';
import '../../data/models.dart';
import '../../widgets/entrance.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';
import '../goals/goal_format.dart';
import '../goals/goals_page.dart';
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

    return ListenableBuilder(
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
        return SubPage(
          title: l10n.profile,
          glass: settings.liquidGlass,
          largeTitle: Column(
            children: [
              M3EContainer(
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
              const SizedBox(height: 16),
              Text(
                l10n.profile,
                textAlign: TextAlign.center,
                style: context.emphasizedTextTheme.headlineLarge,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // The sections come in one after the other.
            children: staggered([
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
              M3ESegmentedColumn(
                color: scheme.surfaceBright,
                haptic: M3EHapticFeedback.light,
                onTap: (_) => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GoalsPage()),
                ),
                children: [
                  M3EListItem(
                    headline: Text(l10n.goalsOpen),
                    supportingText: Text(
                      [for (final goal in settings.goals) goal.label(l10n)]
                          .join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
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
            ]),
          ),
        );
      },
    );
  }
}
