import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backup.dart';
import 'body_age.dart';
import 'health_history.dart';
import 'health_repository.dart';
import 'health_snapshot.dart';
import 'json_store.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'night_archive.dart';
import 'settings_controller.dart';
import 'sync_report.dart';
import 'workout_archive.dart';

enum HealthStatus {
  /// Nothing to show yet.
  loading,
  needsAccess,
  unavailable,
  unsupported,
  ready,

  /// Reading failed and there is no earlier snapshot to fall back on.
  failed,
}

/// Holds the current snapshot, the selected day and the loading state.
class HealthController extends ChangeNotifier {
  HealthController({
    required this._repository,
    required this._store,
    this._clock = DateTime.now,
  });

  final HealthRepository _repository;
  final JsonStore _store;
  final DateTime Function() _clock;
  late final HistoryArchive _archive = HistoryArchive(_store);
  late final WorkoutArchive _workoutArchive = WorkoutArchive(_store);
  late final NightArchive _nightArchive = NightArchive(_store);

  /// How many days one request for older data covers.
  static const int backfillChunkDays = 90;

  /// Empty stretches in a row after which older data is assumed not to exist.
  static const int _emptyChunksToStop = 2;

  static const int weekLength = 7;

  /// 2: workouts carry the store's own totals of their time, so the ones
  /// loaded before, with the numbers of every source added up, are loaded
  /// once more.
  static const int _workoutBackfillVersion = 2;

  HealthStatus _status = HealthStatus.loading;
  HealthSnapshot? _snapshot;
  int _selectedIndex = 0;
  bool _refreshing = false;
  bool _backgroundAccess = false;
  HealthHistory? _history;
  DateTime? _backfillReached;
  bool _backfilling = false;
  bool _backfillingWorkouts = false;
  List<Workout> _workouts = const [];
  List<RemovedWorkout> _removedWorkouts = const [];
  bool _backfillingNights = false;
  List<SleepNight> _nights = const [];
  SyncReport? _backgroundSync;
  DateTime? _birthDate;

  /// The maximum heart rate the snapshot on screen was read with.
  int? _readWith;
  bool _refreshAgain = false;
  bool _disposed = false;
  int _revision = 0;

  /// Counts the changes, for what is worked out from the data and kept
  /// until the next one.
  int get revision => _revision;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  /// The birth date of the profile. The intensity minutes are estimated
  /// from the heart rate with it, so a change reads again.
  set birthDate(DateTime? value) {
    if (value == _birthDate) return;
    _birthDate = value;
    // Before the first read there is nothing to read again.
    if (_snapshot == null && !_refreshing) return;
    if (_refreshing) {
      _refreshAgain = true;
    } else {
      unawaited(refresh());
    }
  }

  int? get _maxHeartRate => switch (_birthDate) {
    final birthDate? => maxHeartRateOn(birthDate, _clock()),
    null => null,
  };

  HealthStatus get status => _status;
  bool get refreshing => _refreshing;
  bool get backgroundAccess => _backgroundAccess;

  /// What the last refresh in the background reported, if one has run.
  SyncReport? get backgroundSync => _backgroundSync;

  /// One value per day for as long as the app has been collecting. Null
  /// until it has been loaded from disk.
  HealthHistory? get history => _history;

  /// While older data is being fetched: the day it has reached so far.
  DateTime? get backfillReached => _backfilling ? _backfillReached : null;

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// The moment it is, by the clock the app was started with.
  DateTime get now => _clock();

  /// Only valid while [status] is [HealthStatus.ready].
  HealthSnapshot get snapshot => _snapshot!;

  /// The value of [metric] on [day]: from the snapshot inside its window,
  /// from the history before it.
  double? valueOn(Metric metric, DateTime day) {
    final index = _snapshot?.indexOf(day);
    return (index == null ? null : _snapshot?.value(metric, index)) ??
        _history?.value(metric, day);
  }

  /// Every day the app has steps for, oldest first.
  List<DateTime> get days {
    final snapshot = _snapshot;
    final keys = <int>{
      ...?_history?.daysOf(Metric.steps),
      if (snapshot != null)
        for (var i = 0; i < snapshot.dayCount; i++)
          if (snapshot.value(Metric.steps, i) != null)
            dayKey(snapshot.dateAt(i)),
    }.toList()..sort();
    return [for (final key in keys) dateOfKey(key)];
  }

  int get selectedIndex => _selectedIndex;
  int get todayIndex => snapshot.dayCount - 1;
  bool get isTodaySelected => _selectedIndex == todayIndex;
  DateTime get selectedDate => snapshot.dateAt(_selectedIndex);

  /// Index of the first day of the most recent week.
  int get weekStart => snapshot.dayCount - weekLength;

  double? value(Metric metric) => snapshot.value(metric, _selectedIndex);

  double? valueAt(Metric metric, int index) => snapshot.value(metric, index);

  SleepNight? get night => snapshot.nights[_selectedIndex];

  List<HeartSample> get heartSamples => snapshot.heart[_selectedIndex];

  /// Every night the app has seen, oldest first, as the archive keeps them:
  /// without the curve of the stages. Reaches further back than the
  /// snapshot's window.
  List<SleepNight> get nights => _nights;

  SleepNight? get latestNight => _nights.isEmpty ? null : _nights.last;

  /// [night] with the curve of its stages, as long as the snapshot's window
  /// still holds it.
  SleepNight withCurve(SleepNight night) {
    final index = _snapshot?.indexOf(night.date);
    return (index == null ? null : _snapshot?.nights[index]) ?? night;
  }

  /// Every workout the app has seen, oldest first. Reaches further back
  /// than the snapshot's window.
  List<Workout> get workouts => _workouts;

  Workout? get latestWorkout => _workouts.isEmpty ? null : _workouts.last;

  /// The workouts the user took out of the app, in the order of removal.
  List<RemovedWorkout> get removedWorkouts => _removedWorkouts;

  /// Shows the saved snapshot at once, then checks access and reads fresh.
  Future<void> start() async {
    final saved = HealthSnapshot.fromJson(
      await _store.read(StoreKeys.snapshot),
    );
    await _loadArchives();
    // The profile may not be loaded yet, and the first read needs it.
    _birthDate ??= savedBirthDate(await _store.read(StoreKeys.settings));
    if (_disposed) return;
    if (saved != null) {
      _show(saved);
      _readWith = _maxHeartRate;
    }
    await refresh();
    if (_disposed || _status != HealthStatus.ready) return;
    await _backfill();
    await _backfillWorkouts();
    await _backfillNights();
  }

  Future<void> _loadArchives() async {
    final history = await _archive.load(_clock());
    final workouts = await _workoutArchive.load();
    final removed = await _workoutArchive.loadRemoved();
    final nights = await _nightArchive.load();
    final sync = SyncReport.fromJson(await _store.read(StoreKeys.sync));
    if (_disposed) return;
    _history = history;
    _workouts = List.unmodifiable(workouts);
    _removedWorkouts = List.unmodifiable(removed);
    _nights = List.unmodifiable(nights);
    _backgroundSync = sync;
  }

  /// The history, the nights, the workouts and the settings as one text to
  /// keep outside the app.
  Future<String> backup() => exportBackup(_store, _clock());

  /// Adds what the backup [text] holds to the app's data and shows it.
  /// Throws a [FormatException] when [text] is not a backup.
  Future<BackupResult> restore(String text) async {
    final result = await importBackup(_store, text, _clock());
    await _loadArchives();
    if (!_disposed) notifyListeners();
    return result;
  }

  /// A snapshot younger than this is not read again when the app merely
  /// comes back to the foreground.
  static const Duration _freshFor = Duration(minutes: 2);

  /// Reads again unless the data on screen was loaded a moment ago.
  Future<void> refreshIfStale() async {
    final snapshot = _snapshot;
    if (snapshot != null &&
        _clock().difference(snapshot.loadedAt).abs() < _freshFor) {
      return;
    }
    await refresh();
  }

  /// With [full], nothing is taken over from the snapshot on screen; that
  /// also picks up records a source wrote late for a day long past.
  Future<void> refresh({bool full = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!_disposed) notifyListeners();
    try {
      final access = await _repository.access();
      if (_disposed) return;
      if (access != HealthAccess.granted) {
        _snapshot = null;
        _status = switch (access) {
          HealthAccess.denied => HealthStatus.needsAccess,
          HealthAccess.unavailable => HealthStatus.unavailable,
          _ => HealthStatus.unsupported,
        };
        return;
      }
      final shown = _snapshot;
      final maxHeartRate = _maxHeartRate;
      final read = await _repository.load(
        _clock(),
        // The first read of a day is a full one as well, and so is the one
        // after the profile's age changed what the heart rate means.
        previous:
            full ||
                shown == null ||
                shown.today != today ||
                maxHeartRate != _readWith
            ? null
            : shown,
        maxHeartRate: maxHeartRate,
      );
      _readWith = maxHeartRate;
      final fresh = withoutWorkouts(read, _removedWorkouts);
      final background = await _repository.backgroundAccessGranted();
      final sync = SyncReport.fromJson(await _store.read(StoreKeys.sync));
      if (_disposed) return;
      _backgroundAccess = background;
      _backgroundSync = sync;
      _show(fresh);
      await _store.write(StoreKeys.snapshot, fresh.toJson());
      await _archiveDays(dailyValuesOf(fresh));
      await _archiveWorkouts(
        workoutsWithHeart(fresh),
        // The read covers these days in full, so what the archive has
        // beyond it was deleted where it came from.
        window: (fresh.dateAt(0), fresh.loadedAt),
      );
      await _archiveNights(nightSummaries(fresh));
    } on Exception catch (error) {
      debugPrint('Health refresh failed: $error');
      // An earlier snapshot stays on screen; a failed read is no reason to
      // take the user's data away.
      if (_snapshot == null) _status = HealthStatus.failed;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
    if (_refreshAgain && !_disposed) {
      _refreshAgain = false;
      await refresh();
    }
  }

  Future<void> requestAccess() async {
    try {
      await _repository.requestAccess();
    } on Exception catch (error) {
      // The refresh below shows what access there is.
      debugPrint('Requesting access failed: $error');
    }
    if (_disposed) return;
    await refresh();
    if (_disposed || _status != HealthStatus.ready) return;
    await _backfill();
    await _backfillWorkouts();
    await _backfillNights();
  }

  Future<void> _archiveNights(List<SleepNight> nights) async {
    final merged = mergeNights(_nights, nights);
    if (merged == null) return;
    _nights = List.unmodifiable(merged);
    await _nightArchive.mergeIntoStore(nights);
  }

  Future<void> _archiveWorkouts(
    Iterable<Workout> workouts, {
    (DateTime, DateTime)? window,
  }) async {
    final all = await _workoutArchive.mergeIntoStore(workouts, window: window);
    if (_disposed) return;
    _workouts = List.unmodifiable(all);
  }

  /// Takes [workout] out of the app, with what the store counted while it
  /// ran: steps, distance, energy, minutes of activity and floors. The
  /// health store keeps all of it; an app cannot delete another's records.
  /// Returns what [restoreWorkout] needs to undo it.
  Future<RemovedWorkout> removeWorkout(Workout workout) async {
    var totals = const <Metric, Map<DateTime, double>>{};
    try {
      totals = await _repository.loadTotalsDuring(workout.start, workout.end);
    } on Exception catch (error) {
      debugPrint('Reading the totals of a workout failed: $error');
    }
    if (totals.values.every((days) => days.isEmpty)) {
      totals = ownTotals(workout);
    }
    final removed = RemovedWorkout(workout: workout, totals: totals);
    final all = await _workoutArchive.remove(removed);
    if (_disposed) return removed;
    _workouts = List.unmodifiable(all);
    _removedWorkouts = List.unmodifiable([
      for (final other in _removedWorkouts)
        if (other.workout.key != workout.key) other,
      removed,
    ]);
    final snapshot = _snapshot;
    if (snapshot != null) {
      // The snapshot on screen is already without the earlier ones.
      final next = withoutWorkouts(snapshot, [removed]);
      _snapshot = next;
      await _store.write(StoreKeys.snapshot, next.toJson());
      await _archiveDays(dailyValuesOf(next));
    }
    await _changeOlderDays(removed, restore: false);
    if (!_disposed) notifyListeners();
    return removed;
  }

  /// Undoes [removeWorkout].
  Future<void> restoreWorkout(RemovedWorkout removed) async {
    final all = await _workoutArchive.restore(removed);
    if (_disposed) return;
    _workouts = List.unmodifiable(all);
    _removedWorkouts = List.unmodifiable([
      for (final other in _removedWorkouts)
        if (other.workout.key != removed.workout.key) other,
    ]);
    await _changeOlderDays(removed, restore: true);
    if (_disposed) return;
    notifyListeners();
    // The days of the window are read again, with the workout in them.
    await refresh(full: true);
  }

  /// Takes what [removed] added out of the days before the snapshot's
  /// window, or puts it back. Those days are not read again, so the history
  /// is changed directly.
  Future<void> _changeOlderDays(
    RemovedWorkout removed, {
    required bool restore,
  }) async {
    final history = _history;
    if (history == null) return;
    final changed = <Metric, Map<DateTime, double>>{};
    for (final MapEntry(key: metric, value: days) in removed.totals.entries) {
      for (final MapEntry(key: day, value: amount) in days.entries) {
        final value = history.value(metric, day);
        if (value == null || _snapshot?.indexOf(day) != null) continue;
        changed.putIfAbsent(metric, () => {})[day] = restore
            ? value + amount
            : (value > amount ? value - amount : 0);
      }
    }
    if (changed.isEmpty) return;
    if (history.merge(changed).isNotEmpty) {
      await _archive.mergeIntoStore(changed);
    }
  }

  Future<void> _archiveDays(DailyValues values) async {
    final history = _history;
    if (history == null) return;
    // Merged into the stored years rather than written over them: the
    // background task may have added to them since they were loaded.
    if (history.merge(values).isNotEmpty) await _archive.mergeIntoStore(values);
  }

  /// Fills the history once with what the store already holds, going back in
  /// stretches until two in a row are empty or the retention limit is
  /// reached. Progress is saved, so an interrupted run continues next time.
  Future<void> _backfill() async {
    if (_backfilling || _history == null) return;
    final state = await _store.read(StoreKeys.backfill);
    if (_disposed) return;
    var asked = false;
    DateTime? reached;
    if (state case {'done': true}) return;
    if (state case {'asked': final bool value}) asked = value;
    if (state case {'reached': final String value}) {
      reached = DateTime.tryParse(value);
    }

    Future<void> save({bool done = false}) => _store.write(StoreKeys.backfill, {
      'done': done,
      'asked': asked,
      'reached': reached?.toIso8601String(),
    });

    try {
      var granted = await _repository.historyAccessGranted();
      if (!granted && !asked) {
        // Asked once. If it is refused the app simply collects from now on.
        asked = true;
        granted = await _repository.requestHistoryAccess();
        await save();
      }
      if (!granted || _disposed) return;

      final limit = DateTime(today.year - HistoryArchive.retentionYears + 1);
      // The live window already covers the most recent days.
      var to = reached ?? snapshot.dateAt(0).subtract(const Duration(days: 1));
      to = DateTime(to.year, to.month, to.day);
      var empty = 0;
      _backfilling = true;
      while (empty < _emptyChunksToStop && !to.isBefore(limit)) {
        var from = DateTime(to.year, to.month, to.day - backfillChunkDays + 1);
        if (from.isBefore(limit)) from = limit;
        _backfillReached = from;
        if (!_disposed) notifyListeners();
        final values = withoutRemovedTotals(
          await _repository.loadHistory(from, to),
          _removedWorkouts,
        );
        if (_disposed) return;
        empty = values.values.every((days) => days.isEmpty) ? empty + 1 : 0;
        await _archiveDays(values);
        to = DateTime(from.year, from.month, from.day - 1);
        reached = to;
        await save();
      }
      await save(done: true);
    } on Exception catch (error) {
      // Not marked as done, so the next start continues where this stopped.
      debugPrint('Loading older data failed: $error');
    } finally {
      _backfilling = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Fills the workout archive once with the workouts the store already
  /// holds, back to the oldest day of the history. It has its own progress,
  /// apart from [_backfill], and does not stop at an empty stretch: months
  /// without a workout are normal. It never asks for the permission; that is
  /// [_backfill]'s to ask, once.
  Future<void> _backfillWorkouts() async {
    final history = _history;
    if (_backfillingWorkouts || _disposed || history == null) return;
    final state = await _store.read(StoreKeys.workoutBackfill);
    if (_disposed) return;
    DateTime? reached;
    if (state case {'version': _workoutBackfillVersion}) {
      if (state case {'done': true}) return;
      if (state case {'reached': final String value}) {
        reached = DateTime.tryParse(value);
      }
    }

    Future<void> save({bool done = false}) =>
        _store.write(StoreKeys.workoutBackfill, {
          'version': _workoutBackfillVersion,
          'done': done,
          'reached': reached?.toIso8601String(),
        });

    _backfillingWorkouts = true;
    try {
      if (!await _repository.historyAccessGranted() || _disposed) return;
      var limit = DateTime(today.year - HistoryArchive.retentionYears + 1);
      final oldest = history.firstDayOfAll;
      // Without any older day there is nothing to go back to yet.
      if (oldest == null) return;
      if (oldest.isAfter(limit)) limit = oldest;
      // The live window already covers the most recent days.
      var to = reached ?? snapshot.dateAt(0).subtract(const Duration(days: 1));
      to = DateTime(to.year, to.month, to.day);
      while (!to.isBefore(limit)) {
        var from = DateTime(to.year, to.month, to.day - backfillChunkDays + 1);
        if (from.isBefore(limit)) from = limit;
        final workouts = await _repository.loadWorkouts(from, to);
        if (_disposed) return;
        if (workouts.isNotEmpty) {
          await _archiveWorkouts(workouts);
          if (_disposed) return;
          notifyListeners();
        }
        to = DateTime(from.year, from.month, from.day - 1);
        reached = to;
        await save();
      }
      await save(done: true);
    } on Exception catch (error) {
      // Not marked as done, so the next start continues where this stopped.
      debugPrint('Loading older workouts failed: $error');
    } finally {
      _backfillingWorkouts = false;
    }
  }

  /// Fills the night archive once with the nights the store already holds,
  /// in the way [_backfillNights] does for workouts.
  Future<void> _backfillNights() async {
    final history = _history;
    if (_backfillingNights || _disposed || history == null) return;
    final state = await _store.read(StoreKeys.nightBackfill);
    if (_disposed) return;
    if (state case {'done': true}) return;
    DateTime? reached;
    if (state case {'reached': final String value}) {
      reached = DateTime.tryParse(value);
    }

    Future<void> save({bool done = false}) => _store.write(
      StoreKeys.nightBackfill,
      {'done': done, 'reached': reached?.toIso8601String()},
    );

    _backfillingNights = true;
    try {
      if (!await _repository.historyAccessGranted() || _disposed) return;
      var limit = DateTime(today.year - HistoryArchive.retentionYears + 1);
      final oldest = history.firstDayOfAll;
      // Without any older day there is nothing to go back to yet.
      if (oldest == null) return;
      if (oldest.isAfter(limit)) limit = oldest;
      // The live window already covers the most recent days.
      var to = reached ?? snapshot.dateAt(0).subtract(const Duration(days: 1));
      to = DateTime(to.year, to.month, to.day);
      while (!to.isBefore(limit)) {
        var from = DateTime(to.year, to.month, to.day - backfillChunkDays + 1);
        if (from.isBefore(limit)) from = limit;
        final nights = await _repository.loadNights(from, to);
        if (_disposed) return;
        if (nights.isNotEmpty) {
          await _archiveNights(nights);
          if (_disposed) return;
          notifyListeners();
        }
        to = DateTime(from.year, from.month, from.day - 1);
        reached = to;
        await save();
      }
      await save(done: true);
    } on Exception catch (error) {
      // Not marked as done, so the next start continues where this stopped.
      debugPrint('Loading older nights failed: $error');
    } finally {
      _backfillingNights = false;
    }
  }

  Future<void> installStore() async {
    try {
      await _repository.installStore();
    } on Exception catch (error) {
      debugPrint('Opening the store page failed: $error');
    }
  }

  Future<void> requestBackgroundAccess() async {
    var granted = false;
    try {
      granted = await _repository.requestBackgroundAccess();
    } on Exception catch (error) {
      debugPrint('Requesting background access failed: $error');
    }
    if (_disposed) return;
    _backgroundAccess = granted;
    notifyListeners();
  }

  void selectDay(int index) {
    if (_snapshot == null) return;
    if (index == _selectedIndex || index < 0 || index >= snapshot.dayCount) {
      return;
    }
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> addEntry(EntryDraft draft) async {
    await _repository.add(draft);
    if (_disposed) return;
    await refresh();
  }

  Future<void> deleteEntry(HealthEntry entry) async {
    if (!entry.isOwn) {
      throw ArgumentError('Only entries written by this app can be deleted.');
    }
    await _repository.delete(entry);
    if (_disposed) return;
    await refresh();
    await _forgetDeleted(entry);
  }

  /// A day's value that is gone with [entry] also leaves the history, which
  /// otherwise keeps what a later reading no longer has.
  Future<void> _forgetDeleted(HealthEntry entry) async {
    final snapshot = _snapshot;
    final history = _history;
    final day = entry.draft.time;
    final index = snapshot?.indexOf(day);
    if (_disposed || snapshot == null || history == null || index == null) {
      return;
    }
    final gone = [
      for (final metric in switch (entry.draft.kind) {
        EntryKind.water => const [Metric.water],
        EntryKind.weight => const [Metric.weight],
        EntryKind.meal => const [
          Metric.energyIntake,
          Metric.carbs,
          Metric.protein,
          Metric.fat,
          Metric.fiber,
          Metric.sugar,
        ],
      })
        if (snapshot.value(metric, index) == null &&
            history.remove(metric, day))
          metric,
    ];
    if (gone.isEmpty) return;
    await _archive.forget(gone, day);
    if (!_disposed) notifyListeners();
  }

  /// Health Connect cannot change a record, so an edit is a delete followed
  /// by a new entry.
  Future<void> replaceEntry(HealthEntry entry, EntryDraft draft) async {
    if (!entry.isOwn) {
      throw ArgumentError('Only entries written by this app can be edited.');
    }
    // Written first: if that fails, the old entry is still there.
    await _repository.add(draft);
    await _repository.delete(entry);
    if (_disposed) return;
    await refresh();
    await _forgetDeleted(entry);
  }

  void _show(HealthSnapshot next) {
    final previous = _snapshot;
    // Keep the selected calendar day across a refresh; start on today.
    final keep = previous == null
        ? null
        : next.indexOf(previous.dateAt(_selectedIndex));
    _snapshot = next;
    _selectedIndex = keep ?? next.dayCount - 1;
    _status = HealthStatus.ready;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
