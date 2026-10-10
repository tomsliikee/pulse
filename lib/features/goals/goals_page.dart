import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/goals.dart';
import '../../data/health_controller.dart';
import '../../data/health_history.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_type.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/entrance.dart';
import '../../widgets/floating_tab_bar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/wavy_bar.dart';
import 'goal_format.dart';
import '../../l10n/generated/app_localizations.dart';

/// The spans the goals page can show.
enum _Span { day, week, month, year }

/// Every goal the user follows, and whether it was reached: today, over a
/// week or a month day by day, and over a year month by month. Below them
/// the goals are switched on and off and their targets set.
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  _Span _span = _Span.day;

  /// How many spans back from the current one.
  int _offset = 0;

  void _show(_Span span) {
    if (span == _span) return;
    setState(() {
      _span = span;
      _offset = 0;
    });
  }

  void _page(int by) {
    Haptics.selection();
    setState(() => _offset += by);
  }

  /// The first and the last day of the span that is shown.
  (DateTime, DateTime) _range(DateTime today) => switch (_span) {
    _Span.day => (
      DateTime(today.year, today.month, today.day - _offset),
      DateTime(today.year, today.month, today.day - _offset),
    ),
    _Span.week => () {
      final monday = weekStart(today);
      final from = DateTime(
        monday.year,
        monday.month,
        monday.day - 7 * _offset,
      );
      return (from, DateTime(from.year, from.month, from.day + 6));
    }(),
    _Span.month => (
      DateTime(today.year, today.month - _offset),
      DateTime(today.year, today.month - _offset + 1, 0),
    ),
    _Span.year => (
      DateTime(today.year - _offset),
      DateTime(today.year - _offset, 12, 31),
    ),
  };

  String _rangeLabel(Formats formats, DateTime from, DateTime to) =>
      switch (_span) {
        _Span.day => formats.longDate(from),
        _Span.week => formats.dayRange(from, to),
        _Span.month => formats.month(from),
        _Span.year => '${from.year}',
      };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final AppScope(:health, :settings) = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([health, settings]),
      builder: (context, _) {
        final ready = health.status == HealthStatus.ready;
        return SubPage(
          title: l10n.goals,
          glass: settings.liquidGlass,
          // The page ends above the floating tabs.
          bottomPadding: 16 + FloatingTabBar.height + 24 + media.padding.bottom,
          overlay: !ready
              ? null
              : Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + media.padding.bottom,
                  child: Center(
                    child: FloatingTabBar(
                      labels: [
                        l10n.navToday,
                        l10n.periodWeek,
                        l10n.periodMonth,
                        l10n.periodYear,
                      ],
                      selectedIndex: _span.index,
                      glass: settings.liquidGlass,
                      onSelected: (index) => _show(_Span.values[index]),
                    ),
                  ),
                ),
          child: ready
              ? _content(context, health, settings)
              : const SizedBox(
                  height: 240,
                  child: Center(child: M3ELoadingIndicator()),
                ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    HealthController health,
    SettingsController settings,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final today = health.today;
    final data = goalDataOf(health, settings);
    final (from, to) = _range(today);
    final days = health.days;
    // Back as far as the app has days for.
    final canGoBack = days.isNotEmpty && dayKey(from) > dayKey(days.first);

    final cards = <Widget>[
      for (final goal in settings.goals)
        _GoalCard(
          // A new card per span, so its bars and marks come in afresh.
          key: ValueKey((goal, _span, _offset)),
          goal: goal,
          target: settings.goalTarget(goal),
          span: _span,
          from: from,
          to: to,
          today: today,
          data: data,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.earlier,
              onPressed: canGoBack ? () => _page(1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                _rangeLabel(formats, from, to),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: l10n.later,
              onPressed: _offset > 0 ? () => _page(-1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (cards.isEmpty)
          SurfaceCard(child: EmptyNote(l10n.goalsNone))
        else ...[
          // Keyed by what is shown, so the segments come in again for
          // another span.
          SegmentGroup(key: cards.first.key, children: cards),
          if (_span == _Span.week || _span == _Span.month)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                l10n.goalLegend,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        SectionTitle(l10n.goalsCustomize),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            l10n.goalsCustomizeNote,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final group in GoalGroup.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              group.label(l10n),
              style: AppType.of(context).label(
                theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SegmentGroup(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            children: [
              for (final goal in Goal.values)
                if (goal.group == group)
                  _GoalSetting(goal: goal, settings: settings),
            ],
          ),
        ],
      ],
    );
  }
}

/// One goal over the span that is shown.
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    super.key,
    required this.goal,
    required this.target,
    required this.span,
    required this.from,
    required this.to,
    required this.today,
    required this.data,
  });

  final Goal goal;
  final double target;
  final _Span span;
  final DateTime from;
  final DateTime to;
  final DateTime today;
  final GoalData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    // A weekly goal has one value for a week, as a daily one has for a day.
    final single = span == _Span.day || (span == _Span.week && goal.weekly);

    Widget? trailing;
    String? note;
    Widget body;
    if (single) {
      final progress = goalProgress(goal, target, from, data);
      trailing = progress.reached
          ? Icon(
              Icons.check_circle_rounded,
              color: scheme.primary,
              semanticLabel: l10n.goalMarkReached,
            )
          : null;
      note = goal.formatProgress(formats, progress);
      body = WavyBar(value: progress.share);
    } else if (span == _Span.year) {
      final rates = goalYear(goal, target, from.year, today, data);
      body = _YearBars(rates: rates, labels: formats.monthInitials);
    } else {
      final row = goalRow(goal, target, from, to, today, data);
      if (row.counted > 0) {
        note = l10n.goalReachedOf(row.reached, row.counted);
      }
      body = goal.weekly || span == _Span.week
          ? _MarkRow(
              marks: row.marks,
              labels: goal.weekly ? null : formats.weekdayShort,
            )
          : _MonthGrid(marks: row.marks, first: from);
    }
    final streak = goalStreak(goal, target, today, data);

    final type = AppType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.label(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.title(context.emphasizedTextTheme.titleMedium),
              ),
            ),
            ?trailing,
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note, style: muted),
        ],
        const SizedBox(height: 14),
        body,
        if (streak > 1) ...[
          const SizedBox(height: 12),
          Text(
            goal.weekly
                ? l10n.goalStreakWeeks(streak)
                : l10n.goalStreakDays(streak),
            style: type.strong(
              context.emphasizedTextTheme.labelLarge?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One day or week: a filled scalloped shape when reached, an empty ring
/// when missed, a half-filled circle while it is still open, a dot without
/// data.
class _Mark extends StatelessWidget {
  const _Mark(this.mark, {this.size = 28});

  final GoalMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final Widget shape = switch (mark) {
      GoalMark.reached => M3EContainer(
        Shapes.c9SidedCookie,
        width: size,
        height: size,
        color: scheme.primary,
        child: Icon(
          Icons.check_rounded,
          size: size * 0.6,
          color: scheme.onPrimary,
        ),
      ),
      GoalMark.missed => _ring(scheme.outlineVariant),
      GoalMark.open => _half(scheme.primary),
      GoalMark.none || GoalMark.ahead => Container(
        width: size * 0.22,
        height: size * 0.22,
        decoration: BoxDecoration(
          color: mark == GoalMark.none
              ? scheme.outlineVariant
              : scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
      ),
    };
    return Semantics(
      label: switch (mark) {
        GoalMark.reached => l10n.goalMarkReached,
        GoalMark.missed => l10n.goalMarkMissed,
        GoalMark.open => l10n.goalMarkOpen,
        GoalMark.none => l10n.goalMarkNone,
        GoalMark.ahead => null,
      },
      child: SizedBox.square(
        dimension: size,
        // Reached marks pop in; the others are simply there.
        child: Center(
          child: mark != GoalMark.reached
              ? shape
              : SingleMotionBuilder(
                  from: 0,
                  value: 1,
                  motion: AppMotion.spatial,
                  builder: (context, t, child) =>
                      Transform.scale(scale: t < 0 ? 0 : t, child: child),
                  child: shape,
                ),
        ),
      ),
    );
  }

  /// A ring whose left half is filled.
  Widget _half(Color color) => SizedBox.square(
    dimension: size * 0.72,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          clipper: const _LeftHalf(),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
        ),
      ],
    ),
  );

  Widget _ring(Color color) => Container(
    width: size * 0.72,
    height: size * 0.72,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 2.5),
    ),
  );
}

class _LeftHalf extends CustomClipper<Rect> {
  const _LeftHalf();

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(_LeftHalf oldClipper) => false;
}

/// The marks of a week, or of the weeks of a month, in one row.
class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.marks, this.labels});

  final List<GoalMark> marks;

  /// One under each mark, such as the days of the week.
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = this.labels;
    return Row(
      children: [
        for (final (index, mark) in marks.indexed)
          Expanded(
            child: Column(
              children: [
                Entrance(order: index, child: _Mark(mark)),
                if (labels != null && index < labels.length) ...[
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The days of a month as a calendar, Monday first.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.marks, required this.first});

  final List<GoalMark> marks;

  /// The first day of the month.
  final DateTime first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final cells = <GoalMark?>[
      for (var i = 1; i < first.weekday; i++) null,
      ...marks,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Column(
      children: [
        Row(
          children: [
            for (final label in formats.weekdayShort)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < cells.length; week += 7)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (final mark in cells.sublist(week, week + 7))
                  Expanded(
                    child: mark == null
                        ? const SizedBox(height: 24)
                        : _Mark(mark, size: 24),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The share reached in each month of a year as twelve bars.
class _YearBars extends StatelessWidget {
  const _YearBars({required this.rates, required this.labels});

  final List<double?> rates;
  final List<String> labels;

  static const double _height = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, rate) in rates.indexed)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: _height,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleMotionBuilder(
                      from: 0,
                      value: rate ?? 0,
                      motion: AppMotion.spatial,
                      builder: (context, current, _) => Container(
                        width: 14,
                        // A month without anything keeps a stub to stand on.
                        height: 6 + (_height - 6) * current.clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          color: rate == null
                              ? scheme.surfaceContainerHighest
                              : scheme.primary,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The switch of a goal and, while it is on, the slider of its target.
class _GoalSetting extends StatelessWidget {
  const _GoalSetting({required this.goal, required this.settings});

  final Goal goal;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final on = settings.isGoalOn(goal);
    final target = settings.goalTarget(goal);
    final shown = goal.format(formats, target);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.label(l10n), style: theme.textTheme.titleMedium),
                  if (on)
                    Text(
                      goal.isLimit ? l10n.goalAtMost(shown) : shown,
                      style: context.emphasizedTextTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            Semantics(
              label: goal.label(l10n),
              child: Switch(
                value: on,
                onChanged: (value) {
                  Haptics.selection();
                  settings.setGoalOn(goal, value);
                },
              ),
            ),
          ],
        ),
        // Folds out with the switch.
        SingleMotionBuilder(
          value: on ? 1 : 0,
          motion: AppMotion.spatialFast,
          builder: (context, t, child) => t <= 0.001 && !on
              ? const SizedBox(width: double.infinity)
              : ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: t < 0 ? 0 : t,
                    child: Opacity(
                      opacity: t.clamp(0, 1).toDouble(),
                      child: child,
                    ),
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: M3ESlider(
              value: target.clamp(goal.min, goal.max).toDouble(),
              min: goal.min,
              max: goal.max,
              divisions: ((goal.max - goal.min) / goal.step).round(),
              // The slider ticks itself, a step at a time and firmer the
              // further up it is; the value it reports changes with every
              // tremor of a resting finger.
              decoration: const M3ESliderDecoration(
                haptic: M3EHapticFeedback.light,
                hapticConfig: Haptics.slider,
              ),
              onChanged: (next) => settings.setGoalTarget(goal, next),
            ),
          ),
        ),
      ],
    );
  }
}
