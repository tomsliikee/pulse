import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_history.dart' show dayKey;
import '../../data/morning.dart';
import '../../widgets/floating_surface.dart';
import '../../widgets/board_page.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pressable.dart';
import '../../widgets/stat_tile.dart';
import '../browse/all_data_section.dart';
import '../morning/morning_page.dart';
import '../profile/profile_page.dart';
import '../../theme/page_accent.dart';
import 'add_tiles_section.dart';
import 'day_scene.dart';
import 'day_tiles.dart';
import 'today_tiles.dart';
import '../../l10n/generated/app_localizations.dart';

/// Today at a glance. Which tiles it shows, and how large, is the user's
/// choice; see [buildTodayTile].
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([health, settings]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final snapshot = health.snapshot;

        final shown = [
          for (final id in settings.todayTiles)
            if (todayTileAvailable(id, health, settings)) id,
        ];
        return PageAccent.day(
          child: _MorningOpener(
            child: Builder(
              builder: (context) => BoardPage(
                pageId: 'today',
                // The scene stands at this minute, so its sky says whether
                // the title has to be light.
                backdropInk:
                    DayScene.isDarkAt(health.now.hour * 60 + health.now.minute)
                    ? const Color(0xFFEFF1FF)
                    : null,
                backdrop: !dayHeroBleeds(context, shown)
                    ? null
                    : (context, boardTop) =>
                          DayBackdrop(extent: boardTop + DayCard.sceneHeight),
                title: l10n.navToday,
                // This page always shows today, whatever day is selected elsewhere.
                subtitle: formats.longDate(snapshot.dateAt(health.todayIndex)),
                trailing: const _ProfileButton(),
                editMenu: SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.showAllData,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: settings.showAllData,
                        onChanged: (value) {
                          Haptics.selection();
                          settings.setShowAllData(value);
                        },
                      ),
                    ],
                  ),
                ),
                editFooter: AddTilesSection(health: health, settings: settings),
                footer: !settings.showAllData
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                          SectionTitle(
                            l10n.allData,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                            child: Text(
                              l10n.last30FromHealthConnect,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          AllDataSection(snapshot: snapshot),
                        ],
                      ),
                tiles: [
                  for (final id in settings.todayTiles)
                    ?buildTodayTile(
                      context,
                      id: id,
                      health: health,
                      settings: settings,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens the morning's cards by themselves, once a day: the first time the
/// Today page is in front during the morning.
class _MorningOpener extends StatefulWidget {
  const _MorningOpener({required this.child});

  final Widget child;

  @override
  State<_MorningOpener> createState() => _MorningOpenerState();
}

class _MorningOpenerState extends State<_MorningOpener> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _check();
  }

  @override
  void didUpdateWidget(_MorningOpener oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The page above rebuilds with every change of the data and settings.
    _check();
  }

  void _check() {
    if (_scheduled) return;
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    // Settings that are not read yet cannot say whether it opened today.
    if (!settings.loaded || !settings.morningBrief) return;
    final now = health.now;
    if (settings.morningSeen == dayKey(now)) return;
    if (!morningWindow(health.nights, now).holds(now)) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      settings.setMorningSeen(now);
      openMorning(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void open() =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));
    return Semantics(
      container: true,
      button: true,
      label: AppLocalizations.of(context).profile,
      onTap: open,
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 0.88,
        child: GestureDetector(
          onTap: open,
          child: M3EContainer(
            Shapes.c7SidedCookie,
            width: FloatingSurface.height,
            height: FloatingSurface.height,
            color: scheme.tertiary,
            child: Icon(Icons.person_rounded, color: scheme.onTertiary),
          ),
        ),
      ),
    );
  }
}
