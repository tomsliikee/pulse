import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/heart_day.dart';
import 'package:pulse/data/models.dart';

HeartSample _at(int minute, int bpm) =>
    HeartSample(minuteOfDay: minute, bpm: bpm);

void main() {
  // A morning, a gap of three hours, an afternoon.
  final day = [
    _at(420, 60),
    _at(430, 64),
    _at(480, 90),
    _at(660, 120),
    _at(720, 150),
  ];

  test('positions are true to time, so a gap stays as wide as it was', () {
    expect(curvePositions(day), [0, 10 / 300, 60 / 300, 240 / 300, 1]);
    expect(curvePositions(const []), isEmpty);
    expect(curvePositions([_at(600, 70)]), [0]);
  });

  test('the nearest sample is picked, also in a gap and past the ends', () {
    expect(indexNear(day, 0), 0);
    expect(indexNear(day, 1), 4);
    expect(indexNear(day, -3), 0);
    expect(indexNear(day, 7), 4);
    // 08:30 is nearer to 08:00, 10:00 nearer to 11:00.
    expect(indexNear(day, 90 / 300), 2);
    expect(indexNear(day, 180 / 300), 3);
    expect(indexNear([_at(600, 70)], 0.5), 0);
  });

  test('a whole day is marked every six hours, away from its ends', () {
    expect(hourMarks(0, 1430), [360, 720, 1080]);
    // Until 15:00: 06:00 and 12:00.
    expect(hourMarks(0, 900), [360, 720]);
  });

  test('a shorter span is marked more finely, never at its very ends', () {
    expect(hourMarks(420, 1080), [540, 720, 900]);
    expect(hourMarks(600, 720), [660]);
    expect(hourMarks(600, 640), isEmpty);
    expect(hourMarks(600, 600), isEmpty);
    for (final (first, last) in [(0, 1430), (330, 1110), (415, 505)]) {
      for (final mark in hourMarks(first, last)) {
        expect(mark % 60, 0);
        expect((mark - first) / (last - first), inInclusiveRange(0.08, 0.92));
      }
    }
  });

  test('the summary is the lowest, the highest and the rounded mean', () {
    expect(heartSummary(day), (low: 60, high: 150, average: 97));
    expect(heartSummary(const []), isNull);
  });

  test('every sample counts its minutes for the zone it is in', () {
    expect(zoneMinutes(day), [20, 10, 10, 10]);
    expect(zoneMinutes([_at(0, 70), _at(10, 115), _at(20, 140)]), [
      0,
      heartBucketMinutes,
      heartBucketMinutes,
      heartBucketMinutes,
    ]);
  });

  test('hours without samples are left out', () {
    final hours = heartHours(day);
    expect([for (final hour in hours) hour.hour], [7, 8, 11, 12]);
    expect(hours.first.low, 60);
    expect(hours.first.high, 64);
    expect(hours.first.average, 62);
  });
}
