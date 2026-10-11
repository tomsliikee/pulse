import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/energy_balance.dart';
import 'package:pulse/data/metric_catalog.dart';

void main() {
  final today = DateTime(2026, 10, 6);
  DateTime ago(int days) => DateTime(2026, 10, 6 - days);

  /// The balance of values given by how many days ago they are from.
  EnergyBalance balance({
    double? Function(int ago)? eaten,
    double? Function(int ago)? weight,
    double? Function(int ago)? source,
    double? Function(int ago)? fine,
  }) => energyBalance(
    today: today,
    valueOn: (metric, day) {
      final back = today.difference(day).inDays;
      expect(day, ago(back));
      return switch (metric) {
        Metric.energyIntake => eaten?.call(back),
        Metric.weight => weight?.call(back),
        Metric.totalEnergy => source?.call(back),
        Metric.fineTotalEnergy => fine?.call(back),
        _ => null,
      };
    },
  );

  test('a steady weight says the burn is what was eaten', () {
    final result = balance(eaten: (_) => 2800, weight: (_) => 80);
    expect(result.complete, isTrue);
    expect(result.eaten, 2800);
    expect(result.kgPerWeek, closeTo(0, 1e-9));
    expect(result.burn, closeTo(2800, 1e-6));
  });

  test('losing half a kilo a week adds 550 kcal a day', () {
    // 28 days ago is the oldest day; the weight falls by 1/14 kg a day.
    final result = balance(
      eaten: (_) => 2300,
      weight: (back) => 80 + back / 14,
    );
    expect(result.kgPerWeek, closeTo(-0.5, 1e-9));
    expect(result.burn, closeTo(2300 + 550, 1e-6));
  });

  test('gaining takes it off, and the line holds through uneven weigh-ins', () {
    final result = balance(
      eaten: (_) => 3000,
      // Weighed every fourth day, a little off the line each time.
      weight: (back) =>
          back % 4 == 0 ? 80 - back / 28 + (back % 8 == 0 ? 0.2 : -0.2) : null,
    );
    expect(result.weighIns, 7);
    expect(result.kgPerWeek, closeTo(0.25, 0.03));
    expect(result.burn, closeTo(3000 - 275, 35));
  });

  test('days without food are left out of the mean, up to four of them', () {
    final result = balance(
      eaten: (back) => back <= 4 ? null : 2400,
      weight: (_) => 80,
    );
    expect(result.foodDays, 24);
    expect(result.burn, closeTo(2400, 1e-6));
  });

  test('too little says what is missing and gives no burn', () {
    final food = balance(
      eaten: (back) => back <= 5 ? null : 2400,
      weight: (_) => 80,
    );
    expect(food.foodDays, 23);
    expect(food.enoughFood, isFalse);
    expect(food.enoughWeight, isTrue);
    expect(food.burn, isNull);

    final few = balance(
      eaten: (_) => 2400,
      weight: (back) => back % 7 == 0 ? 80 : null,
    );
    expect(few.weighIns, 4);
    expect(few.enoughWeight, isFalse);
    expect(few.burn, isNull);

    // Enough weigh-ins, but none in the last week.
    final early = balance(
      eaten: (_) => 2400,
      weight: (back) => back > 10 ? 80 : null,
    );
    expect(early.weighIns, 18);
    expect(early.weighedLate, isFalse);
    expect(early.burn, isNull);

    final none = balance();
    expect(none.foodDays, 0);
    expect(none.weighIns, 0);
    expect(none.complete, isFalse);
  });

  test('the estimates stand beside it once they have enough days', () {
    final result = balance(
      eaten: (_) => 2800,
      weight: (_) => 80,
      source: (_) => 3100,
      fine: (back) => back <= 14 ? 2850 : null,
    );
    expect(result.source, 3100);
    expect(result.fine, 2850);

    final young = balance(
      eaten: (_) => 2800,
      weight: (_) => 80,
      fine: (back) => back <= 13 ? 2850 : null,
    );
    expect(young.fine, isNull);
    expect(young.source, isNull);
  });

  test('today is not part of the window', () {
    final asked = <DateTime>{};
    energyBalance(
      today: today,
      valueOn: (metric, day) {
        asked.add(day);
        return null;
      },
    );
    expect(asked.length, balanceDays);
    expect(asked, isNot(contains(today)));
    expect(asked, contains(ago(1)));
    expect(asked, contains(ago(28)));
  });
}
