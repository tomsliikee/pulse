import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_header.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/tile_surface.dart';
import 'day_tiles.dart';

/// Every day the app knows, newest first and month by month.
class DayListPage extends StatelessWidget {
  const DayListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    // The rows the list starts with come in; the ones scrolled to do not.
    return EntranceGate(
      builder: (context, opening) => ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final formats = Formats.of(context);

          // A month's heading, then its days. A day and a month are both
          // dates, so the headings are kept apart by their index.
          final rows = <DateTime>[];
          final headings = <int>{};
          DateTime? month;
          for (final day in health.days.reversed) {
            final start = DateTime(day.year, day.month);
            if (start != month) {
              headings.add(rows.length);
              rows.add(month = start);
            }
            rows.add(day);
          }

          return SubPage(
            title: formats.l10n.allDays,
            glass: scope.settings.liquidGlass,
            slivers: [
              SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) => Entrance(
                  order: index,
                  animate: index < Entrance.staggered && opening(),
                  child: headings.contains(index)
                      ? SectionTitle(
                          formats.month(rows[index]),
                          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TileSurface(
                            color: scheme.surfaceBright,
                            radius: AppRadii.extraLarge,
                            child: SizedBox(
                              height: 72,
                              child: DayRow(day: rows[index]),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
