import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/energy_balance.dart';
import '../../data/health_controller.dart';
import '../../data/health_history.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/day_switcher.dart';
import '../../widgets/detail_sections.dart';
import '../../widgets/entrance.dart';
import '../../widgets/floating_tab_bar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/sub_page.dart';
import '../detail/energy_balance_card.dart';
import '../detail/metric_detail_page.dart';
import '../detail/metric_spec.dart';

/// What the body burned on a day and what was eaten: the balance of the
/// two, what the burn is made of, how the active part went over the day,
/// the nutrients and meals, and what the person really burns by food and
/// weight. The bar at its bottom leads to other days and, under "Weitere",
/// to the weeks, months and years of the burn.
class CaloriesDetailPage extends StatefulWidget {
  const CaloriesDetailPage({super.key, required this.date});

  /// The day the page opens on.
  final DateTime date;

  @override
  State<CaloriesDetailPage> createState() => _CaloriesDetailPageState();
}

class _CaloriesDetailPageState extends State<CaloriesDetailPage> {
  late DateTime _date = widget.date;

  void _show(DateTime day) {
    if (day == _date) return;
    setState(() => _date = day);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final l10n = Formats.of(context).l10n;
    return PageAccent.activity(
      child: ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) => SubPage(
          title: l10n.caloriesInDetail,
          glass: scope.settings.liquidGlass,
          // The page ends above the floating bar.
          bottomPadding:
              16 +
              FloatingTabBar.height +
              24 +
              MediaQuery.paddingOf(context).bottom,
          overlay: health.status != HealthStatus.ready
              ? null
              : Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  child: Center(
                    child: DaySwitcher(
                      today: health.today,
                      selected: _date,
                      earlier: _earlier(health),
                      glass: scope.settings.liquidGlass,
                      onSelected: _show,
                      extras: [
                        DayExtra(
                          label: l10n.caloriesHistory,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MetricDetailPage(
                                metric: Metric.totalEnergy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          child: health.status == HealthStatus.ready
              ? _content(context, health)
              : const SizedBox(
                  height: 240,
                  child: Center(child: M3ELoadingIndicator()),
                ),
        ),
      ),
    );
  }

  /// The days before yesterday that the menu of the bar offers.
  List<DateTime> _earlier(HealthController health) {
    final before = dayKey(health.today) - 1;
    return [
      for (final day in health.days.reversed)
        if (dayKey(day) < before) day,
    ].take(DaySwitcher.menuDays).toList();
  }

  Widget _content(BuildContext context, HealthController health) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final snapshot = health.snapshot;
    final index = snapshot.indexOf(_date);
    double? value(Metric metric) =>
        index == null ? null : snapshot.value(metric, index);
    final burned = value(Metric.totalEnergy) ?? value(Metric.fineTotalEnergy);
    final eaten = value(Metric.energyIntake);
    final active = value(Metric.activeEnergy) ?? value(Metric.fineActiveEnergy);
    final parts = [
      (Metric.basalEnergy.title(l10n), value(Metric.basalEnergy)),
      (Metric.activeEnergy.title(l10n), active),
      (l10n.finePartWorkouts, value(Metric.fineWorkoutEnergy)),
      (l10n.finePartSteps, value(Metric.fineStepEnergy)),
    ];
    final hours = index == null
        ? null
        : snapshot.hoursOf(Metric.activeEnergy, index) ??
              snapshot.hoursOf(Metric.fineActiveEnergy, index);
    final meals = index == null
        ? const <HealthEntry>[]
        : snapshot.entriesOn(index, EntryKind.meal);
    final macros = [
      (l10n.metricCarbs, value(Metric.carbs), scheme.primary),
      (l10n.metricProtein, value(Metric.protein), scheme.secondary),
      (l10n.metricFat, value(Metric.fat), scheme.tertiary),
    ];
    final grams = macros.fold(0.0, (sum, m) => sum + (m.$2 ?? 0));
    final quiet = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Widget figure(String label, double? kcal, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: quiet),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kcal == null
                  ? '–'
                  : Metric.totalEnergy.formatWithUnit(formats, kcal),
              style: type.hero(
                context.emphasizedTextTheme.headlineMedium?.copyWith(
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    String net(double kcal) =>
        '${formats.integer(kcal.abs().round())} ${Metric.totalEnergy.unit}';

    final sections = <Widget>[
      if (burned == null && eaten == null)
        SurfaceCard(child: EmptyNote(l10n.caloriesNoData))
      else
        TitledSection(
          title: l10n.caloriesBalance,
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    figure(l10n.caloriesBurned, burned, scheme.secondary),
                    const SizedBox(width: 16),
                    figure(l10n.caloriesEaten, eaten, scheme.tertiary),
                  ],
                ),
                if (burned != null && eaten != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          eaten > burned
                              ? l10n.caloriesSurplus
                              : l10n.caloriesDeficit,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      DifferenceText(text: net(eaten - burned), good: null),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      if (parts.any((part) => part.$2 != null))
        TitledSection(
          title: l10n.caloriesBurnParts,
          child: SegmentGroup(
            children: [
              for (final (label, kcal) in parts)
                if (kcal != null)
                  _PartRow(
                    label: label,
                    text: Metric.totalEnergy.formatWithUnit(formats, kcal),
                    share: burned == null || burned <= 0
                        ? 0
                        : (kcal / burned).clamp(0, 1).toDouble(),
                    color: scheme.secondary,
                  ),
            ],
          ),
        ),
      if (hours != null)
        TitledSection(
          title: l10n.caloriesOverDay,
          child: SurfaceCard(
            child: Column(
              children: [
                BarChart(
                  key: ValueKey(_date),
                  values: hours,
                  color: scheme.secondary,
                  selectedColor: scheme.secondary,
                  height: 160,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final hour in const [0, 6, 12, 18, 24])
                      Text(formatClockHour(hour), style: quiet),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (grams > 0 || meals.isNotEmpty)
        TitledSection(
          title: l10n.caloriesMeals,
          child: SegmentGroup(
            children: [
              if (grams > 0) _MacroRow(macros: macros, grams: grams),
              for (final meal in meals)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meal.draft.name ?? Metric.energyIntake.title(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      Metric.energyIntake.formatWithUnit(
                        formats,
                        meal.draft.amount,
                      ),
                      style: type.figure(theme.textTheme.titleMedium),
                    ),
                  ],
                ),
            ],
          ),
        ),
      EnergyBalanceCard(
        balance: energyBalance(
          today: health.today,
          valueOn: health.readValueOn,
        ),
      ),
      if (Metric.totalEnergy.note(l10n, fine: health.fineValues)
          case final note?)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(
            note,
            style: type.aside(
              theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text(
            formats.longDate(_date),
            style: type.aside(
              theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        for (var i = 0; i < sections.length; i++)
          // Keyed by the day, so they come in again when it changes.
          Entrance(key: ValueKey((_date, i)), order: i, child: sections[i]),
      ],
    );
  }
}

/// One part of the burn: its name and kcal, and a bar for its share.
class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.label,
    required this.text,
    required this.share,
    required this.color,
  });

  final String label;
  final String text;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(
              text,
              style: AppType.of(context).figure(theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 10,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

/// The three nutrients as one bar, each as long as its share of the grams,
/// with a line for each below it.
class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.macros, required this.grams});

  final List<(String, double?, Color)> macros;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final type = AppType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              spacing: 2,
              children: [
                for (final (_, value, color) in macros)
                  if ((value ?? 0) > 0)
                    Expanded(
                      flex: (value! / grams * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: color),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final (label, value, color) in macros)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
                Text(
                  value == null ? '–' : '${formats.integer(value.round())} g',
                  style: type.figure(theme.textTheme.labelLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
