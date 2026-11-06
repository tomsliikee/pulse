import 'package:material_ui/material_ui.dart';

import '../../../data/day_insights.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/morning.dart';
import '../../../features/detail/metric_spec.dart';
import '../../../features/profile/profile_page.dart';
import '../../../features/supplements/supplement_format.dart';
import '../../../features/today/day_format.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/mono_actions.dart';
import '../data/mono_data.dart';
import '../data/mono_energy.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_energy_rings.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_edit_list.dart';
import '../widgets/mono_gauge.dart';
import '../widgets/mono_motion.dart';
import '../widgets/mono_page.dart';
import 'calories_page.dart';
import 'category_page.dart';
import 'day_page.dart';
import 'goals_page.dart';
import 'links_page.dart';
import 'list_pages.dart';
import 'week_page.dart';

/// The cards of Insights, by the id their order and hiding are kept under.
enum MonoInsightCard {
  recovery(MonoCategory.recovery),
  activity(MonoCategory.activity),
  sleep(MonoCategory.sleep),
  heart(MonoCategory.heart),
  vitals(MonoCategory.vitals),
  calories(MonoCategory.nutrition),
  supplements(MonoCategory.supplements);

  const MonoInsightCard(this.category);

  final MonoCategory category;

  IconData get icon =>
      this == calories ? Icons.local_fire_department_rounded : category.icon;

  String label(AppLocalizations l10n) =>
      this == calories ? l10n.monoCalories : category.label(l10n);
}

/// Insights: the day in a few calm cards — one statement, one number and
/// one small chart each. The pencil lets the cards be put in another order
/// or hidden.
class MonoInsightsPage extends StatefulWidget {
  const MonoInsightsPage({super.key, required this.onOpenBrowse});

  final VoidCallback onOpenBrowse;

  /// Air between two cards, and before a section.
  static const double cardGap = 28;
  static const double sectionGap = 48;

  /// The page the order and the hidden cards are kept under in the settings.
  static const String tilePage = 'monoInsights';

  @override
  State<MonoInsightsPage> createState() => _MonoInsightsPageState();
}

class _MonoInsightsPageState extends State<MonoInsightsPage> {
  bool _editing = false;

  /// Every card in the order of the settings, those it does not know yet at
  /// their place by default.
  static List<MonoInsightCard> _ordered(List<String> saved) {
    final byName = MonoInsightCard.values.asNameMap();
    final order = [for (final id in saved) ?byName[id]];
    for (final card in MonoInsightCard.values) {
      if (!order.contains(card)) {
        final at = card.index.clamp(0, order.length);
        order.insert(at, card);
      }
    }
    return order;
  }

  Widget _card(MonoCtx c, MonoInsightCard card) => switch (card) {
    MonoInsightCard.recovery => _RecoveryCard(c),
    MonoInsightCard.activity => _ActivityCard(c),
    MonoInsightCard.sleep => _SleepCard(c),
    MonoInsightCard.heart => _HeartCard(c),
    MonoInsightCard.vitals => _VitalsCard(c),
    MonoInsightCard.calories => _CaloriesCard(c),
    MonoInsightCard.supplements => _SupplementsCard(c),
  };

  List<Widget> _actions(MonoCtx c) => [
    MonoCircleButton(
      icon: _editing ? Icons.check_rounded : Icons.edit_rounded,
      label: _editing ? c.l10n.done : c.l10n.monoEditCards,
      fill: _editing ? c.t.solid : c.t.fill,
      color: _editing ? c.t.onSolid : c.t.ink,
      size: 36,
      onTap: () => setState(() => _editing = !_editing),
    ),
    MonoCircleButton(
      icon: Icons.refresh_rounded,
      label: c.l10n.refresh,
      fill: c.t.fill,
      color: c.t.ink,
      size: 36,
      onTap: () => c.health.refresh(),
    ),
    MonoCircleButton(
      icon: Icons.person_rounded,
      label: c.l10n.profile,
      fill: c.t.recovery,
      color: c.t.bg,
      size: 36,
      onTap: () => c.push(const ProfilePage()),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.health,
        scope.settings,
        scope.supplements,
      ]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        const page = MonoInsightsPage.tilePage;
        final hidden = c.settings.hiddenTiles(page);
        final order = _ordered(c.settings.tileOrder(page));
        final hasSupplements = c.scope.supplements.data.mine.isNotEmpty;
        bool available(MonoInsightCard card) =>
            card != MonoInsightCard.supplements || hasSupplements;
        final shown = [
          for (final card in order)
            if (available(card) && !hidden.contains(card.name)) card,
        ];
        return MonoPage(
          bottomInset: 140,
          floatTitle: c.l10n.monoInsights,
          floatActions: _actions(c),
          children: [
            _Header(
              c,
              editing: _editing,
              onEdit: () => setState(() => _editing = !_editing),
            ),
            const SizedBox(height: 28),
            _Shortcuts(c),
            const SizedBox(height: 40),
            if (_editing)
              MonoEditList(
                c: c,
                page: MonoInsightsPage.tilePage,
                items: [
                  for (final card in order)
                    if (available(card))
                      MonoEditItem(
                        card.name,
                        card.label(c.l10n),
                        card.icon,
                        card.category.color(c.t),
                      ),
                ],
                hidden: hidden,
              )
            else
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(height: MonoInsightsPage.cardGap),
                MonoRise(
                  order: i,
                  page: 'insights',
                  child: KeyedSubtree(
                    key: ValueKey(shown[i]),
                    child: _card(c, shown[i]),
                  ),
                ),
              ],
            const SizedBox(height: MonoInsightsPage.sectionGap),
            MonoSection(c.l10n.monoForYou),
            const SizedBox(height: 16),
            _ForYou(c),
            const SizedBox(height: MonoInsightsPage.sectionGap),
            MonoSection(c.l10n.monoDays),
            const SizedBox(height: 14),
            _Days(c),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.c, {required this.editing, required this.onEdit});

  final MonoCtx c;
  final bool editing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoSerif.title(c.l10n.monoInsights),
              const SizedBox(height: 8),
              Text(c.dateText, style: MonoType.sub(t)),
              Text(c.l10n.monoUpdated(c.updated), style: MonoType.label(t)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        MonoCircleButton(
          icon: editing ? Icons.check_rounded : Icons.edit_rounded,
          label: editing ? c.l10n.done : c.l10n.monoEditCards,
          fill: editing ? t.solid : t.fill,
          color: editing ? t.onSolid : t.ink,
          onTap: onEdit,
        ),
        const SizedBox(width: 10),
        MonoCircleButton(
          icon: Icons.refresh_rounded,
          label: c.l10n.refresh,
          fill: t.fill,
          color: t.ink,
          onTap: () => c.health.refresh(),
        ),
        const SizedBox(width: 10),
        MonoCircleButton(
          icon: Icons.person_rounded,
          label: c.l10n.profile,
          fill: t.recovery,
          color: t.bg,
          onTap: () => c.push(const ProfilePage()),
        ),
      ],
    );
  }
}

/// The pages that used to sit behind "More": the week, the goals and the
/// links, one tap away.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        MonoRoundButton(
          icon: Icons.view_week_rounded,
          label: l10n.monoWeekShort,
          active: true,
          onTap: () => c.push(const MonoWeekPage()),
        ),
        MonoRoundButton(
          icon: Icons.flag_rounded,
          label: l10n.goals,
          onTap: () => c.push(const MonoGoalsPage()),
        ),
        MonoRoundButton(
          icon: Icons.link_rounded,
          label: l10n.monoLinksShort,
          onTap: () => c.push(const MonoLinksPage()),
        ),
      ],
    );
  }
}

// ─── Cards ──────────────────────────────────────────────────────────────

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final percent = c.recovery.total;
    final band = percent == null ? null : monoGaugeBand(percent);
    final name = switch (band) {
      0 => l10n.monoBandRecover,
      1 => l10n.monoBandPace,
      2 => l10n.monoBandReady,
      3 => l10n.monoBandGo,
      _ => l10n.monoNoRecovery,
    };
    final statement = percent == null || c.simple
        ? name
        : '${c.formats.integer(percent)} % · $name';
    return MonoCard(
      category: MonoCategory.recovery,
      categoryLabel: l10n.recovery,
      time: c.updated,
      statement: statement,
      semanticsLabel: '${l10n.recovery}, $statement',
      onTap: () => c.push(MonoDayPage(date: c.today)),
      child: Center(
        child: MonoGauge(
          percent: percent,
          semantics: statement,
          labels: [
            l10n.monoGaugeRecover,
            l10n.monoGaugePace,
            l10n.monoGaugeReady,
            l10n.monoGaugeGo,
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final steps = c.valueToday(Metric.steps);
    final goal = c.settings.stepGoal;
    final statement = steps == null
        ? l10n.monoActivityNone
        : steps >= goal
        ? l10n.monoActivityDone
        : steps >= goal / 2
        ? l10n.monoActivityHalf
        : l10n.monoActivityQuiet;
    final hours = c.hours(Metric.steps);
    final bars = hours ?? c.days(Metric.steps, 7);
    return MonoCard(
      category: MonoCategory.activity,
      categoryLabel: l10n.groupActivity,
      time: c.updated,
      statement: statement,
      semanticsLabel:
          '${l10n.groupActivity}, $statement, '
          '${Metric.steps.formatWithUnit(c.formats, steps)}',
      onTap: () => openMonoCategory(context, MonoCategory.activity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoStat(
            label: Metric.steps.title(l10n),
            value: Metric.steps.format(c.formats, steps),
            unit: Metric.steps.unitFor(l10n, steps),
          ),
          const SizedBox(height: 18),
          MonoBars(
            values: bars,
            highlight: hours == null ? bars.length - 1 : _lastHour(hours),
            semantics: statement,
            height: 56,
          ),
        ],
      ),
    );
  }

  static int _lastHour(List<double?> hours) {
    for (var i = hours.length - 1; i >= 0; i--) {
      if ((hours[i] ?? 0) > 0) return i;
    }
    return 0;
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final raw = c.health.latestNight;
    final night = raw == null ? null : c.health.withCurve(raw);
    final goal = c.settings.sleepGoalHours * 60;
    final statement = night == null
        ? l10n.monoSleepNone
        : night.totalMinutes >= goal
        ? l10n.monoSleepFull
        : night.totalMinutes >= goal * 0.85
        ? l10n.monoSleepAlmost
        : l10n.monoSleepShort;
    return MonoCard(
      category: MonoCategory.sleep,
      categoryLabel: l10n.groupSleep,
      time: night == null
          ? null
          : formatClockOf(night.bedtimeMinute + night.totalMinutes),
      statement: statement,
      semanticsLabel:
          '${l10n.groupSleep}, $statement'
          '${night == null ? '' : ', ${c.formats.duration(night.totalMinutes)}'}',
      onTap: () => openMonoCategory(context, MonoCategory.sleep),
      child: night == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoStat(
                  label: l10n.sleepDuration,
                  value: c.formats.duration(night.totalMinutes),
                ),
                const SizedBox(height: 18),
                night.hasCurve
                    ? MonoHypnogram(
                        segments: night.segments,
                        totalMinutes: night.totalMinutes,
                        semantics: statement,
                        height: 52,
                      )
                    : MonoTrack(
                        value: night.totalMinutes / goal,
                        semantics: statement,
                      ),
              ],
            ),
    );
  }
}

class _HeartCard extends StatelessWidget {
  const _HeartCard(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final samples = c.health.snapshot.heart[c.health.todayIndex];
    final latest = samples.isEmpty ? null : samples.last;
    final resting = c.valueToday(Metric.restingHeartRate);
    final before = [
      for (var back = 1; back <= 30; back++)
        ?c.health.valueOn(
          Metric.restingHeartRate,
          DateTime(c.today.year, c.today.month, c.today.day - back),
        ),
    ];
    final mean = before.length < 5
        ? null
        : before.reduce((a, b) => a + b) / before.length;
    final statement = resting == null || mean == null
        ? (latest == null ? l10n.monoHeartNone : l10n.monoHeartUsual)
        : resting < mean - 2
        ? l10n.monoHeartLower
        : resting > mean + 2
        ? l10n.monoHeartHigher
        : l10n.monoHeartUsual;
    return MonoCard(
      category: MonoCategory.heart,
      categoryLabel: l10n.navHeart,
      time: latest == null ? null : formatClockOf(latest.minuteOfDay),
      statement: statement,
      semanticsLabel:
          '${l10n.navHeart}, $statement'
          '${latest == null ? '' : ', ${latest.bpm} ${Metric.heartRate.unit}'}',
      onTap: () => openMonoCategory(context, MonoCategory.heart),
      child: latest == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoStat(
                  label: l10n.metricHeartRate,
                  value: '${latest.bpm}',
                  unit: Metric.heartRate.unit,
                ),
                const SizedBox(height: 18),
                MonoLine(
                  values: [for (final s in samples) s.bpm.toDouble()],
                  color: c.t.heart,
                  semantics: statement,
                  height: 56,
                ),
              ],
            ),
    );
  }
}

class _VitalsCard extends StatefulWidget {
  const _VitalsCard(this.c);

  final MonoCtx c;

  @override
  State<_VitalsCard> createState() => _VitalsCardState();
}

class _VitalsCardState extends State<_VitalsCard> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final l10n = c.l10n;
    final t = c.t;
    final night = _mode == 0;
    final shown = night
        ? morningVitals
        : const [
            Metric.heartRateVariability,
            Metric.heartRate,
            Metric.respiratoryRate,
            Metric.oxygenSaturation,
            Metric.systolic,
          ];
    final off = {
      for (final d in vitalDeviations(c.health.valueOn, c.today)) d.metric,
    };
    final known = [for (final m in shown) c.valueToday(m)];
    final statement = known.every((v) => v == null)
        ? l10n.monoVitalsNone
        : off.isEmpty
        ? l10n.monoVitalsOk
        : l10n.monoVitalsOff;
    final hrv = c.valueToday(Metric.heartRateVariability);
    return MonoCard(
      category: MonoCategory.vitals,
      categoryLabel: l10n.groupVitals,
      time: c.updated,
      statement: statement,
      semanticsLabel: '${l10n.groupVitals}, $statement',
      onTap: () => openMonoCategory(context, MonoCategory.vitals),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoSegmented(
            labels: [l10n.monoOvernight, l10n.monoDaytime],
            selected: _mode,
            onChanged: (i) => setState(() => _mode = i),
          ),
          const SizedBox(height: 20),
          MonoStat(
            label: Metric.heartRateVariability.title(l10n),
            value: Metric.heartRateVariability.format(c.formats, hrv),
            unit: Metric.heartRateVariability.unit,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Semantics(
                  label:
                      '${shown[i].title(l10n)}, '
                      '${shown[i].formatWithUnit(c.formats, known[i])}',
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: known[i] == null
                          ? t.fill
                          : off.contains(shown[i])
                          ? t.heart
                          : t.ink3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final t = c.t;
    final e = MonoEnergy.of(c);
    String kcal(double v) => c.formats.integer(v.round());
    final unit = Metric.totalEnergy.unit;
    final balance = e.balance;
    final statement = e.burned == null && e.eaten == null
        ? l10n.monoCaloriesNone
        : e.bothReached
        ? l10n.monoCaloriesBoth
        : e.eaten == null
        ? l10n.monoCaloriesNoMeals
        : balance! >= 0
        ? l10n.monoCaloriesDeficit(kcal(balance))
        : l10n.monoCaloriesSurplus(kcal(-balance));
    final burnedColors = e.split
        ? [t.ink3, t.solid, t.ink2]
        : [t.ink3, t.solid];
    final burnedLabels = e.split
        ? [l10n.monoRest, l10n.finePartWorkouts, l10n.monoMovement]
        : [l10n.monoRest, l10n.monoActive];
    final eatenColors = [
      t.recovery,
      t.recovery.withValues(alpha: 0.62),
      t.recovery.withValues(alpha: 0.34),
    ];
    final eatenLabels = [l10n.metricProtein, l10n.metricCarbs, l10n.metricFat];
    final semantics =
        '${l10n.monoCalories}, $statement, '
        '${l10n.monoBurned} ${e.burned == null ? '–' : kcal(e.burned!)} $unit, '
        '${l10n.monoEaten} ${e.eaten == null ? '–' : kcal(e.eaten!)} $unit';
    return MonoCard(
      category: MonoCategory.nutrition,
      icon: MonoInsightCard.calories.icon,
      categoryLabel: l10n.monoCalories,
      time: c.updated,
      statement: statement,
      semanticsLabel: semantics,
      onTap: () => c.push(MonoCaloriesPage(backLabel: l10n.monoInsights)),
      child: Row(
        children: [
          MonoEnergyRings(
            day: c.today,
            semantics: semantics,
            size: 148,
            outer: MonoRingData(
              parts: e.burnedParts,
              colors: burnedColors,
              goal: e.burnedGoal,
              total: e.burned,
            ),
            inner: MonoRingData(
              parts: e.eatenParts,
              // What the macros do not cover is drawn faint.
              colors: [...eatenColors, t.recovery.withValues(alpha: 0.18)],
              goal: e.eatenGoal,
              total: e.eaten,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EnergyFigure(
                  label: l10n.monoBurned,
                  value: e.burned == null ? '–' : kcal(e.burned!),
                  unit: unit,
                  goal: l10n.monoOfGoal(kcal(e.burnedGoal)),
                  reached: e.burnedReached,
                  tokens: t,
                ),
                const SizedBox(height: 8),
                _Legend(colors: burnedColors, labels: burnedLabels, tokens: t),
                const SizedBox(height: 18),
                _EnergyFigure(
                  label: l10n.monoEaten,
                  value: e.eaten == null ? '–' : kcal(e.eaten!),
                  unit: unit,
                  goal: l10n.monoOfGoal(kcal(e.eatenGoal)),
                  reached: e.eatenReached,
                  color: t.recovery,
                  tokens: t,
                ),
                const SizedBox(height: 8),
                _Legend(colors: eatenColors, labels: eatenLabels, tokens: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyFigure extends StatelessWidget {
  const _EnergyFigure({
    required this.label,
    required this.value,
    required this.unit,
    required this.goal,
    required this.reached,
    required this.tokens,
    this.color,
  });

  final String label;
  final String value;
  final String unit;
  final String goal;
  final bool reached;
  final MonoTokens tokens;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: MonoType.label(t)),
            if (reached) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded, size: 14, color: color ?? t.ink),
            ],
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: MonoType.numberSmall(t).copyWith(color: color),
                ),
                TextSpan(text: ' $unit', style: MonoType.unit(t)),
              ],
            ),
          ),
        ),
        Text(goal, style: MonoType.time(t)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.colors,
    required this.labels,
    required this.tokens,
  });

  final List<Color> colors;
  final List<String> labels;
  final MonoTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (var i = 0; i < labels.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                labels[i],
                style: MonoType.inter(11, 14, FontWeight.w500, tokens.ink2),
              ),
            ],
          ),
      ],
    );
  }
}

class _SupplementsCard extends StatelessWidget {
  const _SupplementsCard(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final data = c.scope.supplements.data;
    final mine = data.mine;
    final now = c.health.now;
    final taken = [for (final s in mine) data.takenOn(s.key, now) != null];
    final count = taken.where((v) => v).length;
    final statement = count == mine.length
        ? l10n.monoSuppAll
        : count == 0
        ? l10n.monoSuppNone
        : l10n.monoSuppSome;
    return MonoCard(
      category: MonoCategory.supplements,
      categoryLabel: l10n.supplements,
      time: c.updated,
      statement: statement,
      semanticsLabel:
          '${l10n.supplements}, $statement, '
          '${l10n.supplementsTakenOf(c.formats.integer(count), c.formats.integer(mine.length))}',
      onTap: () => openMonoCategory(context, MonoCategory.supplements),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (var i = 0; i < mine.length; i++)
            MonoSupplementButton(
              label: mine[i].title(l10n),
              taken: taken[i],
              onTap: () => monoToggleSupplement(context, mine[i]),
            ),
        ],
      ),
    );
  }
}

/// One supplement as a round button: solid with a check that draws itself
/// when taken.
class MonoSupplementButton extends StatelessWidget {
  const MonoSupplementButton({
    super.key,
    required this.label,
    required this.taken,
    required this.onTap,
  });

  final String label;
  final bool taken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final initials = label.characters.take(2).toString();
    return Semantics(
      button: true,
      toggled: taken,
      label: label,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: onTap,
          squash: 0.08,
          child: SizedBox(
            width: 62,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: monoStill(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: taken ? t.solid : t.fill,
                  ),
                  child: taken
                      ? MonoDrawIn(
                          key: const ValueKey('check'),
                          duration: const Duration(milliseconds: 360),
                          builder: (context, p) => CustomPaint(
                            size: const Size(24, 24),
                            painter: _CheckPainter(t.onSolid, p),
                          ),
                        )
                      : Text(
                          initials,
                          style: MonoType.inter(17, 22, FontWeight.w600, t.ink),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MonoType.inter(
                    12,
                    16,
                    FontWeight.w500,
                    taken ? t.ink : t.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color, this.t);

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.84, size.height * 0.28);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.color != color;
}

// ─── For You, Days ──────────────────────────────────────────────────────

class _ForYou extends StatelessWidget {
  const _ForYou(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final t = c.t;
    final items = <(String, String, Color, Widget)>[
      (l10n.weekTitle, l10n.weekTileReady, t.recoveryBg, const MonoWeekPage()),
      (l10n.linksTitle, l10n.linksNote, t.card, const MonoLinksPage()),
      (l10n.goals, l10n.goalsCustomizeNote, t.card, const MonoGoalsPage()),
    ];
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final (cat, head, bg, page) = items[i];
          return SizedBox(
            width: 244,
            child: MonoPress(
              onTap: () => c.push(page),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat,
                      style: MonoType.category(i == 0 ? t.recovery : t.ink),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        head,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: MonoType.inter(16, 22, FontWeight.w500, t.ink),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 20, color: t.ink2),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Days extends StatelessWidget {
  const _Days(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final goals = dayGoalsOf(c.settings);
    final rows = <Widget>[];
    for (var back = 0; back < 3; back++) {
      final day = DateTime(c.today.year, c.today.month, c.today.day - back);
      final score = dayScore(
        day: day,
        valueOf: c.health.valueOn,
        nights: c.health.nights,
        goals: goals,
      ).total;
      final steps = c.health.valueOn(Metric.steps, day);
      rows.add(
        MonoRow(
          title: c.formats.relativeDay(day, c.today),
          subtitle: steps == null
              ? null
              : Metric.steps.formatWithUnit(c.formats, steps),
          leading: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.recoveryBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              score == null ? '–' : '$score',
              style: MonoType.inter(17, 22, FontWeight.w600, t.recovery),
            ),
          ),
          onTap: () => c.push(MonoDayPage(date: day)),
        ),
      );
    }
    rows.add(
      MonoRow(
        title: c.l10n.allDays,
        onTap: () => c.push(const MonoDayListPage()),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          rows[i],
        ],
      ],
    );
  }
}
