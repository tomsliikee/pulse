import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../app/app_info.dart';
import 'health_history.dart';
import 'health_repository.dart';
import 'health_snapshot.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'snapshot_builder.dart';

/// Reads from and writes to Android's Health Connect. The only file that
/// knows the `health` plugin.
class HealthConnectRepository implements HealthRepository {
  HealthConnectRepository({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  /// Raw heart-rate samples are only read for the days whose curve the app
  /// can show; a wearable writes thousands per day.
  static const int _heartRateDays = 8;

  /// Metrics whose day value is a total. Health Connect aggregates these
  /// itself and removes the overlap between sources.
  static const Map<Metric, HealthDataType> _totals = {
    Metric.steps: HealthDataType.STEPS,
    Metric.distance: HealthDataType.DISTANCE_DELTA,
    Metric.activeEnergy: HealthDataType.ACTIVE_ENERGY_BURNED,
    Metric.totalEnergy: HealthDataType.TOTAL_CALORIES_BURNED,
    Metric.water: HealthDataType.WATER,
  };

  /// Minutes of activity are added up here from their records: the store
  /// refuses to aggregate them on some phones, and the plugin hides that.
  static const HealthDataType _intensity = HealthDataType.ACTIVITY_INTENSITY;

  /// Metrics read as individual records and combined by their [DayRule].
  static const Map<Metric, HealthDataType> _samples = {
    Metric.floors: HealthDataType.FLIGHTS_CLIMBED,
    Metric.speed: HealthDataType.SPEED,
    Metric.restingHeartRate: HealthDataType.RESTING_HEART_RATE,
    Metric.heartRateVariability: HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    Metric.oxygenSaturation: HealthDataType.BLOOD_OXYGEN,
    Metric.respiratoryRate: HealthDataType.RESPIRATORY_RATE,
    Metric.systolic: HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    Metric.diastolic: HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    Metric.bloodGlucose: HealthDataType.BLOOD_GLUCOSE,
    Metric.bodyTemperature: HealthDataType.BODY_TEMPERATURE,
    Metric.skinTemperature: HealthDataType.SKIN_TEMPERATURE,
    Metric.weight: HealthDataType.WEIGHT,
    Metric.height: HealthDataType.HEIGHT,
    Metric.bodyFat: HealthDataType.BODY_FAT_PERCENTAGE,
    Metric.leanMass: HealthDataType.LEAN_BODY_MASS,
    Metric.bodyWater: HealthDataType.BODY_WATER_MASS,
    Metric.basalEnergy: HealthDataType.BASAL_ENERGY_BURNED,
  };

  static const Map<HealthDataType, SleepStage> _sleepStages = {
    HealthDataType.SLEEP_AWAKE: SleepStage.awake,
    HealthDataType.SLEEP_AWAKE_IN_BED: SleepStage.awake,
    HealthDataType.SLEEP_OUT_OF_BED: SleepStage.awake,
    HealthDataType.SLEEP_REM: SleepStage.rem,
    HealthDataType.SLEEP_LIGHT: SleepStage.light,
    // A source that only says "asleep" is drawn on the light lane.
    HealthDataType.SLEEP_ASLEEP: SleepStage.light,
    HealthDataType.SLEEP_DEEP: SleepStage.deep,
  };

  static const List<HealthDataType> _written = [
    HealthDataType.WATER,
    HealthDataType.WEIGHT,
    HealthDataType.NUTRITION,
  ];

  /// Granting any of these counts as access; the user may refuse the rest.
  static const List<HealthDataType> _core = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
  ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<List<HealthDataType>> _readTypes() async {
    final skin = await _health.isSkinTemperatureAvailable();
    return [
      ..._totals.values,
      _intensity,
      for (final type in _samples.values)
        if (type != HealthDataType.SKIN_TEMPERATURE || skin) type,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.WORKOUT,
      HealthDataType.NUTRITION,
    ];
  }

  @override
  Future<HealthAccess> access() async {
    await _configure();
    final status = await _health.getHealthConnectSdkStatus();
    if (status != HealthConnectSdkStatus.sdkAvailable) {
      return HealthAccess.unavailable;
    }
    for (final type in _core) {
      final granted = await _health.hasPermissions(
        [type],
        permissions: [HealthDataAccess.READ],
      );
      if (granted ?? false) return HealthAccess.granted;
    }
    return HealthAccess.denied;
  }

  @override
  Future<HealthAccess> requestAccess() async {
    await _configure();
    final types = await _readTypes();
    await _health.requestAuthorization(
      types,
      permissions: [
        for (final type in types)
          _written.contains(type)
              ? HealthDataAccess.READ_WRITE
              : HealthDataAccess.READ,
      ],
    );
    return access();
  }

  @override
  Future<void> installStore() async {
    await _configure();
    await _health.installHealthConnect();
  }

  @override
  Future<bool> backgroundAccessGranted() async {
    await _configure();
    if (!await _health.isHealthDataInBackgroundAvailable()) return false;
    return _health.isHealthDataInBackgroundAuthorized();
  }

  @override
  Future<bool> requestBackgroundAccess() async {
    await _configure();
    if (!await _health.isHealthDataInBackgroundAvailable()) return false;
    return _health.requestHealthDataInBackgroundAuthorization();
  }

  @override
  Future<bool> historyAccessGranted() async {
    await _configure();
    if (!await _health.isHealthDataHistoryAvailable()) return false;
    return _health.isHealthDataHistoryAuthorized();
  }

  @override
  Future<bool> requestHistoryAccess() async {
    await _configure();
    if (!await _health.isHealthDataHistoryAvailable()) return false;
    return _health.requestHealthDataHistoryAuthorization();
  }

  /// Reading means decoding and sorting thousands of records. That is done
  /// in a worker isolate, so the interface keeps drawing meanwhile. Static,
  /// so that nothing but its arguments travels to the worker.
  static Future<T> _inWorker<T>(
    RootIsolateToken token,
    Future<T> Function(HealthConnectRepository repository) read,
  ) => Isolate.run(() {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    return read(HealthConnectRepository());
  });

  static Future<HealthSnapshot> _loadInWorker(
    RootIsolateToken token,
    DateTime now,
    HealthSnapshot? previous,
  ) => _inWorker(token, (repository) => repository._load(now, previous));

  static Future<DailyValues> _loadHistoryInWorker(
    RootIsolateToken token,
    DateTime from,
    DateTime to,
  ) => _inWorker(token, (repository) => repository._loadHistory(from, to));

  static Future<List<Workout>> _loadWorkoutsInWorker(
    RootIsolateToken token,
    DateTime from,
    DateTime to,
  ) => _inWorker(token, (repository) => repository._loadWorkouts(from, to));

  @override
  Future<List<Workout>> loadWorkouts(DateTime from, DateTime to) {
    final token = RootIsolateToken.instance;
    return token == null
        ? _loadWorkouts(from, to)
        : _loadWorkoutsInWorker(token, from, to);
  }

  Future<List<Workout>> _loadWorkouts(DateTime from, DateTime to) async {
    await _configure();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return [
      for (final point in await _read(HealthDataType.WORKOUT, start, end))
        ?_workout(point),
    ];
  }

  static Future<List<SleepNight>> _loadNightsInWorker(
    RootIsolateToken token,
    DateTime from,
    DateTime to,
  ) => _inWorker(token, (repository) => repository._loadNights(from, to));

  @override
  Future<List<SleepNight>> loadNights(DateTime from, DateTime to) {
    final token = RootIsolateToken.instance;
    return token == null
        ? _loadNights(from, to)
        : _loadNightsInWorker(token, from, to);
  }

  Future<List<SleepNight>> _loadNights(DateTime from, DateTime to) async {
    await _configure();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    final (sessions, stages) = await _readSleep(start, end);
    // The same builder as for the live window, so a night means the same in
    // both.
    final snapshot = buildSnapshot(
      now: end,
      dayCount: dayKey(end) - dayKey(start) + 1,
      raw: RawReadings(sleepSessions: sessions, sleepStages: stages),
    );
    return [for (final night in snapshot.nights) ?night?.summary];
  }

  @override
  Future<HealthSnapshot> load(DateTime now, {HealthSnapshot? previous}) {
    final token = RootIsolateToken.instance;
    return token == null
        ? _load(now, previous)
        : _loadInWorker(token, now, previous);
  }

  @override
  Future<DailyValues> loadHistory(DateTime from, DateTime to) {
    final token = RootIsolateToken.instance;
    return token == null
        ? _loadHistory(from, to)
        : _loadHistoryInWorker(token, from, to);
  }

  Future<HealthSnapshot> _load(DateTime now, HealthSnapshot? previous) async {
    await _configure();
    const dayCount = HealthSnapshot.defaultDayCount;
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(today.year, today.month, today.day - dayCount + 1);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    // Heart rate is by far the largest read. Days that were complete when
    // [previous] was loaded keep their curve; only the days since are read.
    var heartFrom = DateTime(
      today.year,
      today.month,
      today.day - _heartRateDays + 1,
    );
    if (previous != null) {
      final loaded = previous.loadedAt;
      final since = DateTime(loaded.year, loaded.month, loaded.day);
      final from = since.isBefore(yesterday) ? since : yesterday;
      if (from.isAfter(heartFrom)) heartFrom = from;
    }

    final hourly = <Metric, Map<DateTime, double>>{};
    for (final MapEntry(key: metric, value: type) in _totals.entries) {
      final hours = await _totalsBy(
        type,
        metric,
        yesterday,
        now,
        Duration.secondsPerHour,
      );
      if (hours.isNotEmpty) hourly[metric] = hours;
    }

    final fresh = buildSnapshot(
      now: now,
      dayCount: dayCount,
      raw: await _readRaw(
        start,
        now,
        heartFrom: heartFrom,
        withEntries: true,
        hourly: hourly,
      ),
    );
    return previous == null
        ? fresh
        : keepHeartBefore(heartFrom, fresh: fresh, previous: previous);
  }

  Future<DailyValues> _loadHistory(DateTime from, DateTime to) async {
    await _configure();
    final start = DateTime(from.year, from.month, from.day);
    // The end of the last day, so that day is read in full.
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    final dayCount = dayKey(end) - dayKey(start) + 1;
    // The same builder as for the live window, so a day means the same in
    // both. Raw heart rate is left out: years of single beats are too many.
    final snapshot = buildSnapshot(
      now: end,
      dayCount: dayCount,
      raw: await _readRaw(start, end),
    );
    return dailyValuesOf(snapshot);
  }

  Future<(List<RawSleepSession>, List<RawSleepStage>)> _readSleep(
    DateTime start,
    DateTime end,
  ) async {
    // A night can start before the first day of the window.
    final sleepStart = start.subtract(const Duration(hours: 12));
    final sessions = [
      for (final point in await _read(
        HealthDataType.SLEEP_SESSION,
        sleepStart,
        end,
      ))
        RawSleepSession(point.dateFrom, point.dateTo),
    ];
    final stages = <RawSleepStage>[];
    for (final MapEntry(key: type, value: stage) in _sleepStages.entries) {
      for (final point in await _read(type, sleepStart, end)) {
        stages.add(RawSleepStage(stage, point.dateFrom, point.dateTo));
      }
    }
    return (sessions, stages);
  }

  Future<RawReadings> _readRaw(
    DateTime start,
    DateTime end, {
    DateTime? heartFrom,
    bool withEntries = false,
    Map<Metric, Map<DateTime, double>> hourly = const {},
  }) async {
    final skin = await _health.isSkinTemperatureAvailable();

    final totals = <Metric, Map<DateTime, double>>{};
    for (final MapEntry(key: metric, value: type) in _totals.entries) {
      final days = await _totalsBy(
        type,
        metric,
        start,
        end,
        Duration.secondsPerDay,
      );
      if (days.isNotEmpty) totals[metric] = days;
    }

    final active = minutesByHour([
      for (final point in await _read(_intensity, start, end))
        (point.dateFrom, point.dateTo),
    ]);
    if (active.isNotEmpty) {
      final days = totals[Metric.intensityMinutes] = <DateTime, double>{};
      for (final MapEntry(key: hour, value: minutes) in active.entries) {
        final day = DateTime(hour.year, hour.month, hour.day);
        days[day] = (days[day] ?? 0) + minutes;
      }
    }

    final samples = <RawSample>[];
    for (final MapEntry(key: metric, value: type) in _samples.entries) {
      if (type == HealthDataType.SKIN_TEMPERATURE && !skin) continue;
      for (final point in await _read(type, start, end)) {
        final value = _numeric(point);
        if (value == null) continue;
        samples.add(RawSample(metric, point.dateFrom, _convert(metric, value)));
      }
    }
    if (heartFrom != null) {
      for (final point in await _read(
        HealthDataType.HEART_RATE,
        heartFrom,
        end,
      )) {
        final value = _numeric(point);
        if (value != null) {
          samples.add(RawSample(Metric.heartRate, point.dateFrom, value));
        }
      }
    }

    final (sessions, stages) = await _readSleep(start, end);

    final nutrition = await _read(HealthDataType.NUTRITION, start, end);
    final entries = <HealthEntry>[
      if (withEntries) ...[
        for (final point in await _read(HealthDataType.WATER, start, end))
          ?_entry(point, EntryKind.water, scale: 1000),
        for (final point in await _read(HealthDataType.WEIGHT, start, end))
          ?_entry(point, EntryKind.weight),
      ],
      // Meals are always needed: the nutrition values are their sums.
      for (final point in nutrition) ?_meal(point),
    ];

    return RawReadings(
      samples: samples,
      dailyTotals: totals,
      sleepSessions: sessions,
      sleepStages: stages,
      workouts: withEntries
          ? [
              for (final point in await _read(
                HealthDataType.WORKOUT,
                start,
                end,
              ))
                ?_workout(point),
            ]
          : const [],
      entries: entries,
      hourlyTotals: {
        ...hourly,
        if (active.isNotEmpty) Metric.intensityMinutes: active,
      },
    );
  }

  @override
  Future<void> add(EntryDraft draft) async {
    await _configure();
    final ok = switch (draft.kind) {
      EntryKind.water => await _health.writeHealthData(
        value: draft.amount / 1000,
        unit: HealthDataUnit.LITER,
        type: HealthDataType.WATER,
        startTime: draft.time,
        // Health Connect requires an interval for hydration.
        endTime: draft.time.add(const Duration(minutes: 1)),
        recordingMethod: RecordingMethod.manual,
      ),
      EntryKind.weight => await _health.writeHealthData(
        value: draft.amount,
        unit: HealthDataUnit.KILOGRAM,
        type: HealthDataType.WEIGHT,
        startTime: draft.time,
        recordingMethod: RecordingMethod.manual,
      ),
      EntryKind.meal => await _health.writeMeal(
        mealType: MealType.UNKNOWN,
        startTime: draft.time,
        endTime: draft.time.add(const Duration(minutes: 1)),
        name: draft.name,
        caloriesConsumed: draft.amount,
        carbohydrates: draft.carbs,
        protein: draft.protein,
        fatTotal: draft.fat,
        fiber: draft.fiber,
        sugar: draft.sugar,
        recordingMethod: RecordingMethod.manual,
      ),
    };
    if (!ok) {
      throw const HealthStoreException('Health Connect rejected the entry.');
    }
  }

  @override
  Future<void> delete(HealthEntry entry) async {
    await _configure();
    final ok = await _health.deleteByUUID(
      uuid: entry.id,
      type: switch (entry.draft.kind) {
        EntryKind.water => HealthDataType.WATER,
        EntryKind.weight => HealthDataType.WEIGHT,
        EntryKind.meal => HealthDataType.NUTRITION,
      },
    );
    if (!ok) {
      throw const HealthStoreException(
        'Health Connect did not delete the entry.',
      );
    }
  }

  /// Reads one type. A type the user did not allow, or one this device does
  /// not have, yields nothing instead of failing the whole load.
  Future<List<HealthDataPoint>> _read(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
    } on Exception catch (error) {
      debugPrint('Health Connect: no $type ($error)');
      return const [];
    }
  }

  /// Totals per slice of [seconds], keyed by the start of the slice (a day
  /// or an hour), aggregated by the store.
  Future<Map<DateTime, double>> _totalsBy(
    HealthDataType type,
    Metric metric,
    DateTime start,
    DateTime end,
    int seconds,
  ) async {
    final totals = <DateTime, double>{};
    final daily = seconds == Duration.secondsPerDay;
    // The store slices by a fixed duration, not by calendar day. Asking for
    // one stretch per UTC offset keeps the slices on local midnights across
    // a daylight-saving change.
    for (final (from, to) in _constantOffsetRanges(start, end)) {
      final List<HealthDataPoint> buckets;
      try {
        buckets = await _health.getHealthIntervalDataFromTypes(
          startDate: from,
          endDate: to,
          types: [type],
          interval: seconds,
        );
      } on Exception catch (error) {
        debugPrint('Health Connect: no totals for $type ($error)');
        continue;
      }
      for (final bucket in buckets) {
        final value = _numeric(bucket);
        if (value == null || value == 0) continue;
        final at = bucket.dateFrom;
        final key = DateTime(at.year, at.month, at.day, daily ? 0 : at.hour);
        totals[key] = (totals[key] ?? 0) + _convert(metric, value);
      }
    }
    return totals;
  }

  static List<(DateTime, DateTime)> _constantOffsetRanges(
    DateTime start,
    DateTime end,
  ) {
    final ranges = <(DateTime, DateTime)>[];
    var from = start;
    var day = start;
    while (day.isBefore(end)) {
      final next = DateTime(day.year, day.month, day.day + 1);
      if (next.timeZoneOffset != from.timeZoneOffset && next.isBefore(end)) {
        ranges.add((from, next));
        from = next;
      }
      day = next;
    }
    ranges.add((from, end));
    return ranges;
  }

  static double? _numeric(HealthDataPoint point) => switch (point.value) {
    NumericHealthValue(:final numericValue) => numericValue.toDouble(),
    ActivityIntensityHealthValue(:final minutes) => minutes,
    SkinTemperatureHealthValue(:final temperatureDelta) => temperatureDelta,
    _ => null,
  };

  /// Brings a value into the unit the catalog uses for [metric].
  static double _convert(Metric metric, double value) => switch (metric) {
    Metric.distance => value / 1000,
    Metric.height => value * 100,
    Metric.speed => value * 3.6,
    _ => value,
  };

  static HealthEntry? _entry(
    HealthDataPoint point,
    EntryKind kind, {
    double scale = 1,
  }) {
    final value = _numeric(point);
    if (value == null || point.uuid.isEmpty) return null;
    return HealthEntry(
      id: point.uuid,
      source: point.sourceName,
      isOwn: point.sourceName == kAppId,
      draft: EntryDraft(
        kind: kind,
        time: point.dateFrom,
        amount: value * scale,
      ),
    );
  }

  static HealthEntry? _meal(HealthDataPoint point) {
    final value = point.value;
    if (value is! NutritionHealthValue || point.uuid.isEmpty) return null;
    return HealthEntry(
      id: point.uuid,
      source: point.sourceName,
      isOwn: point.sourceName == kAppId,
      draft: EntryDraft(
        kind: EntryKind.meal,
        time: point.dateFrom,
        amount: value.calories ?? 0,
        name: value.name,
        carbs: value.carbs,
        protein: value.protein,
        fat: value.fat,
        fiber: value.fiber,
        sugar: value.sugar,
      ),
    );
  }

  static Workout? _workout(HealthDataPoint point) {
    final value = point.value;
    if (value is! WorkoutHealthValue) return null;
    final distance = value.totalDistance;
    return Workout(
      type: switch (value.workoutActivityType) {
        HealthWorkoutActivityType.RUNNING ||
        HealthWorkoutActivityType.RUNNING_TREADMILL => WorkoutType.run,
        HealthWorkoutActivityType.BIKING ||
        HealthWorkoutActivityType.BIKING_STATIONARY => WorkoutType.ride,
        HealthWorkoutActivityType.WALKING => WorkoutType.walk,
        HealthWorkoutActivityType.HIKING => WorkoutType.hike,
        HealthWorkoutActivityType.STRENGTH_TRAINING ||
        HealthWorkoutActivityType.WEIGHTLIFTING => WorkoutType.strength,
        HealthWorkoutActivityType.YOGA ||
        HealthWorkoutActivityType.PILATES => WorkoutType.yoga,
        HealthWorkoutActivityType.SWIMMING ||
        HealthWorkoutActivityType.SWIMMING_POOL ||
        HealthWorkoutActivityType.SWIMMING_OPEN_WATER => WorkoutType.swim,
        _ => WorkoutType.other,
      },
      start: point.dateFrom,
      minutes: point.dateTo.difference(point.dateFrom).inMinutes,
      kcal: value.totalEnergyBurned,
      distanceKm: distance == null ? null : distance / 1000,
      steps: switch (value.totalSteps) {
        final int steps when steps > 0 => steps,
        _ => null,
      },
    );
  }
}
