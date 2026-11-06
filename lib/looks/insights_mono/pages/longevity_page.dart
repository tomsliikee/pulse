import 'package:material_ui/material_ui.dart';

import '../../../app/formatters.dart';
import '../../../data/body_age.dart';
import '../../../data/metric_catalog.dart';
import '../../../features/age/body_age_page.dart';
import '../../../features/detail/metric_spec.dart';
import '../../../features/profile/birth_date_sheet.dart';
import '../../../features/profile/target_weight_sheet.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/mono_data.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_age_ring.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_controls.dart';
import '../widgets/mono_edit_list.dart';
import '../widgets/mono_motion.dart';
import '../widgets/mono_page.dart';
import 'body_age_page.dart';

/// The seven areas of the ring, in order, and the factors of the body age
/// that belong to each. Hearing and nutrition have no data in the app.
enum _Area {
  heart([AgeFactorKind.restingHeartRate, AgeFactorKind.bloodPressure]),
  sleep([AgeFactorKind.sleepDuration, AgeFactorKind.sleepRegularity]),
  mental([AgeFactorKind.heartRateVariability]),
  movement([
    AgeFactorKind.steps,
    AgeFactorKind.intensity,
    AgeFactorKind.strength,
  ]),
  metabolic([AgeFactorKind.bodyFat, AgeFactorKind.bodyMassIndex]),
  hearing([]),
  nutrition([]);

  const _Area(this.kinds);

  final List<AgeFactorKind> kinds;

  IconData get icon => switch (this) {
    _Area.heart => Icons.favorite_rounded,
    _Area.sleep => Icons.bedtime_rounded,
    _Area.mental => Icons.psychology_rounded,
    _Area.movement => Icons.directions_run_rounded,
    _Area.metabolic => Icons.local_fire_department_rounded,
    _Area.hearing => Icons.hearing_rounded,
    _Area.nutrition => Icons.restaurant_rounded,
  };

  String label(AppLocalizations l10n) => switch (this) {
    _Area.heart => l10n.monoAreaHeart,
    _Area.sleep => l10n.monoAreaSleep,
    _Area.mental => l10n.monoAreaMental,
    _Area.movement => l10n.monoAreaMovement,
    _Area.metabolic => l10n.monoAreaMetabolic,
    _Area.hearing => l10n.monoAreaHearing,
    _Area.nutrition => l10n.monoAreaNutrition,
  };
}

enum _Block { hero, shapes, areas, checks, weight, method, sources }

/// Longevity: the body age as a ring, what shapes it and the seven areas.
/// The pencil lets the blocks be put in another order or hidden.
class MonoLongevityPage extends StatefulWidget {
  const MonoLongevityPage({super.key});

  /// The page the order and the hidden blocks are kept under.
  static const String tilePage = 'monoLongevity';

  /// The page the order and the hidden areas of the seven are kept under.
  static const String areasPage = 'monoLongevityAreas';

  @override
  State<MonoLongevityPage> createState() => _MonoLongevityPageState();
}

class _MonoLongevityPageState extends State<MonoLongevityPage> {
  bool _editing = false;

  static List<_Area> _orderedAreas(List<String> saved) {
    final byName = _Area.values.asNameMap();
    final order = [for (final id in saved) ?byName[id]];
    for (final area in _Area.values) {
      if (!order.contains(area)) {
        order.insert(area.index.clamp(0, order.length), area);
      }
    }
    return order;
  }

  static List<_Block> _ordered(List<String> saved) {
    final byName = _Block.values.asNameMap();
    final order = [for (final id in saved) ?byName[id]];
    for (final block in _Block.values) {
      if (!order.contains(block)) {
        order.insert(block.index.clamp(0, order.length), block);
      }
    }
    return order;
  }

  String _label(AppLocalizations l10n, _Block b) => switch (b) {
    _Block.hero => l10n.bodyAge,
    _Block.shapes => l10n.monoShapes,
    _Block.areas => l10n.monoAreas,
    _Block.checks => l10n.monoChecks,
    _Block.weight => l10n.metricWeight,
    _Block.method => l10n.monoMethod,
    _Block.sources => l10n.monoSources,
  };

  IconData _icon(_Block b) => switch (b) {
    _Block.hero => Icons.hourglass_bottom_rounded,
    _Block.shapes => Icons.tune_rounded,
    _Block.areas => Icons.donut_small_rounded,
    _Block.checks => Icons.fitness_center_rounded,
    _Block.weight => Icons.monitor_weight_rounded,
    _Block.method => Icons.info_outline_rounded,
    _Block.sources => Icons.source_rounded,
  };

  List<_Area> _shownAreas(MonoCtx c) {
    final hidden = c.settings.hiddenTiles(MonoLongevityPage.areasPage);
    return [
      for (final a in _orderedAreas(
        c.settings.tileOrder(MonoLongevityPage.areasPage),
      ))
        if (!hidden.contains(a.name)) a,
    ];
  }

  Widget _block(MonoCtx c, BodyAge result, _Block b) {
    final l10n = c.l10n;
    return switch (b) {
      _Block.hero => MonoRise(
        order: 0,
        page: 'longevity',
        child: _Hero(c, result),
      ),
      _Block.shapes => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoSection(l10n.monoShapes),
          const SizedBox(height: 14),
          _Shapes(c, result),
        ],
      ),
      _Block.areas => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MonoSection(l10n.monoAreas),
          const SizedBox(height: 14),
          for (final (i, area) in _shownAreas(c).indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            _AreaCard(c: c, area: area, result: result),
          ],
        ],
      ),
      _Block.checks => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _checks(c, result),
      ),
      _Block.weight => _Weight(c),
      _Block.method => MonoSurface(
        color: c.t.recoveryBg,
        onTap: () => c.push(const MonoBodyAgePage()),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.monoExpertNote,
                style: MonoType.inter(15, 21, FontWeight.w500, c.t.ink),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.t.recovery),
          ],
        ),
      ),
      _Block.sources => MonoSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.monoSources, style: MonoType.label(c.t)),
            const SizedBox(height: 6),
            Text(l10n.last30FromHealthConnect, style: MonoType.body(c.t)),
          ],
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final result = bodyAgeOf(c.health, c.settings);
        const page = MonoLongevityPage.tilePage;
        final hidden = c.settings.hiddenTiles(page);
        final order = _ordered(c.settings.tileOrder(page));
        final shown = [
          for (final b in order)
            if (!hidden.contains(b.name)) b,
        ];
        return MonoPage(
          bottomInset: 140,
          floatTitle: l10n.monoLongevity,
          floatActions: [_pencil(c, 36)],
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoSerif.title(l10n.monoLongevity),
                      const SizedBox(height: 8),
                      Text(l10n.estimateLast30, style: MonoType.sub(c.t)),
                    ],
                  ),
                ),
                if (result != null) _pencil(c, 48),
              ],
            ),
            const SizedBox(height: 32),
            if (result == null)
              _NoBirthDate(c)
            else if (_editing) ...[
              MonoEditList(
                c: c,
                page: page,
                items: [
                  for (final b in order)
                    MonoEditItem(
                      b.name,
                      _label(l10n, b),
                      _icon(b),
                      c.t.recovery,
                    ),
                ],
                hidden: hidden,
              ),
              const SizedBox(height: 44),
              MonoSection(l10n.monoAreas),
              const SizedBox(height: 14),
              MonoEditList(
                c: c,
                page: MonoLongevityPage.areasPage,
                items: [
                  for (final a in _orderedAreas(
                    c.settings.tileOrder(MonoLongevityPage.areasPage),
                  ))
                    MonoEditItem(a.name, a.label(l10n), a.icon, c.t.recovery),
                ],
                hidden: c.settings.hiddenTiles(MonoLongevityPage.areasPage),
              ),
            ] else
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(height: 44),
                KeyedSubtree(
                  key: ValueKey(shown[i]),
                  child: _block(c, result, shown[i]),
                ),
              ],
          ],
        );
      },
    );
  }

  Widget _pencil(MonoCtx c, double size) => MonoCircleButton(
    icon: _editing ? Icons.check_rounded : Icons.edit_rounded,
    label: _editing ? c.l10n.done : c.l10n.monoEditCards,
    fill: _editing ? c.t.solid : c.t.fill,
    color: _editing ? c.t.onSolid : c.t.ink,
    size: size,
    onTap: () => setState(() => _editing = !_editing),
  );

  /// The strength check, the one of the movement checks the app has data for.
  List<Widget> _checks(MonoCtx c, BodyAge result) {
    final strength = _factor(result, AgeFactorKind.strength);
    if (strength == null || strength.value == null) return const [];
    return [
      MonoSection(c.l10n.monoChecks),
      const SizedBox(height: 14),
      MonoSurface(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.l10n.workoutStrength, style: MonoType.label(c.t)),
                  const SizedBox(height: 4),
                  Text(
                    c.l10n.readingStrength(c.formats.decimal(strength.value!)),
                    style: MonoType.numberSmall(c.t),
                  ),
                ],
              ),
            ),
            _Chip(_statusOf(strength.years == null ? null : [strength]), c),
          ],
        ),
      ),
      const SizedBox(height: 28),
    ];
  }
}

AgeFactor? _factor(BodyAge result, AgeFactorKind kind) {
  for (final f in result.factors) {
    if (f.kind == kind) return f;
  }
  return null;
}

MonoStatus _statusOf(List<AgeFactor>? factors) {
  final counted = [
    for (final f in factors ?? const <AgeFactor>[])
      if (f.years != null) f.years!,
  ];
  if (counted.isEmpty) return MonoStatus.none;
  final sum = counted.reduce((a, b) => a + b);
  return sum < -0.3
      ? MonoStatus.favorable
      : sum > 0.3
      ? MonoStatus.attention
      : MonoStatus.typical;
}

List<AgeFactor> _factorsOf(BodyAge result, _Area area) => [
  for (final f in result.factors)
    if (area.kinds.contains(f.kind)) f,
];

class _NoBirthDate extends StatelessWidget {
  const _NoBirthDate(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    return MonoSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.l10n.birthDateMissing, style: MonoType.statement(c.t)),
          const SizedBox(height: 10),
          Text(c.l10n.birthDateWhy, style: MonoType.sub(c.t)),
          const SizedBox(height: 18),
          MonoPressButton(
            label: c.l10n.enterBirthDate,
            onTap: () => showBirthDateSheet(context),
          ),
        ],
      ),
    );
  }
}

/// A solid pill button.
class MonoPressButton extends StatelessWidget {
  const MonoPressButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.solid,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              label,
              style: MonoType.inter(15, 20, FontWeight.w600, t.onSolid),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero(this.c, this.result);

  final MonoCtx c;
  final BodyAge result;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final t = c.t;
    final diff = result.difference;
    final real = c.formats.decimal(result.chronological);
    final statement = diff == null
        ? l10n.needFactors(minAgeFactors)
        : c.simple
        ? (diff < -0.05
              ? l10n.monoYoungerPlain
              : diff > 0.05
              ? l10n.monoOlderPlain
              : l10n.monoSameAge)
        : diff < -0.05
        ? l10n.yearsYounger(c.formats.decimal(-diff), real)
        : diff > 0.05
        ? l10n.yearsOlder(c.formats.decimal(diff), real)
        : l10n.exactlyYourAge(real);
    final statuses = [
      for (final area in _Area.values) _statusOf(_factorsOf(result, area)),
    ];
    return MonoCard(
      category: MonoCategory.recovery,
      categoryLabel: l10n.bodyAge,
      statement: statement,
      semanticsLabel: '${l10n.bodyAge}, $statement',
      onTap: () => c.push(const MonoBodyAgePage()),
      child: Column(
        children: [
          const SizedBox(height: 6),
          MonoAgeRing(
            statuses: statuses,
            bodyAge: result.age,
            realAge: result.chronological,
            unit: l10n.monoYears,
            semantics: statement,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 8,
            children: [
              _Legend(t.recovery, l10n.monoStatusFavorable, t),
              _Legend(t.ink3, l10n.monoStatusTypical, t),
              _Legend(t.heart, l10n.monoStatusAttention, t),
            ],
          ),
          const SizedBox(height: 26),
          MonoAgeScale(
            bodyAge: result.age,
            realAge: result.chronological,
            bodyLabel: l10n.bodyAge,
            realLabel: l10n.monoRealAge,
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label, this.t);

  final Color color;
  final String label;
  final MonoTokens t;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(width: 6),
      Text(label, style: MonoType.label(t)),
    ],
  );
}

String _title(AppLocalizations l10n, AgeFactorKind kind) => switch (kind) {
  AgeFactorKind.steps => l10n.metricSteps,
  AgeFactorKind.intensity => l10n.factorIntensity,
  AgeFactorKind.sleepDuration => l10n.sleepDuration,
  AgeFactorKind.sleepRegularity => l10n.factorSleepRhythm,
  AgeFactorKind.restingHeartRate => l10n.metricRestingHeartRate,
  AgeFactorKind.heartRateVariability => l10n.metricHeartRateVariability,
  AgeFactorKind.bodyFat => l10n.metricBodyFat,
  AgeFactorKind.bodyMassIndex => l10n.metricBodyMassIndex,
  AgeFactorKind.bloodPressure => l10n.bloodPressure,
  AgeFactorKind.strength => l10n.workoutStrength,
};

String _reading(Formats formats, AgeFactor factor) {
  final l10n = formats.l10n;
  final value = factor.value;
  if (value == null) return l10n.noData;
  final whole = '${value.round()}';
  return switch (factor.kind) {
    AgeFactorKind.steps => formats.integer(value.round()),
    AgeFactorKind.intensity => '$whole min',
    AgeFactorKind.sleepDuration => formats.duration((value * 60).round()),
    AgeFactorKind.sleepRegularity => '$whole min',
    AgeFactorKind.restingHeartRate => '$whole bpm',
    AgeFactorKind.heartRateVariability => '$whole ms',
    AgeFactorKind.bodyFat => l10n.percentText(formats.decimal(value)),
    AgeFactorKind.bodyMassIndex => formats.decimal(value),
    AgeFactorKind.bloodPressure =>
      '${value.round()}/${factor.second?.round() ?? '–'} mmHg',
    AgeFactorKind.strength => l10n.readingStrength(formats.decimal(value)),
  };
}

/// "−1,2 years" style text for a factor's years.
String _years(MonoCtx c, double? years) =>
    years == null ? '–' : formatYears(c.formats, years);

class _Shapes extends StatelessWidget {
  const _Shapes(this.c, this.result);

  final MonoCtx c;
  final BodyAge result;

  @override
  Widget build(BuildContext context) {
    final counted = [
      for (final f in result.factors)
        if (f.years != null) f,
    ]..sort((a, b) => b.years!.abs().compareTo(a.years!.abs()));
    final top = counted.take(4).toList();
    return MonoSurface(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
      child: top.isEmpty
          ? Text(c.l10n.noData30, style: MonoType.sub(c.t))
          : MonoFactorBars(
              rows: [
                for (final f in top)
                  (
                    _title(c.l10n, f.kind),
                    '${_reading(c.formats, f)} · ${_years(c, f.years)}',
                    f.years,
                  ),
              ],
            ),
    );
  }
}

class _AreaCard extends StatefulWidget {
  const _AreaCard({required this.c, required this.area, required this.result});

  final MonoCtx c;
  final _Area area;
  final BodyAge result;

  @override
  State<_AreaCard> createState() => _AreaCardState();
}

class _AreaCardState extends State<_AreaCard> {
  bool _open = false;

  /// Twelve weeks, oldest first: −1 better, 0 typical, 1 worse than usual.
  List<int?> _weeks() {
    final c = widget.c;
    final (metric, curve) = switch (widget.area) {
      _Area.heart => (
        Metric.restingHeartRate,
        restingHeartRateCurve(c.settings.sex),
      ),
      _Area.sleep => (Metric.sleep, sleepDurationCurve),
      _Area.movement => (Metric.steps, stepsCurve),
      _ => (null, null),
    };
    if (metric == null || curve == null) return List.filled(12, null);
    return [
      for (var w = 11; w >= 0; w--)
        () {
          final known = <double>[];
          for (var d = 0; d < 7; d++) {
            final day = DateTime(
              c.today.year,
              c.today.month,
              c.today.day - (w * 7 + d),
            );
            final v = c.health.valueOn(metric, day);
            if (v != null) known.add(v);
          }
          if (known.length < 3) return null;
          final mean = known.reduce((a, b) => a + b) / known.length;
          final years = yearsOn(curve, mean);
          return years < -0.3 ? -1 : (years > 0.3 ? 1 : 0);
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final l10n = c.l10n;
    final t = c.t;
    final factors = _factorsOf(widget.result, widget.area);
    final status = _statusOf(factors);
    final statement = switch (status) {
      MonoStatus.favorable => l10n.monoAreaFavorable,
      MonoStatus.typical => l10n.monoAreaTypical,
      MonoStatus.attention => l10n.monoAreaAttention,
      MonoStatus.none => l10n.monoAreaNone,
    };
    final still = monoStill(context);
    return Semantics(
      container: true,
      button: factors.isNotEmpty,
      expanded: _open,
      label: '${widget.area.label(l10n)}, $statement',
      child: ExcludeSemantics(
        child: MonoPress(
          squash: 0.012,
          onTap: factors.isEmpty ? null : () => setState(() => _open = !_open),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.area.label(l10n),
                        style: MonoType.category(t.ink),
                      ),
                    ),
                    _Chip(status, c),
                    if (factors.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _open ? 0.25 : 0,
                        duration: still
                            ? Duration.zero
                            : const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: t.ink3,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(statement, style: MonoType.statement(t)),
                const SizedBox(height: 18),
                MonoWeekMarkers(states: _weeks()),
                AnimatedSize(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _open
                      ? Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: _Slide(
                            child: MonoFactorBars(
                              rows: [
                                for (final f in factors)
                                  (
                                    _title(l10n, f.kind),
                                    '${_reading(c.formats, f)} · ${_years(c, f.years)}',
                                    f.years,
                                  ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the factors of an area slide in as it unfolds.
class _Slide extends StatelessWidget {
  const _Slide({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: monoStill(context) ? 1 : 0, end: 1),
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
    ),
    child: child,
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.status, this.c);

  final MonoStatus status;
  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final t = c.t;
    final l10n = c.l10n;
    final (bg, fg, text) = switch (status) {
      MonoStatus.favorable => (
        t.recoveryBg,
        t.recovery,
        l10n.monoStatusFavorable,
      ),
      MonoStatus.typical => (t.fill, t.ink2, l10n.monoStatusTypical),
      MonoStatus.attention => (t.heartBg, t.heart, l10n.monoStatusAttention),
      MonoStatus.none => (t.fill, t.ink3, l10n.noData),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: MonoType.inter(13, 18, FontWeight.w600, fg)),
    );
  }
}

class _Weight extends StatelessWidget {
  const _Weight(this.c);

  final MonoCtx c;

  @override
  Widget build(BuildContext context) {
    final l10n = c.l10n;
    final values = c.days(Metric.weight, 90);
    final known = values.whereType<double>().toList();
    if (known.isEmpty) return const SizedBox.shrink();
    final target = c.settings.targetWeightKg;
    return MonoCard(
      category: MonoCategory.body,
      categoryLabel: l10n.metricWeight,
      statement: l10n.monoWeight90,
      semanticsLabel: '${l10n.metricWeight}, ${l10n.monoWeight90}',
      onTap: target == null ? () => showTargetWeightSheet(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoStat(
            value: Metric.weight.format(c.formats, known.last),
            unit: Metric.weight.unit,
            label: target == null
                ? null
                : l10n.targetNamed(
                    Metric.weight.formatWithUnit(c.formats, target),
                  ),
          ),
          const SizedBox(height: 18),
          MonoLine(
            values: values,
            goal: target,
            semantics: l10n.monoWeight90,
            height: 96,
          ),
        ],
      ),
    );
  }
}
