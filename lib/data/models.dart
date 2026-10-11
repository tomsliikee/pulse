import 'package:flutter/foundation.dart';

enum SleepStage { awake, rem, light, deep }

/// What kinds of workout share: their shape and the figure of their scene.
enum WorkoutFamily {
  run,
  ride,
  walk,
  water,
  ball,
  winter,
  strength,
  studio,
  calm,
  other,
}

/// How the fine values work out the energy of a workout.
enum FineEnergy {
  /// From the heart rate, minute by minute.
  pulse,

  /// A fixed rate for each of its minutes.
  fixed,

  /// From its steps, like the rest of the day.
  steps,
}

/// The figure a workout's scene shows.
enum WorkoutFigure { walk, run, hike, ride, swim, lift, breathe }

/// Every kind of workout Health Connect tells apart. The first eight are
/// the ones the app began with; their names are in stored workouts.
enum WorkoutType {
  run(WorkoutFamily.run, FineEnergy.pulse, 9.8),
  ride(WorkoutFamily.ride, FineEnergy.pulse, 7.5),
  walk(WorkoutFamily.walk, FineEnergy.steps, 3.5),
  hike(
    WorkoutFamily.walk,
    FineEnergy.steps,
    6.0,
    ownFigure: WorkoutFigure.hike,
  ),
  strength(WorkoutFamily.strength, FineEnergy.fixed, 3.5),
  yoga(WorkoutFamily.calm, FineEnergy.fixed, 2.5),
  swim(WorkoutFamily.water, FineEnergy.pulse, 6.0),
  other(WorkoutFamily.other, FineEnergy.fixed, 3.5),
  treadmill(WorkoutFamily.run, FineEnergy.pulse, 9.0, oldName: 'run'),
  stationaryBike(WorkoutFamily.ride, FineEnergy.pulse, 7.0, oldName: 'ride'),
  wheelchair(WorkoutFamily.walk, FineEnergy.pulse, 3.5),
  stairs(
    WorkoutFamily.walk,
    FineEnergy.pulse,
    8.0,
    ownFigure: WorkoutFigure.hike,
  ),
  openWater(WorkoutFamily.water, FineEnergy.pulse, 6.0, oldName: 'swim'),
  waterPolo(WorkoutFamily.water, FineEnergy.pulse, 10.0),
  surfing(WorkoutFamily.water, FineEnergy.pulse, 3.0),
  sailing(WorkoutFamily.water, FineEnergy.fixed, 3.0),
  scuba(WorkoutFamily.water, FineEnergy.fixed, 7.0),
  rowing(WorkoutFamily.water, FineEnergy.pulse, 7.0),
  americanFootball(WorkoutFamily.ball, FineEnergy.pulse, 8.0),
  australianFootball(WorkoutFamily.ball, FineEnergy.pulse, 8.0),
  badminton(WorkoutFamily.ball, FineEnergy.pulse, 5.5),
  baseball(WorkoutFamily.ball, FineEnergy.pulse, 5.0),
  basketball(WorkoutFamily.ball, FineEnergy.pulse, 6.5),
  cricket(WorkoutFamily.ball, FineEnergy.pulse, 4.8),
  frisbee(WorkoutFamily.ball, FineEnergy.pulse, 5.0),
  golf(WorkoutFamily.ball, FineEnergy.fixed, 4.8),
  handball(WorkoutFamily.ball, FineEnergy.pulse, 8.0),
  racquetball(WorkoutFamily.ball, FineEnergy.pulse, 7.0),
  rugby(WorkoutFamily.ball, FineEnergy.pulse, 8.3),
  soccer(WorkoutFamily.ball, FineEnergy.pulse, 7.0),
  softball(WorkoutFamily.ball, FineEnergy.pulse, 5.0),
  squash(WorkoutFamily.ball, FineEnergy.pulse, 7.3),
  tableTennis(WorkoutFamily.ball, FineEnergy.pulse, 4.0),
  tennis(WorkoutFamily.ball, FineEnergy.pulse, 7.3),
  volleyball(WorkoutFamily.ball, FineEnergy.pulse, 4.0),
  ski(WorkoutFamily.winter, FineEnergy.pulse, 7.0),
  snowboard(WorkoutFamily.winter, FineEnergy.pulse, 5.3),
  snowshoe(WorkoutFamily.winter, FineEnergy.steps, 5.3),
  iceSkating(WorkoutFamily.winter, FineEnergy.pulse, 7.0),
  iceHockey(WorkoutFamily.winter, FineEnergy.pulse, 8.0),
  weights(WorkoutFamily.strength, FineEnergy.fixed, 3.5, oldName: 'strength'),
  calisthenics(WorkoutFamily.strength, FineEnergy.fixed, 3.8),
  gymnastics(WorkoutFamily.strength, FineEnergy.fixed, 3.8),
  climbing(WorkoutFamily.strength, FineEnergy.pulse, 5.8),
  hiit(WorkoutFamily.studio, FineEnergy.pulse, 8.0),
  elliptical(WorkoutFamily.studio, FineEnergy.pulse, 5.0),
  rowingMachine(WorkoutFamily.studio, FineEnergy.pulse, 7.0),
  stairMachine(WorkoutFamily.studio, FineEnergy.pulse, 9.0),
  dance(WorkoutFamily.studio, FineEnergy.pulse, 6.0),
  boxing(WorkoutFamily.studio, FineEnergy.pulse, 7.8),
  martialArts(WorkoutFamily.studio, FineEnergy.pulse, 7.5),
  fencing(WorkoutFamily.studio, FineEnergy.pulse, 6.0),
  pilates(WorkoutFamily.calm, FineEnergy.fixed, 3.0, oldName: 'yoga'),
  breathing(WorkoutFamily.calm, FineEnergy.fixed, 1.3),
  skating(WorkoutFamily.other, FineEnergy.pulse, 7.0),
  paragliding(WorkoutFamily.other, FineEnergy.fixed, 3.5);

  const WorkoutType(
    this.family,
    this.energy,
    this.met, {
    this.oldName,
    this.ownFigure,
  });

  final WorkoutFamily family;

  /// How the fine values count it. In strength training and the like the
  /// pulse rises further than the energy spent does, and walking at a
  /// moderate pulse costs far less than the pulse suggests.
  final FineEnergy energy;

  /// Its effort as a multiple of rest (Compendium of Physical Activities):
  /// the rate of a [FineEnergy.fixed] kind, and of the minutes of a
  /// [FineEnergy.pulse] kind that have no pulse.
  final double met;

  /// The coarser kind the app once read it as.
  final String? oldName;
  final WorkoutFigure? ownFigure;

  /// The name a workout's [Workout.key] is built from. A kind the app once
  /// read as a coarser one keeps that one's, so the key of a stored workout
  /// does not change when it is read again.
  String get stem => oldName ?? (index < 8 ? name : 'other');

  WorkoutFigure get figure =>
      ownFigure ??
      switch (family) {
        WorkoutFamily.run => WorkoutFigure.run,
        WorkoutFamily.ride => WorkoutFigure.ride,
        WorkoutFamily.walk => WorkoutFigure.walk,
        WorkoutFamily.water => WorkoutFigure.swim,
        WorkoutFamily.ball => WorkoutFigure.run,
        WorkoutFamily.winter => WorkoutFigure.hike,
        WorkoutFamily.strength => WorkoutFigure.lift,
        WorkoutFamily.studio => WorkoutFigure.run,
        WorkoutFamily.calm => WorkoutFigure.breathe,
        WorkoutFamily.other => WorkoutFigure.walk,
      };

  /// Whether its distance is swum: a pace is then per 100 metres.
  bool get swims => this == swim || this == openWater;

  /// Whether it covers ground fast enough for a speed instead of a pace.
  bool get rolls =>
      family == WorkoutFamily.ride ||
      const {
        skating,
        ski,
        snowboard,
        iceSkating,
        rowing,
        sailing,
      }.contains(this);

  /// Whether it covers ground on foot or by swimming, so it has a pace.
  bool get paced =>
      family == WorkoutFamily.run ||
      family == WorkoutFamily.walk ||
      swims ||
      this == snowshoe;

  /// Whether it builds strength, for what counts sessions of that.
  bool get buildsStrength =>
      family == WorkoutFamily.strength && this != climbing;
}

/// Asked for in the profile; Health Connect on Android does not have it.
enum Sex { female, male }

/// What the app itself can record.
enum EntryKind { water, weight, meal }

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

@immutable
class SleepSegment {
  const SleepSegment({
    required this.stage,
    required this.startMinute,
    required this.minutes,
  });

  final SleepStage stage;

  /// Minutes after the night's bedtime.
  final int startMinute;
  final int minutes;

  Map<String, Object?> toJson() => {
    'stage': stage.name,
    'start': startMinute,
    'minutes': minutes,
  };

  static SleepSegment? fromJson(Object? json) {
    if (json
        case {
          'stage': final String stage,
          'start': final int start,
          'minutes': final int minutes,
        }
        when start >= 0 && minutes > 0) {
      final parsed = _enumByName(SleepStage.values, stage);
      if (parsed == null) return null;
      return SleepSegment(stage: parsed, startMinute: start, minutes: minutes);
    }
    return null;
  }
}

/// The night that ends on the morning of [date].
@immutable
class SleepNight {
  const SleepNight({
    required this.date,
    required this.bedtimeMinute,
    required this.totalMinutes,
    required this.segments,
    this.stageMinutes,
  });

  final DateTime date;

  /// Minute of the day the night started, e.g. 23:10 is 1390.
  final int bedtimeMinute;

  /// Length of the whole session. Sources that record no stages still give
  /// this, so it does not depend on [segments].
  final int totalMinutes;

  /// Empty when the source recorded no sleep stages, and for a night from
  /// the archive, which keeps [stageMinutes] instead.
  final List<SleepSegment> segments;

  /// The minutes in each stage of a night whose [segments] were not kept.
  final Map<SleepStage, int>? stageMinutes;

  /// Whether the night says how long each stage lasted.
  bool get hasStages => segments.isNotEmpty || stageMinutes != null;

  /// Whether the night says when each stage was.
  bool get hasCurve => segments.isNotEmpty;

  /// The night as the archive keeps it: the times and the minutes in each
  /// stage, without the curve.
  SleepNight get summary => SleepNight(
    date: date,
    bedtimeMinute: bedtimeMinute,
    totalMinutes: totalMinutes,
    segments: const [],
    stageMinutes: !hasStages
        ? null
        : {
            for (final stage in SleepStage.values)
              if (minutesIn(stage) > 0) stage: minutesIn(stage),
          },
  );

  int get asleepMinutes => totalMinutes - minutesIn(SleepStage.awake);

  int get wakeMinute => (bedtimeMinute + totalMinutes) % (24 * 60);

  int minutesIn(SleepStage stage) {
    if (segments.isEmpty) return stageMinutes?[stage] ?? 0;
    return segments
        .where((s) => s.stage == stage)
        .fold(0, (sum, s) => sum + s.minutes);
  }

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'bedtime': bedtimeMinute,
    'total': totalMinutes,
    'segments': [for (final s in segments) s.toJson()],
    'stages': ?switch (stageMinutes) {
      final minutes? => {
        for (final MapEntry(:key, :value) in minutes.entries) key.name: value,
      },
      null => null,
    },
  };

  static SleepNight? fromJson(Object? json) {
    if (json
        case {
          'date': final String date,
          'bedtime': final int bedtime,
          'total': final int total,
          'segments': final List<Object?> segments,
        }
        when total > 0 && bedtime >= 0 && bedtime < 24 * 60) {
      final parsedDate = DateTime.tryParse(date);
      if (parsedDate == null) return null;
      return SleepNight(
        date: parsedDate,
        bedtimeMinute: bedtime,
        totalMinutes: total,
        segments: [for (final s in segments) ?SleepSegment.fromJson(s)],
        stageMinutes: switch (json['stages']) {
          final Map<String, Object?> stages => {
            for (final stage in SleepStage.values)
              if (stages[stage.name] case final int minutes when minutes > 0)
                stage: minutes,
          },
          _ => null,
        },
      );
    }
    return null;
  }
}

@immutable
class HeartSample {
  const HeartSample({required this.minuteOfDay, required this.bpm});

  final int minuteOfDay;
  final int bpm;
}

@immutable
class Workout {
  const Workout({
    required this.type,
    required this.start,
    required this.minutes,
    this.kcal,
    this.distanceKm,
    this.steps,
    this.avgBpm,
    this.maxBpm,
    this.fineKcal,
  });

  final WorkoutType type;
  final DateTime start;
  final int minutes;
  final int? kcal;
  final double? distanceKm;
  final int? steps;

  /// The heart rate during the workout. Not from the store: worked out from
  /// the day's curve while the app still has it.
  final int? avgBpm;
  final int? maxBpm;

  /// The active energy as the fine values count it: estimated from the heart
  /// rate, less what the time would have cost at rest. Worked out while the
  /// app still has the beats of that day.
  final int? fineKcal;

  /// Names the workout across reads of the store.
  String get key => '${type.stem}@${start.toIso8601String()}';

  DateTime get end => start.add(Duration(minutes: minutes));

  Workout withHeart({required int? avgBpm, required int? maxBpm}) => Workout(
    type: type,
    start: start,
    minutes: minutes,
    kcal: kcal,
    distanceKm: distanceKm,
    steps: steps,
    avgBpm: avgBpm,
    maxBpm: maxBpm,
    fineKcal: fineKcal,
  );

  /// This workout as the fine values show it: with their energy in place of
  /// the store's.
  Workout get fine => Workout(
    type: type,
    start: start,
    minutes: minutes,
    kcal: fineKcal,
    distanceKm: distanceKm,
    steps: steps,
    avgBpm: avgBpm,
    maxBpm: maxBpm,
    fineKcal: fineKcal,
  );

  Workout withFineKcal(int? fineKcal) => Workout(
    type: type,
    start: start,
    minutes: minutes,
    kcal: kcal,
    distanceKm: distanceKm,
    steps: steps,
    avgBpm: avgBpm,
    maxBpm: maxBpm,
    fineKcal: fineKcal,
  );

  Map<String, Object?> toJson() => {
    'type': type.name,
    'start': start.toIso8601String(),
    'minutes': minutes,
    'kcal': kcal,
    'km': distanceKm,
    'steps': ?steps,
    'avgBpm': ?avgBpm,
    'maxBpm': ?maxBpm,
    'fineKcal': ?fineKcal,
  };

  static Workout? fromJson(Object? json) {
    if (json
        case {
          'type': final String type,
          'start': final String start,
          'minutes': final int minutes,
          'kcal': final int? kcal,
          'km': final num? km,
        }
        when minutes >= 0) {
      final parsedStart = DateTime.tryParse(start);
      if (parsedStart == null) return null;
      // Added later; documents written before do not have them.
      int? positive(String name) => switch (json[name]) {
        final int value when value > 0 => value,
        _ => null,
      };
      return Workout(
        type: _enumByName(WorkoutType.values, type) ?? WorkoutType.other,
        start: parsedStart,
        minutes: minutes,
        kcal: kcal,
        distanceKm: km?.toDouble(),
        steps: positive('steps'),
        avgBpm: positive('avgBpm'),
        maxBpm: positive('maxBpm'),
        fineKcal: positive('fineKcal'),
      );
    }
    return null;
  }
}

/// The content of a water, weight or meal entry, before or after it is saved.
///
/// [amount] is millilitres for water, kilograms for weight and kilocalories
/// for a meal. The remaining fields only apply to meals.
@immutable
class EntryDraft {
  const EntryDraft({
    required this.kind,
    required this.time,
    required this.amount,
    this.name,
    this.carbs,
    this.protein,
    this.fat,
    this.fiber,
    this.sugar,
  });

  final EntryKind kind;
  final DateTime time;
  final double amount;
  final String? name;
  final double? carbs;
  final double? protein;
  final double? fat;
  final double? fiber;
  final double? sugar;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'time': time.toIso8601String(),
    'amount': amount,
    'name': name,
    'carbs': carbs,
    'protein': protein,
    'fat': fat,
    'fiber': fiber,
    'sugar': sugar,
  };

  static EntryDraft? fromJson(Object? json) {
    if (json case {
      'kind': final String kind,
      'time': final String time,
      'amount': final num amount,
      'name': final String? name,
      'carbs': final num? carbs,
      'protein': final num? protein,
      'fat': final num? fat,
      'fiber': final num? fiber,
      'sugar': final num? sugar,
    }) {
      final parsedKind = _enumByName(EntryKind.values, kind);
      final parsedTime = DateTime.tryParse(time);
      if (parsedKind == null || parsedTime == null || !amount.isFinite) {
        return null;
      }
      return EntryDraft(
        kind: parsedKind,
        time: parsedTime,
        amount: amount.toDouble(),
        name: name,
        carbs: carbs?.toDouble(),
        protein: protein?.toDouble(),
        fat: fat?.toDouble(),
        fiber: fiber?.toDouble(),
        sugar: sugar?.toDouble(),
      );
    }
    return null;
  }
}

/// A saved entry. Only entries this app wrote ([isOwn]) can be changed or
/// deleted; Health Connect does not let an app touch another app's records.
@immutable
class HealthEntry {
  const HealthEntry({
    required this.id,
    required this.source,
    required this.isOwn,
    required this.draft,
  });

  final String id;

  /// Package name of the app that wrote the entry.
  final String source;
  final bool isOwn;
  final EntryDraft draft;

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source,
    'own': isOwn,
    'draft': draft.toJson(),
  };

  static HealthEntry? fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'source': final String source,
      'own': final bool own,
      'draft': final Object? draft,
    }) {
      final parsed = EntryDraft.fromJson(draft);
      if (parsed == null) return null;
      return HealthEntry(id: id, source: source, isOwn: own, draft: parsed);
    }
    return null;
  }
}
