import 'package:material_ui/material_ui.dart';

import '../../../app/formatters.dart';
import '../../../app/haptics.dart';
import '../../../data/energy_balance.dart';
import '../../../data/health_controller.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../data/period.dart';
import '../../../data/trend.dart';
import '../../../features/detail/energy_balance_card.dart';
import '../../../features/detail/metric_detail_page.dart' show PeriodKindLabel;
import '../../../features/detail/metric_spec.dart';
import '../../../features/detail/metric_tiles.dart';
import '../../../features/entry/entry_sheet.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_page.dart';

/// The category a measurement belongs to in the look.
MonoCategory monoCategoryOf(Metric metric) => switch (metric) {
  Metric.heartRate || Metric.restingHeartRate => MonoCategory.heart,
  _ => switch (metric.group) {
    MetricGroup.activity => MonoCategory.activity,
    MetricGroup.vitals => MonoCategory.vitals,
    MetricGroup.body => MonoCategory.body,
    MetricGroup.sleep => MonoCategory.sleep,
    MetricGroup.nutrition => MonoCategory.nutrition,
  },
};

/// One measurement over a day, a week, a month, a year or all of it: the
/// number, how it compares with the span before, the chart, what was
/// entered, and the highest and lowest. The same as the standard page, in
/// the look.
class MonoMetricPage extends StatefulWidget {
  const MonoMetricPage({super.key, required this.metric});

  final Metric metric;

  @override
  State<MonoMetricPage> createState() => _MonoMetricPageState();
}

class _MonoMetricPageState extends State<MonoMetricPage> {
  // A weight says little on one day, so its page opens on the week.
  late PeriodKind _kind = widget.metric == Metric.weight
      ? PeriodKind.week
      : PeriodKind.today;
  int _offset = 0;

  void _page(int by) {
    Haptics.selection();
    setState(() => _offset += by);
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ScaffoldMessenger(
      child: ListenableBuilder(
        listenable: Listenable.merge([scope.health, scope.settings]),
        builder: (context, _) {
          final c = MonoCtx.of(context);
          final metric = widget.metric;
          final category = monoCategoryOf(metric);
          final ready =
              c.health.status == HealthStatus.ready && c.health.history != null;
          if (!ready) {
            return MonoSubPage(
              category: category,
              icon: metric.spec.icon,
              categoryLabel: metric.title(c.l10n),
              backLabel: c.l10n.monoBrowse,
              children: const [],
            );
          }
          return _content(context, c);
        },
      ),
    );
  }

  Widget _content(BuildContext context, MonoCtx c) {
    final l10n = c.l10n;
    final formats = c.formats;
    final t = c.t;
    final metric = widget.metric;
    final health = c.health;
    final snapshot = health.snapshot;
    final view = buildPeriod(
      history: health.history!,
      metric: metric,
      kind: _kind,
      today: snapshot.today,
      offset: _offset,
    );
    final dayIndex = view.kind.isDay ? snapshot.indexOf(view.start) : null;
    final hours = dayIndex == null ? null : snapshot.hoursOf(metric, dayIndex);
    final heart = dayIndex != null && metric == Metric.heartRate
        ? snapshot.heart[dayIndex]
        : const <HeartSample>[];
    final known = [for (final b in view.buckets) ?b.value];
    final latest = view.kind == PeriodKind.today && view.headline == null
        ? tileReading(formats, snapshot, metric)
        : null;
    final shown = view.headline ?? latest?.value;
    final trend = metric == Metric.weight;
    final points = trend
        ? trendPoints(history: health.history!, metric: metric, view: view)
        : const <TrendPoint>[];
    final change = trendChange(points);
    final rows = trend && !view.kind.isDay
        ? trendRows(history: health.history!, metric: metric, view: view)
        : const <PeriodBucket>[];
    final kind = metric.entryKind;
    final category = monoCategoryOf(metric);
    final accent = category == MonoCategory.heart ? t.heart : null;

    var low = known.isEmpty ? 0.0 : known.first;
    var high = low;
    for (final value in known) {
      if (value < low) low = value;
      if (value > high) high = value;
    }

    String? comparison() {
      if (latest?.value != null && latest?.note != null) {
        return l10n.lastMeasured(latest!.note!);
      }
      final current = view.headline;
      final previous = view.previous;
      if (current == null || previous == null) return null;
      final span = view.kind.span;
      final difference = current - previous;
      if (metric.format(formats, difference.abs()) ==
          metric.format(formats, 0)) {
        return l10n.comparisonSame(span);
      }
      final value = metric.formatWithUnit(formats, difference.abs());
      return difference > 0
          ? l10n.comparisonMore(value, span)
          : l10n.comparisonLess(value, span);
    }

    final rangeLabel = switch (view.kind) {
      PeriodKind.today || PeriodKind.yesterday => formats.longDate(view.start),
      PeriodKind.week => formats.dayRange(view.start, view.end),
      PeriodKind.month => formats.month(view.start),
      PeriodKind.year => '${view.start.year}',
      PeriodKind.all =>
        view.start.year == view.end.year
            ? '${view.start.year}'
            : l10n.rangeFromTo('${view.start.year}', '${view.end.year}'),
    };
    final axis = switch (view.kind) {
      PeriodKind.week => [
        for (final b in view.buckets) formats.weekdayShort[b.start.weekday - 1],
      ],
      PeriodKind.year => formats.monthInitials,
      PeriodKind.all => [
        for (final b in view.buckets) "'${'${b.start.year}'.substring(2)}",
      ],
      _ => null,
    };
    final said = comparison();
    final statement = shown == null
        ? l10n.noDataInPeriod
        : '${metric.formatWithUnit(formats, shown)}'
              '${change == null ? '' : ' · ${_change(l10n, formats, change)}'}';

    Widget chart() {
      if (view.kind.isDay) {
        if (hours != null) {
          return Column(
            children: [
              MonoBars(
                key: ValueKey(view.start),
                values: hours,
                accent: accent,
                semantics: statement,
                height: 150,
              ),
              MonoAxis([
                for (final hour in const [0, 6, 12, 18, 24])
                  formatClockHour(hour),
              ]),
            ],
          );
        }
        if (heart.length >= 2) {
          return MonoLine(
            key: ValueKey(view.start),
            values: [for (final s in heart) s.bpm.toDouble()],
            color: accent,
            semantics: statement,
            height: 150,
          );
        }
        return const SizedBox.shrink();
      }
      if (known.isEmpty) {
        return SizedBox(
          height: 120,
          child: Center(
            child: Text(l10n.noDataInPeriod, style: MonoType.sub(t)),
          ),
        );
      }
      return Column(
        children: [
          if (points.length >= 2) ...[
            MonoLine(
              key: ValueKey(('line', view.kind, view.start)),
              values: [for (final p in points) p.value],
              goal: c.settings.targetWeightKg,
              semantics: statement,
              height: 150,
            ),
            const SizedBox(height: 18),
          ],
          MonoBars(
            key: ValueKey((view.kind, view.start)),
            values: [for (final b in view.buckets) b.value],
            accent: accent,
            semantics: statement,
            height: points.length >= 2 ? 90 : 150,
            radius: 6,
            gap: view.buckets.length > 20 ? 2 : 6,
          ),
          if (axis != null) MonoAxis(axis),
        ],
      );
    }

    final kinds = PeriodKind.values;
    final children = <Widget>[
      MonoSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonoSegmented(
              labels: [for (final k in kinds) k.tab(l10n)],
              selected: kinds.indexOf(_kind),
              onChanged: (i) => setState(() {
                _kind = kinds[i];
                _offset = 0;
              }),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (view.kind.pages)
                  MonoIconButton(
                    icon: Icons.chevron_left_rounded,
                    label: l10n.earlier,
                    onTap: view.canGoBack ? () => _page(1) : null,
                  ),
                Expanded(
                  child: Text(
                    rangeLabel,
                    textAlign: view.kind.pages
                        ? TextAlign.center
                        : TextAlign.start,
                    style: MonoType.inter(14, 18, FontWeight.w600, t.ink2),
                  ),
                ),
                if (view.kind.pages)
                  MonoIconButton(
                    icon: Icons.chevron_right_rounded,
                    label: l10n.later,
                    onTap: view.canGoForward ? () => _page(-1) : null,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            MonoStat(
              label: latest?.value != null && latest?.note != null
                  ? l10n.latestValue
                  : view.kind.headline(l10n),
              value: metric.format(formats, shown),
              unit: metric.unitFor(l10n, shown),
            ),
            if (said != null) ...[
              const SizedBox(height: 4),
              Text(said, style: MonoType.label(t)),
            ],
            const SizedBox(height: 20),
            chart(),
          ],
        ),
      ),
      if (metric.note(l10n, fine: health.fineValues) case final note?)
        MonoNote(note),
      if (metric == Metric.activeEnergy &&
          health.fineValues &&
          dayIndex != null)
        if ([
              for (final part in Metric.fineParts)
                health.readValueOn(part, snapshot.dateAt(dayIndex)),
            ]
            case [final workouts?, final steps?])
          MonoBlock(
            title: l10n.finePartsTitle,
            child: MonoList(
              children: [
                MonoPair(
                  label: l10n.finePartWorkouts,
                  value: metric.formatWithUnit(formats, workouts),
                ),
                MonoPair(
                  label: l10n.finePartSteps,
                  value: metric.formatWithUnit(formats, steps),
                ),
              ],
            ),
          ),
      if (metric == Metric.totalEnergy)
        EnergyBalanceCard(
          balance: energyBalance(
            today: health.today,
            valueOn: health.readValueOn,
          ),
        ),
      if (kind != null && dayIndex != null)
        MonoBlock(
          title: l10n.entries,
          child: MonoEntries(
            entries: snapshot.entriesOn(dayIndex, kind),
            kind: kind,
            health: health,
          ),
        ),
      if (rows.isNotEmpty)
        MonoBlock(
          title: l10n.trendRows,
          child: MonoList(
            children: [
              for (final row in rows)
                MonoPair(
                  label: _rowLabel(c, view, row),
                  value: metric.formatWithUnit(formats, row.value),
                ),
            ],
          ),
        ),
      if (known.length >= 2)
        MonoBlock(
          title: l10n.inPeriod,
          child: MonoList(
            children: [
              MonoPair(
                label: l10n.highest,
                value: metric.formatWithUnit(formats, high),
              ),
              MonoPair(
                label: l10n.lowest,
                value: metric.formatWithUnit(formats, low),
              ),
            ],
          ),
        ),
    ];
    return MonoSubPage(
      category: category,
      icon: metric.spec.icon,
      categoryLabel: metric.title(l10n),
      backLabel: l10n.monoBrowse,
      statement: statement,
      children: children,
    );
  }

  static String _change(AppLocalizations l10n, Formats formats, double change) {
    const metric = Metric.weight;
    if (metric.format(formats, change.abs()) == metric.format(formats, 0)) {
      return l10n.trendSame;
    }
    return change < 0
        ? l10n.trendLost(metric.formatWithUnit(formats, -change))
        : l10n.trendGained(metric.formatWithUnit(formats, change));
  }

  String _rowLabel(MonoCtx c, PeriodView view, PeriodBucket row) {
    final formats = c.formats;
    final today = c.health.snapshot.today;
    return switch (view.kind) {
      PeriodKind.month =>
        !today.isBefore(row.start) && !today.isAfter(row.end)
            ? c.l10n.thisWeek
            : row.start == row.end
            ? formats.shortDate(row.start)
            : formats.dayRange(row.start, row.end),
      PeriodKind.year => formats.month(row.start),
      PeriodKind.all => '${row.start.year}',
      _ => formats.longDate(row.start),
    };
  }
}

/// The entries of one day. Those Pulse wrote can be changed and deleted;
/// those of other apps show their source, as Health Connect keeps them.
class MonoEntries extends StatelessWidget {
  const MonoEntries({
    super.key,
    required this.entries,
    required this.kind,
    required this.health,
  });

  final List<HealthEntry> entries;
  final EntryKind kind;
  final HealthController health;

  String _describe(Formats formats, EntryDraft draft) => switch (draft.kind) {
    EntryKind.water => '${formats.integer(draft.amount.round())} ml',
    EntryKind.weight => '${formats.decimal(draft.amount)} kg',
    EntryKind.meal => [
      ?draft.name,
      '${formats.integer(draft.amount.round())} kcal',
    ].join(' · '),
  };

  Future<void> _delete(BuildContext context, HealthEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await health.deleteEntry(entry);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
      return;
    }
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.entryDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            // Health Connect has no undo; the entry is written again.
            onPressed: () async {
              try {
                await health.addEntry(entry.draft);
              } on Exception {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.restoreFailed)),
                );
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return MonoList(
      children: [
        if (entries.isEmpty)
          Text(
            l10n.noEntriesThatDay,
            style: MonoType.sub(MonoCtx.of(context).t),
          ),
        for (final entry in entries)
          Row(
            children: [
              Expanded(
                child: MonoPair(
                  label: _describe(formats, entry.draft),
                  value: '',
                  sub: [
                    formatClock(
                      entry.draft.time.hour * 60 + entry.draft.time.minute,
                    ),
                    entry.isOwn ? 'Pulse' : entry.source,
                  ].join(' · '),
                ),
              ),
              if (entry.isOwn) ...[
                MonoIconButton(
                  icon: Icons.edit_rounded,
                  label: l10n.edit,
                  onTap: () => showEntrySheet(context, kind, existing: entry),
                ),
                MonoIconButton(
                  icon: Icons.delete_outline_rounded,
                  label: l10n.delete,
                  onTap: () => _delete(context, entry),
                ),
              ],
            ],
          ),
        MonoRow(
          title: kind.addTitle(l10n),
          leading: Icon(Icons.add_rounded, color: MonoCtx.of(context).t.ink),
          onTap: () => showEntrySheet(context, kind),
        ),
      ],
    );
  }
}
