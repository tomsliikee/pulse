import 'package:material_ui/material_ui.dart';

import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../features/detail/metric_spec.dart';
import '../data/mono_data.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_page.dart';
import 'category_page.dart';
import 'list_pages.dart';

/// Browse: the pinned values and every category, filtered live by the
/// search that floats above the bar.
class MonoBrowsePage extends StatelessWidget {
  const MonoBrowsePage({super.key, required this.query});

  /// The text of the search, shared with the search of the floating bar.
  final ValueNotifier<String> query;

  static const _categories = [
    MonoCategory.activity,
    MonoCategory.workouts,
    MonoCategory.heart,
    MonoCategory.vitals,
    MonoCategory.sleep,
    MonoCategory.body,
    MonoCategory.nutrition,
    MonoCategory.supplements,
  ];

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings, query]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final q = query.value.trim().toLowerCase();
        bool match(String s) => q.isEmpty || s.toLowerCase().contains(q);
        final pinned =
            <_Pin>[
              _Pin(MonoCategory.activity, Metric.steps),
              _Pin(MonoCategory.sleep, Metric.sleep),
              _Pin(MonoCategory.heart, Metric.restingHeartRate),
              _Pin(MonoCategory.body, Metric.weight),
            ].where(
              (p) =>
                  match(p.metric.title(l10n)) || match(p.category.label(l10n)),
            );
        final cats = _categories
            .where((cat) => match(cat.label(l10n)))
            .toList();
        final workouts = q.isEmpty || match(l10n.monoLatestWorkouts)
            ? c.health.workouts.reversed.take(3).toList()
            : <Workout>[];
        return MonoPage(
          floatTitle: l10n.monoBrowse,
          // Room for the search that floats above the bar.
          bottomInset: 214,
          children: [
            MonoSerif.title(l10n.monoBrowse),
            const SizedBox(height: 40),
            if (pinned.isNotEmpty) ...[
              MonoSection(l10n.monoPinned),
              const SizedBox(height: 14),
              MonoSurface(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  children: [
                    for (final (i, p) in pinned.indexed) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _PinRow(c: c, pin: p),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 44),
            ],
            if (workouts.isNotEmpty) ...[
              MonoSection(l10n.monoLatestWorkouts),
              const SizedBox(height: 14),
              MonoSurface(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  children: [
                    for (final (i, w) in workouts.indexed) ...[
                      if (i > 0) const SizedBox(height: 16),
                      monoWorkoutRow(c, w),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 44),
            ],
            if (cats.isNotEmpty) ...[
              MonoSection(l10n.monoCategories),
              const SizedBox(height: 14),
              MonoSurface(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  children: [
                    for (final (i, cat) in cats.indexed) ...[
                      if (i > 0) const SizedBox(height: 16),
                      MonoRow(
                        title: cat.label(l10n),
                        leading: _Tile(cat, c.t),
                        onTap: () => openMonoCategory(
                          context,
                          cat,
                          backLabel: l10n.monoBrowse,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (pinned.isEmpty && cats.isEmpty && workouts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(l10n.noData, style: MonoType.sub(c.t)),
              ),
          ],
        );
      },
    );
  }
}

class _Pin {
  const _Pin(this.category, this.metric);

  final MonoCategory category;
  final Metric metric;
}

class _PinRow extends StatelessWidget {
  const _PinRow({required this.c, required this.pin});

  final MonoCtx c;
  final _Pin pin;

  @override
  Widget build(BuildContext context) {
    final metric = pin.metric;
    double? value;
    DateTime? day;
    for (var back = 0; back < 90 && value == null; back++) {
      day = DateTime(c.today.year, c.today.month, c.today.day - back);
      value = c.health.valueOn(metric, day);
    }
    final shown = metric == Metric.sleep && value != null
        ? c.formats.duration((value * 60).round())
        : metric.format(c.formats, value);
    return MonoRow(
      title: metric.title(c.l10n),
      subtitle: pin.category.label(c.l10n),
      value: shown,
      unit: metric == Metric.sleep ? null : metric.unitFor(c.l10n, value),
      when: value == null || day == null
          ? null
          : c.formats.relativeDay(day, c.today),
      onTap: () =>
          openMonoCategory(context, pin.category, backLabel: c.l10n.monoBrowse),
    );
  }
}

/// A category's square icon on a solid ground.
class _Tile extends StatelessWidget {
  const _Tile(this.category, this.t);

  final MonoCategory category;
  final MonoTokens t;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: t.solid,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(category.icon, size: 19, color: t.onSolid),
  );
}
