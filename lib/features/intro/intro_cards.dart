import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/morning_notices.dart';
import '../../data/goals.dart';
import '../../data/health_controller.dart';
import '../../data/models.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../goals/goals_page.dart';
import '../morning/morning_cards.dart';
import '../morning/morning_scene.dart';
import '../profile/birth_date_sheet.dart';
import '../profile/height_sheet.dart';
import '../profile/name_sheet.dart';
import '../profile/place_sheet.dart';

/// The head of a card: what it is about in large, and a sentence to it.
class _Head extends StatelessWidget {
  const _Head({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            title,
            style: AppType.of(context)
                .title(context.emphasizedTextTheme.headlineMedium),
          ),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small word over a group of rows.
class _Over extends StatelessWidget {
  const _Over(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: AppType.of(context).label(
          theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// An icon on a shape with a name, a sentence and, where there is one, a
/// switch or a mark at its end.
class _Point extends StatelessWidget {
  const _Point({
    required this.shape,
    required this.icon,
    required this.title,
    required this.text,
    this.trailing,
  });

  final Shapes shape;
  final IconData icon;
  final String title;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = PageAccent.colorsOf(context);
    return Row(
      children: [
        ShapeBadge(
          shape: shape,
          icon: icon,
          size: 40,
          color: accent.container,
          iconColor: accent.onContainer,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: 12),
          trailing,
        ],
      ],
    );
  }
}

/// The mark of something the system has allowed.
class _Allowed extends StatelessWidget {
  const _Allowed();

  @override
  Widget build(BuildContext context) => Icon(
    Icons.check_circle_rounded,
    color: Theme.of(context).colorScheme.primary,
    semanticLabel: Formats.of(context).l10n.introAllowed,
  );
}

/// What Pulse is, over the morning's scene.
class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = Formats.of(context).l10n;
    final type = AppType.of(context);
    return MorningCard(
      children: [
        const SurfaceCard(
          padding: EdgeInsets.zero,
          child: MorningScene(height: 200),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Text(
            l10n.introWelcomeTitle,
            style: type.title(context.emphasizedTextTheme.displaySmall),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l10n.introWelcomeBody, style: theme.textTheme.bodyLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: Text(
            l10n.introWelcomeAside,
            style: type.aside(
              theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Where the data is kept and the one thing that leaves the phone.
class PrivacyCard extends StatelessWidget {
  const PrivacyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = Formats.of(context).l10n;
    return MorningCard(
      children: [
        _Head(title: l10n.introPrivacyTitle, body: l10n.introPrivacyBody),
        SegmentGroup(
          children: [
            _Point(
              shape: Shapes.c9SidedCookie,
              icon: Icons.person_off_rounded,
              title: l10n.introPrivacyAccount,
              text: l10n.introPrivacyAccountText,
            ),
            _Point(
              shape: Shapes.gem,
              icon: Icons.smartphone_rounded,
              title: l10n.introPrivacyDevice,
              text: l10n.introPrivacyDeviceText,
            ),
            _Point(
              shape: Shapes.sunny,
              icon: Icons.wb_sunny_rounded,
              title: l10n.introPrivacyWeather,
              text: l10n.introPrivacyWeatherText,
            ),
            _Point(
              shape: Shapes.puffy,
              icon: Icons.save_alt_rounded,
              title: l10n.introPrivacyBackup,
              text: l10n.introPrivacyBackupText,
            ),
          ],
        ),
      ],
    );
  }
}

/// What Pulse reads from Health Connect and what it writes, said before the
/// system asks, and the button that makes it ask.
class AccessCard extends StatefulWidget {
  const AccessCard({super.key});

  @override
  State<AccessCard> createState() => _AccessCardState();
}

class _AccessCardState extends State<AccessCard> {
  bool _asking = false;

  Future<void> _ask(HealthController health) async {
    setState(() => _asking = true);
    await health.requestAccess();
    if (mounted) setState(() => _asking = false);
  }

  @override
  Widget build(BuildContext context) {
    final health = AppScope.of(context).health;
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) => _card(context, health),
    );
  }

  Widget _card(BuildContext context, HealthController health) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final status = health.status;
    return MorningCard(
      children: [
        _Head(title: 'Health Connect', body: l10n.introAccessBody),
        Align(
          alignment: Alignment.centerLeft,
          child: switch (status) {
            HealthStatus.ready || HealthStatus.failed => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                const _Allowed(),
                Flexible(
                  child: Text(
                    l10n.introAccessGranted,
                    style: context.emphasizedTextTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            HealthStatus.unavailable => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Text(l10n.introAccessMissing, style: theme.textTheme.bodyLarge),
                M3EFilledButton(
                  size: M3EButtonSize.md,
                  onPressed: health.installStore,
                  child: Text(l10n.missingAction),
                ),
              ],
            ),
            HealthStatus.needsAccess => M3EFilledButton(
              size: M3EButtonSize.md,
              onPressed: _asking ? null : () => _ask(health),
              child: Text(l10n.accessAction),
            ),
            _ => const M3ELoadingIndicator(),
          },
        ),
        _Over(l10n.introReads),
        SegmentGroup(
          children: [
            for (final (shape, icon, title, text) in [
              (
                Shapes.c6SidedCookie,
                Icons.directions_walk_rounded,
                l10n.introActivity,
                l10n.introActivityText,
              ),
              (
                Shapes.heart,
                Icons.favorite_rounded,
                l10n.introHeart,
                l10n.introHeartText,
              ),
              (
                Shapes.oval,
                Icons.bedtime_rounded,
                l10n.introSleep,
                l10n.introSleepText,
              ),
              (
                Shapes.pentagon,
                Icons.monitor_weight_rounded,
                l10n.introBody,
                l10n.introBodyText,
              ),
              (
                Shapes.flower,
                Icons.restaurant_rounded,
                l10n.introFood,
                l10n.introFoodText,
              ),
            ])
              _Point(shape: shape, icon: icon, title: title, text: text),
          ],
        ),
        _Over(l10n.introWrites),
        SegmentGroup(
          from: 5,
          children: [
            _Point(
              shape: Shapes.softBurst,
              icon: Icons.edit_rounded,
              title: l10n.introOwnEntries,
              text: l10n.introOwnEntriesText,
            ),
          ],
        ),
      ],
    );
  }
}

/// What may be allowed on top: each behind a switch that asks the system
/// at once and then shows what it answered.
class OptionalCard extends StatefulWidget {
  const OptionalCard({super.key});

  @override
  State<OptionalCard> createState() => _OptionalCardState();
}

class _OptionalCardState extends State<OptionalCard> {
  /// Whether the system shows notifications of the app.
  bool _notices = false;

  @override
  void initState() {
    super.initState();
    MorningNotices.allowed().then((allowed) {
      if (mounted && allowed) setState(() => _notices = true);
    });
  }

  Future<void> _setNotices(bool on) async {
    final settings = AppScope.of(context).settings;
    Haptics.selection();
    if (on) {
      final allowed = await MorningNotices.allow();
      if (!mounted) return;
      setState(() => _notices = allowed);
      if (!allowed) return;
    }
    settings
      ..setMorningBrief(on)
      ..setWeekReport(on);
  }

  @override
  Widget build(BuildContext context) {
    final AppScope(:health, :settings) = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([health, settings]),
      builder: (context, _) => _card(context, health, settings),
    );
  }

  Widget _card(
    BuildContext context,
    HealthController health,
    SettingsController settings,
  ) {
    final theme = Theme.of(context);
    final l10n = Formats.of(context).l10n;
    final open = health.status == HealthStatus.ready;

    Widget ask(String label, bool granted, Future<void> Function() request) =>
        granted
        ? const _Allowed()
        : Semantics(
            label: label,
            child: Switch(
              value: false,
              onChanged: open
                  ? (_) {
                      Haptics.selection();
                      request();
                    }
                  : null,
            ),
          );

    return MorningCard(
      children: [
        _Head(title: l10n.introOptionalTitle, body: l10n.introOptionalBody),
        SegmentGroup(
          children: [
            _Point(
              shape: Shapes.c7SidedCookie,
              icon: Icons.notifications_rounded,
              title: l10n.introNotices,
              text: l10n.introNoticesText,
              trailing: Semantics(
                label: l10n.introNotices,
                child: Switch(
                  value:
                      _notices &&
                      (settings.morningBrief || settings.weekReport),
                  onChanged: _setNotices,
                ),
              ),
            ),
            _Point(
              shape: Shapes.l4LeafClover,
              icon: Icons.sync_rounded,
              title: l10n.introBackground,
              text: l10n.introBackgroundText,
              trailing: ask(
                l10n.introBackground,
                health.backgroundAccess,
                health.requestBackgroundAccess,
              ),
            ),
            _Point(
              shape: Shapes.arch,
              icon: Icons.history_rounded,
              title: l10n.introHistory,
              text: l10n.introHistoryText,
              trailing: ask(
                l10n.introHistory,
                health.historyAccess,
                health.requestHistoryAccess,
              ),
            ),
            _Point(
              shape: Shapes.slanted,
              icon: Icons.route_rounded,
              title: l10n.introRoutes,
              text: l10n.introRoutesText,
            ),
          ],
        ),
        if (!open)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              l10n.introNeedsAccess,
              style: AppType.of(context).aside(
                theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Who the numbers are about: each row says what it is good for and opens
/// the sheet the profile has for it.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  static const _sexes = [Sex.female, Sex.male];

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _card(context, settings),
    );
  }

  Widget _card(BuildContext context, SettingsController settings) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return MorningCard(
      children: [
        _Head(title: l10n.introAboutTitle, body: l10n.introAboutBody),
        SegmentGroup(
          padding: EdgeInsets.zero,
          children: [
            for (final (label, why, value, open) in [
              (
                l10n.nameLabel,
                l10n.introNameWhy,
                settings.name ?? l10n.notGiven,
                showNameSheet,
              ),
              (
                l10n.birthDate,
                l10n.introBirthWhy,
                switch (settings.birthDate) {
                  final date? => formats.birthDate(date),
                  null => l10n.notGiven,
                },
                showBirthDateSheet,
              ),
              (
                l10n.heightLabel,
                l10n.introHeightWhy,
                switch (settings.heightCm) {
                  final height? => '$height cm',
                  null => l10n.notGiven,
                },
                showHeightSheet,
              ),
              (
                l10n.placeLabel,
                l10n.introPlaceWhy,
                settings.place?.name ?? l10n.notGiven,
                showPlaceSheet,
              ),
            ])
              InkWell(
                onTap: () => open(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: theme.textTheme.titleMedium),
                            Text(why, style: muted),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // A long name or place gives way to its label.
                      Expanded(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: context.emphasizedTextTheme.titleMedium
                              ?.copyWith(color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.sex, style: theme.textTheme.titleMedium),
                  Text(l10n.introSexWhy, style: muted),
                  const SizedBox(height: 12),
                  M3EToggleButtonGroup(
                    type: M3EButtonGroupType.connected,
                    style: M3EButtonStyle.tonal,
                    size: M3EButtonSize.md,
                    haptic: Haptics.widget,
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
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The three goals of a day to begin with, each with the switch and the
/// slider the goals' page has.
class IntroGoalsCard extends StatelessWidget {
  const IntroGoalsCard({super.key});

  static const _goals = [Goal.steps, Goal.sleepDuration, Goal.water];

  @override
  Widget build(BuildContext context) {
    final l10n = Formats.of(context).l10n;
    final settings = AppScope.of(context).settings;
    return MorningCard(
      children: [
        _Head(title: l10n.introGoalsTitle, body: l10n.introGoalsBody),
        ListenableBuilder(
          listenable: settings,
          builder: (context, _) => SegmentGroup(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            children: [
              for (final goal in _goals)
                GoalSetting(goal: goal, settings: settings),
            ],
          ),
        ),
      ],
    );
  }
}

/// The choice between the few numbers and all of them, each drawn small.
class ModeCard extends StatelessWidget {
  const ModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = Formats.of(context).l10n;
    final settings = AppScope.of(context).settings;
    return MorningCard(
      children: [
        _Head(title: l10n.introModeTitle, body: l10n.introModeBody),
        for (final (simple, title, text) in [
          (true, l10n.simpleOn, l10n.simpleOnNote),
          (false, l10n.simpleOff, l10n.simpleOffNote),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListenableBuilder(
              listenable: settings,
              builder: (context, _) => _ModeChoice(
                simple: simple,
                title: title,
                text: text,
                chosen: settings.simple == simple,
                onTap: () {
                  Haptics.selection();
                  settings.setSimple(simple);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.simple,
    required this.title,
    required this.text,
    required this.chosen,
    required this.onTap,
  });

  final bool simple;
  final String title;
  final String text;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = PageAccent.colorsOf(context);
    final ink = chosen ? accent.onContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: chosen,
      child: Material(
        color: chosen ? accent.container : scheme.surfaceBright,
        borderRadius: BorderRadius.circular(AppRadii.extraLargeIncreased),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _ModeSketch(
                  simple: simple,
                  color: ink.withValues(alpha: chosen ? 0.75 : 0.3),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.emphasizedTextTheme.titleLarge?.copyWith(
                          color: ink,
                        ),
                      ),
                      Text(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: chosen ? ink : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  chosen
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: chosen ? ink : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A page of tiles in small: one large number and two beside it, or many.
class _ModeSketch extends StatelessWidget {
  const _ModeSketch({required this.simple, required this.color});

  final bool simple;
  final Color color;

  Widget _tile({int flex = 1}) => Expanded(
    flex: flex,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const SizedBox.expand(),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 72,
    child: Column(
      spacing: 4,
      children: simple
          ? [
              _tile(flex: 2),
              Expanded(child: Row(spacing: 4, children: [_tile(), _tile()])),
            ]
          : [
              for (var row = 0; row < 4; row++)
                Expanded(
                  child: Row(
                    spacing: 4,
                    children: [
                      for (var i = 0; i < (row.isEven ? 2 : 3); i++) _tile(),
                    ],
                  ),
                ),
            ],
    ),
  );
}
