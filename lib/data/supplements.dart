import 'package:flutter/foundation.dart';

/// What a dose of a supplement is counted in.
enum SupplementUnit {
  capsule,
  tablet,
  scoop,
  drop,
  piece,
  gram,
  milligram,
  millilitre,
  iu,
}

/// When of the day a supplement is due.
enum SupplementTime {
  /// At no set time: it is never reminded of.
  any,
  morning,
  noon,
  evening;

  /// The minute of the day the reminder comes at, until the user sets one.
  int get usualMinute => switch (this) {
    SupplementTime.any => 0,
    SupplementTime.morning => 8 * 60,
    SupplementTime.noon => 13 * 60,
    SupplementTime.evening => 21 * 60,
  };

  /// The times of day a reminder can come at.
  static const List<SupplementTime> reminded = [morning, noon, evening];
}

T? _named<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

double? _positive(Object? json) => switch (json) {
  final num value when value.isFinite && value > 0 => value.toDouble(),
  _ => null,
};

/// The hour from which caffeine counts as late in the day.
const int lateCaffeineHour = 14;

/// One of the well-known supplements the app offers, by what it is and
/// never by a brand. Its name is a text of the app, found by [id].
@immutable
class SupplementPreset {
  const SupplementPreset(
    this.id, {
    this.amount,
    this.unit,
    this.caffeineMg,
    this.time = SupplementTime.any,
  });

  final String id;

  /// A common way to count it, as a start; not a recommendation.
  final double? amount;
  final SupplementUnit? unit;
  final double? caffeineMg;
  final SupplementTime time;

  Supplement added(DateTime now) => Supplement(
    key: id,
    preset: id,
    amount: amount,
    unit: unit,
    caffeineMg: caffeineMg,
    time: time,
    addedAt: now,
  );
}

/// The supplements offered to pick from, most common first.
const List<SupplementPreset> supplementCatalog = [
  SupplementPreset('creatine', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('protein', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('omega3', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('vitaminD', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('magnesium', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('multivitamin', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('vitaminC', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('vitaminB12', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('vitaminK2', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('zinc', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('iron', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('calcium', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('folicAcid', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('biotin', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('ashwagandha', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('rhodiola', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('ginseng', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('melatonin', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('theanine', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('glycine', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset(
    'caffeine',
    amount: 1,
    unit: SupplementUnit.tablet,
    caffeineMg: 200,
  ),
  SupplementPreset(
    'preWorkout',
    amount: 1,
    unit: SupplementUnit.scoop,
    caffeineMg: 200,
  ),
  SupplementPreset('bcaa', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('eaa', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('glutamine', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('betaAlanine', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('citrulline', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('carnitine', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('taurine', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('collagen', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('electrolytes', amount: 1, unit: SupplementUnit.tablet),
  SupplementPreset('probiotics', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('psyllium', amount: 1, unit: SupplementUnit.scoop),
  SupplementPreset('curcumin', amount: 1, unit: SupplementUnit.capsule),
  SupplementPreset('coenzymeQ10', amount: 1, unit: SupplementUnit.capsule),
  // Not supplements, but where most caffeine comes from.
  SupplementPreset('coffee', caffeineMg: 80),
  SupplementPreset('espresso', caffeineMg: 60),
  SupplementPreset('energyDrink', caffeineMg: 80),
];

/// The preset called [id], if the app still offers it.
SupplementPreset? presetOf(String? id) {
  for (final preset in supplementCatalog) {
    if (preset.id == id) return preset;
  }
  return null;
}

/// The key of a supplement of the user's own called [name]: its name
/// without case and outer blanks, apart from every preset.
String ownSupplementKey(String name) => 'own:${name.trim().toLowerCase()}';

/// A supplement the user takes.
@immutable
class Supplement {
  const Supplement({
    required this.key,
    required this.addedAt,
    this.preset,
    this.name,
    this.amount,
    this.unit,
    this.caffeineMg,
    this.time = SupplementTime.any,
    this.remind = false,
    this.removedAt,
  });

  /// The preset's id, or [ownSupplementKey] of the name.
  final String key;

  /// The id in [supplementCatalog] its name comes from; null for one of
  /// the user's own, which has a [name].
  final String? preset;
  final String? name;

  /// How much one dose is. Without it the supplement is only "taken".
  final double? amount;
  final SupplementUnit? unit;

  /// The caffeine in one dose, in milligrams.
  final double? caffeineMg;
  final SupplementTime time;

  /// Whether the reminder of its [time] names it while it is open.
  final bool remind;
  final DateTime addedAt;

  /// When the user took it off the list. What was taken of it stays.
  final DateTime? removedAt;

  bool get removed => removedAt != null;

  Supplement copyWith({
    String? name,
    double? Function()? amount,
    SupplementUnit? Function()? unit,
    double? Function()? caffeineMg,
    SupplementTime? time,
    bool? remind,
    DateTime? Function()? removedAt,
  }) => Supplement(
    key: key,
    preset: preset,
    addedAt: addedAt,
    name: name ?? this.name,
    amount: amount == null ? this.amount : amount(),
    unit: unit == null ? this.unit : unit(),
    caffeineMg: caffeineMg == null ? this.caffeineMg : caffeineMg(),
    time: time ?? this.time,
    remind: remind ?? this.remind,
    removedAt: removedAt == null ? this.removedAt : removedAt(),
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'preset': ?preset,
    'name': ?name,
    'amount': ?amount,
    'unit': ?unit?.name,
    'caffeineMg': ?caffeineMg,
    'time': time.name,
    'remind': remind,
    'addedAt': addedAt.toIso8601String(),
    'removedAt': ?removedAt?.toIso8601String(),
  };

  static Supplement? fromJson(Object? json) {
    if (json case {'key': final String key, 'addedAt': final String addedAt}
        when key.isNotEmpty) {
      final added = DateTime.tryParse(addedAt);
      final preset = switch (json['preset']) {
        final String id => id,
        _ => null,
      };
      final name = switch (json['name']) {
        final String name when name.trim().isNotEmpty => name.trim(),
        _ => null,
      };
      // Without a name of its own or a preset there is nothing to call it.
      if (added == null || (name == null && presetOf(preset) == null)) {
        return null;
      }
      return Supplement(
        key: key,
        preset: preset,
        name: name,
        amount: _positive(json['amount']),
        unit: _named(SupplementUnit.values, json['unit']),
        caffeineMg: _positive(json['caffeineMg']),
        time: _named(SupplementTime.values, json['time']) ?? SupplementTime.any,
        remind: json['remind'] == true,
        addedAt: added,
        removedAt: switch (json['removedAt']) {
          final String at => DateTime.tryParse(at),
          _ => null,
        },
      );
    }
    return null;
  }
}

/// One time a supplement was taken, with the dose it was taken in.
@immutable
class Intake {
  const Intake({
    required this.key,
    required this.at,
    this.amount,
    this.unit,
    this.caffeineMg,
  });

  /// The [Supplement.key] of what was taken.
  final String key;
  final DateTime at;
  final double? amount;
  final SupplementUnit? unit;
  final double? caffeineMg;

  DateTime get day => DateTime(at.year, at.month, at.day);

  Map<String, Object?> toJson() => {
    'key': key,
    'at': at.millisecondsSinceEpoch,
    'amount': ?amount,
    'unit': ?unit?.name,
    'caffeineMg': ?caffeineMg,
  };

  static Intake? fromJson(Object? json) {
    if (json case {'key': final String key, 'at': final int at}
        when key.isNotEmpty) {
      return Intake(
        key: key,
        at: DateTime.fromMillisecondsSinceEpoch(at),
        amount: _positive(json['amount']),
        unit: _named(SupplementUnit.values, json['unit']),
        caffeineMg: _positive(json['caffeineMg']),
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Intake && other.key == key && other.at == at;

  @override
  int get hashCode => Object.hash(key, at);
}

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// Everything the app knows of the user's supplements: which they take,
/// when they took them, and when they want to be reminded.
@immutable
class SupplementData {
  const SupplementData({
    this.supplements = const [],
    this.intakes = const [],
    this.minutes = const {},
  });

  /// In the order they were added, the removed ones among them.
  final List<Supplement> supplements;

  /// Oldest first.
  final List<Intake> intakes;

  /// The minute of the day of each reminder the user moved.
  final Map<SupplementTime, int> minutes;

  static const int schemaVersion = 1;

  /// The ones on the user's list.
  List<Supplement> get mine => [
    for (final supplement in supplements)
      if (!supplement.removed) supplement,
  ];

  Supplement? byKey(String key) {
    for (final supplement in supplements) {
      if (supplement.key == key) return supplement;
    }
    return null;
  }

  int minuteOf(SupplementTime time) => minutes[time] ?? time.usualMinute;

  /// What was taken on [day], oldest first.
  List<Intake> intakesOn(DateTime day) {
    final date = _dayOf(day);
    return [
      for (final intake in intakes)
        if (intake.day == date) intake,
    ];
  }

  /// Every time the supplement [key] was taken, oldest first.
  List<Intake> intakesOf(String key) => [
    for (final intake in intakes)
      if (intake.key == key) intake,
  ];

  /// The last time [key] was taken on [day], if it was.
  Intake? takenOn(String key, DateTime day) {
    final date = _dayOf(day);
    for (final intake in intakes.reversed) {
      if (intake.key == key && intake.day == date) return intake;
    }
    return null;
  }

  /// The days [key] was taken on.
  Set<DateTime> daysOf(String key) => {
    for (final intake in intakes)
      if (intake.key == key) intake.day,
  };

  /// Days in a row [key] was taken, ending on [today], or on the day
  /// before while today is still open.
  int streak(String key, DateTime today) {
    final days = daysOf(key);
    var day = _dayOf(today);
    if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// On how many of the last [days] days up to [today] the supplement [key]
  /// was taken, and how many of those days it has been on the list for.
  ({int taken, int of}) rate(String key, DateTime today, {int days = 30}) {
    final end = _dayOf(today);
    var first = DateTime(end.year, end.month, end.day - days + 1);
    final taken = daysOf(key);
    final added = byKey(key)?.addedAt;
    final since = [if (added != null) _dayOf(added), ...taken].fold<DateTime?>(
      null,
      (earliest, day) =>
          earliest == null || day.isBefore(earliest) ? day : earliest,
    );
    if (since != null && since.isAfter(first)) first = since;
    var count = 0;
    var of = 0;
    for (
      var day = first;
      !day.isAfter(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      of++;
      if (taken.contains(day)) count++;
    }
    return (taken: count, of: of);
  }

  /// The caffeine taken on [day] in milligrams; null where none was.
  double? caffeineOn(DateTime day) {
    var sum = 0.0;
    for (final intake in intakesOn(day)) {
      sum += intake.caffeineMg ?? 0;
    }
    return sum > 0 ? sum : null;
  }

  /// When caffeine was last taken on [day].
  DateTime? lastCaffeine(DateTime day) {
    for (final intake in intakesOn(day).reversed) {
      if ((intake.caffeineMg ?? 0) > 0) return intake.at;
    }
    return null;
  }

  /// Whether caffeine was taken on [day] from [lateCaffeineHour] on.
  bool lateCaffeineOn(DateTime day) => intakesOn(day).any(
    (intake) =>
        (intake.caffeineMg ?? 0) > 0 && intake.at.hour >= lateCaffeineHour,
  );

  /// The supplements of [time] with a reminder that are not taken yet on
  /// the day of [now].
  List<Supplement> open(SupplementTime time, DateTime now) => [
    for (final supplement in mine)
      if (supplement.time == time &&
          supplement.remind &&
          takenOn(supplement.key, now) == null)
        supplement,
  ];

  /// The user's supplements, the ones taken most often in the [days]
  /// before [now] first; on a tie in the order of the list.
  List<Supplement> mostTaken(DateTime now, {int days = 30}) {
    final from = now.subtract(Duration(days: days));
    final counts = <String, int>{};
    for (final intake in intakes) {
      if (intake.at.isAfter(from)) {
        counts[intake.key] = (counts[intake.key] ?? 0) + 1;
      }
    }
    final list = mine;
    final order = {for (final (index, s) in list.indexed) s.key: index};
    return list..sort((a, b) {
      final byCount = (counts[b.key] ?? 0).compareTo(counts[a.key] ?? 0);
      return byCount != 0 ? byCount : order[a.key]!.compareTo(order[b.key]!);
    });
  }

  /// With [supplement] on the list: new at its end, or in the place of the
  /// one with its key, which also brings a removed one back.
  SupplementData withSupplement(Supplement supplement) {
    final known = byKey(supplement.key) != null;
    return _with(
      supplements: [
        for (final other in supplements)
          other.key == supplement.key ? supplement : other,
        if (!known) supplement,
      ],
    );
  }

  /// With [key] off the list from [now] on. What was taken of it stays; a
  /// supplement never taken is forgotten altogether.
  SupplementData without(String key, DateTime now) {
    final taken = intakes.any((intake) => intake.key == key);
    return _with(
      supplements: [
        for (final other in supplements)
          if (other.key != key)
            other
          else if (taken)
            other.copyWith(removedAt: () => now),
      ],
    );
  }

  SupplementData withIntake(Intake intake) => _with(
    intakes: [
      for (final other in intakes)
        if (other != intake) other,
      intake,
    ]..sort((a, b) => a.at.compareTo(b.at)),
  );

  SupplementData withoutIntake(Intake intake) => _with(
    intakes: [
      for (final other in intakes)
        if (other != intake) other,
    ],
  );

  SupplementData withMinute(SupplementTime time, int minute) =>
      _with(minutes: {...minutes, time: minute});

  SupplementData _with({
    List<Supplement>? supplements,
    List<Intake>? intakes,
    Map<SupplementTime, int>? minutes,
  }) => SupplementData(
    supplements: supplements ?? this.supplements,
    intakes: intakes ?? this.intakes,
    minutes: minutes ?? this.minutes,
  );

  /// Both lists joined: what [other] has and this lacks is added, what
  /// both have stays as it is here. For reading a backup.
  SupplementData mergedWith(SupplementData other) {
    final keys = {for (final supplement in supplements) supplement.key};
    final taken = {...intakes};
    return SupplementData(
      supplements: [
        ...supplements,
        for (final supplement in other.supplements)
          if (!keys.contains(supplement.key)) supplement,
      ],
      intakes: [
        ...intakes,
        for (final intake in other.intakes)
          if (!taken.contains(intake)) intake,
      ]..sort((a, b) => a.at.compareTo(b.at)),
      minutes: {...other.minutes, ...minutes},
    );
  }

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'minutes': {
      for (final MapEntry(key: time, value: minute) in minutes.entries)
        time.name: minute,
    },
    'supplements': [for (final supplement in supplements) supplement.toJson()],
    'intakes': [for (final intake in intakes) intake.toJson()],
  };

  /// Anything that is not valid is skipped; another version gives nothing.
  static SupplementData fromJson(Object? json) {
    if (json case {
      'version': schemaVersion,
      'supplements': final List<Object?> supplements,
      'intakes': final List<Object?> intakes,
    }) {
      final minutes = <SupplementTime, int>{};
      if (json['minutes'] case final Map<String, Object?> saved) {
        for (final time in SupplementTime.reminded) {
          if (saved[time.name] case final int minute
              when minute >= 0 && minute < 24 * 60) {
            minutes[time] = minute;
          }
        }
      }
      final seen = <String>{};
      return SupplementData(
        supplements: [
          for (final entry in supplements)
            if (Supplement.fromJson(entry) case final supplement?
                when seen.add(supplement.key))
              supplement,
        ],
        intakes: [for (final entry in intakes) ?Intake.fromJson(entry)]
          ..sort((a, b) => a.at.compareTo(b.at)),
        minutes: minutes,
      );
    }
    return const SupplementData();
  }
}
