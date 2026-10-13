import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/app_scope.dart';
import 'package:pulse/data/health_repository.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/features/access/access_page.dart';
import 'package:pulse/features/intro/intro_cards.dart';
import 'package:pulse/features/intro/intro_page.dart';
import 'package:pulse/features/morning/morning_sunrise.dart';
import 'package:pulse/features/profile/profile_page.dart';
import 'package:pulse/features/today/today_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

/// A store of an installation that is in the middle of its first start.
Future<MemoryJsonStore> _storeWith(Map<String, Object?> settings) async {
  final store = MemoryJsonStore();
  await store.write(StoreKeys.settings, {'introDone': false, ...settings});
  return store;
}

/// Answers the channel the notifications are asked over: [granted] says
/// what the system says when asked, [asked] counts how often it was.
void _notices(
  WidgetTester tester, {
  bool allowed = false,
  bool grants = true,
  List<String>? calls,
}) {
  var now = allowed;
  const channel = MethodChannel('at.haiden.pulse/morning');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method.startsWith('allow')) calls?.add(call.method);
    switch (call.method) {
      case 'allowed':
        return now;
      case 'allow':
        return now = now || grants;
      default:
        return null;
    }
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

Future<void> _next(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.text(l10n.morningNext));
  await advance(tester);
}

/// Scrolls the card on screen to its end, so that everything on it is laid
/// out at this size.
Future<void> _toTheEnd(WidgetTester tester, Type card) async {
  final scroll = find.descendant(
    of: find.byType(card),
    matching: find.byType(Scrollable),
  );
  await tester.drag(scroll.first, const Offset(0, -1200));
  await advance(tester);
}

/// The switch of the row that is named [title].
Finder _switchOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
  matching: find.byType(Switch),
);

AppScope _scope(WidgetTester tester) =>
    AppScope.of(tester.element(find.byType(IntroPage)));

const _cards = [
  WelcomeCard,
  PrivacyCard,
  AccessCard,
  OptionalCard,
  AboutCard,
  IntroGoalsCard,
  ModeCard,
];

void main() {
  setUpAll(loadAppFont);

  group('the setting', () {
    test('a new installation has not been through it', () async {
      final settings = SettingsController(MemoryJsonStore());
      await settings.load();
      expect(settings.introDone, isFalse);
    });

    test('an installation from before it is not led through it', () async {
      final store = MemoryJsonStore();
      await store.write(StoreKeys.settings, {'stepGoal': 9000});
      final settings = SettingsController(store);
      await settings.load();
      expect(settings.introDone, isTrue);
    });

    test('is kept, also while the introduction is not over', () async {
      final store = MemoryJsonStore();
      final settings = SettingsController(store);
      await settings.load();
      settings.setName('Mira');
      await Future<void>.delayed(Duration.zero);
      final again = SettingsController(store);
      await again.load();
      expect(again.introDone, isFalse);

      again.setIntroDone(true);
      await Future<void>.delayed(Duration.zero);
      final third = SettingsController(store);
      await third.load();
      expect(third.introDone, isTrue);
    });
  });

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      for (final look in ['light', 'dark']) {
        testWidgets('every card in $language at '
            '${size.width.round()}x${size.height.round()}, $look', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(Locale(language));
          _notices(tester);
          await pumpApp(
            tester,
            size: size,
            locale: Locale(language),
            repository: FixtureRepository(currentAccess: HealthAccess.denied),
            store: await _storeWith({'themeMode': look, 'simple': true}),
          );
          expect(find.byType(IntroPage), findsOneWidget);
          expect(find.text(l10n.introWelcomeTitle), findsOneWidget);
          for (final (index, card) in _cards.indexed) {
            expect(find.byType(card), findsOneWidget);
            await _toTheEnd(tester, card);
            if (card == AccessCard) {
              // Allowed here, so the next card's switches are open.
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, 1200),
              );
              await advance(tester);
              await tester.tap(find.text(l10n.accessAction));
              await advance(tester);
              expect(find.text(l10n.introAccessGranted), findsOneWidget);
              await _toTheEnd(tester, card);
            }
            if (index < _cards.length - 1) await _next(tester, l10n);
          }
          expect(find.text(l10n.introFinish), findsOneWidget);
        });
      }
    }
  }

  testWidgets('a new installation begins with it, one from before does not', (
    tester,
  ) async {
    _notices(tester);
    await pumpApp(tester, fresh: true);
    expect(find.byType(IntroPage), findsOneWidget);
    expect(find.byType(TodayPage), findsNothing);
  });

  testWidgets('an installation from before it opens on its pages', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(IntroPage), findsNothing);
    expect(find.byType(TodayPage), findsOneWidget);
  });

  testWidgets('skipping ends it on every card and it does not come back', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    for (var card = 0; card < _cards.length; card++) {
      _notices(tester);
      final (:repository, :store) = await pumpApp(tester, fresh: true);
      for (var i = 0; i < card; i++) {
        await _next(tester, l10n);
      }
      expect(find.byType(_cards[card]), findsOneWidget);
      await tester.tap(find.text(l10n.introSkip));
      await advance(tester);
      expect(find.byType(IntroPage), findsNothing);
      expect(find.byType(MorningSunrise), findsNothing);
      expect(find.byType(TodayPage), findsOneWidget);
      expect(store.documents[StoreKeys.settings], contains('"introDone":true'));
      // The question for older data is not put later without a word.
      expect(repository.historyPermissionRequests, 0);
      expect(store.documents[StoreKeys.backfill], contains('"asked":true'));
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('skipped without access, it gives way to the access page', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    _notices(tester);
    await pumpApp(
      tester,
      fresh: true,
      repository: FixtureRepository(currentAccess: HealthAccess.denied),
    );
    await tester.tap(find.text(l10n.introSkip));
    await advance(tester);
    expect(find.byType(AccessPage), findsOneWidget);
    expect(find.text(l10n.accessTitle), findsOneWidget);
  });

  testWidgets('the whole way: access, switches, who, goals, mode, sunrise', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    final calls = <String>[];
    _notices(tester, calls: calls);
    final gate = Completer<void>();
    final (:repository, :store) = await pumpApp(
      tester,
      fresh: true,
      repository: FixtureRepository(currentAccess: HealthAccess.denied)
        ..historyAccess = false,
    );
    final scope = _scope(tester);
    expect(scope.health.askHistory, isFalse);

    await _next(tester, l10n);
    await _next(tester, l10n);

    // Health Connect: the button asks, the mark takes its place, and the
    // question for older data does not follow by itself.
    await tester.tap(find.text(l10n.accessAction));
    await advance(tester);
    expect(find.text(l10n.accessAction), findsNothing);
    expect(find.text(l10n.introAccessGranted), findsOneWidget);
    expect(repository.historyPermissionRequests, 0);
    await _next(tester, l10n);

    // The switches ask at once and show the answer.
    expect(calls, ['allowed']);
    await tester.tap(_switchOf(l10n.introNotices));
    await advance(tester);
    expect(calls, ['allowed', 'allow']);
    expect(scope.settings.morningBrief, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    await tester.tap(_switchOf(l10n.introNotices));
    await advance(tester);
    expect(scope.settings.morningBrief, isFalse);
    expect(scope.settings.weekReport, isFalse);

    expect(scope.health.backgroundAccess, isFalse);
    await tester.tap(_switchOf(l10n.introBackground));
    await advance(tester);
    expect(scope.health.backgroundAccess, isTrue);
    expect(_switchOf(l10n.introBackground), findsNothing);

    // Older data is refused here: the switch stays, the question was put.
    await tester.tap(_switchOf(l10n.introHistory));
    await advance(tester);
    expect(repository.historyPermissionRequests, 1);
    expect(scope.health.historyAccess, isFalse);
    expect(_switchOf(l10n.introHistory), findsOneWidget);
    repository.historyAccess = true;
    await tester.tap(_switchOf(l10n.introHistory));
    await advance(tester);
    expect(scope.health.historyAccess, isTrue);
    expect(_switchOf(l10n.introHistory), findsNothing);
    await _next(tester, l10n);

    // Who: the rows open the profile's sheets.
    expect(find.text(l10n.notGiven), findsNWidgets(4));
    await tester.tap(find.text(l10n.nameLabel));
    await advance(tester);
    await tester.enterText(find.byType(TextField), 'Mira');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await advance(tester);
    expect(scope.settings.name, 'Mira');
    expect(find.text('Mira'), findsOneWidget);
    await tester.tap(find.text(l10n.male).first);
    await advance(tester);
    expect(scope.settings.sex, Sex.male);
    await _next(tester, l10n);

    // Goals: the three of a day, with what is suggested.
    expect(find.byType(Slider), findsNothing);
    expect(scope.settings.stepGoal, 10000);
    await _next(tester, l10n);

    // Mode: simple is chosen, a tap chooses the other.
    expect(scope.settings.simple, isTrue);
    await tester.tap(find.text(l10n.simpleOff));
    await advance(tester);
    expect(scope.settings.simple, isFalse);

    // The end: the sun rises while the read runs, then the pages.
    repository.gate = gate;
    unawaited(scope.health.refresh(full: true));
    await tester.pump();
    await tester.tap(find.text(l10n.introFinish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MorningSunrise), findsOneWidget);
    expect(find.text(l10n.introHello('Mira')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(MorningSunrise), findsOneWidget);
    expect(scope.settings.introDone, isFalse);
    gate.complete();
    await advance(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(IntroPage), findsNothing);
    expect(find.byType(TodayPage), findsOneWidget);
    expect(store.documents[StoreKeys.settings], contains('"introDone":true'));
    expect(store.documents[StoreKeys.settings], contains('"name":"Mira"'));
  });

  testWidgets('the sunrise does not wait for a read longer than its limit', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    _notices(tester);
    final (:repository, store: _) = await pumpApp(tester, fresh: true);
    final scope = _scope(tester);
    for (var i = 0; i < _cards.length - 1; i++) {
      await _next(tester, l10n);
    }
    final gate = Completer<void>();
    repository.gate = gate;
    unawaited(scope.health.refresh(full: true));
    await tester.pump();
    await tester.tap(find.text(l10n.introFinish));
    await tester.pump();
    await tester.pump(const Duration(seconds: 14));
    expect(find.byType(IntroPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(IntroPage), findsNothing);
    gate.complete();
    await advance(tester);
  });

  testWidgets('without access the switches are shut and the end has no '
      'sunrise', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    _notices(tester);
    final (:repository, store: _) = await pumpApp(
      tester,
      fresh: true,
      repository: FixtureRepository(currentAccess: HealthAccess.denied),
    );
    for (var i = 0; i < 3; i++) {
      await _next(tester, l10n);
    }
    expect(find.text(l10n.introNeedsAccess), findsOneWidget);
    await tester.tap(_switchOf(l10n.introBackground));
    await advance(tester);
    expect(repository.background, isFalse);
    for (var i = 3; i < _cards.length - 1; i++) {
      await _next(tester, l10n);
    }
    await tester.tap(find.text(l10n.introFinish));
    await advance(tester);
    expect(find.byType(MorningSunrise), findsNothing);
    expect(find.byType(AccessPage), findsOneWidget);
  });

  testWidgets('a refused notification leaves its switch off', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    _notices(tester, grants: false);
    await pumpApp(tester, fresh: true);
    final scope = _scope(tester);
    for (var i = 0; i < 3; i++) {
      await _next(tester, l10n);
    }
    await tester.tap(_switchOf(l10n.introNotices));
    await advance(tester);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    // What the reports are set to is left alone.
    expect(scope.settings.morningBrief, isTrue);
  });

  testWidgets('a store that is missing offers to install it', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    _notices(tester);
    await pumpApp(
      tester,
      fresh: true,
      repository: FixtureRepository(currentAccess: HealthAccess.unavailable),
    );
    await _next(tester, l10n);
    await _next(tester, l10n);
    expect(find.text(l10n.introAccessMissing), findsOneWidget);
    expect(find.text(l10n.missingAction), findsOneWidget);
    expect(find.text(l10n.accessAction), findsNothing);
  });

  testWidgets('a platform without a health store is not led through it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      fresh: true,
      repository: FixtureRepository(currentAccess: HealthAccess.unsupported),
    );
    expect(find.byType(IntroPage), findsNothing);
    expect(find.byType(AccessPage), findsOneWidget);
  });

  testWidgets('back turns to the card before', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    _notices(tester);
    await pumpApp(tester, fresh: true);
    await _next(tester, l10n);
    await _next(tester, l10n);
    expect(find.byType(AccessCard), findsOneWidget);
    await tester.binding.handlePopRoute();
    await advance(tester);
    expect(find.byType(PrivacyCard), findsOneWidget);
    expect(find.byType(AccessCard), findsNothing);
    await tester.binding.handlePopRoute();
    await advance(tester);
    expect(find.byType(WelcomeCard), findsOneWidget);
    expect(find.byType(IntroPage), findsOneWidget);
  });

  testWidgets('the language can be changed on the first card only', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    _notices(tester);
    await pumpApp(tester, fresh: true);
    await tester.tap(find.byTooltip(l10n.language));
    await advance(tester);
    await tester.tap(find.text('English'));
    await advance(tester);
    await tester.tapAt(const Offset(200, 40));
    await advance(tester);
    final english = lookupAppLocalizations(const Locale('en'));
    expect(find.text(english.introWelcomeTitle), findsOneWidget);
    await _next(tester, english);
    expect(find.byTooltip(english.language), findsNothing);
  });

  testWidgets('the profile opens it again, and there it only closes', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    _notices(tester, allowed: true);
    final (:repository, :store) = await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.person_rounded).first);
    await advance(tester);
    await tapInView(tester, find.text(l10n.introAgain));
    await advance(tester);
    expect(find.byType(IntroPage), findsOneWidget);
    expect(find.text(l10n.introSkip), findsNothing);
    for (var i = 0; i < 3; i++) {
      await _next(tester, l10n);
    }
    // Notifications are allowed already, and the switch says so.
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    for (var i = 3; i < _cards.length - 1; i++) {
      await _next(tester, l10n);
    }
    await tester.tap(find.text(l10n.introFinish));
    await advance(tester);
    expect(find.byType(IntroPage), findsNothing);
    expect(find.byType(MorningSunrise), findsNothing);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(repository.currentAccess, HealthAccess.granted);
    expect(
      store.documents[StoreKeys.settings],
      isNot(contains('introDone":false')),
    );
  });

  testWidgets('the profile offers older data while it is not allowed', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    final (:repository, store: _) = await pumpApp(tester);
    final asked = repository.historyPermissionRequests;
    await tester.tap(find.byIcon(Icons.person_rounded).first);
    await advance(tester);
    repository
      ..historyAccess = true
      ..olderDays = fixtureOlderDays();
    await tapInView(tester, find.text(l10n.historyLoad));
    await advance(tester);
    expect(repository.historyPermissionRequests, asked + 1);
    expect(find.text(l10n.historyLoad), findsNothing);
    expect(repository.historyRequests, isNotEmpty);
  });
}
