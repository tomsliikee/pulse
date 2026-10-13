import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pressable.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/tile_surface.dart';
import 'supplement_format.dart';
import 'supplement_row.dart';

const IconData caffeineIcon = Icons.coffee_rounded;

/// Days the caffeine page draws as bars.
const int _days = 14;

/// "160 mg".
String caffeineText(Formats formats, double mg) =>
    '${formats.integer(mg.round())} ${formats.l10n.unitMilligram}';

/// The caffeine logged today and when the last of it was, on the Today
/// page. Only what was logged in the app counts.
class CaffeineTile extends StatelessWidget {
  const CaffeineTile({super.key});

  static const double height = 96;

  // The board holds this tile as a constant, so it listens for itself.
  @override
  Widget build(BuildContext context) {
    final supplements = AppScope.of(context).supplements;
    return ListenableBuilder(
      listenable: supplements,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final tone = scheme.tone(Tone.tertiary);
        final today = supplements.now;
        final mg = supplements.data.caffeineOn(today);
        final last = supplements.data.lastCaffeine(today);
        return Pressable(
          pressedScale: 0.98,
          child: TileSurface(
            color: scheme.surfaceBright,
            radius: AppRadii.extraLarge,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  Haptics.tap();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CaffeinePage(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      ShapeBadge(
                        shape: Shapes.c6SidedCookie,
                        icon: caffeineIcon,
                        size: 40,
                        color: tone.container,
                        iconColor: tone.onContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.metricCaffeine,
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              last == null
                                  ? l10n.caffeineNone
                                  : l10n.caffeineLast(clockOf(last)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (mg != null)
                        Text(
                          caffeineText(formats, mg),
                          style: context.emphasizedTextTheme.titleLarge,
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The caffeine of today, of the last two weeks, and each time it was
/// logged today.
class CaffeinePage extends StatelessWidget {
  const CaffeinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.supplements, scope.settings]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final data = scope.supplements.data;
        final now = scope.supplements.now;
        final today = DateTime(now.year, now.month, now.day);
        final days = [
          for (var back = _days - 1; back >= 0; back--)
            DateTime(today.year, today.month, today.day - back),
        ];
        final mg = data.caffeineOn(today);
        final last = data.lastCaffeine(today);
        final taken = [
          for (final intake in data.intakesOn(today).reversed)
            if (intake.caffeineMg != null) intake,
        ];
        return SubPage(
          title: l10n.metricCaffeine,
          glass: scope.settings.liquidGlass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TileSurface(
                color: scheme.surfaceBright,
                radius: AppRadii.extraLarge,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caffeineText(formats, mg ?? 0),
                        style: context.emphasizedTextTheme.displaySmall,
                      ),
                      Text(
                        last == null
                            ? l10n.caffeineNone
                            : l10n.caffeineLast(clockOf(last)),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      BarChart(
                        values: [for (final day in days) data.caffeineOn(day)],
                        labels: [
                          for (final day in days)
                            day.weekday == DateTime.monday ? '${day.day}.' : '',
                        ],
                        selectedIndex: days.length - 1,
                        color: scheme.tertiaryContainer,
                        selectedColor: scheme.tertiary,
                        height: 140,
                      ),
                    ],
                  ),
                ),
              ),
              if (taken.isNotEmpty) SectionTitle(l10n.navToday),
              for (final (index, intake) in taken.indexed)
                ListSegment(
                  first: index == 0,
                  last: index == taken.length - 1,
                  child: SupplementRow(
                    title: data.byKey(intake.key)?.title(l10n) ?? intake.key,
                    line:
                        '${clockOf(intake.at)} · '
                        '${caffeineText(formats, intake.caffeineMg!)}',
                    onTap: () {},
                    trailing: caffeineIcon,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
