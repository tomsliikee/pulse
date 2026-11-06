import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../data/backup.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/morning_notices.dart';
import '../../data/health_controller.dart';
import '../../data/models.dart';
import '../../data/settings_controller.dart';
import '../../widgets/entrance.dart';
import '../../widgets/fold_section.dart';
import '../../widgets/look_toggle.dart';
import '../../widgets/sub_page.dart';
import '../goals/goal_format.dart';
import '../goals/goals_page.dart';
import '../intro/intro_page.dart';
import '../supplements/supplement_format.dart';
import '../supplements/supplements_page.dart';
import 'birth_date_sheet.dart';
import 'color_style_row.dart';
import 'height_sheet.dart';
import 'target_weight_sheet.dart';
import 'language_sheet.dart';
import '../../theme/pulse_look.dart';
import 'live_settings.dart';
import 'name_sheet.dart';
import 'place_sheet.dart';
import 'step_counting_sheet.dart';

/// The settings, in parts that fold open: you, goals and supplements, the
/// notifications, the values, the look, the numbers, the data and the app.
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
    final AppScope(:health, :settings, :files, :supplements) = AppScope.of(
      context,
    );
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
      await supplements.load();
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
    final mono = PulseLook.monoOf(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        health,
        settings,
        scope.language,
        scope.systemPalette,
        scope.supplements,
      ]),
      builder: (context, _) {
        final ready = health.status == HealthStatus.ready;
        final loadedAt = ready ? health.snapshot.loadedAt : null;
        final backfill = health.backfillReached;
        final sync = ready ? health.backgroundSync : null;
        final mine = scope.supplements.data.mine;
        final themeLabels = [l10n.themeSystem, l10n.themeLight, l10n.themeDark];
        final lookLabels = [l10n.lookStandard, l10n.lookMono, l10n.lookFlex];
        String? notGiven(String? value) => value ?? l10n.notGiven;
        final notices = [
          if (settings.morningBrief) l10n.morningTitle,
          if (settings.weekReport) l10n.weekTitle,
          if (settings.dayNotice) l10n.liveDay,
          if (settings.liveMorning ||
              settings.liveSupplements ||
              settings.liveWeek ||
              settings.liveDay)
            l10n.liveTitle,
        ];
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
              FoldSection(
                icon: Icons.person_rounded,
                title: l10n.aboutYou,
                summary: [
                  ?settings.name,
                  if (settings.birthDate case final date?)
                    formats.birthDate(date),
                  if (settings.heightCm case final cm?) '$cm cm',
                ].join(' · '),
                children: [
                  SettingLink(
                    title: l10n.nameLabel,
                    value: notGiven(settings.name),
                    onTap: () => showNameSheet(context),
                  ),
                  SettingLink(
                    title: l10n.birthDate,
                    value: switch (settings.birthDate) {
                      final date? => formats.birthDate(date),
                      null => l10n.notGiven,
                    },
                    onTap: () => showBirthDateSheet(context),
                  ),
                  SettingLink(
                    title: l10n.heightLabel,
                    value: switch (settings.heightCm) {
                      final height? => '$height cm',
                      null => l10n.notGiven,
                    },
                    onTap: () => showHeightSheet(context),
                  ),
                  SettingLink(
                    title: l10n.targetWeightLabel,
                    value: switch (settings.targetWeightKg) {
                      final kg? => '${formats.decimal(kg)} kg',
                      null => l10n.notGiven,
                    },
                    onTap: () => showTargetWeightSheet(context),
                  ),
                  SettingLink(
                    title: l10n.placeLabel,
                    value: notGiven(settings.place?.name),
                    onTap: () => showPlaceSheet(context),
                  ),
                  SettingBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.sex, style: muted),
                        const SizedBox(height: 8),
                        _SexToggle(settings: settings),
                      ],
                    ),
                  ),
                ],
              ),
              FoldSection(
                icon: Icons.flag_rounded,
                title: l10n.settingsGoalsSupps,
                summary: [for (final goal in settings.goals) goal.label(l10n)]
                    .join(' · '),
                children: [
                  SettingLink(
                    title: l10n.goalsOpen,
                    subtitle: [
                      for (final goal in settings.goals) goal.label(l10n),
                    ].join(' · '),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GoalsPage(),
                      ),
                    ),
                  ),
                  SettingLink(
                    title: l10n.supplementsChoose,
                    subtitle: mine.isEmpty
                        ? l10n.supplementsNone
                        : [
                            for (final supplement in mine)
                              supplement.title(l10n),
                          ].join(' · '),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SupplementsPage(),
                      ),
                    ),
                  ),
                ],
              ),
              FoldSection(
                icon: Icons.notifications_rounded,
                title: l10n.settingsNotifications,
                summary: notices.join(' · '),
                children: [
                  SettingSwitch(
                    title: l10n.morningTitle,
                    note: l10n.morningSwitchNote,
                    value: settings.morningBrief,
                    onChanged: (value) {
                      settings.setMorningBrief(value);
                      // The notification needs the system's consent.
                      if (value) MorningNotices.allow();
                    },
                    children: [
                      SettingSwitch(
                        title: l10n.morningTileAllDayNote,
                        value: settings.morningTileAllDay,
                        onChanged: settings.setMorningTileAllDay,
                      ),
                    ],
                  ),
                  SettingSwitch(
                    title: l10n.weekTitle,
                    note: l10n.weekSwitchNote,
                    value: settings.weekReport,
                    onChanged: (value) {
                      settings.setWeekReport(value);
                      if (value) MorningNotices.allow();
                    },
                  ),
                  SettingSwitch(
                    title: l10n.liveDay,
                    note: l10n.dayNoticeSwitchNote,
                    value: settings.dayNotice,
                    onChanged: (value) {
                      settings.setDayNotice(value);
                      if (value) MorningNotices.allow();
                    },
                  ),
                  SettingBlock(
                    child: Text(
                      l10n.liveTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  LiveSettings(settings: settings),
                ],
              ),
              FoldSection(
                icon: Icons.tune_rounded,
                title: l10n.settingsValues,
                summary: [
                  settings.fineValues ? l10n.valuesFine : l10n.valuesCoarse,
                  settings.stepCounting.label(l10n),
                ].join(' · '),
                children: [
                  SettingBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LookToggle(
                          size: M3EButtonSize.md,
                          labels: [l10n.valuesCoarse, l10n.valuesFine],
                          selected: settings.fineValues ? 1 : 0,
                          onChanged: (index) =>
                              settings.setFineValues(index == 1),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          settings.fineValues
                              ? l10n.valuesFineNote
                              : l10n.valuesCoarseNote,
                          style: muted,
                        ),
                        if (settings.fineValues)
                          if ([
                                if (health.fineMissing.birthDate)
                                  l10n.birthDate,
                                if (health.fineMissing.sex) l10n.sex,
                                if (health.fineMissing.weight)
                                  l10n.metricWeight,
                              ]
                              case final missing when missing.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                l10n.valuesFineMissing(missing.join(', ')),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.error,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  SettingLink(
                    title: l10n.stepCounting,
                    value: settings.stepCounting.label(l10n),
                    onTap: () => showStepCountingSheet(context),
                  ),
                  SettingBlock(
                    child: Text(
                      l10n.routeTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (health.routesNeedConsent)
                    SettingBlock(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.routeConsentNote, style: muted),
                          const SizedBox(height: 12),
                          M3EFilledButton.tonal(
                            onPressed: health.requestRoutes,
                            child: Text(l10n.routeAllow),
                          ),
                        ],
                      ),
                    ),
                  SettingSwitch(
                    title: l10n.routeSplitsSwitch,
                    value: settings.routeSplits,
                    onChanged: settings.setRouteSplits,
                  ),
                  SettingSwitch(
                    title: l10n.routeClimbSwitch,
                    value: settings.routeClimb,
                    onChanged: settings.setRouteClimb,
                  ),
                  SettingSwitch(
                    title: l10n.routeTilesSwitch,
                    value: settings.routeOnTiles,
                    onChanged: settings.setRouteOnTiles,
                  ),
                ],
              ),
              FoldSection(
                icon: Icons.palette_rounded,
                title: l10n.appearance,
                summary: [
                  lookLabels[settings.look.index],
                  themeLabels[_modes.indexOf(settings.themeMode)],
                ].join(' · '),
                children: [
                  SettingBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.settingsLook, style: muted),
                        const SizedBox(height: 8),
                        LookToggle(
                          size: M3EButtonSize.md,
                          labels: lookLabels,
                          selected: settings.look.index,
                          onChanged: (index) =>
                              settings.setLook(AppLook.values[index]),
                        ),
                      ],
                    ),
                  ),
                  if (settings.look.isInsights)
                    SettingSwitch(
                      title: l10n.glassBlur,
                      note: l10n.glassBlurNote,
                      value: settings.glassBlur,
                      onChanged: settings.setGlassBlur,
                    ),
                  if (settings.look.isInsights && settings.glassBlur)
                    SettingBlock(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.glassLevel, style: muted),
                          const SizedBox(height: 8),
                          LookToggle(
                            size: M3EButtonSize.md,
                            labels: [
                              l10n.glassLevelFrosted,
                              l10n.glassLevelClearer,
                              l10n.glassLevelClear,
                            ],
                            selected: settings.glassLevel,
                            onChanged: settings.setGlassLevel,
                          ),
                        ],
                      ),
                    ),
                  if (settings.look == AppLook.insightsFlex)
                    SettingSwitch(
                      title: l10n.flexTint,
                      note: l10n.flexTintNote,
                      value: settings.flexTint,
                      onChanged: settings.setFlexTint,
                    ),
                  SettingBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.themeLabel, style: muted),
                        const SizedBox(height: 8),
                        LookToggle(
                          size: M3EButtonSize.md,
                          labels: themeLabels,
                          selected: _modes.indexOf(settings.themeMode),
                          onChanged: (index) =>
                              settings.setThemeMode(_modes[index]),
                        ),
                      ],
                    ),
                  ),
                  ColorStyleRow(
                    selected: settings.colorStyle,
                    system: scope.systemPalette.value,
                    onSelected: settings.setColorStyle,
                  ),
                  SettingSwitch(
                    title: l10n.hapticsLabel,
                    value: settings.haptics,
                    onChanged: settings.setHaptics,
                  ),
                  SettingLink(
                    title: l10n.language,
                    value: switch (scope.language.choice) {
                      final code? => languageName(code),
                      null => l10n.languageSystem,
                    },
                    onTap: () => showLanguageSheet(context),
                  ),
                  // What only the standard look draws; the Insights looks
                  // bring their own.
                  if (!mono)
                    FoldSection.inner(
                      title: l10n.settingsStandardExtras,
                      children: [
                        for (final (label, value, set) in [
                          (
                            l10n.liquidGlass,
                            settings.liquidGlass,
                            settings.setLiquidGlass,
                          ),
                          (
                            l10n.edgeHero,
                            settings.edgeToEdgeHero,
                            settings.setEdgeToEdgeHero,
                          ),
                          (
                            l10n.flexFont,
                            settings.flexFont,
                            settings.setFlexFont,
                          ),
                          (l10n.calmMode, settings.calm, settings.setCalm),
                          (l10n.mascot, settings.mascot, settings.setMascot),
                          (
                            l10n.expressiveRework,
                            settings.expressive,
                            settings.setExpressive,
                          ),
                        ])
                          SettingSwitch(
                            title: label,
                            value: value,
                            onChanged: set,
                          ),
                      ],
                    ),
                ],
              ),
              FoldSection(
                icon: Icons.tag_rounded,
                title: l10n.simpleTitle,
                summary: settings.simple ? l10n.simpleOn : l10n.simpleOff,
                children: [
                  SettingBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LookToggle(
                          size: M3EButtonSize.md,
                          labels: [l10n.simpleOn, l10n.simpleOff],
                          selected: settings.simple ? 0 : 1,
                          onChanged: (index) => settings.setSimple(index == 0),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          settings.simple
                              ? l10n.simpleOnNote
                              : l10n.simpleOffNote,
                          style: muted,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.simpleTilesTitle,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(l10n.simpleTilesBody, style: muted),
                      ],
                    ),
                  ),
                ],
              ),
              FoldSection(
                icon: Icons.storage_rounded,
                title: l10n.settingsDataBackup,
                summary: loadedAt == null
                    ? null
                    : l10n.dateAtTime(
                        formats.shortDate(loadedAt),
                        formatClock(loadedAt.hour * 60 + loadedAt.minute),
                      ),
                children: [
                  if (ready)
                    SettingBlock(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.lastUpdated,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (loadedAt != null)
                            Text(
                              l10n.dateAtTime(
                                formats.shortDate(loadedAt),
                                formatClock(
                                  loadedAt.hour * 60 + loadedAt.minute,
                                ),
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
                                  formatClock(
                                    sync.at.hour * 60 + sync.at.minute,
                                  ),
                                ),
                              ),
                              style: muted,
                            ),
                          if (backfill != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              l10n.loadingOlderData,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              l10n.reachedSoFar(
                                '${formats.shortDate(backfill)} '
                                '${backfill.year}',
                              ),
                              style: muted,
                            ),
                          ],
                          const SizedBox(height: 14),
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
                          if (!health.historyAccess) ...[
                            const SizedBox(height: 14),
                            Text(l10n.historyOff, style: muted),
                            const SizedBox(height: 12),
                            M3EFilledButton.tonal(
                              onPressed: health.requestHistoryAccess,
                              child: Text(l10n.historyLoad),
                            ),
                          ],
                        ],
                      ),
                    ),
                  SettingBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.backup, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
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
              ),
              FoldSection(
                icon: Icons.info_outline_rounded,
                title: l10n.settingsAbout,
                children: [
                  SettingLink(
                    title: l10n.introAgain,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => const IntroPage(again: true),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Female or male, or neither while none is chosen.
class _SexToggle extends StatelessWidget {
  const _SexToggle({required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final l10n = Formats.of(context).l10n;
    const sexes = ProfilePage._sexes;
    final selected = switch (settings.sex) {
      final sex? => sexes.indexOf(sex),
      null => null,
    };
    // The slider of the Insights looks always shows a choice; the group of
    // buttons can show none, and a second tap takes the choice back.
    if (PulseLook.monoOf(context) && selected != null) {
      return LookToggle(
        labels: [l10n.female, l10n.male],
        selected: selected,
        onChanged: (index) => settings.setSex(sexes[index]),
      );
    }
    return M3EToggleButtonGroup(
      type: M3EButtonGroupType.connected,
      style: M3EButtonStyle.tonal,
      size: M3EButtonSize.md,
      haptic: Haptics.widget,
      selectedIndex: selected,
      onSelectedIndexChanged: (index) =>
          settings.setSex(index == null ? null : sexes[index]),
      actions: [
        M3EToggleButtonGroupAction(label: Text(l10n.female)),
        M3EToggleButtonGroupAction(label: Text(l10n.male)),
      ],
    );
  }
}
