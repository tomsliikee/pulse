import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/supplement_controller.dart';
import '../../data/supplements.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/tile_surface.dart';
import 'supplement_detail_page.dart';
import 'supplement_format.dart';
import 'supplement_row.dart';
import 'supplements_page.dart';

/// The user's supplements on the Today page: which are taken today and
/// which are open. A tap on the circle of one notes it as taken now, or
/// takes that back.
class SupplementsCard extends StatelessWidget {
  const SupplementsCard({super.key, required this.simple});

  /// Whether only the count is shown, without a row for each.
  final bool simple;

  static const double _header = 84;
  static const double _row = 52;

  /// The height with [count] supplements on the list.
  static double heightFor(int count, {required bool simple}) =>
      simple || count == 0 ? _header : _header + count * _row + 12;

  Future<void> _toggle(
    BuildContext context,
    SupplementController supplements,
    Supplement supplement,
    Intake? taken,
  ) async {
    final l10n = Formats.of(context).l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = supplement.title(l10n);
    if (taken == null) {
      Haptics.confirm();
      await supplements.take(supplement);
      return;
    }
    Haptics.tap();
    await supplements.untake(taken);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.supplementUntook(name)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => supplements.restore(taken),
          ),
        ),
      );
  }

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
        final data = supplements.data;
        final mine = data.mine;
        final today = supplements.now;
        final taken = {
          for (final supplement in mine)
            supplement.key: data.takenOn(supplement.key, today),
        };
        final done = taken.values.nonNulls.length;
        return TileSurface(
          color: scheme.surfaceBright,
          radius: AppRadii.extraLargeIncreased,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    Haptics.tap();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SupplementsPage(),
                      ),
                    );
                  },
                  child: SizedBox(
                    height: _header,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          ShapeBadge(
                            shape: supplementShape,
                            icon: supplementIcon,
                            size: 44,
                            color: scheme.tertiary,
                            iconColor: scheme.onTertiary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.supplements,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (mine.isEmpty)
                            Flexible(
                              child: Text(
                                l10n.supplementsChoose,
                                maxLines: 2,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            Text(
                              l10n.supplementsTakenOf(
                                formats.integer(done),
                                formats.integer(mine.length),
                              ),
                              style: context.emphasizedTextTheme.titleLarge,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!simple)
                  for (final supplement in mine)
                    _Row(
                      height: _row,
                      title: supplement.title(l10n),
                      line: switch (taken[supplement.key]) {
                        final intake? => l10n.supplementTakenAt(
                          clockOf(intake.at),
                        ),
                        null =>
                          doseText(
                                formats,
                                supplement.amount,
                                supplement.unit,
                              ) ??
                              l10n.supplementOpen,
                      },
                      taken: taken[supplement.key] != null,
                      toggleLabel: taken[supplement.key] == null
                          ? l10n.supplementTakenNow
                          : l10n.supplementUntook(supplement.title(l10n)),
                      onToggle: () => _toggle(
                        context,
                        supplements,
                        supplement,
                        taken[supplement.key],
                      ),
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SupplementDetailPage(
                            supplementKey: supplement.key,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.height,
    required this.title,
    required this.line,
    required this.taken,
    required this.toggleLabel,
    required this.onToggle,
    required this.onOpen,
  });

  final double height;
  final String title;
  final String line;
  final bool taken;
  final String toggleLabel;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          const SizedBox(width: 10),
          IconButton(
            tooltip: toggleLabel,
            onPressed: onToggle,
            icon: Icon(
              taken
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 28,
              color: taken ? scheme.tertiary : scheme.outline,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                Haptics.tap();
                onOpen();
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: taken
                                  ? scheme.tertiary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
        ],
      ),
    );
  }
}
