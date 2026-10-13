import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/step_counting.dart';

const _watch = 'com.fitbit.FitbitMobile';
const _phone = 'com.android.healthconnect.phone';

DateTime _at(int hour, [int minute = 0, int day = 8]) =>
    DateTime(2026, 10, day, hour, minute);

/// [count] steps of [source], written from [from] for [minutes].
StepRecord _steps(
  String source,
  DateTime from,
  double count, [
  int minutes = 1,
]) => StepRecord(source, from, from.add(Duration(minutes: minutes)), count);

double _sum(Map<DateTime, double> hours) =>
    hours.values.fold(0, (sum, steps) => sum + steps);

void main() {
  group('StepCounting', () {
    // Both count from nine to ten, the phone a little more; from ten to
    // eleven the watch wrote nothing.
    final day = [
      _steps(_watch, _at(9, 10), 1000, 30),
      _steps(_phone, _at(9, 10), 1200, 30),
      _steps(_phone, _at(10, 5), 3000, 40),
    ];

    test('the mean of the day halves an hour only one source saw', () {
      final hours = stepsByHour(day, StepCounting.dayMean);
      expect(hours, {_at(9): 1100, _at(10): 1500});
    });

    test('the mean of the hour counts such an hour in full', () {
      final hours = stepsByHour(day, StepCounting.hourMean);
      expect(hours, {_at(9): 1100, _at(10): 3000});
    });

    test('the watch alone leaves out what only the phone saw', () {
      final hours = stepsByHour(day, StepCounting.wearable);
      expect(hours, {_at(9): 1000});
    });

    test('the phone counts on a day the watch wrote nothing', () {
      final hours = stepsByHour([
        ...day,
        _steps(_phone, _at(12, 0, 9), 800),
      ], StepCounting.wearable);
      expect(hours, {_at(9): 1000, _at(12, 0, 9): 800});
    });

    test('of two watches the one with more steps that day is taken', () {
      final hours = stepsByHour([
        _steps(_watch, _at(9), 500),
        _steps('other.watch', _at(9), 700),
        _steps(_phone, _at(9), 900),
      ], StepCounting.wearable);
      expect(hours, {_at(9): 700});
    });

    test('three sources are divided by three, each day by its own', () {
      final records = [
        _steps(_watch, _at(9), 300),
        _steps('other.watch', _at(9), 600),
        _steps(_phone, _at(9), 900),
        _steps(_phone, _at(9, 0, 9), 400),
      ];
      expect(stepsByHour(records, StepCounting.dayMean), {
        _at(9): 600,
        _at(9, 0, 9): 400,
      });
      expect(stepsByHour(records, StepCounting.hourMean), {
        _at(9): 600,
        _at(9, 0, 9): 400,
      });
    });

    test('a record across the turn of an hour is shared out by time', () {
      final hours = stepsByHour([
        _steps(_watch, _at(9, 45), 400, 20),
      ], StepCounting.hourMean);
      expect(hours, {_at(9): 300, _at(10): 100});
    });

    test('a record without a length counts in the hour it stands in', () {
      final hours = stepsByHour([
        StepRecord(_watch, _at(9, 30), _at(9, 30), 50),
      ], StepCounting.wearable);
      expect(hours, {_at(9): 50});
    });

    test('a day the watch lost a walk on: 6,620 and 12,206', () {
      // As read on 8 October: the watch has nothing from three to four.
      final records = [
        _steps(_watch, _at(10), 6091, 60),
        _steps(_watch, _at(14), 529, 60),
        _steps(_phone, _at(10), 5370, 60),
        _steps(_phone, _at(14), 2260, 60),
        _steps(_phone, _at(15), 4576, 60),
      ];
      expect(_sum(stepsByHour(records, StepCounting.dayMean)), 9413);
      expect(_sum(stepsByHour(records, StepCounting.wearable)), 6620);
      expect(
        _sum(stepsByHour(records, StepCounting.hourMean)),
        (6091 + 5370) / 2 + (529 + 2260) / 2 + 4576,
      );
    });

    test('the store\'s own total is not worked out here', () {
      expect(() => stepsByHour(day, StepCounting.store), throwsArgumentError);
    });

    test('what a stretch of time holds is taken by the part inside', () {
      final records = [
        _steps(_watch, _at(9), 600, 60),
        _steps(_phone, _at(9), 1200, 60),
        _steps(_phone, _at(11), 100, 10),
      ];
      // Half of the hour both counted in.
      expect(
        stepsDuring(records, _at(9, 15), _at(9, 45), StepCounting.hourMean),
        450,
      );
      expect(
        stepsDuring(records, _at(9, 15), _at(9, 45), StepCounting.wearable),
        300,
      );
      expect(stepsDuring(records, _at(12), _at(13), StepCounting.dayMean), 0);
    });

    test('a saved name gives its way, anything else the store\'s', () {
      expect(
        savedStepCounting({'stepCounting': 'hourMean'}),
        StepCounting.hourMean,
      );
      expect(savedStepCounting({'stepCounting': 'gone'}), StepCounting.store);
      expect(savedStepCounting(const <String, Object?>{}), StepCounting.store);
      expect(savedStepCounting(null), StepCounting.store);
    });

    test('the phone is known by its package', () {
      expect(isPhoneCounter(_phone), isTrue);
      expect(isPhoneCounter(_watch), isFalse);
    });
  });
}
