import 'health_history.dart';
import 'health_snapshot.dart';
import 'models.dart';

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
  Future<HealthSnapshot> load(DateTime now, {HealthSnapshot? previous});

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
  Future<HealthSnapshot> load(DateTime now, {HealthSnapshot? previous}) =>
      throw StateError('No health store on this platform.');

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
}
