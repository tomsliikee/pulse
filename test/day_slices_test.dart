import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/health_connect_repository.dart';

void main() {
  const slices = HealthConnectRepository.daySlices;

  test('a stretch is cut at every local midnight and nowhere else', () {
    expect(slices(DateTime(2026, 10, 6), DateTime(2026, 10, 8, 15, 30)), [
      (DateTime(2026, 10, 6), DateTime(2026, 10, 7)),
      (DateTime(2026, 10, 7), DateTime(2026, 10, 8)),
      (DateTime(2026, 10, 8), DateTime(2026, 10, 8, 15, 30)),
    ]);
  });

  test('a stretch inside one day stays whole, and it may start at any '
      'time', () {
    expect(slices(DateTime(2026, 10, 8, 9), DateTime(2026, 10, 8, 15)), [
      (DateTime(2026, 10, 8, 9), DateTime(2026, 10, 8, 15)),
    ]);
    expect(slices(DateTime(2026, 10, 7, 22), DateTime(2026, 10, 8, 1)), [
      (DateTime(2026, 10, 7, 22), DateTime(2026, 10, 8)),
      (DateTime(2026, 10, 8), DateTime(2026, 10, 8, 1)),
    ]);
  });

  test('the pieces leave no gap and do not overlap, across the end of '
      'summer time too', () {
    final start = DateTime(2026, 10, 20, 7);
    final end = DateTime(2026, 10, 28, 12);
    final pieces = slices(start, end);
    expect(pieces.first.$1, start);
    expect(pieces.last.$2, end);
    for (var i = 1; i < pieces.length; i++) {
      expect(pieces[i].$1, pieces[i - 1].$2);
      expect(pieces[i].$1.hour, 0);
    }
    expect(pieces, hasLength(9));
  });

  test('an empty stretch has no pieces', () {
    expect(slices(DateTime(2026, 10, 8), DateTime(2026, 10, 8)), isEmpty);
  });
}
