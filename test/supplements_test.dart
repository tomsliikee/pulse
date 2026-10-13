import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/background/supplement_notice.dart';
import 'package:pulse/data/backup.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/supplement_controller.dart';
import 'package:pulse/data/supplements.dart';

import 'support/fixtures.dart';

DateTime _at(int day, [int hour = 8, int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);

final _creatine = presetOf('creatine')!.added(_at(1));
final _magnesium = presetOf('magnesium')!
    .added(_at(1))
    .copyWith(time: SupplementTime.evening, remind: true);
final _coffee = presetOf('coffee')!.added(_at(1));

Intake _took(Supplement supplement, DateTime at) => Intake(
  key: supplement.key,
  at: at,
  amount: supplement.amount,
  unit: supplement.unit,
  caffeineMg: supplement.caffeineMg,
);

void main() {
  group('the catalog', () {
    test('offers each supplement once, and never by a brand', () {
      final ids = [for (final preset in supplementCatalog) preset.id];
      expect(ids.toSet().length, ids.length);
      expect(ids, containsAll(['creatine', 'ashwagandha', 'magnesium']));
      expect(presetOf('creatine')!.unit, SupplementUnit.scoop);
      expect(presetOf('nothing'), isNull);
    });

    test('a preset is added with its usual dose and can lose it', () {
      expect(_creatine.amount, 1);
      final plain = _creatine.copyWith(amount: () => null, unit: () => null);
      expect(plain.amount, isNull);
      expect(plain.unit, isNull);
      expect(plain.key, 'creatine');
    });
  });

  group('SupplementData', () {
    final data = SupplementData(
      supplements: [_creatine, _magnesium, _coffee],
      intakes: [
        _took(_creatine, _at(10)),
        _took(_creatine, _at(11)),
        _took(_creatine, _at(12)),
        _took(_coffee, _at(12, 7, 30)),
        _took(_coffee, _at(12, 15, 10)),
        _took(_magnesium, _at(11, 21)),
      ],
    );

    test('says what was taken on a day and when', () {
      expect(data.takenOn('creatine', _at(12, 23))?.at, _at(12));
      expect(data.takenOn('magnesium', _at(12)), isNull);
      expect(data.intakesOn(_at(12)).length, 3);
    });

    test('a streak ends today, or yesterday while today is open', () {
      expect(data.streak('creatine', _at(12)), 3);
      expect(data.streak('creatine', _at(13)), 3);
      expect(data.streak('creatine', _at(14)), 0);
      expect(data.streak('magnesium', _at(12)), 1);
      expect(data.streak('coffee', _at(1)), 0);
    });

    test('the rate counts from the day a supplement came on the list', () {
      // On the list since the first, taken on three of twelve days.
      expect(data.rate('creatine', _at(12)), (taken: 3, of: 12));
      expect(data.rate('creatine', _at(12), days: 3), (taken: 3, of: 3));
      expect(data.rate('magnesium', _at(12), days: 7), (taken: 1, of: 7));
    });

    test('adds up the caffeine of a day and knows the last of it', () {
      expect(data.caffeineOn(_at(12)), 160);
      expect(data.lastCaffeine(_at(12)), _at(12, 15, 10));
      expect(data.lateCaffeineOn(_at(12)), isTrue);
      expect(data.caffeineOn(_at(11)), isNull);
      expect(data.lastCaffeine(_at(11)), isNull);
      expect(data.lateCaffeineOn(_at(11)), isFalse);
    });

    test('what is open at a time of day is what is reminded of', () {
      expect(data.open(SupplementTime.evening, _at(12, 21)), [_magnesium]);
      expect(data.open(SupplementTime.evening, _at(11, 22)), isEmpty);
      // Creatine has no time of day and no reminder.
      expect(data.open(SupplementTime.morning, _at(13)), isEmpty);
      expect(data.open(SupplementTime.any, _at(13)), isEmpty);
    });

    test('the most taken come first, the rest in the order of the list', () {
      expect(
        [for (final s in data.mostTaken(_at(13))) s.key],
        ['creatine', 'coffee', 'magnesium'],
      );
      // Nothing was taken in the last day but the list stays whole.
      expect(
        [for (final s in data.mostTaken(_at(20), days: 1)) s.key],
        ['creatine', 'magnesium', 'coffee'],
      );
    });

    test('a removed supplement keeps its past and can come back', () {
      final without = data.without('creatine', _at(13));
      expect([for (final s in without.mine) s.key], ['magnesium', 'coffee']);
      expect(without.intakesOf('creatine').length, 3);
      expect(without.byKey('creatine')!.removed, isTrue);
      final back = without.withSupplement(
        without.byKey('creatine')!.copyWith(removedAt: () => null),
      );
      expect(
        [for (final s in back.mine) s.key],
        ['creatine', 'magnesium', 'coffee'],
      );
    });

    test('one never taken is forgotten when removed', () {
      final own = Supplement(
        key: ownSupplementKey(' Mein Pulver '),
        name: 'Mein Pulver',
        addedAt: _at(5),
      );
      expect(own.key, 'own:mein pulver');
      final added = data.withSupplement(own);
      expect(added.mine.last.name, 'Mein Pulver');
      expect(added.without(own.key, _at(6)).byKey(own.key), isNull);
    });

    test('taking back removes exactly that time', () {
      final taken = data.takenOn('coffee', _at(12))!;
      final without = data.withoutIntake(taken);
      expect(without.caffeineOn(_at(12)), 80);
      expect(without.withIntake(taken).caffeineOn(_at(12)), 160);
      // Noted twice, it is still there once.
      expect(data.withIntake(taken).intakes.length, data.intakes.length);
    });

    test('survives being saved, and skips what it cannot read', () {
      final moved = data.withMinute(SupplementTime.evening, 22 * 60 + 15);
      final read = SupplementData.fromJson(moved.toJson());
      expect(read.supplements.length, 3);
      expect(read.intakes, unorderedEquals(moved.intakes));
      expect(read.byKey('magnesium')!.remind, isTrue);
      expect(read.byKey('magnesium')!.time, SupplementTime.evening);
      expect(read.byKey('coffee')!.caffeineMg, 80);
      expect(read.minuteOf(SupplementTime.evening), 22 * 60 + 15);
      expect(read.minuteOf(SupplementTime.morning), 8 * 60);

      final damaged = SupplementData.fromJson({
        'version': SupplementData.schemaVersion,
        'minutes': {'evening': 5000, 'noon': 'late'},
        'supplements': [
          _creatine.toJson(),
          _creatine.toJson(),
          {'key': 'gone', 'preset': 'gone', 'addedAt': '2026-10-01'},
          {'key': 'own:x', 'addedAt': 'never', 'name': 'X'},
          'nonsense',
        ],
        'intakes': [
          {'key': 'creatine', 'at': 5},
          {'key': '', 'at': 5},
          {'key': 'creatine'},
          {'key': 'creatine', 'at': 1, 'amount': -2, 'unit': 'bucket'},
        ],
      });
      expect([for (final s in damaged.supplements) s.key], ['creatine']);
      expect(damaged.intakes.length, 2);
      expect(damaged.intakes.first.amount, isNull);
      expect(damaged.intakes.first.unit, isNull);
      expect(damaged.minuteOf(SupplementTime.evening), 21 * 60);

      expect(SupplementData.fromJson(null).supplements, isEmpty);
      expect(SupplementData.fromJson({'version': 99}).supplements, isEmpty);
    });
  });

  group('SupplementController', () {
    test('keeps what is added and taken in the store', () async {
      final store = MemoryJsonStore();
      var now = _at(12, 9);
      final controller = SupplementController(store, clock: () => now);
      await controller.load();
      expect(controller.data.mine, isEmpty);

      final creatine = (await controller.addPreset('creatine'))!;
      expect(await controller.addPreset('nothing'), isNull);
      final intake = await controller.take(creatine);
      expect(intake.at, now);
      expect(intake.amount, 1);
      expect(intake.unit, SupplementUnit.scoop);

      // Once in another dose and at another time, without a dose at all.
      now = _at(12, 18);
      await controller.take(
        creatine,
        at: _at(11, 20),
        amount: () => null,
        unit: () => null,
      );
      await controller.setMinute(SupplementTime.morning, 7 * 60);

      final again = SupplementController(store, clock: () => now);
      await again.load();
      expect(again.data.mine.single.key, 'creatine');
      expect(again.data.intakes.length, 2);
      expect(again.data.takenOn('creatine', _at(11))!.amount, isNull);
      expect(again.data.streak('creatine', now), 2);
      expect(again.data.minuteOf(SupplementTime.morning), 7 * 60);

      await again.untake(intake);
      expect(again.data.takenOn('creatine', _at(12)), isNull);
      await again.restore(intake);
      expect(again.data.takenOn('creatine', _at(12)), intake);

      await again.remove('creatine');
      expect(again.data.mine, isEmpty);
      // Added again, it is the same one with its past.
      await again.addPreset('creatine');
      expect(again.data.mine.single.removed, isFalse);
      expect(again.data.intakesOf('creatine').length, 2);
    });
  });

  group('the reminder', () {
    final data = SupplementData(
      supplements: [
        _creatine,
        _magnesium,
        presetOf('vitaminD')!
            .added(_at(1))
            .copyWith(time: SupplementTime.morning, remind: true),
        // A time of day without a reminder is left out.
        presetOf('zinc')!.added(_at(1)).copyWith(time: SupplementTime.noon),
      ],
    ).withMinute(SupplementTime.evening, 22 * 60);

    test('names what is due at each time of day, in the app\'s words', () {
      expect(supplementAlarmFor(data, language: 'de'), {
        'title': 'Supplements',
        'body': 'Noch offen: %s',
        'slots': [
          {
            'minute': 8 * 60,
            'items': [
              {'key': 'vitaminD', 'name': 'Vitamin D'},
            ],
          },
          {
            'minute': 22 * 60,
            'items': [
              {'key': 'magnesium', 'name': 'Magnesium'},
            ],
          },
        ],
      });
      final polish = supplementAlarmFor(data, language: 'pl')!;
      expect(polish['body'], 'Jeszcze otwarte: %s');
      // A language the app does not speak gets English.
      expect(
        supplementAlarmFor(data, language: 'fr')!['body'],
        'Still open: %s',
      );
    });

    test('is left for the platform, and only told when it changed', () async {
      final store = MemoryJsonStore();
      expect(await leaveSupplementAlarm(store, data, language: 'de'), isTrue);
      expect(await store.read(StoreKeys.supplementAlarm), isNotNull);
      expect(await leaveSupplementAlarm(store, data, language: 'de'), isFalse);
      expect(
        await leaveSupplementAlarm(
          store,
          data.withMinute(SupplementTime.morning, 7 * 60),
          language: 'de',
        ),
        isTrue,
      );
      // Nothing to remind of: the alarm goes.
      const none = SupplementData();
      expect(await leaveSupplementAlarm(store, none, language: 'de'), isTrue);
      expect(await store.read(StoreKeys.supplementAlarm), isNull);
      expect(await leaveSupplementAlarm(store, none, language: 'de'), isFalse);
    });
  });

  group('the backup', () {
    test('holds the supplements, and adds only what is missing', () async {
      final from = MemoryJsonStore();
      await from.write(
        StoreKeys.supplements,
        SupplementData(
          supplements: [_creatine, _coffee],
          intakes: [_took(_creatine, _at(10)), _took(_coffee, _at(10, 9))],
        ).toJson(),
      );
      final text = await exportBackup(from, _at(12));
      expect(text, contains('creatine'));

      final into = MemoryJsonStore();
      final kept = _creatine.copyWith(amount: () => 3);
      await into.write(
        StoreKeys.supplements,
        SupplementData(
          supplements: [kept],
          intakes: [_took(kept, _at(10)), _took(kept, _at(11))],
        ).toJson(),
      );
      await importBackup(into, text, _at(12));
      final merged = SupplementData.fromJson(
        await into.read(StoreKeys.supplements),
      );
      expect(
        [for (final s in merged.supplements) s.key],
        ['creatine', 'coffee'],
      );
      // What the app had stays as it was.
      expect(merged.byKey('creatine')!.amount, 3);
      expect(merged.intakes.length, 3);
      expect(merged.takenOn('creatine', _at(10))!.amount, 3);
    });
  });
}
