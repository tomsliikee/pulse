import 'package:material_ui/material_ui.dart';

import '../../../app/formatters.dart';
import '../../../app/haptics.dart';
import '../../../data/goals.dart';
import '../../../data/health_controller.dart';
import '../../../data/health_history.dart';
import '../../../features/goals/goal_format.dart';
import '../../../features/goals/goals_page.dart'
    show GoalCard, GoalSetting, GoalSpan;
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_page.dart';

/// Every goal followed, and whether it was reached today, over a week, a
/// month or a year; below, the goals switched on and off and their targets
/// set. In the look.
class MonoGoalsPage extends StatefulWidget {
  const MonoGoalsPage({super.key});

  @override
  State<MonoGoalsPage> createState() => _MonoGoalsPageState();
}

class _MonoGoalsPageState extends State<MonoGoalsPage> {
  GoalSpan _span = GoalSpan.day;
  int _offset = 0;

  (DateTime, DateTime) _range(DateTime today) => switch (_span) {
    GoalSpan.day => (
      DateTime(today.year, today.month, today.day - _offset),
      DateTime(today.year, today.month, today.day - _offset),
    ),
    GoalSpan.week => () {
      final monday = weekStart(today);
      final from = DateTime(
        monday.year,
        monday.month,
        monday.day - 7 * _offset,
      );
      return (from, DateTime(from.year, from.month, from.day + 6));
    }(),
    GoalSpan.month => (
      DateTime(today.year, today.month - _offset),
      DateTime(today.year, today.month - _offset + 1, 0),
    ),
    GoalSpan.year => (
      DateTime(today.year - _offset),
      DateTime(today.year - _offset, 12, 31),
    ),
  };

  String _label(Formats formats, DateTime from, DateTime to) => switch (_span) {
    GoalSpan.day => formats.longDate(from),
    GoalSpan.week => formats.dayRange(from, to),
    GoalSpan.month => formats.month(from),
    GoalSpan.year => '${from.year}',
  };

  void _page(int by) {
    Haptics.selection();
    setState(() => _offset += by);
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final t = c.t;
        final health = c.health;
        final settings = c.settings;
        final ready = health.status == HealthStatus.ready;
        final today = health.today;
        final (from, to) = _range(today);
        final days = health.days;
        final canGoBack = days.isNotEmpty && dayKey(from) > dayKey(days.first);
        final data = ready ? goalDataOf(health, settings) : null;
        final reached = data == null
            ? 0
            : [
                for (final goal in settings.goals)
                  if (goalProgress(
                    goal,
                    settings.goalTarget(goal),
                    today,
                    data,
                  ).reached)
                    goal,
              ].length;
        return MonoSubPage(
          category: MonoCategory.recovery,
          icon: Icons.flag_rounded,
          categoryLabel: l10n.goals,
          backLabel: l10n.monoInsights,
          statement: settings.goals.isEmpty
              ? l10n.goalsNone
              : l10n.goalReachedOf(reached, settings.goals.length),
          children: [
            MonoSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonoSegmented(
                    labels: [
                      l10n.navToday,
                      l10n.periodWeek,
                      l10n.periodMonth,
                      l10n.periodYear,
                    ],
                    selected: _span.index,
                    onChanged: (i) => setState(() {
                      _span = GoalSpan.values[i];
                      _offset = 0;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      MonoIconButton(
                        icon: Icons.chevron_left_rounded,
                        label: l10n.earlier,
                        onTap: canGoBack ? () => _page(1) : null,
                      ),
                      Expanded(
                        child: Text(
                          _label(c.formats, from, to),
                          textAlign: TextAlign.center,
                          style: MonoType.inter(
                            14,
                            18,
                            FontWeight.w600,
                            t.ink2,
                          ),
                        ),
                      ),
                      MonoIconButton(
                        icon: Icons.chevron_right_rounded,
                        label: l10n.later,
                        onTap: _offset > 0 ? () => _page(-1) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (data != null)
              for (final goal in settings.goals)
                MonoSurface(
                  child: GoalCard(
                    key: ValueKey((goal, _span, _offset)),
                    goal: goal,
                    target: settings.goalTarget(goal),
                    span: _span,
                    from: from,
                    to: to,
                    today: today,
                    data: data,
                  ),
                ),
            if (_span == GoalSpan.week || _span == GoalSpan.month)
              MonoNote(l10n.goalLegend),
            MonoBlock(
              title: l10n.goalsCustomize,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonoNote(l10n.goalsCustomizeNote),
                  for (final group in GoalGroup.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                      child: Text(
                        group.label(l10n),
                        style: MonoType.category(t.ink2),
                      ),
                    ),
                    MonoList(
                      children: [
                        for (final goal in Goal.values)
                          if (goal.group == group)
                            GoalSetting(goal: goal, settings: settings),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
