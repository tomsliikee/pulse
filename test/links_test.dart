import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/goals.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/links.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/features/links/link_format.dart';

import 'support/fixtures.dart';

/// A Sunday, so whole weeks end on it.
final _until = DateTime(2026, 10, 4);

DateTime _ago(int days) =>
    DateTime(_until.year, _until.month, _until.day - days);

/// Some scatter that is the same in every run: from -8 to 8.
int _noise(int n) => (n * 7) % 5 * 4 - 8;

SleepNight _night(int ago, int asleep, {int bedtime = 23 * 60, int? deep}) =>
    SleepNight(
      date: _ago(ago),
      bedtimeMinute: bedtime % (24 * 60),
      totalMinutes: asleep,
      segments: const [],
      stageMinutes: deep == null
          ? null
          : {SleepStage.deep: deep, SleepStage.light: asleep - deep},
    );

Workout _workout(int ago) => Workout(
  type: WorkoutType.run,
  start: _ago(ago).add(const Duration(hours: 18)),
  minutes: 30,
);

GoalData _data({
  List<SleepNight> nights = const [],
  List<Workout> workouts = const [],
  Map<Metric, Map<int, double>> values = const {},
}) => GoalData(
  valueOf: (metric, day) => values[metric]?[dayKey(day)],
  // Oldest first, as the app holds them.
  nights: [...nights]..sort((a, b) => a.date.compareTo(b.date)),
  workouts: [...workouts]..sort((a, b) => a.start.compareTo(b.start)),
  sleepGoalHours: 8,
);

List<Link> _find(
  GoalData data, {
  double Function(Goal goal)? targetOf,
  Set<LinkKind>? kinds,
  DateTime? until,
}) => findLinks(
  data: data,
  targetOf: targetOf ?? (goal) => goal.defaultTarget,
  until: until ?? _until,
  kinds: kinds ?? LinkKind.values.toSet(),
);

Link? _one(List<Link> links, LinkCause cause, LinkEffect effect) {
  final found = [
    for (final link in links)
      if (link.cause == cause && link.effect == effect) link,
  ];
  expect(found.length, lessThanOrEqualTo(1));
  return found.firstOrNull;
}

void main() {
  group('a day and the night after', () {
    // Sixty nights; the night that ends on day n follows day n + 1 (counted
    // back), and every third day had a workout.
    bool trained(int ago) => (ago + 1) % 3 == 0;
    List<SleepNight> nights({int more = 40, int scatter = 1}) => [
      for (var ago = 0; ago < 60; ago++)
        _night(
          ago,
          440 + (trained(ago) ? more : 0) + _noise(ago) * scatter,
          deep: 80 + (trained(ago) ? 20 : 0) + _noise(ago) ~/ 2,
        ),
    ];
    final workouts = [
      for (var ago = 0; ago < 60; ago++)
        if (trained(ago)) _workout(ago + 1),
    ];

    test('nights after a workout are set against the others', () {
      final links = _find(_data(nights: nights(), workouts: workouts));
      final asleep = _one(links, LinkCause.workout, LinkEffect.asleep)!;
      expect(asleep.kind, LinkKind.dayToNight);
      expect(asleep.split, LinkSplit.yesNo);
      expect(asleep.countWith, 20);
      expect(asleep.countWithout, 40);
      expect(asleep.difference, closeTo(40, 3));
      expect(asleep.strength, greaterThan(2));
      final deep = _one(links, LinkCause.workout, LinkEffect.deep)!;
      expect(deep.difference, closeTo(20, 2));
      // The strongest first.
      for (var i = 1; i < links.length; i++) {
        expect(links[i - 1].strength, greaterThanOrEqualTo(links[i].strength));
      }
    });

    test('nine days on one side are too few', () {
      final few = workouts.sublist(0, 9);
      final links = _find(_data(nights: nights(), workouts: few));
      expect(links.where((link) => link.cause == LinkCause.workout), isEmpty);
    });

    test('a small difference is not a connection', () {
      final links = _find(_data(nights: nights(more: 2), workouts: workouts));
      expect(_one(links, LinkCause.workout, LinkEffect.asleep), isNull);
    });

    test('a difference too small to matter is not one, however even the '
        'numbers', () {
      // Six minutes more after every workout, and no scatter at all.
      final even = [
        for (var ago = 0; ago < 60; ago++)
          _night(ago, trained(ago) ? 446 : 440),
      ];
      expect(_find(_data(nights: even, workouts: workouts)), isEmpty);
    });

    test('a difference that drowns in the scatter is not one either', () {
      final links = _find(
        _data(nights: nights(scatter: 15), workouts: workouts),
      );
      expect(_one(links, LinkCause.workout, LinkEffect.asleep), isNull);
    });

    test('a night after the last day does not count', () {
      final links = _find(
        _data(nights: nights(), workouts: workouts),
        until: _ago(45),
      );
      // Fifteen nights are left, five of them after a workout.
      expect(links, isEmpty);
    });

    test('steps are split at the goal, or at the median where it is never '
        'reached', () {
      final steps = {
        for (var ago = 1; ago <= 60; ago++)
          dayKey(_ago(ago)): trained(ago - 1)
              ? 12000.0 + _noise(ago) * 50
              : 6000.0 + _noise(ago) * 50,
      };
      final data = _data(nights: nights(), values: {Metric.steps: steps});
      final atGoal = _one(_find(data), LinkCause.steps, LinkEffect.asleep)!;
      expect(atGoal.split, LinkSplit.goal);
      expect(atGoal.countWith, 20);
      expect(atGoal.difference, closeTo(40, 3));

      final never = _one(
        _find(data, targetOf: (goal) => 20000),
        LinkCause.steps,
        LinkEffect.asleep,
      )!;
      expect(never.split, LinkSplit.usual);
      expect(never.difference, greaterThan(15));
    });

    test('only the asked kinds are looked for', () {
      final links = _find(
        _data(nights: nights(), workouts: workouts),
        kinds: {LinkKind.weekday},
      );
      expect(links.where((link) => link.kind != LinkKind.weekday), isEmpty);
    });
  });

  group('a night and the day after', () {
    // Every other night is long, and the resting pulse of its day is lower.
    final nights = [
      for (var ago = 0; ago < 60; ago++)
        _night(ago, (ago.isEven ? 500 : 420) + _noise(ago)),
    ];
    final values = {
      Metric.restingHeartRate: {
        for (var ago = 0; ago < 60; ago++)
          dayKey(_ago(ago)): (ago.isEven ? 52.0 : 58.0) + _noise(ago) / 8,
      },
      Metric.heartRateVariability: {
        for (var ago = 0; ago < 60; ago++)
          dayKey(_ago(ago)): 45.0 + _noise(ago) / 4,
      },
    };

    test('long nights are set against short ones at the sleep goal', () {
      final links = _find(_data(nights: nights, values: values));
      final pulse = _one(links, LinkCause.asleep, LinkEffect.restingPulse)!;
      expect(pulse.kind, LinkKind.nightToDay);
      expect(pulse.split, LinkSplit.goal);
      expect(pulse.countWith, 30);
      expect(pulse.difference, closeTo(-6, 0.5));
      // The variability does not follow the nights.
      expect(_one(links, LinkCause.asleep, LinkEffect.variability), isNull);
    });

    test('the recovery is not set against the night it is made of', () {
      final links = _find(_data(nights: nights, values: values));
      expect(_one(links, LinkCause.asleep, LinkEffect.recovery), isNull);
      expect(_one(links, LinkCause.sleepScore, LinkEffect.recovery), isNull);
    });
  });

  group('days of the week', () {
    test('the day that stands out is named, and only that one', () {
      final steps = {
        for (var ago = 0; ago < 90; ago++)
          dayKey(_ago(ago)):
              (_ago(ago).weekday == DateTime.saturday ? 15000.0 : 7000.0) +
              _noise(ago) * 60,
      };
      final links = _find(_data(values: {Metric.steps: steps}));
      final weekdays = links.where((link) => link.kind == LinkKind.weekday);
      expect(weekdays, hasLength(1));
      expect(weekdays.single.weekday, DateTime.saturday);
      expect(weekdays.single.effect, LinkEffect.steps);
      expect(weekdays.single.countWith, 13);
      expect(weekdays.single.difference, closeTo(8000, 200));
    });

    test('sides that never vary and differ are a connection too', () {
      final steps = {
        for (var ago = 0; ago < 90; ago++)
          dayKey(_ago(ago)): _ago(ago).weekday == DateTime.monday
              ? 3000.0
              : 9000.0,
      };
      final link = _find(
        _data(values: {Metric.steps: steps}),
        kinds: {LinkKind.weekday},
      ).single;
      expect(link.weekday, DateTime.monday);
      expect(link.difference, -6000);
    });
  });

  group('weeks', () {
    Map<Metric, Map<int, double>> values(int weeks) => {
      Metric.steps: {
        for (var ago = 0; ago < weeks * 7; ago++)
          dayKey(_ago(ago)): (ago ~/ 7).isEven ? 10000.0 : 5000.0,
      },
      Metric.restingHeartRate: {
        for (var ago = 0; ago < weeks * 7; ago++)
          dayKey(_ago(ago)):
              ((ago ~/ 7).isEven ? 52.0 : 58.0) + _noise(ago ~/ 7) / 8,
      },
    };

    test('weeks with more steps are set against those with fewer, a year '
        'back', () {
      final link = _one(
        _find(_data(values: values(40)), kinds: {LinkKind.weeks}),
        LinkCause.weekSteps,
        LinkEffect.restingPulse,
      )!;
      expect(link.split, LinkSplit.usual);
      expect(link.countWith, 20);
      expect(link.countWithout, 20);
      expect(link.difference, closeTo(-6, 0.5));
    });

    test('three months of weeks are too few', () {
      expect(
        _find(_data(values: values(13)), kinds: {LinkKind.weeks}),
        isEmpty,
      );
    });

    test('a week that began after the last day is left out', () {
      // Wednesday: the week it lies in is not over.
      final links = _find(
        _data(values: values(40)),
        kinds: {LinkKind.weeks},
        until: _ago(4),
      );
      expect(links.single.countWith + links.single.countWithout, 39);
    });
  });

  test('without data nothing is found', () {
    expect(_find(_data()), isEmpty);
    expect(linkNights(const [], _until), 0);
  });

  test('the nights of the stretch are counted up to the last day', () {
    final nights = [for (var ago = 119; ago >= 0; ago--) _night(ago, 450)];
    expect(linkNights(nights, _until), 90);
    expect(linkNights(nights.sublist(100), _until), 20);
  });

  group('sentences', () {
    Link link(
      LinkCause cause,
      LinkEffect effect, {
      LinkKind kind = LinkKind.dayToNight,
      LinkSplit split = LinkSplit.yesNo,
      double withMean = 475,
      double withoutMean = 450,
      int? weekday,
    }) => Link(
      kind: kind,
      cause: cause,
      split: split,
      effect: effect,
      withMean: withMean,
      withoutMean: withoutMean,
      countWith: 12,
      countWithout: 30,
      strength: 1,
      weekday: weekday,
    );

    test('a connection reads as a sentence in each language', () {
      final shorter = link(LinkCause.workout, LinkEffect.asleep, withMean: 425);
      expect(
        linkSentence(formatsOf(), shorter),
        'Nach Tagen mit Training schläfst du im Schnitt 25 min kürzer.',
      );
      expect(
        linkSentence(formatsOf('en'), shorter),
        'After days with a workout you sleep 25 min less on average.',
      );
      expect(
        linkSentence(formatsOf('pl'), shorter),
        'Po dniach z treningiem śpisz średnio o 25 min krócej.',
      );
    });

    test('the split and the day of the week are named', () {
      final formats = formatsOf();
      expect(
        linkSentence(
          formats,
          link(LinkCause.steps, LinkEffect.deep, split: LinkSplit.goal),
        ),
        'Nach Tagen über deinem Schrittziel hast du im Schnitt 25 min mehr '
        'Tiefschlaf.',
      );
      expect(
        linkSentence(
          formats,
          link(LinkCause.steps, LinkEffect.bedtime, split: LinkSplit.usual),
        ),
        'Nach Tagen mit mehr Schritten als üblich gehst du im Schnitt 25 min '
        'später ins Bett.',
      );
      expect(
        linkSentence(
          formats,
          link(
            LinkCause.weekday,
            LinkEffect.steps,
            kind: LinkKind.weekday,
            weekday: DateTime.saturday,
            withMean: 15000,
            withoutMean: 7000,
          ),
        ),
        'Am Samstag gehst du im Schnitt 8.000 Schritte mehr.',
      );
      expect(
        linkSentence(
          formatsOf('pl'),
          link(
            LinkCause.weekday,
            LinkEffect.asleep,
            kind: LinkKind.weekday,
            weekday: DateTime.wednesday,
          ),
        ),
        'W nocy na środę śpisz średnio o 25 min dłużej.',
      );
      expect(
        linkSentence(
          formatsOf('en'),
          link(
            LinkCause.weekSteps,
            LinkEffect.restingPulse,
            kind: LinkKind.weeks,
            split: LinkSplit.usual,
            withMean: 52,
            withoutMean: 58,
          ),
        ),
        'In weeks with more steps than usual your resting heart rate is '
        '6 bpm lower on average.',
      );
    });

    test('every cause and effect has a sentence in every language', () {
      for (final language in ['de', 'en', 'pl']) {
        final formats = formatsOf(language);
        for (final cause in LinkCause.values) {
          for (final split in LinkSplit.values) {
            for (final effect in LinkEffect.values) {
              final sentence = linkSentence(
                formats,
                link(cause, effect, split: split, weekday: 7),
              );
              expect(sentence, endsWith('.'));
              expect(sentence, isNot(contains('{')));
            }
          }
        }
      }
    });

    test('values stand beside their bars in their own unit', () {
      final formats = formatsOf();
      expect(linkValue(formats, LinkEffect.asleep, 452), '7 h 32 min');
      expect(linkValue(formats, LinkEffect.bedtime, 24 * 60 + 10), '00:10');
      expect(linkValue(formats, LinkEffect.steps, 8412.4), '8.412');
      expect(linkBarFrom(LinkEffect.bedtime), 18 * 60);
      expect(linkBarFrom(LinkEffect.steps), 0);
    });
  });
}
