import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../data/health_controller.dart';
import '../data/models.dart';
import '../features/access/access_page.dart';
import '../features/activity/activity_page.dart';
import '../features/entry/entry_sheet.dart';
import '../features/supplements/supplement_row.dart';
import '../features/supplements/supplement_sheet.dart';
import '../features/heart/heart_page.dart';
import '../features/intro/intro_page.dart';
import '../features/sleep/sleep_page.dart';
import '../features/today/today_page.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/entrance.dart';
import '../widgets/glass_scope.dart';
import 'app_scope.dart';
import 'container_route.dart';
import 'floating_nav_bar.dart';
import 'glass_fab_menu.dart';
import 'haptics.dart';
import '../l10n/generated/app_localizations.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static List<NavDestination> _destinations(AppLocalizations l10n) => [
    NavDestination(
      label: l10n.navToday,
      icon: Icons.wb_sunny_outlined,
      selectedIcon: Icons.wb_sunny_rounded,
    ),
    NavDestination(
      label: l10n.groupActivity,
      icon: Icons.directions_run_outlined,
      selectedIcon: Icons.directions_run_rounded,
    ),
    NavDestination(
      label: l10n.groupSleep,
      icon: Icons.bedtime_outlined,
      selectedIcon: Icons.bedtime_rounded,
    ),
    NavDestination(
      label: l10n.navHeart,
      icon: Icons.favorite_outline_rounded,
      selectedIcon: Icons.favorite_rounded,
    ),
  ];

  static const _entries = [
    (EntryKind.water, Icons.water_drop_rounded),
    (EntryKind.weight, Icons.monitor_weight_rounded),
    (EntryKind.meal, Icons.restaurant_rounded),
  ];

  /// The tone each destination's page is painted in.
  static const _tones = [
    Tone.primary,
    Tone.secondary,
    Tone.tertiary,
    Tone.error,
  ];

  int _index = 0;

  /// The pages opened so far. They are kept while another is shown, so
  /// coming back costs no new build; [_visits] lets what comes in on them
  /// come in again.
  final Set<int> _opened = {0};
  final List<int> _visits = [0, 0, 0, 0];

  /// Each page keeps its place in the tree, and with it its state, while it
  /// springs into place anew.
  final List<GlobalKey> _keys = List.generate(4, (_) => GlobalKey());

  static Widget _page(int index) => switch (index) {
    0 => const TodayPage(),
    1 => const ActivityPage(),
    2 => const SleepPage(),
    _ => const HeartPage(),
  };

  void _open(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      if (!_opened.add(index)) _visits[index]++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final AppScope(:health, :settings) = AppScope.of(context);
    // In the colourful style the bar and the ground take the colour of the
    // page that is open.
    final theme = Theme.of(context);
    final own = theme.extension<PageSchemes>()?.of(_tones[_index]);
    return AnimatedTheme(
      data: own ?? theme,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: Listenable.merge([health, settings]),
          builder: (context, _) {
            // A new installation is led through its first start, where
            // there is a health store to lead it to.
            if (settings.loaded &&
                !settings.introDone &&
                health.status != HealthStatus.loading &&
                health.status != HealthStatus.unsupported) {
              return const IntroPage();
            }
            if (health.status != HealthStatus.ready) {
              return SafeArea(child: AccessPage(status: health.status));
            }
            final glass = settings.liquidGlass;
            return Stack(
              children: [
                for (final index in _opened)
                  Positioned.fill(
                    key: ValueKey(index),
                    child: _KeptPage(
                      shown: index == _index,
                      visit: _visits[index],
                      // Its own tone, so the colour the shell turns to does
                      // not build the pages again in every frame.
                      theme: theme.extension<PageSchemes>()?.of(_tones[index]) ??
                          theme,
                      child: KeyedSubtree(
                        key: _keys[index],
                        child: glass
                            ? GlassScope(child: _page(index))
                            : _page(index),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + media.padding.bottom,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flexible, so the bar learns how much room the add
                      // button leaves it.
                      Flexible(
                        child: LayoutBuilder(
                          builder: (context, box) => FloatingNavBar(
                            destinations: _destinations(l10n),
                            selectedIndex: _index,
                            showLabel: media.size.width >= 400,
                            maxWidth: box.maxWidth,
                            glass: glass,
                            onSelected: _open,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (glass)
                        GlassFabMenu(
                          items: [
                            for (final (kind, icon) in _entries)
                              GlassFabMenuItem(
                                icon: icon,
                                label: kind.label(l10n),
                                onPressed: () => showEntrySheet(context, kind),
                              ),
                            GlassFabMenuItem(
                              icon: supplementIcon,
                              label: l10n.supplement,
                              onPressed: () => showSupplementSheet(context),
                            ),
                          ],
                        )
                      else
                        M3EFabMenu(
                          color: M3EFabColor.tertiary,
                          onOpenChanged: (_) => Haptics.tap(),
                          items: [
                            for (final (kind, icon) in _entries)
                              M3EFabMenuItem(
                                icon: Icon(icon),
                                label: kind.label(l10n),
                                onPressed: () {
                                  Haptics.tap();
                                  showEntrySheet(context, kind);
                                },
                              ),
                            M3EFabMenuItem(
                              icon: const Icon(supplementIcon),
                              label: l10n.supplement,
                              onPressed: () {
                                Haptics.tap();
                                showSupplementSheet(context);
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One of the shell's pages, kept while another is shown: then it is neither
/// drawn nor moving. Shown again, it settles into place on a spring. Only
/// its size and place move, not its opacity: the page fading as a whole
/// would be drawn into a layer of its own in every frame of the spring, and
/// its tiles come in by themselves.
class _KeptPage extends StatelessWidget {
  const _KeptPage({
    required this.shown,
    required this.visit,
    required this.theme,
    required this.child,
  });

  final bool shown;
  final int visit;
  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !shown,
    child: TickerMode(
      enabled: shown,
      child: PageVisits(
        visit: visit,
        child: Theme(
          data: theme,
          child: SingleMotionBuilder(
            // A new key per visit restarts the spring.
            key: ValueKey(visit),
            from: shown ? 0 : 1,
            value: 1,
            motion: AppMotion.spatial,
            builder: (context, t, child) =>
                Transform.scale(scale: 0.94 + 0.06 * t, child: child),
            child: _RestsBeneath(child: child),
          ),
        ),
      ),
    ),
  );
}

/// Stops what moves by itself on [child] for as long as another page lies
/// over all of it. A page that grows out of a tile leaves this one in the
/// tree beneath it, where it would go on drawing unseen.
class _RestsBeneath extends StatelessWidget {
  const _RestsBeneath({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: ContainerRoute.covering,
    builder: (context, covering, child) =>
        TickerMode(enabled: covering == 0, child: child!),
    child: child,
  );
}
