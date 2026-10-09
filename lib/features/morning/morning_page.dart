import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/morning_notices.dart';
import '../../data/morning.dart';
import '../../data/night_insights.dart';
import '../../theme/page_accent.dart';
import '../goals/goal_format.dart';
import '../today/day_format.dart';
import 'morning_cards.dart';

/// Opens the morning's cards: out of the tile at [origin], or from below
/// when the app opens them by itself.
void openMorning(BuildContext context, {Rect? origin}) {
  Navigator.of(context).push(
    origin == null
        ? MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const MorningPage(byItself: true),
          )
        : ContainerRoute<void>(
            origin: origin,
            originColor: Theme.of(context).colorScheme.primaryContainer,
            builder: (_) => const MorningPage(),
          ),
  );
}

/// Good morning: a few cards to swipe through, each about one thing the
/// day starts with. A card that has nothing to show is left out, but the
/// night's says so while the watch has not synced.
class MorningPage extends StatefulWidget {
  const MorningPage({super.key, this.byItself = false});

  /// Whether the app opened the page, and not a tap on the tile. Leaving
  /// it then asks once for the consent to the morning's notification.
  final bool byItself;

  @override
  State<MorningPage> createState() => _MorningPageState();
}

class _MorningPageState extends State<MorningPage> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    if (widget.byItself) MorningNotices.allow();
    _pages.dispose();
    super.dispose();
  }

  List<Widget> _cards(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    final today = health.today;
    final insights = dayInsightsOf(health, settings, today);
    final night = insights.night;
    final recovery = insights.recovery;
    final deviations = vitalDeviations(health.valueOn, today);
    final plan = tonight(health.nights, settings.sleepGoalHours, today);
    final weather = scope.weather.weather;
    return [
      GreetingCard(
        name: settings.name,
        today: today,
        effort: effortFor(
          day: today,
          recovery: recovery,
          workouts: health.workouts,
        ),
        weather: weather,
        hasPlace: settings.place != null,
      ),
      SleepCard(
        insights: night == null
            ? null
            : NightInsights.of(night, health.nights, settings.sleepGoalHours),
      ),
      if (recovery.parts.isNotEmpty || deviations.isNotEmpty)
        RecoveryCard(recovery: recovery, deviations: deviations),
      if (settings.place != null)
        WeatherCard(weather: weather, now: health.now),
      MorningGoalsCard(
        goals: settings.goals,
        targetOf: settings.goalTarget,
        data: goalDataOf(health, settings),
        today: today,
        yesterday: dayInsightsOf(
          health,
          settings,
          DateTime(today.year, today.month, today.day - 1),
        ),
      ),
      if (plan != null)
        TonightCard(plan: plan, goalHours: settings.sleepGoalHours),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PageAccent.day(
      child: Scaffold(
        backgroundColor: scheme.surfaceContainer,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              scope.health,
              scope.settings,
              scope.weather,
            ]),
            builder: (context, _) {
              final l10n = Formats.of(context).l10n;
              final cards = _cards(context);
              // A card may go while the page is open, such as the weather's.
              final index = _index.clamp(0, cards.length - 1);
              final last = index == cards.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            spacing: 6,
                            children: [
                              for (var i = 0; i < cards.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  width: i == index ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: i == index
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: l10n.close,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (index) {
                        Haptics.selection();
                        setState(() => _index = index);
                      },
                      children: cards,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: M3EFilledButton(
                        size: M3EButtonSize.md,
                        onPressed: last
                            ? () => Navigator.of(context).maybePop()
                            : () => _pages.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOutCubicEmphasized,
                              ),
                        child: Text(last ? l10n.morningDone : l10n.morningNext),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
