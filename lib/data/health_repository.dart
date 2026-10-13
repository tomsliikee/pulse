import 'fine_values.dart';
import 'health_history.dart';
import 'health_snapshot.dart';
import 'models.dart';
import 'routes.dart';
import 'step_counting.dart';

enum HealthAccess {
  granted,

  /// The user has not allowed reading yet, or has revoked it.
  denied,

  /// Health Connect is missing or needs an update.
  unavailable,

  /// This platform has no health store the app can read.
  unsupported,
}

/// The health store refused to write or delete an entry.
class HealthStoreException implements Exception {
  const HealthStoreException(this.message);

  final String message;

  @override
  String toString() => 'HealthStoreException: $message';
}

/// Where health data comes from and goes to. The app talks to this and never
/// to a platform API, so another source can be put behind it later.
abstract interface class HealthRepository {
  Future<HealthAccess> access();

  /// Shows the system's permission dialog.
  Future<HealthAccess> requestAccess();

  /// Opens the store page that installs or updates the health store.
  Future<void> installStore();

  /// Reads the window ending at [now]. With [previous], what cannot have
  /// changed since it was loaded may be taken from it instead of read again.
  /// With [maxHeartRate], days without recorded intensity minutes get the
  /// ones estimated from their heart rate. With [fine], the days whose heart
  /// rate is read get their fine values as well. The steps are counted the
  /// [steps] way; a [previous] must have been read the same way.
  Future<HealthSnapshot> load(
    DateTime now, {
    HealthSnapshot? previous,
    int? maxHeartRate,
    FineProfile? fine,
    StepCounting steps = StepCounting.store,
  });

  Future<void> add(EntryDraft draft);

  /// Only valid for entries with [HealthEntry.isOwn].
  Future<void> delete(HealthEntry entry);

  Future<bool> backgroundAccessGranted();

  Future<bool> requestBackgroundAccess();

  /// Whether data older than the store's default window may be read.
  Future<bool> historyAccessGranted();

  Future<bool> requestHistoryAccess();

  /// One value per day and metric for the days from [from] to [to], both
  /// inclusive. Used once to fill the history with what the store already has.
  Future<DailyValues> loadHistory(DateTime from, DateTime to);

  /// The workouts that started from [from] to [to], both days inclusive.
  /// Used once to fill the workout archive with what the store already has.
  Future<List<Workout>> loadWorkouts(
    DateTime from,
    DateTime to, {
    StepCounting steps = StepCounting.store,
  });

  /// What the store counted from [start] to [end], by the day it fell on:
  /// its totals, the minutes of activity and the floors. Used to take a
  /// removed workout out of its days.
  Future<DailyValues> loadTotalsDuring(
    DateTime start,
    DateTime end, {
    StepCounting steps = StepCounting.store,
  });

  /// The nights that ended on the days from [from] to [to], both inclusive,
  /// as the archive keeps them. Used once to fill the night archive.
  Future<List<SleepNight>> loadNights(DateTime from, DateTime to);

  /// The meals eaten on the days from [from] to [to], both inclusive. Used
  /// once to fill the food archive with what the store already has.
  Future<List<HealthEntry>> loadMeals(DateTime from, DateTime to);

  /// The routes of the workouts that started on the days from [from] to
  /// [to], both inclusive, as far as the store hands them out.
  Future<RouteReading> loadRoutes(DateTime from, DateTime to);

  /// Asks the user to let the app read the route of the workout the store
  /// names [consentFor], and with it, if they choose so, every route.
  /// Whether a route was allowed.
  Future<bool> requestRouteAccess(String consentFor);
}

/// Used where there is nothing to read from, such as the desktop build.
class UnsupportedHealthRepository implements HealthRepository {
  const UnsupportedHealthRepository();

  @override
  Future<HealthAccess> access() async => HealthAccess.unsupported;

  @override
  Future<HealthAccess> requestAccess() async => HealthAccess.unsupported;

  @override
  Future<void> installStore() async {}

  @override
  Future<HealthSnapshot> load(
    DateTime now, {
    HealthSnapshot? previous,
    int? maxHeartRate,
    FineProfile? fine,
    StepCounting steps = StepCounting.store,
  }) => throw StateError('No health store on this platform.');

  @override
  Future<void> add(EntryDraft draft) =>
      throw StateError('No health store on this platform.');

  @override
  Future<void> delete(HealthEntry entry) =>
      throw StateError('No health store on this platform.');

  @override
  Future<bool> backgroundAccessGranted() async => false;

  @override
  Future<bool> requestBackgroundAccess() async => false;

  @override
  Future<bool> historyAccessGranted() async => false;

  @override
  Future<bool> requestHistoryAccess() async => false;

  @override
  Future<DailyValues> loadHistory(DateTime from, DateTime to) async => const {};

  @override
  Future<List<Workout>> loadWorkouts(
    DateTime from,
    DateTime to, {
    StepCounting steps = StepCounting.store,
  }) async => const [];

  @override
  Future<DailyValues> loadTotalsDuring(
    DateTime start,
    DateTime end, {
    StepCounting steps = StepCounting.store,
  }) async => const {};

  @override
  Future<List<SleepNight>> loadNights(DateTime from, DateTime to) async =>
      const [];

  @override
  Future<List<HealthEntry>> loadMeals(DateTime from, DateTime to) async =>
      const [];

  @override
  Future<RouteReading> loadRoutes(DateTime from, DateTime to) async =>
      (routes: const <WorkoutRoute>[], consentFor: null);

  @override
  Future<bool> requestRouteAccess(String consentFor) async => false;
}
