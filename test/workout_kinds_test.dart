import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:pulse/data/health_connect_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/workout_archive.dart';
import 'package:pulse/data/workout_insights.dart';
import 'package:pulse/features/activity/workout_style.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

void main() {
  test('every kind the plugin reads on Android has a kind of its own', () {
    // What the plugin's reader can name; see workoutTypeOf.
    const read = {
      HealthWorkoutActivityType.AMERICAN_FOOTBALL: WorkoutType.americanFootball,
      HealthWorkoutActivityType.BADMINTON: WorkoutType.badminton,
      HealthWorkoutActivityType.CARDIO_DANCE: WorkoutType.dance,
      HealthWorkoutActivityType.CROSS_COUNTRY_SKIING: WorkoutType.ski,
      HealthWorkoutActivityType.GUIDED_BREATHING: WorkoutType.breathing,
      HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
          WorkoutType.hiit,
      HealthWorkoutActivityType.RUNNING_TREADMILL: WorkoutType.treadmill,
      HealthWorkoutActivityType.SWIMMING_OPEN_WATER: WorkoutType.openWater,
      HealthWorkoutActivityType.SWIMMING_POOL: WorkoutType.swim,
      HealthWorkoutActivityType.TENNIS: WorkoutType.tennis,
      HealthWorkoutActivityType.WEIGHTLIFTING: WorkoutType.weights,
      HealthWorkoutActivityType.WHEELCHAIR: WorkoutType.wheelchair,
      HealthWorkoutActivityType.OTHER: WorkoutType.other,
      HealthWorkoutActivityType.FISHING: WorkoutType.other,
    };
    read.forEach((from, to) => expect(workoutTypeOf(from), to));
    // No kind is out of reach.
    final reached = {
      for (final type in HealthWorkoutActivityType.values) workoutTypeOf(type),
    };
    expect(reached, WorkoutType.values.toSet());
  });

  test('a kind once read as a coarser one keeps that one\'s key', () {
    final start = DateTime(2026, 10, 3, 9);
    Workout of(WorkoutType type) =>
        Workout(type: type, start: start, minutes: 30);
    expect(of(WorkoutType.treadmill).key, of(WorkoutType.run).key);
    expect(of(WorkoutType.weights).key, of(WorkoutType.strength).key);
    expect(of(WorkoutType.pilates).key, of(WorkoutType.yoga).key);
    expect(of(WorkoutType.openWater).key, of(WorkoutType.swim).key);
    expect(of(WorkoutType.tennis).key, of(WorkoutType.other).key);
    expect(of(WorkoutType.run).key, isNot(of(WorkoutType.walk).key));
  });

  test('a workout read again as a finer kind takes the place of the stored '
      'one and keeps its heart rate', () {
    final start = DateTime(2026, 10, 3, 9);
    final stored = Workout(
      type: WorkoutType.other,
      start: start,
      minutes: 60,
      avgBpm: 140,
      maxBpm: 170,
      fineKcal: 400,
    );
    final merged = mergeWorkouts(
      [stored],
      [Workout(type: WorkoutType.tennis, start: start, minutes: 60)],
    );
    expect(merged, hasLength(1));
    expect(merged!.single.type, WorkoutType.tennis);
    expect(merged.single.avgBpm, 140);
    expect(merged.single.fineKcal, 400);
  });

  test('only what covers ground on foot or in the water has a pace, only '
      'what rolls or glides a speed', () {
    Workout of(WorkoutType type) => Workout(
      type: type,
      start: DateTime(2026, 10, 3, 9),
      minutes: 60,
      distanceKm: 6,
    );
    for (final type in WorkoutType.values) {
      final pace = measureOf(of(type), WorkoutMeasure.pace);
      final speed = measureOf(of(type), WorkoutMeasure.speed);
      expect(pace != null && speed != null, isFalse, reason: type.name);
    }
    expect(measureOf(of(WorkoutType.treadmill), WorkoutMeasure.pace), 10);
    expect(measureOf(of(WorkoutType.ski), WorkoutMeasure.speed), 6);
    expect(measureOf(of(WorkoutType.tennis), WorkoutMeasure.pace), isNull);
    expect(measureOf(of(WorkoutType.tennis), WorkoutMeasure.speed), isNull);
  });

  test('strength counts where the body is loaded, not on the wall', () {
    expect(WorkoutType.strength.buildsStrength, isTrue);
    expect(WorkoutType.weights.buildsStrength, isTrue);
    expect(WorkoutType.calisthenics.buildsStrength, isTrue);
    expect(WorkoutType.climbing.buildsStrength, isFalse);
    expect(WorkoutType.run.buildsStrength, isFalse);
  });

  test('every kind has a name in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final type in WorkoutType.values) {
        expect(type.label(l10n), isNotEmpty);
      }
      expect(
        {for (final type in WorkoutType.values) type.label(l10n)}.length,
        WorkoutType.values.length,
        reason: locale.languageCode,
      );
    }
  });
}
