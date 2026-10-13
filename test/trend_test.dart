import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/period.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/data/trend.dart';
import 'package:pulse/features/profile/target_weight_sheet.dart';

import 'support/fixtures.dart';

/// Tuesday.
final _today = DateTime(2026, 10, 6);

HealthHistory _history(Map<DateTime, double> weights) =>
    HealthHistory()..merge({Metric.weight: weights});

PeriodView _view(HealthHistory history, PeriodKind kind, {int offset = 0}) =>
    buildPeriod(
      history: history,
      metric: Metric.weight,
      kind: kind,
      today: _today,
      offset: offset,
    );

List<TrendPoint> _points(HealthHistory history, PeriodKind kind) => trendPoints(
  history: history,
  metric: Metric.weight,
  view: _view(history, kind),
);

List<PeriodBucket> _rows(HealthHistory history, PeriodKind kind) => trendRows(
  history: history,
  metric: Metric.weight,
  view: _view(history, kind),
);

void main() {
  final history = _history({
    DateTime(2024, 3, 10): 120,
    DateTime(2026, 9, 1): 116,
    DateTime(2026, 9, 3): 115,
    DateTime(2026, 9, 28): 113,
    DateTime(2026, 10, 1): 112.8,
    DateTime(2026, 10, 4): 112.4,
    DateTime(2026, 10, 5): 112.2,
    DateTime(2026, 10, 6): 112,
  });

  test('a week has a point for each day that was measured, true to time', () {
    final points = _points(history, PeriodKind.week);
    expect(
      [for (final p in points) p.day],
      [DateTime(2026, 10, 5), DateTime(2026, 10, 6)],
    );
    expect([for (final p in points) p.value], [112.2, 112]);
    // The middle of Monday and of Tuesday in a week of seven days.
    expect(points[0].position, closeTo(0.5 / 7, 1e-9));
    expect(points[1].position, closeTo(1.5 / 7, 1e-9));
  });

  test('a day without a measurement leaves no point and no row', () {
    final points = _points(history, PeriodKind.month);
    expect([for (final p in points) p.day.day], [1, 4, 5, 6]);
    expect(points.first.position, closeTo(0.5 / 31, 1e-9));
    expect(points.last.position, closeTo(5.5 / 31, 1e-9));
  });

  test('a year keeps its days, everything has one point a month', () {
    expect(_points(history, PeriodKind.year), hasLength(7));

    final all = _points(history, PeriodKind.all);
    expect(
      [for (final p in all) p.day],
      [DateTime(2024, 3), DateTime(2026, 9), DateTime(2026, 10)],
    );
    expect(all[1].value, closeTo((116 + 115 + 113) / 3, 1e-9));
    expect(all.first.position, greaterThan(0));
    expect(all.last.position, lessThan(1));
    for (var i = 1; i < all.length; i++) {
      expect(all[i].position, greaterThan(all[i - 1].position));
    }
  });

  test('a single day has no line', () {
    expect(_points(history, PeriodKind.today), isEmpty);
    expect(_rows(history, PeriodKind.today), isEmpty);
  });

  test('the change is the last point against the first', () {
    expect(
      trendChange(_points(history, PeriodKind.month)),
      closeTo(-0.8, 1e-9),
    );
    expect(trendChange(_points(history, PeriodKind.year)), closeTo(-4, 1e-9));
    expect(trendChange(const []), isNull);
    expect(
      trendChange(_points(_history({_today: 112}), PeriodKind.week)),
      isNull,
    );
  });

  test('the rows of a week are its measured days, newest first', () {
    final rows = _rows(history, PeriodKind.week);
    expect([for (final r in rows) r.start.day], [6, 5]);
    expect([for (final r in rows) r.value], [112, 112.2]);
  });

  test('the rows of a month are its weeks from Monday, cut at its ends', () {
    final rows = _rows(history, PeriodKind.month);
    // October 2026 starts on a Thursday.
    expect([for (final r in rows) (r.start.day, r.end.day)], [(5, 11), (1, 4)]);
    expect(rows[0].value, closeTo(112.1, 1e-9));
    expect(rows[1].value, closeTo(112.6, 1e-9));

    final september = trendRows(
      history: history,
      metric: Metric.weight,
      view: _view(history, PeriodKind.month, offset: 1),
    );
    expect(
      [for (final r in september) (r.start.day, r.end.day)],
      [(28, 30), (1, 6)],
    );
  });

  test('the rows of a year are months and those of everything years', () {
    expect(
      [for (final r in _rows(history, PeriodKind.year)) r.start.month],
      [10, 9],
    );
    expect(
      [for (final r in _rows(history, PeriodKind.all)) r.start.year],
      [2026, 2024],
    );
  });

  test('a target weight is read from what a user types', () {
    expect(parseTargetWeightKg('100'), 100);
    expect(parseTargetWeightKg(' 99,5 kg'), 99.5);
    expect(parseTargetWeightKg('99.46'), 99.5);
    expect(parseTargetWeightKg('19'), isNull);
    expect(parseTargetWeightKg('401'), isNull);
    expect(parseTargetWeightKg('leicht'), isNull);
  });

  test('a target weight is saved, loaded and taken away again', () async {
    final store = MemoryJsonStore();
    final settings = SettingsController(store)..setTargetWeightKg(99.5);
    await Future<void>.delayed(Duration.zero);
    final loaded = SettingsController(store);
    await loaded.load();
    expect(loaded.targetWeightKg, 99.5);

    settings.setTargetWeightKg(500);
    expect(settings.targetWeightKg, 99.5);
    settings.setTargetWeightKg(null);
    await Future<void>.delayed(Duration.zero);
    final cleared = SettingsController(store);
    await cleared.load();
    expect(cleared.targetWeightKg, isNull);

    store.documents['settings'] = '{"targetWeightKg":5}';
    final refused = SettingsController(store);
    await refused.load();
    expect(refused.targetWeightKg, isNull);

    store.documents['settings'] = '{"targetWeightKg":100}';
    final whole = SettingsController(store);
    await whole.load();
    expect(whole.targetWeightKg, 100);
  });
}
