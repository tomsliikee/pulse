import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/app_scope.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/data/supplements.dart';
import 'package:pulse/features/supplements/caffeine_tile.dart';
import 'package:pulse/features/supplements/supplement_card.dart';
import 'package:pulse/features/supplements/supplement_detail_page.dart';
import 'package:pulse/features/supplements/supplement_format.dart';
import 'package:pulse/features/supplements/supplements_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];
const _languages = ['de', 'en', 'pl'];

DateTime _at(int back, int hour, [int minute = 0]) => DateTime(
  fixtureNow.year,
  fixtureNow.month,
  fixtureNow.day - back,
  hour,
  minute,
);

/// Five supplements, two of them with a reminder, three taken today, and
/// coffee twice.
Future<MemoryJsonStore> _store({
  bool simple = false,
  bool withTiles = true,
  bool expressive = false,
}) async {
  final added = _at(40, 8);
  final creatine = presetOf('creatine')!.added(added);
  final magnesium = presetOf('magnesium')!
      .added(added)
      .copyWith(time: SupplementTime.evening, remind: true);
  final psyllium = presetOf('psyllium')!
      .added(added)
      .copyWith(amount: () => 2.5, time: SupplementTime.morning, remind: true);
  final own = Supplement(
    key: ownSupplementKey('Mein sehr langer Name eines Pulvers'),
    name: 'Mein sehr langer Name eines Pulvers',
    addedAt: added,
  );
  final coffee = presetOf('coffee')!.added(added);
  Intake took(Supplement s, DateTime when) => Intake(
    key: s.key,
    at: when,
    amount: s.amount,
    unit: s.unit,
    caffeineMg: s.caffeineMg,
  );
  final store = MemoryJsonStore();
  await store.write(StoreKeys.settings, {
    'simple': simple,
    'expressive': expressive,
    if (withTiles) 'todayTiles': [dayTileId, supplementsTileId, caffeineTileId],
    if (withTiles) 'todayTilesVersion': 5,
  });
  await store.write(
    StoreKeys.supplements,
    SupplementData(
      supplements: [creatine, psyllium, magnesium, own, coffee],
      intakes: [
        for (var back = 12; back >= 0; back--) took(creatine, _at(back, 8, 5)),
        took(psyllium, _at(0, 8, 6)),
        for (var back = 12; back >= 1; back--)
          took(magnesium, _at(back, 21, 30)),
        took(coffee, _at(1, 9)),
        took(coffee, _at(0, 7, 40)),
        took(coffee, _at(0, 13, 15)),
      ]..sort((a, b) => a.at.compareTo(b.at)),
    ).toJson(),
  );
  return store;
}

void main() {
  setUpAll(loadAppFont);

  for (final size in _sizes) {
    testWidgets('in the rework the tile has a capsule for each supplement at '
        '${size.width.round()}', (tester) async {
      await pumpApp(
        tester,
        size: size,
        store: await _store(expressive: true, simple: true),
      );
      final card = find.byType(SupplementsCard);
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await advance(tester);
      final capsules = find.descendant(
        of: card,
        matching: find.byType(AnimatedContainer),
      );
      expect(capsules, findsNWidgets(5));
      final filled = [
        for (final element in capsules.evaluate())
          ((element.widget as AnimatedContainer).decoration! as ShapeDecoration)
                  .color !=
              Colors.transparent,
      ];
      expect(filled.where((on) => on).length, 3);
      expect(
        find.descendant(of: card, matching: find.text('3 von 5')),
        findsOneWidget,
      );
    });
  }

  for (final size in _sizes) {
    for (final language in _languages) {
      final label = '$language at ${size.width.round()}x${size.height.round()}';

      testWidgets('the card, the caffeine and their pages render in $label', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          store: await _store(),
        );
        await bringIntoView(tester, find.byType(SupplementsCard));
        expect(find.text(l10n.supplementsTakenOf('3', '5')), findsOneWidget);
        expect(find.text(l10n.supplementTakenAt('08:05')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await bringIntoView(tester, find.byType(CaffeineTile));
        expect(find.text('160 ${l10n.unitMilligram}'), findsOneWidget);
        expect(find.text(l10n.caffeineLast('13:15')), findsOneWidget);
        await tester.tap(find.byType(CaffeineTile));
        await advance(tester);
        expect(find.byType(CaffeinePage), findsOneWidget);
        expect(find.text(l10n.supplementCoffeeName), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await advance(tester);

        // The page of one supplement, and the sheet that changes it.
        await bringIntoView(tester, find.byType(SupplementsCard));
        await tapInView(tester, find.text(l10n.supplementCreatineName));
        expect(find.byType(SupplementDetailPage), findsOneWidget);
        expect(find.text(l10n.supplementStreakDays(13)), findsOneWidget);
        expect(find.text(l10n.supplementRateDays('13', '30')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.tune_rounded));
        await advance(tester);
        expect(find.text(l10n.supplementRemind), findsOneWidget);
        expect(find.text(l10n.supplementTimeEvening), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the list in the profile renders in $label', (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          store: await _store(),
        );
        await tester.tap(find.bySemanticsLabel(l10n.profile));
        await advance(tester);
        await bringIntoView(tester, find.text(l10n.supplementsChoose));
        await tapInView(tester, find.text(l10n.supplementsChoose));
        expect(find.byType(SupplementsPage), findsOneWidget);
        expect(find.text(l10n.supplementsMine), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, -6000),
        );
        await advance(tester);
        expect(find.text(l10n.supplementsNote), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the sheet at the plus renders in $label', (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          store: await _store(),
        );
        await tester.tap(find.byIcon(Icons.add_rounded).last);
        await advance(tester);
        await tester.tap(find.text(l10n.supplement).last);
        await advance(tester);
        expect(find.text(l10n.supplementAdd), findsOneWidget);
        expect(find.text(l10n.supplementsOften), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.schedule_rounded).first);
        await advance(tester);
        expect(find.text(l10n.save), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a tap on the circle notes a supplement as taken, and a second '
      'takes that back with a way to undo', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    final (repository: _, :store) = await pumpApp(
      tester,
      store: await _store(),
    );
    final scope = AppScope.of(tester.element(find.byType(SupplementsCard)));
    await bringIntoView(tester, find.byType(SupplementsCard));
    expect(find.text(l10n.supplementsTakenOf('3', '5')), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.supplementTakenNow).first);
    await advance(tester);
    expect(find.text(l10n.supplementsTakenOf('4', '5')), findsOneWidget);
    final taken = scope.supplements.data.takenOn('magnesium', fixtureNow)!;
    expect(taken.at, fixtureNow);
    expect(taken.amount, 1);
    expect(
      SupplementData.fromJson(await store.read(StoreKeys.supplements))
          .takenOn('magnesium', fixtureNow),
      isNotNull,
    );

    await tester.tap(find.byTooltip(l10n.supplementUntook('Magnesium')));
    await advance(tester);
    expect(find.text(l10n.supplementsTakenOf('3', '5')), findsOneWidget);
    expect(scope.supplements.data.takenOn('magnesium', fixtureNow), isNull);
    await tester.tap(find.text(l10n.undo));
    await advance(tester);
    expect(scope.supplements.data.takenOn('magnesium', fixtureNow), taken);
    expect(tester.takeException(), isNull);
  });

  testWidgets('simple mode shows the count only', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(tester, store: await _store(simple: true));
    await bringIntoView(tester, find.byType(SupplementsCard));
    expect(find.text(l10n.supplementsTakenOf('3', '5')), findsOneWidget);
    expect(find.byTooltip(l10n.supplementTakenNow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without supplements the card leads to the list, a preset is '
      'added with a tap, and one of the user\'s own with a form', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(tester);
    await bringIntoView(tester, find.byType(SupplementsCard));
    final scope = AppScope.of(tester.element(find.byType(SupplementsCard)));
    // No caffeine was ever logged, so there is no tile for it to add.
    expect(find.byType(CaffeineTile), findsNothing);
    await tapInView(tester, find.text(l10n.supplementsChoose));
    expect(find.byType(SupplementsPage), findsOneWidget);
    expect(find.text(l10n.supplementsMine), findsNothing);

    await tester.tap(find.text(l10n.supplementCreatineName));
    await advance(tester);
    expect(scope.supplements.data.mine.single.key, 'creatine');
    expect(find.text(l10n.supplementsMine), findsOneWidget);

    await tester.tap(find.text(l10n.supplementOwn));
    await advance(tester);
    // Without a name nothing is saved.
    await tester.tap(find.text(l10n.save));
    await advance(tester);
    expect(find.text(l10n.supplementNameMissing), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'Ingwer');
    await tester.enterText(find.byType(TextField).at(2), '2');
    await tester.tap(find.text(l10n.unitPiece(2)));
    await tester.tap(find.text(l10n.save));
    await advance(tester);
    final own = scope.supplements.data.byKey(ownSupplementKey('Ingwer'))!;
    expect(own.title(l10n), 'Ingwer');
    expect(own.amount, 2);
    expect(own.unit, SupplementUnit.piece);
    expect(find.text('2 ${l10n.unitPiece(2)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet at the plus notes a tapped supplement as taken now', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(tester, store: await _store());
    final scope = AppScope.of(tester.element(find.byType(SupplementsCard)));
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await advance(tester);
    await tester.tap(find.text(l10n.supplement).last);
    await advance(tester);
    await tester.tap(find.text('Magnesium').last);
    await advance(tester);
    expect(
      scope.supplements.data.takenOn('magnesium', fixtureNow)?.at,
      fixtureNow,
    );
    expect(find.text(l10n.supplementTook('Magnesium')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
