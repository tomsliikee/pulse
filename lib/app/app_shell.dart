import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../data/health_controller.dart';
import '../data/models.dart';
import '../features/access/access_page.dart';
import '../features/activity/activity_page.dart';
import '../features/entry/entry_sheet.dart';
import '../features/heart/heart_page.dart';
import '../features/sleep/sleep_page.dart';
import '../features/today/today_page.dart';
import '../theme/app_motion.dart';
import '../widgets/glass_scope.dart';
import 'app_scope.dart';
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

  int _index = 0;

  Widget _page() => switch (_index) {
    0 => const TodayPage(),
    1 => const ActivityPage(),
    2 => const SleepPage(),
    _ => const HeartPage(),
  };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final AppScope(:health, :settings) = AppScope.of(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([health, settings]),
        builder: (context, _) {
          if (health.status != HealthStatus.ready) {
            return SafeArea(child: AccessPage(status: health.status));
          }
          final glass = settings.liquidGlass;
          final page = _page();
          return Stack(
            children: [
              Positioned.fill(
                // A new key per destination restarts the spring, so every
                // page fades through and settles into place when opened.
                child: SingleMotionBuilder(
                  key: ValueKey(_index),
                  from: 0,
                  value: 1,
                  motion: AppMotion.spatial,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0, 1).toDouble(),
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * t,
                      child: child,
                    ),
                  ),
                  child: glass ? GlassScope(child: page) : page,
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
                          onSelected: (index) => setState(() => _index = index),
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
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
