import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/supplements.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/tile_surface.dart';
import 'supplement_edit_sheet.dart';
import 'supplement_format.dart';
import 'supplement_row.dart';

/// Weeks the calendar of a supplement shows.
const int _weeks = 6;

/// Times taken that the page lists, newest first.
const int _listed = 30;

/// "heute, 08:05" at the start of a line.
String _capitalised(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// How one supplement went: the days in a row, the last month, a calendar
/// of the last weeks and each time it was taken.
class SupplementDetailPage extends StatelessWidget {
  const SupplementDetailPage({super.key, required this.supplementKey});

  final String supplementKey;

  Future<void> _untake(BuildContext context, Intake intake, String name) async {
    final supplements = AppScope.of(context).supplements;
    final l10n = Formats.of(context).l10n;
    final messenger = ScaffoldMessenger.of(context);
    await supplements.untake(intake);
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.supplementUntook(name)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => supplements.restore(intake),
          ),
        ),
      );
  }

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
        final supplement = data.byKey(supplementKey);
        final now = scope.supplements.now;
        final today = DateTime(now.year, now.month, now.day);
        final name = supplement?.title(l10n) ?? supplementKey;
        final rate = data.rate(supplementKey, today);
        final taken = data.intakesOf(supplementKey).reversed.take(_listed);
        return SubPage(
          title: name,
          glass: scope.settings.liquidGlass,
          action: supplement == null || supplement.removed
              ? null
              : IconButton(
                  tooltip: l10n.supplementEdit,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final key = supplement.key;
                    await showSupplementEditSheet(
                      context,
                      existing: supplement,
                    );
                    // Removed in the sheet: nothing is left to show here.
                    if (scope.supplements.data.byKey(key)?.removed ?? true) {
                      navigator.pop();
                    }
                  },
                  icon: const Icon(Icons.tune_rounded),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 132,
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: l10n.supplementStreak,
                        icon: Icons.local_fire_department_rounded,
                        shape: Shapes.sunny,
                        tone: Tone.tertiary,
                        value: l10n.supplementStreakDays(
                          data.streak(supplementKey, today),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        label: l10n.supplementRate,
                        icon: Icons.calendar_month_rounded,
                        shape: Shapes.c6SidedCookie,
                        value: l10n.supplementRateDays(
                          formats.integer(rate.taken),
                          formats.integer(rate.of),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TileSurface(
                color: scheme.surfaceBright,
                radius: AppRadii.extraLarge,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _Calendar(
                    days: data.daysOf(supplementKey),
                    today: today,
                    weekdays: formats.weekdayShort,
                  ),
                ),
              ),
              SectionTitle(l10n.supplementIntakes),
              if (taken.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    l10n.supplementNoIntakes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final (index, intake) in taken.indexed)
                ListSegment(
                  first: index == 0,
                  last: index == taken.length - 1,
                  child: SupplementRow(
                    title: _capitalised(
                      '${formats.relativeDay(intake.at, today)}, '
                      '${clockOf(intake.at)}',
                    ),
                    line:
                        doseText(formats, intake.amount, intake.unit) ??
                        l10n.supplementTaken,
                    onTap: () {},
                    trailing: Icons.delete_outline_rounded,
                    onTrailing: () => _untake(context, intake, name),
                    trailingLabel: l10n.delete,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The last [_weeks] weeks, Monday to Sunday, a filled dot for each day
/// the supplement was taken on.
class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.days,
    required this.today,
    required this.weekdays,
  });

  final Set<DateTime> days;
  final DateTime today;
  final List<String> weekdays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The Monday of the first week shown.
    final first = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1) - 7 * (_weeks - 1),
    );
    return Column(
      children: [
        Row(
          children: [
            for (final name in weekdays)
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        for (var week = 0; week < _weeks; week++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: Center(
                      child: _Dot(
                        day: DateTime(
                          first.year,
                          first.month,
                          first.day + week * 7 + weekday,
                        ),
                        today: today,
                        days: days,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.day, required this.today, required this.days});

  final DateTime day;
  final DateTime today;
  final Set<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final taken = days.contains(day);
    final future = day.isAfter(today);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: taken
            ? scheme.tertiary
            : future
            ? Colors.transparent
            : scheme.surfaceContainerHighest,
        border: day == today
            ? Border.all(color: scheme.tertiary, width: 2)
            : null,
      ),
      child: Text(
        '${day.day}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: taken
              ? scheme.onTertiary
              : future
              ? scheme.outlineVariant
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
