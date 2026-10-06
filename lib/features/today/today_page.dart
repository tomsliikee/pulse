import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../widgets/board_page.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pressable.dart';
import '../../widgets/stat_tile.dart';
import '../browse/all_data_section.dart';
import '../profile/profile_page.dart';
import 'add_tiles_section.dart';
import 'today_tiles.dart';

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
        final snapshot = health.snapshot;

        return BoardPage(
          pageId: 'today',
          title: 'Heute',
          // This page always shows today, whatever day is selected elsewhere.
          subtitle: formatLongDate(snapshot.dateAt(health.todayIndex)),
          trailing: const _ProfileButton(),
          editMenu: SurfaceCard(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Alle Daten anzeigen',
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
                    const SectionTitle(
                      'Alle Daten',
                      padding: EdgeInsets.symmetric(horizontal: 4),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                      child: Text(
                        'Letzte 30 Tage aus Health Connect',
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
        );
      },
    );
  }
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
      label: 'Profil',
      onTap: open,
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 0.88,
        child: GestureDetector(
          onTap: open,
          child: M3EContainer(
            Shapes.c7SidedCookie,
            width: 56,
            height: 56,
            color: scheme.tertiary,
            child: Icon(Icons.person_rounded, color: scheme.onTertiary),
          ),
        ),
      ),
    );
  }
}
