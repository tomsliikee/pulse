import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../data/backup.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/morning_notices.dart';
import '../../data/health_controller.dart';
import '../../data/models.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/entrance.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';
import '../goals/goal_format.dart';
import '../goals/goals_page.dart';
import 'birth_date_sheet.dart';
import 'height_sheet.dart';
import 'language_sheet.dart';
import 'name_sheet.dart';
import 'place_sheet.dart';

/// Goals, appearance and background refresh.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
  static const _sexes = [Sex.female, Sex.male];

  static Future<void> _saveBackup(BuildContext context) async {
    final AppScope(:health, :files) = AppScope.of(context);
    final l10n = Formats.of(context).l10n;
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    Haptics.tap();
    try {
      final saved = await files.save(
        backupFileName(health.now),
        await health.backup(),
      );
      if (saved) say(l10n.backupSaved);
    } on Exception catch (error) {
      debugPrint('Saving the backup failed: $error');
      say(l10n.backupSaveFailed);
    }
  }

  static Future<void> _openBackup(BuildContext context) async {
    final AppScope(:health, :settings, :files) = AppScope.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    Haptics.tap();
    try {
      final text = await files.open();
      if (text == null) return;
      final result = await health.restore(text);
      if (result.settings) await settings.load();
      final (:days, :nights, :workouts, settings: _) = result;
      say(
        days + nights + workouts == 0
            ? l10n.backupNothingNew
            : l10n.backupRestored(
                formats.integer(days),
                formats.integer(nights),
                formats.integer(workouts),
              ),
      );
    } on FormatException {
      say(l10n.backupInvalid);
    } on Exception catch (error) {
      debugPrint('Reading the backup failed: $error');
      say(l10n.backupOpenFailed);
    }
  }

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
        final sync = ready ? health.backgroundSync : null;
        return SubPage(
          title: l10n.profile,
          glass: settings.liquidGlass,
          // Room for a snackbar below the last card, so it does not lie on
          // the buttons that raised it.
          bottomPadding: 96 + MediaQuery.paddingOf(context).bottom,
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
              SegmentGroup(
                padding: EdgeInsets.zero,
                children: [
                  for (final (label, value, open) in [
                    (
                      l10n.nameLabel,
                      settings.name ?? l10n.notGiven,
                      showNameSheet,
                    ),
                    (
                      l10n.birthDate,
                      switch (settings.birthDate) {
                        final date? => formats.birthDate(date),
                        null => l10n.notGiven,
                      },
                      showBirthDateSheet,
                    ),
                    (
                      l10n.heightLabel,
                      switch (settings.heightCm) {
                        final height? => '$height cm',
                        null => l10n.notGiven,
                      },
                      showHeightSheet,
                    ),
                    (
                      l10n.placeLabel,
                      settings.place?.name ?? l10n.notGiven,
                      showPlaceSheet,
                    ),
                  ])
                    InkWell(
                      onTap: () => open(context),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // A long name or place gives way to its label.
                            Flexible(
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.emphasizedTextTheme.titleMedium
                                    ?.copyWith(color: scheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
              SectionTitle(l10n.morningTitle),
              SegmentGroup(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.morningSwitchNote,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: settings.morningBrief,
                          onChanged: (value) {
                            Haptics.selection();
                            settings.setMorningBrief(value);
                            // The notification needs the system's consent.
                            if (value) MorningNotices.allow();
                          },
                        ),
                      ],
                    ),
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
              const SizedBox(height: 12),
              // The switches and the language as one group of segments.
              SegmentGroup(
                padding: EdgeInsets.zero,
                children: [
                  for (final (label, value, set) in [
                    // Only offered where the system has a wallpaper palette.
                    if (scope.systemPalette.value != null)
                      (
                        l10n.wallpaperColors,
                        settings.dynamicColor,
                        settings.setDynamicColor,
                      ),
                    (
                      'Liquid Glass',
                      settings.liquidGlass,
                      settings.setLiquidGlass,
                    ),
                    (
                      l10n.edgeHero,
                      settings.edgeToEdgeHero,
                      settings.setEdgeToEdgeHero,
                    ),
                    (l10n.flexFont, settings.flexFont, settings.setFlexFont),
                  ])
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Switch(
                            value: value,
                            onChanged: (value) {
                              Haptics.selection();
                              set(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  InkWell(
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
                ],
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
                      if (sync != null)
                        Text(
                          (sync.error == null
                              ? l10n.backgroundLast
                              : l10n.backgroundFailed)(
                            l10n.dateAtTime(
                              formats.shortDate(sync.at),
                              formatClock(sync.at.hour * 60 + sync.at.minute),
                            ),
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
                SectionTitle(l10n.backup),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.backupAbout, style: muted),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          M3EFilledButton.tonal(
                            onPressed: () => _saveBackup(context),
                            child: Text(l10n.backupSave),
                          ),
                          M3EFilledButton.tonal(
                            onPressed: () => _openBackup(context),
                            child: Text(l10n.backupOpen),
                          ),
                        ],
                      ),
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
