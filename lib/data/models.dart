import 'package:flutter/foundation.dart';

enum SleepStage { awake, rem, light, deep }

enum WorkoutType { run, ride, walk, hike, strength, yoga, swim, other }

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
  });

  final DateTime date;

  /// Minute of the day the night started, e.g. 23:10 is 1390.
  final int bedtimeMinute;

  /// Length of the whole session. Sources that record no stages still give
  /// this, so it does not depend on [segments].
  final int totalMinutes;

  /// Empty when the source recorded no sleep stages.
  final List<SleepSegment> segments;

  bool get hasStages => segments.isNotEmpty;

  int get asleepMinutes => totalMinutes - minutesIn(SleepStage.awake);

  int get wakeMinute => (bedtimeMinute + totalMinutes) % (24 * 60);

  int minutesIn(SleepStage stage) => segments
      .where((s) => s.stage == stage)
      .fold(0, (sum, s) => sum + s.minutes);

  /// Health Connect stores no sleep score. This is the app's own rough
  /// estimate from duration and the share of deep sleep, and is labelled as
  /// an estimate wherever it is shown.
  int get estimatedScore {
    final deepShare = hasStages
        ? minutesIn(SleepStage.deep) / totalMinutes
        // Without stages, assume a typical share so the score rests on
        // duration alone.
        : 0.17;
    final score = 28 + asleepMinutes / 9 + deepShare * 45;
    return score.round().clamp(1, 100);
  }

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'bedtime': bedtimeMinute,
    'total': totalMinutes,
    'segments': [for (final s in segments) s.toJson()],
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
  });

  final WorkoutType type;
  final DateTime start;
  final int minutes;
  final int? kcal;
  final double? distanceKm;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'start': start.toIso8601String(),
    'minutes': minutes,
    'kcal': kcal,
    'km': distanceKm,
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
      return Workout(
        type: _enumByName(WorkoutType.values, type) ?? WorkoutType.other,
        start: parsedStart,
        minutes: minutes,
        kcal: kcal,
        distanceKm: km?.toDouble(),
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
