import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/period.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/entrance.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/floating_tab_bar.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/page_header.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../entry/entry_sheet.dart';
import 'metric_spec.dart';
import 'metric_tiles.dart';
import '../../l10n/generated/app_localizations.dart';

extension PeriodKindLabel on PeriodKind {
  String tab(AppLocalizations l10n) => switch (this) {
    PeriodKind.today => l10n.navToday,
    PeriodKind.yesterday => l10n.periodYesterday,
    PeriodKind.week => l10n.periodWeek,
    PeriodKind.month => l10n.periodMonth,
    PeriodKind.year => l10n.periodYear,
    PeriodKind.all => l10n.periodAll,
  };

  /// What the large number is for this span.
  String headline(AppLocalizations l10n) => switch (this) {
    PeriodKind.today => l10n.navToday,
    PeriodKind.yesterday => l10n.periodYesterday,
    PeriodKind.week => l10n.headlineWeek,
    PeriodKind.month => l10n.headlineMonth,
    PeriodKind.year => l10n.headlineYear,
    PeriodKind.all => l10n.headlineAll,
  };

  /// Names the span before this one in the comparison messages, which hold
  /// one whole sentence for each.
  String get span => switch (this) {
    PeriodKind.today || PeriodKind.yesterday => 'day',
    PeriodKind.week => 'week',
    PeriodKind.month => 'month',
    PeriodKind.year || PeriodKind.all => 'year',
  };
}

/// One measurement over a day, a week, a month, a year or everything that
/// has been collected, chosen with the tabs floating at the bottom. For what the app can
/// record itself, a day also lists its single entries.
class MetricDetailPage extends StatefulWidget {
  const MetricDetailPage({super.key, required this.metric});

  final Metric metric;

  @override
  State<MetricDetailPage> createState() => _MetricDetailPageState();
}

class _MetricDetailPageState extends State<MetricDetailPage> {
  PeriodKind _kind = PeriodKind.today;

  /// How many spans back from the current one.
  int _offset = 0;
  int? _bucket;

  void _show(PeriodKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _offset = 0;
      _bucket = null;
    });
  }

  void _page(int by) {
    Haptics.selection();
    setState(() {
      _offset += by;
      _bucket = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final AppScope(:health, :settings) = AppScope.of(context);
    // The page lies on top of the shell, which stays built beneath it. Its own
    // messenger keeps a snackbar from appearing on both scaffolds.
    final group = widget.metric.group;
    return ScaffoldMessenger(
      child: PageAccent(
        // The page keeps the look of the main page its metric belongs to.
        tone: switch (group) {
          MetricGroup.activity => Tone.secondary,
          MetricGroup.sleep => Tone.tertiary,
          MetricGroup.vitals => Tone.error,
          _ => Tone.primary,
        },
        family: switch (group) {
          MetricGroup.activity => ShapeFamily.activity,
          MetricGroup.sleep => ShapeFamily.sleep,
          MetricGroup.vitals => ShapeFamily.heart,
          _ => ShapeFamily.day,
        },
        child: ListenableBuilder(
          listenable: Listenable.merge([health, settings]),
          builder: (context, _) {
            final ready =
                health.status == HealthStatus.ready && health.history != null;
            return SubPage(
              title: widget.metric.title(l10n),
              glass: settings.liquidGlass,
              // The page ends above the floating tabs.
              bottomPadding:
                  16 + FloatingTabBar.height + 24 + media.padding.bottom,
              overlay: !ready
                  ? null
                  : Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16 + media.padding.bottom,
                      child: Center(
                        child: FloatingTabBar(
                          labels: [
                            for (final kind in PeriodKind.values)
                              kind.tab(l10n),
                          ],
                          selectedIndex: _kind.index,
                          glass: settings.liquidGlass,
                          onSelected: (index) =>
                              _show(PeriodKind.values[index]),
                        ),
                      ),
                    ),
              child: ready
                  ? _content(context, health)
                  : const SizedBox(
                      height: 240,
                      child: Center(child: M3ELoadingIndicator()),
                    ),
            );
          },
        ),
      ),
    );
  }

  String _rangeLabel(Formats formats, PeriodView view) => switch (view.kind) {
    PeriodKind.today || PeriodKind.yesterday => formats.longDate(view.start),
    PeriodKind.week => formats.dayRange(view.start, view.end),
    PeriodKind.month => formats.month(view.start),
    PeriodKind.year => '${view.start.year}',
    PeriodKind.all =>
      view.start.year == view.end.year
          ? '${view.start.year}'
          : formats.l10n.rangeFromTo('${view.start.year}', '${view.end.year}'),
  };

  String _bucketLabel(Formats formats, PeriodView view, PeriodBucket bucket) =>
      switch (view.kind) {
        PeriodKind.year => formats.month(bucket.start),
        PeriodKind.all => '${bucket.start.year}',
        _ => formats.longDate(bucket.start),
      };

  List<String>? _axisLabels(Formats formats, PeriodView view) =>
      switch (view.kind) {
        PeriodKind.week => [
          for (final b in view.buckets)
            formats.weekdayShort[b.start.weekday - 1],
        ],
        PeriodKind.year => formats.monthInitials,
        PeriodKind.all => [
          for (final b in view.buckets) "'${'${b.start.year}'.substring(2)}",
        ],
        _ => null,
      };

  /// "412 mehr als in der Woche davor", or null without a span to compare.
  String? _comparison(Formats formats, PeriodView view) {
    final current = view.headline;
    final previous = view.previous;
    if (current == null || previous == null) return null;
    final metric = widget.metric;
    final l10n = formats.l10n;
    final span = view.kind.span;
    final difference = current - previous;
    final shown = metric.format(formats, difference.abs());
    if (shown == metric.format(formats, 0)) return l10n.comparisonSame(span);
    final value = metric.formatWithUnit(formats, difference.abs());
    return difference > 0
        ? l10n.comparisonMore(value, span)
        : l10n.comparisonLess(value, span);
  }

  Widget _content(BuildContext context, HealthController health) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final metric = widget.metric;
    final spec = metric.spec;
    final snapshot = health.snapshot;
    final colors = scheme.tone(spec.tone);
    final view = buildPeriod(
      history: health.history!,
      metric: metric,
      kind: _kind,
      today: snapshot.today,
      offset: _offset,
    );
    final bucket = switch (_bucket) {
      final index? when index < view.buckets.length => view.buckets[index],
      _ => null,
    };
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final dayIndex = view.kind.isDay ? snapshot.indexOf(view.start) : null;
    final hours = dayIndex == null ? null : snapshot.hoursOf(metric, dayIndex);
    final heart = dayIndex != null && metric == Metric.heartRate
        ? snapshot.heart[dayIndex]
        : const <HeartSample>[];
    final known = [for (final b in view.buckets) ?b.value];
    // A measurement taken now and then still holds on a day without one.
    final latest = view.kind == PeriodKind.today && view.headline == null
        ? tileReading(formats, snapshot, metric)
        : null;
    final latestNote = latest?.note;
    final comparison = bucket != null
        ? null
        : latest?.value != null && latestNote != null
        ? l10n.lastMeasured(latestNote)
        : _comparison(formats, view);
    final kind = metric.entryKind;

    var low = known.isEmpty ? 0.0 : known.first;
    var high = low;
    for (final value in known) {
      if (value < low) low = value;
      if (value > high) high = value;
    }

    final type = AppType.of(context);
    final figure = type.hero(context.emphasizedTextTheme.displaySmall);
    Widget row(String label, double value) => Row(
      children: [
        Expanded(
          child: Text(label, style: type.strong(theme.textTheme.titleSmall)),
        ),
        Text(
          metric.formatWithUnit(formats, value),
          style: type.figure(context.emphasizedTextTheme.titleMedium),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The number stands free above the chart, beside the metric's shape.
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Row(
            children: [
              ShapeBadge(
                shape: spec.shape,
                icon: spec.icon,
                size: 72,
                color: colors.accent,
                iconColor: colors.onAccent,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bucket != null
                          ? _bucketLabel(formats, view, bucket)
                          : latest?.value != null && latestNote != null
                          ? l10n.latestValue
                          : view.kind.headline(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: switch (bucket == null
                          ? view.headline ?? latest?.value
                          : bucket.value) {
                        // From the number shown before to the new one.
                        final value? => AnimatedNumber(
                          value: value,
                          format: (current) =>
                              metric.formatWithUnit(formats, current),
                          style: figure,
                        ),
                        null => Text(
                          metric.formatWithUnit(formats, null),
                          maxLines: 1,
                          style: figure,
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (view.kind.pages)
                    IconButton(
                      tooltip: l10n.earlier,
                      onPressed: view.canGoBack ? () => _page(1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                  Expanded(
                    child: Text(
                      _rangeLabel(formats, view),
                      textAlign: view.kind.pages
                          ? TextAlign.center
                          : TextAlign.start,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (view.kind.pages)
                    IconButton(
                      tooltip: l10n.later,
                      onPressed: view.canGoForward ? () => _page(-1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                ],
              ),
              if (comparison != null) ...[
                const SizedBox(height: 4),
                Text(comparison, style: muted),
              ],
              // A day with a value but nothing to draw has the date alone.
              if (!view.kind.isDay ||
                  hours != null ||
                  heart.length >= 2 ||
                  (view.headline == null && latest?.value == null))
                const SizedBox(height: 20),
              if (view.kind.isDay) ...[
                if (hours != null) ...[
                  BarChart(
                    key: ValueKey(view.start),
                    values: hours,
                    color: colors.accent,
                    selectedColor: colors.accent,
                    height: 180,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final hour in const [0, 6, 12, 18, 24])
                        Text(
                          formatClockHour(hour),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ] else if (heart.length >= 2)
                  LineChart(
                    key: ValueKey(view.start),
                    values: [for (final s in heart) s.bpm.toDouble()],
                    color: colors.accent,
                  )
                else if (view.headline == null && latest?.value == null)
                  SizedBox(height: 96, child: EmptyNote(l10n.noDataThatDay)),
              ] else if (known.isEmpty)
                SizedBox(height: 180, child: EmptyNote(l10n.noDataInPeriod))
              else
                BarChart(
                  // Bars grow again for every span.
                  key: ValueKey((view.kind, view.start)),
                  values: [for (final b in view.buckets) b.value],
                  labels: _axisLabels(formats, view),
                  selectedIndex: _bucket,
                  onSelected: (i) =>
                      setState(() => _bucket = _bucket == i ? null : i),
                  color: scheme.secondaryContainer,
                  selectedColor: colors.accent,
                  // A series that barely varies would otherwise show bars of
                  // the same height.
                  baseline: (high - low) < high * 0.4 && low > 0
                      ? low - (high - low) * 0.6
                      : 0,
                  height: 200,
                ),
            ],
          ),
        ),
        if (metric.note(l10n) case final note?)
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
        if (kind != null && dayIndex != null) ...[
          SectionTitle(l10n.entries),
          Entrance(
            order: 1,
            child: _Entries(
              entries: snapshot.entriesOn(dayIndex, kind),
              kind: kind,
              health: health,
            ),
          ),
        ],
        if (known.length >= 2) ...[
          SectionTitle(l10n.inPeriod),
          Entrance(
            order: 2,
            child: SegmentGroup(
              children: [row(l10n.highest, high), row(l10n.lowest, low)],
            ),
          ),
        ],
      ],
    );
  }
}

/// The entries of one day. Entries this app wrote can be edited and deleted;
/// entries of other apps are shown with their source and left alone, because
/// Health Connect does not allow changing another app's records.
class _Entries extends StatelessWidget {
  const _Entries({
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return SegmentGroup(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      children: [
        if (entries.isEmpty)
          SizedBox(height: 72, child: EmptyNote(l10n.noEntriesThatDay)),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _describe(formats, entry.draft),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        [
                          formatClock(
                            entry.draft.time.hour * 60 +
                                entry.draft.time.minute,
                          ),
                          entry.isOwn ? 'Pulse' : entry.source,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.isOwn) ...[
                  IconButton(
                    tooltip: l10n.edit,
                    onPressed: () =>
                        showEntrySheet(context, kind, existing: entry),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: l10n.delete,
                    onPressed: () => _delete(context, entry),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ] else
                  const SizedBox(height: 48),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: M3ETextButton(
            onPressed: () => showEntrySheet(context, kind),
            child: Text(kind.addTitle(l10n)),
          ),
        ),
      ],
    );
  }
}
