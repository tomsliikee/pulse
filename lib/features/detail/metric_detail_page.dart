import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/period.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/floating_tab_bar.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/page_header.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../entry/entry_sheet.dart';
import 'metric_spec.dart';
import 'metric_tiles.dart';

extension PeriodKindLabel on PeriodKind {
  String get tab => switch (this) {
    PeriodKind.today => 'Heute',
    PeriodKind.yesterday => 'Gestern',
    PeriodKind.week => 'Woche',
    PeriodKind.month => 'Monat',
    PeriodKind.year => 'Jahr',
    PeriodKind.all => 'Gesamt',
  };

  /// What the large number is for this span.
  String get headline => switch (this) {
    PeriodKind.today => 'Heute',
    PeriodKind.yesterday => 'Gestern',
    PeriodKind.week => 'Wochenschnitt pro Tag',
    PeriodKind.month => 'Monatsschnitt pro Tag',
    PeriodKind.year => 'Jahresschnitt pro Tag',
    PeriodKind.all => 'Schnitt pro Tag',
  };

  /// Completes "… als …" when comparing with the span before.
  String get before => switch (this) {
    PeriodKind.today || PeriodKind.yesterday => 'am Tag davor',
    PeriodKind.week => 'in der Woche davor',
    PeriodKind.month => 'im Monat davor',
    PeriodKind.year => 'im Jahr davor',
    PeriodKind.all => '',
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
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final AppScope(:health, :settings) = AppScope.of(context);
    // The page lies on top of the shell, which stays built beneath it. Its own
    // messenger keeps a snackbar from appearing on both scaffolds.
    return ScaffoldMessenger(
      child: Scaffold(
        body: ListenableBuilder(
          listenable: Listenable.merge([health, settings]),
          builder: (context, _) {
            final ready =
                health.status == HealthStatus.ready && health.history != null;
            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverAppBar.large(
                      backgroundColor: theme.scaffoldBackgroundColor,
                      surfaceTintColor: theme.scaffoldBackgroundColor,
                      title: Text(
                        widget.metric.spec.title,
                        style: context.emphasizedTextTheme.headlineMedium,
                      ),
                    ),
                    SliverPadding(
                      // The page ends above the floating tabs.
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        16 + FloatingTabBar.height + 24 + media.padding.bottom,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: ready
                            ? _content(context, health)
                            : const SizedBox(
                                height: 240,
                                child: Center(child: M3ELoadingIndicator()),
                              ),
                      ),
                    ),
                  ],
                ),
                if (ready)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16 + media.padding.bottom,
                    child: Center(
                      child: FloatingTabBar(
                        labels: [
                          for (final kind in PeriodKind.values) kind.tab,
                        ],
                        selectedIndex: _kind.index,
                        glass: settings.liquidGlass,
                        onSelected: (index) => _show(PeriodKind.values[index]),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _rangeLabel(PeriodView view) => switch (view.kind) {
    PeriodKind.today || PeriodKind.yesterday => formatLongDate(view.start),
    PeriodKind.week => formatDayRange(view.start, view.end),
    PeriodKind.month => formatMonth(view.start),
    PeriodKind.year => '${view.start.year}',
    PeriodKind.all =>
      view.start.year == view.end.year
          ? '${view.start.year}'
          : '${view.start.year} bis ${view.end.year}',
  };

  String _bucketLabel(PeriodView view, PeriodBucket bucket) =>
      switch (view.kind) {
        PeriodKind.year => formatMonth(bucket.start),
        PeriodKind.all => '${bucket.start.year}',
        _ => formatLongDate(bucket.start),
      };

  List<String>? _axisLabels(PeriodView view) => switch (view.kind) {
    PeriodKind.week => [
      for (final b in view.buckets) weekdayShort[b.start.weekday - 1],
    ],
    PeriodKind.year => monthInitials,
    PeriodKind.all => [
      for (final b in view.buckets) "'${'${b.start.year}'.substring(2)}",
    ],
    _ => null,
  };

  /// "412 mehr als in der Woche davor", or null without a span to compare.
  String? _comparison(PeriodView view) {
    final current = view.headline;
    final previous = view.previous;
    if (current == null || previous == null) return null;
    final metric = widget.metric;
    final difference = current - previous;
    final shown = metric.format(difference.abs());
    if (shown == metric.format(0)) return 'Gleich wie ${view.kind.before}';
    return '${metric.formatWithUnit(difference.abs())} '
        '${difference > 0 ? 'mehr' : 'weniger'} als ${view.kind.before}';
  }

  Widget _content(BuildContext context, HealthController health) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
        ? tileReading(snapshot, metric)
        : null;
    final latestNote = latest?.note;
    final comparison = bucket != null
        ? null
        : latest?.value != null && latestNote != null
        ? 'Zuletzt gemessen: $latestNote'
        : _comparison(view);
    final kind = metric.entryKind;

    var low = known.isEmpty ? 0.0 : known.first;
    var high = low;
    for (final value in known) {
      if (value < low) low = value;
      if (value > high) high = value;
    }

    Widget row(String label, double value) => M3EListItem(
      headline: Text(label),
      trailing: Text(
        metric.formatWithUnit(value),
        style: context.emphasizedTextTheme.titleMedium,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShapeBadge(
                    shape: spec.shape,
                    icon: spec.icon,
                    size: 56,
                    color: colors.accent,
                    iconColor: scheme.surfaceBright,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bucket != null
                              ? _bucketLabel(view, bucket)
                              : latest?.value != null && latestNote != null
                              ? 'Letzter Wert'
                              : view.kind.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            metric.formatWithUnit(
                              bucket == null
                                  ? view.headline ?? latest?.value
                                  : bucket.value,
                            ),
                            maxLines: 1,
                            style: context.emphasizedTextTheme.headlineLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (view.kind.pages)
                    IconButton(
                      tooltip: 'Früher',
                      onPressed: view.canGoBack ? () => _page(1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                  Expanded(
                    child: Text(
                      _rangeLabel(view),
                      textAlign: view.kind.pages
                          ? TextAlign.center
                          : TextAlign.start,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (view.kind.pages)
                    IconButton(
                      tooltip: 'Später',
                      onPressed: view.canGoForward ? () => _page(-1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                ],
              ),
              if (comparison != null) ...[
                const SizedBox(height: 4),
                Text(comparison, style: muted),
              ],
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
                  const SizedBox(
                    height: 96,
                    child: EmptyNote('Keine Daten an diesem Tag.'),
                  ),
              ] else if (known.isEmpty)
                const SizedBox(
                  height: 180,
                  child: EmptyNote('Keine Daten in diesem Zeitraum.'),
                )
              else
                BarChart(
                  // Bars grow again for every span.
                  key: ValueKey((view.kind, view.start)),
                  values: [for (final b in view.buckets) b.value],
                  labels: _axisLabels(view),
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
        if (kind != null && dayIndex != null) ...[
          const SectionTitle('Einträge'),
          _Entries(
            entries: snapshot.entriesOn(dayIndex, kind),
            kind: kind,
            health: health,
          ),
        ],
        if (known.length >= 2) ...[
          const SectionTitle('Im Zeitraum'),
          M3ESegmentedColumn(
            color: scheme.surfaceBright,
            children: [row('Höchstwert', high), row('Tiefstwert', low)],
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

  String _describe(EntryDraft draft) => switch (draft.kind) {
    EntryKind.water => '${formatInt(draft.amount.round())} ml',
    EntryKind.weight => '${formatDecimal(draft.amount)} kg',
    EntryKind.meal => [
      ?draft.name,
      '${formatInt(draft.amount.round())} kcal',
    ].join(' · '),
  };

  Future<void> _delete(BuildContext context, HealthEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await health.deleteEntry(entry);
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Löschen fehlgeschlagen')),
      );
      return;
    }
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Eintrag gelöscht'),
          action: SnackBarAction(
            label: 'Rückgängig',
            // Health Connect has no undo; the entry is written again.
            onPressed: () async {
              try {
                await health.addEntry(entry.draft);
              } on Exception {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Wiederherstellen fehlgeschlagen'),
                  ),
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
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            const SizedBox(
              height: 72,
              child: EmptyNote('Keine Einträge an diesem Tag.'),
            ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _describe(entry.draft),
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
                      tooltip: 'Bearbeiten',
                      onPressed: () =>
                          showEntrySheet(context, kind, existing: entry),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: 'Löschen',
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
              child: Text('${kind.label} eintragen'),
            ),
          ),
        ],
      ),
    );
  }
}
