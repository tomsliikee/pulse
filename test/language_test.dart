import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/health_repository.dart';
import 'package:pulse/data/period.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/age/body_age_page.dart';
import 'package:pulse/features/detail/metric_detail_page.dart';
import 'package:pulse/features/sleep/sleep_detail_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/floating_tab_bar.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];
const _languages = ['en', 'pl'];
const _channel = MethodChannel('at.haiden.pulse/language');

AppLocalizations _l10n(String language) =>
    lookupAppLocalizations(Locale(language));

MemoryJsonStore _storeWithBirthDate() =>
    MemoryJsonStore()
      ..documents['settings'] = '{"birthDate":"1992-03-07","sex":"male"}';

/// Lays out the whole page, so an overflow anywhere on it fails the test.
Future<void> _scrollThrough(WidgetTester tester, Type scrollable) async {
  await tester.drag(find.byType(scrollable).first, const Offset(0, -6000));
  await advance(tester);
}

Future<void> _openLanguageSheet(WidgetTester tester, String language) async {
  final l10n = _l10n(language);
  await tester.tap(find.bySemanticsLabel(l10n.profile));
  await advance(tester);
  // The list builds its lower rows only once they come near.
  await tester.scrollUntilVisible(
    find.text(l10n.language),
    200,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await advance(tester);
  await tester.tap(find.text(l10n.language));
  await advance(tester);
}

/// Answers like Android 13 and newer: the system keeps the app's language and
/// hands it to the app as its locale.
List<String?> _systemKeepsLanguage(WidgetTester tester, {String? chosen}) {
  final set = <String?>[];
  var current = chosen;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    if (call.method == 'get') return {'language': current};
    current = call.arguments as String?;
    set.add(current);
    tester.platformDispatcher.localesTestValue = [Locale(current ?? 'de')];
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    ),
  );
  return set;
}

void main() {
  setUpAll(loadAppFont);

  group('translations', () {
    Map<String, Object?> arb(String language) =>
        jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
            as Map<String, Object?>;
    Set<String> messages(Map<String, Object?> arb) => {
      for (final key in arb.keys)
        if (!key.startsWith('@')) key,
    };

    test('every language has the same messages', () {
      final german = messages(arb('de'));
      for (final language in _languages) {
        expect(messages(arb(language)), german, reason: language);
      }
    });

    test('every message uses its placeholders in every language', () {
      final german = arb('de');
      for (final language in ['de', ..._languages]) {
        final texts = arb(language);
        for (final key in messages(german)) {
          final meta = german['@$key'];
          if (meta is! Map<String, Object?>) continue;
          final placeholders = meta['placeholders'] as Map<String, Object?>;
          for (final name in placeholders.keys) {
            expect(
              texts[key] as String,
              contains('{$name'),
              reason: '$key in $language',
            );
          }
        }
      }
    });
  });

  group('formats', () {
    final day = DateTime(2026, 10, 7);
    final from = DateTime(2026, 9, 29);
    final to = DateTime(2026, 10, 5);

    test('German', () {
      final formats = formatsOf('de');
      expect(formats.integer(7432), '7.432');
      expect(formats.decimal(1.5), '1,5');
      expect(formats.longDate(day), 'Mittwoch, 7. Oktober');
      expect(formats.shortDate(day), 'Mi, 7.10.');
      expect(formats.month(day), 'Oktober 2026');
      expect(formats.dayRange(from, to), '29.9. bis 5.10.');
      expect(formats.duration(444), '7 h 24 min');
      expect(formats.relativeDay(day, day), 'heute');
      expect(formats.relativeDay(to, day), 'Mo, 5.10.');
      expect(formats.birthDate(DateTime(1992, 3, 7)), '7.3.1992');
      expect(formats.weekdayShort, ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']);
    });

    test('English writes the day before the month', () {
      final formats = formatsOf('en');
      expect(formats.integer(7432), '7,432');
      expect(formats.decimal(1.5), '1.5');
      expect(formats.longDate(day), 'Wednesday, 7 October');
      expect(formats.shortDate(day), 'Wed, 7 Oct');
      expect(formats.month(day), 'October 2026');
      expect(formats.dayRange(from, to), '29 Sep to 5 Oct');
      expect(formats.duration(40), '40 min');
      expect(formats.relativeDay(from, day), 'Tue, 29 Sep');
      expect(formats.relativeDay(DateTime(2026, 10, 6), day), 'yesterday');
      expect(formats.birthDate(DateTime(1992, 3, 7)), '7/3/1992');
    });

    test('Polish', () {
      final formats = formatsOf('pl');
      // A no-break space separates the thousands.
      expect(formats.integer(7432), '7 432');
      expect(formats.decimal(1.5), '1,5');
      expect(formats.longDate(day), 'środa, 7 października');
      expect(formats.shortDate(day), 'śr., 7.10');
      expect(formats.month(day), 'październik 2026');
      expect(formats.dayRange(from, to), '29.09 – 5.10');
      expect(formats.duration(444), '7 h 24 min');
      expect(formats.relativeDay(day, day), 'dziś');
      expect(formats.monthInitials, hasLength(12));
    });
  });

  group('plurals', () {
    test('Polish has a form for one, for a few and for many', () {
      final l10n = _l10n('pl');
      expect(l10n.unitSteps(1), 'krok');
      expect(l10n.unitSteps(2), 'kroki');
      expect(l10n.unitSteps(5), 'kroków');
      expect(l10n.unitSteps(22), 'kroki');
      expect(l10n.unitSteps(0), 'kroków');
      expect(l10n.unitFloors(1), 'piętro');
      expect(l10n.unitFloors(3), 'piętra');
      expect(l10n.unitFloors(12), 'pięter');
      expect(l10n.nightsCount(1), '1 noc');
      expect(l10n.nightsCount(4), '4 noce');
      expect(l10n.nightsCount(30), '30 nocy');
      expect(l10n.readingSteps('7 432', 1), 'Śr. 7 432 dziennie, z 1 dnia');
      expect(l10n.readingSteps('7 432', 21), 'Śr. 7 432 dziennie, z 21 dni');
    });

    test('a number with a decimal takes the Polish "roku"', () {
      final formats = formatsOf('pl');
      expect(formatYears(formats, 0.6), '+0,6 roku');
      expect(formatYears(formats, -1), '−1,0 roku');
      expect(formatYears(formats, 0), '±0 lat');
    });

    test('German and English tell one from several', () {
      expect(_l10n('de').unitSteps(1), 'Schritt');
      expect(_l10n('de').unitSteps(7432), 'Schritte');
      expect(_l10n('en').unitSteps(1), 'step');
      expect(_l10n('en').nightsCount(30), '30 nights');
      expect(formatYears(formatsOf('de'), 0.6), '+0,6 Jahre');
    });

    test('a comparison is one sentence for each span', () {
      expect(
        _l10n('de').comparisonMore('412 Schritte', PeriodKind.week.span),
        '412 Schritte mehr als in der Woche davor',
      );
      expect(
        _l10n('en').comparisonLess('412 steps', PeriodKind.month.span),
        '412 steps less than the month before',
      );
      expect(
        _l10n('pl').comparisonSame(PeriodKind.today.span),
        'Tyle samo co dzień wcześniej',
      );
    });
  });

  for (final language in _languages) {
    final l10n = _l10n(language);
    final locale = Locale(language);

    for (final size in _sizes) {
      final label = '$language at ${size.width.round()}x${size.height.round()}';

      testWidgets('the four pages render in $label', (tester) async {
        await pumpApp(tester, size: size, locale: locale);
        expect(find.text(l10n.navToday), findsWidgets);
        expect(stepsTile(formatsOf(language).integer(7432)), findsOneWidget);
        await _scrollThrough(tester, ListView);
        expect(find.text(l10n.groupNutrition), findsOneWidget);
        for (final (destination, marker) in [
          (l10n.groupActivity, l10n.activitySubtitle),
          (l10n.groupSleep, l10n.sleepStages),
          (l10n.navHeart, l10n.dayCurve),
        ]) {
          await tester.tap(find.bySemanticsLabel(destination));
          await advance(tester);
          expect(find.text(marker), findsWidgets, reason: destination);
          await _scrollThrough(tester, ListView);
        }
      });

      testWidgets('the edit mode and all data on Today render in $label', (
        tester,
      ) async {
        final store = MemoryJsonStore();
        await store.write('settings', {'showAllData': true});
        await pumpApp(tester, size: size, store: store, locale: locale);
        await tester.tap(find.byTooltip(l10n.arrangeTiles));
        await advance(tester);
        expect(find.text(l10n.showAllData), findsOneWidget);
        await tester.tap(find.byTooltip(l10n.done));
        await advance(tester);
        await _scrollThrough(tester, ListView);
        expect(find.text(l10n.last30FromHealthConnect), findsOneWidget);
        expect(find.text(l10n.groupVitals), findsWidgets);
      });

      testWidgets('every page renders without any data in $label', (
        tester,
      ) async {
        await pumpApp(
          tester,
          size: size,
          locale: locale,
          repository: FixtureRepository(readings: const RawReadings()),
        );
        await _scrollThrough(tester, ListView);
        for (final destination in [
          l10n.groupActivity,
          l10n.groupSleep,
          l10n.navHeart,
        ]) {
          await tester.tap(find.bySemanticsLabel(destination));
          await advance(tester);
          await _scrollThrough(tester, ListView);
        }
      });

      testWidgets('the profile and its language sheet render in $label', (
        tester,
      ) async {
        await pumpApp(tester, size: size, locale: locale);
        await tester.tap(find.bySemanticsLabel(l10n.profile));
        await advance(tester);
        expect(find.text(l10n.goals), findsOneWidget);
        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, -6000),
        );
        await advance(tester);
        expect(find.text(l10n.lastUpdated), findsOneWidget);
        await tester.tap(find.text(l10n.language));
        await advance(tester);
        for (final name in const ['Deutsch', 'English', 'Polski']) {
          expect(find.text(name), findsOneWidget);
        }
        // The system's language is followed; its name stands in the row
        // beneath the sheet and in the sheet.
        expect(find.text(l10n.languageSystem), findsNWidgets(2));
      });

      testWidgets('every tab of a measurement renders in $label', (
        tester,
      ) async {
        await pumpApp(
          tester,
          size: size,
          locale: locale,
          repository: FixtureRepository()
            ..historyAccess = true
            ..olderDays = fixtureOlderDays(),
        );
        await tapInView(tester, stepsTile(formatsOf(language).integer(7432)));
        expect(find.byType(MetricDetailPage), findsOneWidget);
        for (final kind in PeriodKind.values) {
          await tester.tap(
            find.descendant(
              of: find.byType(FloatingTabBar),
              matching: find.text(kind.tab(l10n)),
            ),
          );
          await advance(tester);
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -2000),
          );
          await advance(tester);
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, 2000),
          );
          await advance(tester);
        }
        expect(find.text(l10n.headlineAll), findsOneWidget);
      });

      testWidgets('the detailed sleep page renders in $label', (tester) async {
        await pumpApp(tester, size: size, locale: locale);
        await tester.tap(find.bySemanticsLabel(l10n.groupSleep));
        await advance(tester);
        await tester.tap(find.text(l10n.lastNight));
        await advance(tester);
        final page = find.byType(SleepDetailPage);
        for (final title in [
          l10n.scoreTitle,
          l10n.compareTitle,
          l10n.sleepTipsTitle,
          l10n.nightsBeforeTitle,
          l10n.sleepStages,
          l10n.stagesCompared,
          l10n.regularity,
          l10n.sleepDebt,
          l10n.nightPulse,
          l10n.nightValues,
        ]) {
          expect(
            find.descendant(of: page, matching: find.text(title)),
            findsWidgets,
            reason: title,
          );
        }
        await _scrollThrough(tester, CustomScrollView);
      });

      testWidgets('the body age page renders in $label', (tester) async {
        await pumpApp(
          tester,
          size: size,
          locale: locale,
          store: _storeWithBirthDate(),
        );
        await tester.tap(
          find.bySemanticsLabel(RegExp(l10n.bodyAge, caseSensitive: false)),
        );
        await advance(tester);
        final page = find.byType(BodyAgePage);
        expect(
          find.descendant(of: page, matching: find.text(l10n.estimateLast30)),
          findsOne,
        );
        await _scrollThrough(tester, CustomScrollView);
        expect(
          find.descendant(of: page, matching: find.text(l10n.howCalculated)),
          findsOne,
        );
      });

      testWidgets('the entry sheets render in $label', (tester) async {
        await pumpApp(tester, size: size, locale: locale);
        for (final (entry, title) in [
          (l10n.metricWater, l10n.addWater),
          (l10n.metricWeight, l10n.addWeight),
          (l10n.entryMeal, l10n.addMeal),
        ]) {
          await tester.tap(find.byIcon(Icons.add_rounded));
          await advance(tester);
          // The menu floats above the page, which may show the same word.
          await tester.tap(find.text(entry).hitTestable().last);
          await advance(tester);
          expect(find.text(title), findsOneWidget);
          // An empty amount is refused, which shows the longest message.
          await tester.tap(find.text(l10n.save).hitTestable());
          await advance(tester);
          Navigator.of(tester.element(find.text(title))).pop();
          await advance(tester);
          expect(find.text(title), findsNothing);
        }
      });

      for (final (access, title) in [
        (HealthAccess.denied, l10n.accessTitle),
        (HealthAccess.unavailable, l10n.missingTitle),
        (HealthAccess.unsupported, l10n.androidOnlyTitle),
      ]) {
        testWidgets('the app without data access ($access) renders in $label', (
          tester,
        ) async {
          await pumpApp(
            tester,
            size: size,
            locale: locale,
            repository: FixtureRepository(currentAccess: access),
          );
          expect(find.text(title), findsOneWidget);
        });
      }
    }
  }

  group('choosing the language', () {
    testWidgets('a system language the app does not speak gives English', (
      tester,
    ) async {
      await pumpApp(tester, locale: const Locale('fr'));
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Heute'), findsNothing);
    });

    testWidgets('a region of a known language is that language', (
      tester,
    ) async {
      await pumpApp(tester, locale: const Locale('pl', 'PL'));
      expect(find.text('Dziś'), findsWidgets);
    });

    testWidgets('where the system keeps none, the choice is a setting', (
      tester,
    ) async {
      final app = await pumpApp(tester);
      await _openLanguageSheet(tester, 'de');
      await tester.tap(find.text('Polski'));
      await advance(tester);

      // The sheet and the page beneath it change at once.
      expect(find.text('Język'), findsNWidgets(2));
      expect(find.text('Sprache'), findsNothing);
      final saved =
          jsonDecode(app.store.documents['settings']!) as Map<String, Object?>;
      expect(saved['language'], 'pl');

      await tester.tap(find.text('Język systemu'));
      await advance(tester);
      expect(find.text('Sprache'), findsNWidgets(2));
      final cleared =
          jsonDecode(app.store.documents['settings']!) as Map<String, Object?>;
      expect(cleared.containsKey('language'), isFalse);
    });

    testWidgets('a saved choice is used at the next start', (tester) async {
      final store = MemoryJsonStore()
        ..documents['settings'] = '{"language":"en"}';
      await pumpApp(tester, store: store);
      expect(find.text('Today'), findsWidgets);
    });

    testWidgets('a language the app does not have is not taken from the file', (
      tester,
    ) async {
      final store = MemoryJsonStore()
        ..documents['settings'] = '{"language":"xx"}';
      await pumpApp(tester, store: store);
      expect(find.text('Heute'), findsWidgets);
    });

    testWidgets(
      'where the system keeps it, the sheet reads and sets it there',
      (tester) async {
        final set = _systemKeepsLanguage(tester, chosen: 'pl');
        // Not used there, even if an older version had saved one.
        final store = MemoryJsonStore()
          ..documents['settings'] = '{"language":"en"}';
        final app = await pumpApp(
          tester,
          store: store,
          locale: const Locale('pl'),
        );
        expect(find.text('Dziś'), findsWidgets);

        await _openLanguageSheet(tester, 'pl');
        // The row beneath the sheet and the sheet name the system's choice.
        expect(find.text('Polski'), findsNWidgets(2));
        await tester.tap(find.text('Deutsch'));
        await advance(tester);

        expect(set, ['de']);
        expect(find.text('Sprache'), findsNWidgets(2));
        expect(find.text('Deutsch'), findsNWidgets(2));
        final saved = jsonDecode(
          app.store.documents['settings']!,
        ) as Map<String, Object?>;
        expect(saved['language'], 'en', reason: 'the setting is left alone');

        await tester.tap(find.text('Systemsprache'));
        await advance(tester);
        expect(set, ['de', null]);
      },
    );

    testWidgets(
      'a change in the system\'s settings shows when the app returns',
      (tester) async {
        var chosen = 'de';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          (call) async => call.method == 'get' ? {'language': chosen} : null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _channel,
            null,
          ),
        );
        await pumpApp(tester);
        await tester.tap(find.bySemanticsLabel('Profil'));
        await advance(tester);
        await tester.scrollUntilVisible(
          find.text('Sprache'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Deutsch'), findsOneWidget);

        chosen = 'en';
        tester.platformDispatcher.localesTestValue = [const Locale('en')];
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await advance(tester);
        expect(find.text('Language'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
      },
    );
  });
}
