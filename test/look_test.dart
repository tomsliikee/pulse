import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/features/activity/workout_scene.dart';
import 'package:pulse/features/heart/heart_scene.dart';
import 'package:pulse/features/links/links_scene.dart';
import 'package:pulse/features/morning/morning_scene.dart';
import 'package:pulse/features/sleep/sleep_scene.dart';
import 'package:pulse/features/today/day_scene.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/theme/app_type.dart';
import 'package:pulse/theme/page_accent.dart';
import 'package:pulse/theme/pulse_look.dart';
import 'package:pulse/widgets/headline.dart';
import 'package:pulse/widgets/metric_card.dart';
import 'package:pulse/widgets/wavy_bar.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

Future<MemoryJsonStore> _store({
  bool simple = false,
  bool glass = false,
}) async {
  final store = MemoryJsonStore();
  await store.write(StoreKeys.settings, {
    'expressive': true,
    'mascot': true,
    'simple': simple,
    'liquidGlass': glass,
    'birthDate': '1992-03-07',
  });
  return store;
}

/// Every scene that draws a figure, as the pages use them.
Map<String, Widget> _scenes() => {
  'day': const DayScene(untilMinute: 600, score: 80, steps: 6000),
  'night': const DayScene(untilMinute: 1380, score: 80, steps: 6000),
  'heart': const HeartScene(bpm: 70),
  'sleep': SleepScene(
    night: SleepNight(
      date: DateTime(2026, 10, 6),
      bedtimeMinute: 1390,
      totalMinutes: 440,
      segments: const [],
    ),
    score: 90,
  ),
  'morning': const MorningScene(),
  'links': const LinksScene(),
  for (final type in WorkoutType.values) type.name: WorkoutScene(type: type),
};

/// Opens what [text] names from the page that is shown, scrolls the page
/// it leads to through to its end and comes back.
Future<void> _visit(WidgetTester tester, String text) async {
  final target = find.textContaining(
    RegExp(RegExp.escape(text), caseSensitive: false),
  );
  await tester.scrollUntilVisible(
    target.first,
    300,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await advance(tester);
  await tester.tap(target.hitTestable().first);
  await advance(tester);
  await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -6000));
  await advance(tester);
  await tester.tap(find.byType(BackButton).last);
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  test('mascot and rework are off at first and survive a restart', () async {
    final store = MemoryJsonStore();
    final settings = SettingsController(store);
    await settings.load();
    expect(settings.mascot, isFalse);
    expect(settings.expressive, isFalse);
    settings
      ..setMascot(true)
      ..setExpressive(true);
    await pumpEventQueue();

    final loaded = SettingsController(store);
    await loaded.load();
    expect(loaded.mascot, isTrue);
    expect(loaded.expressive, isTrue);
  });

  // Without semantics: a page that changes its build while it lies under
  // another one trips an assertion of the semantics tree. The edge-to-edge
  // switch did so before the rework too.
  testWidgets(
    'the two switches on the profile are saved',
    semanticsEnabled: false,
    (tester) async {
      final app = await pumpApp(tester);
      final l10n = lookupAppLocalizations(const Locale('de'));
      await tester.tap(find.byIcon(Icons.person_rounded));
      await advance(tester);
      for (final (label, key) in [
        (l10n.mascot, 'mascot'),
        (l10n.expressiveRework, 'expressive'),
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final row = find.ancestor(
          of: find.text(label),
          matching: find.byType(Row),
        );
        final toggle = find.descendant(
          of: row.first,
          matching: find.byType(Switch),
        );
        await tester.ensureVisible(toggle);
        await advance(tester);
        await tester.tap(toggle);
        await advance(tester);
        expect(app.store.documents['settings'], contains('"$key":true'));
      }
    },
  );

  testWidgets('the rework widens the type and makes the comparison a chip', (
    tester,
  ) async {
    late AppType type;
    await tester.pumpWidget(
      PulseLook(
        expressive: true,
        child: themed(
          Builder(
            builder: (context) {
              type = AppType.of(context);
              return const Headline(
                'Faster than last time',
                color: Colors.blue,
                icon: Icons.bolt_rounded,
              );
            },
          ),
        ),
      ),
    );
    expect(type.expressive, isTrue);
    expect(type.flex, isTrue);
    expect(type.caps('Steps'), 'STEPS');
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) {
            type = AppType.of(context);
            return const Headline(
              'Faster than last time',
              color: Colors.blue,
              icon: Icons.bolt_rounded,
            );
          },
        ),
      ),
    );
    expect(type.expressive, isFalse);
    expect(type.caps('Steps'), 'Steps');
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
  });

  testWidgets('in the rework a small tile with a goal shows a wavy bar, and '
      'nutrition a ring', (tester) async {
    Finder list() => find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    Future<Finder> stepsTile(String title) async {
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: list(),
      );
      await advance(tester);
      return find
          .ancestor(of: find.text(title), matching: find.byType(MetricCard))
          .first;
    }

    await pumpApp(tester, store: await _store());
    expect(
      find.descendant(
        of: await stepsTile('SCHRITTE'),
        matching: find.byType(WavyBar),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('ERNÄHRUNG'),
      300,
      scrollable: list(),
    );
    await advance(tester);
    expect(find.text('Ernährung'), findsNothing);
  });

  testWidgets('without the rework the steps keep their ring alone', (
    tester,
  ) async {
    Finder list() => find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await pumpApp(tester);
    await tester.scrollUntilVisible(stepsTile(), 200, scrollable: list());
    await advance(tester);
    expect(
      find.descendant(
        of: find
            .ancestor(of: stepsTile(), matching: find.byType(MetricCard))
            .first,
        matching: find.byType(WavyBar),
      ),
      findsNothing,
    );
  });

  for (final mascot in [true, false]) {
    testWidgets('every scene draws ${mascot ? 'the turtle' : 'the figure'}, '
        'moving and standing still', (tester) async {
      for (final MapEntry(key: name, value: scene) in _scenes().entries) {
        for (final still in [false, true]) {
          await tester.pumpWidget(
            PulseLook(
              mascot: mascot,
              key: ValueKey('$name$still'),
              child: themed(
                MediaQuery(
                  data: MediaQueryData(disableAnimations: still),
                  child: PageAccent.activity(child: scene),
                ),
              ),
            ),
          );
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 450));
          }
          expect(tester.takeException(), isNull, reason: name);
        }
      }
    });
  }

  for (final size in _sizes) {
    final label = '${size.width.round()}x${size.height.round()}';
    for (final simple in [true, false]) {
      testWidgets('every page renders in the rework at $label'
          '${simple ? ' in simple mode' : ''}', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('de'));
        await pumpApp(
          tester,
          size: size,
          store: await _store(simple: simple),
        );
        for (final destination in [
          l10n.navToday,
          l10n.groupActivity,
          l10n.groupSleep,
          l10n.navHeart,
        ]) {
          await tester.tap(find.bySemanticsLabel(destination).first);
          await advance(tester);
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -6000),
          );
          await advance(tester);
          await tester.drag(find.byType(ListView).first, const Offset(0, 6000));
          await advance(tester);
        }
        await tester.tap(find.bySemanticsLabel(l10n.navToday).first);
        await advance(tester);
        await _visit(tester, l10n.goals);
        await _visit(tester, l10n.linksTitle);
        await tester.tap(find.bySemanticsLabel(l10n.groupActivity).first);
        await advance(tester);
        await _visit(tester, l10n.lastActivity);
        await tester.tap(find.bySemanticsLabel(l10n.groupSleep).first);
        await advance(tester);
        await _visit(tester, l10n.lastNight);
      });
    }
  }

  testWidgets('the rework renders with liquid glass and in the dark', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(tester, store: await _store(glass: true));
    for (final destination in [
      l10n.navToday,
      l10n.groupActivity,
      l10n.groupSleep,
      l10n.navHeart,
    ]) {
      await tester.tap(find.bySemanticsLabel(destination).first);
      await advance(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
      await advance(tester);
    }
    await tester.tap(find.bySemanticsLabel(l10n.navToday).first);
    await advance(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 6000));
    await advance(tester);
    await _visit(tester, l10n.linksTitle);
  });

  for (final language in ['en', 'pl']) {
    testWidgets('the pages of the rework fit in $language at 360x640', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(Locale(language));
      await pumpApp(
        tester,
        size: const Size(360, 640),
        locale: Locale(language),
        store: await _store(simple: true),
      );
      for (final destination in [
        l10n.navToday,
        l10n.groupActivity,
        l10n.groupSleep,
        l10n.navHeart,
      ]) {
        await tester.tap(find.bySemanticsLabel(destination).first);
        await advance(tester);
        await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
        await advance(tester);
      }
      await tester.tap(find.bySemanticsLabel(l10n.navToday).first);
      await advance(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, 6000));
      await advance(tester);
      await _visit(tester, l10n.linksTitle);
    });
  }
}
