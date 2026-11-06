import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Icons, MaterialApp, ReorderableListView, TextField;
import 'package:pulse/app/app_scope.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/looks/insights_mono/data/mono_data.dart';
import 'package:pulse/looks/insights_mono/pages/body_age_page.dart';
import 'package:pulse/looks/insights_mono/pages/browse_page.dart';
import 'package:pulse/looks/insights_mono/pages/calories_page.dart';
import 'package:pulse/looks/insights_mono/pages/day_page.dart';
import 'package:pulse/looks/insights_mono/pages/goals_page.dart';
import 'package:pulse/looks/insights_mono/pages/heart_page.dart';
import 'package:pulse/looks/insights_mono/pages/links_page.dart';
import 'package:pulse/looks/insights_mono/pages/list_pages.dart';
import 'package:pulse/looks/insights_mono/pages/metric_page.dart';
import 'package:pulse/looks/insights_mono/pages/night_page.dart';
import 'package:pulse/looks/insights_mono/pages/supplements_page.dart';
import 'package:pulse/looks/insights_mono/pages/week_page.dart';
import 'package:pulse/looks/insights_mono/pages/category_page.dart';
import 'package:pulse/looks/insights_mono/shell/mono_shell.dart';
import 'package:pulse/looks/insights_mono/widgets/mono_controls.dart';
import 'package:pulse/looks/insights_mono/widgets/mono_floating_bar.dart';
import 'package:pulse/looks/insights_mono/widgets/mono_page.dart';
import 'package:pulse/looks/insights_mono/theme/mono_tokens.dart';

import '../../support/fixtures.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = await File('assets/fonts/$file').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

MemoryJsonStore _store({
  bool dark = false,
  bool simple = false,
  String look = 'insightsMono',
  bool tint = false,
}) => MemoryJsonStore()
  ..documents['settings'] =
      '{"look":"$look","flexTint":$tint,"simple":$simple,"introDone":true,'
      '"birthDate":"1990-05-10","sex":"male","heightCm":180,'
      '"themeMode":"${dark ? 'dark' : 'light'}"}';

/// The looks of the family as (name in the goldens, look, tinted).
const _looks = [
  ('mono', 'insightsMono', false),
  ('flex', 'insightsFlex', false),
  ('flextint', 'insightsFlex', true),
];

/// Tall, so one image shows a whole page.
const _tall = Size(412, 3000);

void main() {
  setUpAll(() async {
    await loadAppFont();
    await _font('Geist Serif', ['GeistSerif-Regular.ttf']);
    await _font('Inter', ['InterVariable.ttf']);
    await _font('Inter Ext', ['InterVariableExt.ttf']);
  });

  for (final (name, look, tint) in _looks) {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      MemoryJsonStore store() => _store(dark: dark, look: look, tint: tint);

      testWidgets('$name opens on Insights in $mode', (tester) async {
        await pumpApp(
          tester,
          size: _tall,
          locale: const Locale('en'),
          store: store(),
        );
        // The pill of the bar takes the colours of the theme with a spring.
        await advance(tester);
        expect(find.byType(MonoShell), findsOneWidget);
        expect(find.text('Insights'), findsWidgets);
        expect(find.text('Calories'), findsWidgets);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MonoShell),
          matchesGoldenFile('goldens/insights_${name}_$mode.png'),
        );
      });

      testWidgets('$name Longevity and Browse in $mode', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          size: _tall,
          locale: const Locale('en'),
          store: store(),
        );
        await tester.tap(find.bySemanticsLabel('Longevity'));
        await advance(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MonoShell),
          matchesGoldenFile('goldens/longevity_${name}_$mode.png'),
        );
        await tester.tap(find.bySemanticsLabel('Browse'));
        await advance(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MonoShell),
          matchesGoldenFile('goldens/browse_${name}_$mode.png'),
        );
        handle.dispose();
      });

      testWidgets('$name Sleep page in $mode', (tester) async {
        await pumpApp(
          tester,
          size: _tall,
          locale: const Locale('en'),
          store: store(),
        );
        await tester.tap(find.text('Sleep').first, warnIfMissed: false);
        await advance(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/sleep_${name}_$mode.png'),
        );
      });
    }
  }

  testWidgets('a pushed page of the standard look wears the look', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: _tall,
      locale: const Locale('en'),
      store: _store(),
    );
    await tester.tap(find.bySemanticsLabel('Profile'));
    await advance(tester);
    await unfoldSettings(tester);
    expect(find.byType(MonoBackPill), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/profile_mono_light.png'),
    );
  });

  testWidgets('coming back from a page does not bring the keyboard back', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'), store: _store());
    await tester.tap(find.bySemanticsLabel('Browse'));
    await advance(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.scrollUntilVisible(
      find.text('Activity').last,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
    await tester.pump();
    await tester.tap(find.text('Activity').last, warnIfMissed: false);
    await advance(tester);
    expect(find.byType(MonoCategoryPage), findsOneWidget);
    await tester.tap(find.byType(MonoBackPill));
    await advance(tester);
    expect(find.byType(MonoCategoryPage), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
  });

  testWidgets('the pencil hides a card and the setting keeps it', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      size: _tall,
      locale: const Locale('en'),
      store: _store(),
    );
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Arrange cards'));
    await advance(tester);
    expect(find.byType(ReorderableListView), findsOneWidget);
    // Recovery, Activity, Sleep, Heart: the fourth minus.
    await tester.tap(find.byIcon(Icons.remove_rounded).at(3));
    await advance(tester);
    expect(find.text('Hidden'), findsWidgets);
    expect(
      app.store.documents['settings'],
      contains('"monoInsights":["heart"]'),
    );
    await tester.tap(find.bySemanticsLabel('Done'));
    await advance(tester);
    expect(find.byType(ReorderableListView), findsNothing);
    handle.dispose();
  });

  testWidgets('the header floats once scrolled and a tap scrolls to the top', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'), store: _store());
    final list = find.byType(Scrollable).first;
    ScrollPosition position() => tester.state<ScrollableState>(list).position;
    await tester.drag(list, const Offset(0, -600));
    await advance(tester);
    expect(position().pixels, greaterThan(MonoPage.floatAfter));
    // The pill carries the title of the page, in front of the content.
    await tester.tapAt(const Offset(60, 60));
    await advance(tester);
    expect(position().pixels, 0);
  });

  testWidgets('the pencil of Longevity arranges its blocks', (tester) async {
    await pumpApp(
      tester,
      size: _tall,
      locale: const Locale('en'),
      store: _store(),
    );
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Longevity'));
    await advance(tester);
    await tester.tap(find.byIcon(Icons.edit_rounded).hitTestable().first);
    await advance(tester);
    expect(find.byType(ReorderableListView), findsNWidgets(2));
    handle.dispose();
  });

  testWidgets('a finger slid along the bar opens the page it ends on', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'), store: _store());
    final bar = tester.getRect(find.byType(MonoFloatingBar));
    final gesture = await tester.startGesture(
      bar.centerLeft + const Offset(40, 0),
    );
    await tester.pump(const Duration(milliseconds: 50));
    for (var x = 40.0; x <= 225; x += 20) {
      await gesture.moveTo(bar.centerLeft + Offset(x, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await advance(tester);
    expect(find.byType(MonoBrowsePage), findsOneWidget);
    expect(
      tester
          .widget<Offstage>(
            find
                .ancestor(
                  of: find.byType(MonoBrowsePage),
                  matching: find.byType(Offstage),
                )
                .first,
          )
          .offstage,
      isFalse,
    );
  });

  testWidgets('the thumb of a slider can be dragged to the other side', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: _tall,
      locale: const Locale('en'),
      store: _store(),
    );
    final slider = find.byType(MonoSegmented).first;
    final box = tester.getRect(slider);
    await tester.dragFrom(
      box.centerLeft + const Offset(30, 0),
      Offset(box.width * 0.7, 0),
    );
    await advance(tester);
    final segmented = tester.widget<MonoSegmented>(slider);
    expect(segmented.selected, 1);
  });

  for (final (name, page) in <(String, Widget Function(DateTime))>[
    ('calories', (_) => const MonoCaloriesPage(backLabel: 'Insights')),
    ('metric', (_) => const MonoMetricPage(metric: Metric.steps)),
    ('weight', (_) => const MonoMetricPage(metric: Metric.weight)),
    ('night', (today) => MonoNightPage(date: today)),
    ('day', (today) => MonoDayPage(date: today)),
    ('week', (_) => const MonoWeekPage()),
    ('heart', (today) => MonoHeartPage(date: today)),
    ('goals', (_) => const MonoGoalsPage()),
    ('links', (_) => const MonoLinksPage()),
    ('workouts', (_) => const MonoWorkoutListPage()),
    ('bodyage', (_) => const MonoBodyAgePage()),
    ('supplements', (_) => const MonoSupplementsPage()),
  ]) {
    testWidgets('the $name page of the look', (tester) async {
      await pumpApp(
        tester,
        size: _tall,
        locale: const Locale('de'),
        store: _store(),
      );
      await advance(tester);
      final context = tester.element(find.byType(MonoShell));
      final today = AppScope.of(context).health.today;
      monoPush<void>(context, page(today));
      await advance(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/page_$name.png'),
      );
    });
  }

  testWidgets('its tokens differ between light and dark', (tester) async {
    final light = MonoTokens.from(Brightness.light, const Color(0xFF3F5BD9));
    final dark = MonoTokens.from(Brightness.dark, const Color(0xFF3F5BD9));
    expect(light.bg, const Color(0xFFFFFFFF));
    expect(dark.bg, const Color(0xFF000000));
    expect(light.recovery, isNot(dark.recovery));
    final tinted = MonoTokens.from(
      Brightness.light,
      const Color(0xFF3F5BD9),
      tint: true,
    );
    expect(tinted.bg, isNot(light.bg));
    expect(tinted.ink, light.ink);
  });
}
