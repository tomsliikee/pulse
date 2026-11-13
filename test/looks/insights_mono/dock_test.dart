import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Icons, MaterialApp, Scaffold, TextField, ThemeData;
import 'package:pulse/looks/insights_mono/pages/search_pins_page.dart';
import 'package:pulse/looks/insights_mono/pages/training/live_page.dart';
import 'package:pulse/looks/insights_mono/pages/training/training_page.dart';
import 'package:pulse/looks/insights_mono/shell/mono_dock.dart';
import 'package:pulse/looks/insights_mono/shell/mono_dock_controller.dart';
import 'package:pulse/looks/insights_mono/theme/mono_tokens.dart';
import 'package:pulse/app/app_scope.dart';
import 'package:pulse/data/training/training_controller.dart';
import 'package:pulse/looks/insights_mono/widgets/mono_card.dart';
import 'package:pulse/looks/insights_mono/widgets/mono_floating_bar.dart';
import 'package:pulse/looks/insights_mono/widgets/mono_supplement_chips.dart';

import 'package:pulse/data/models.dart';
import 'package:pulse/data/training/training_splits.dart';
import 'package:pulse/looks/insights_mono/pages/training/session_page.dart';
import 'package:pulse/looks/insights_mono/pages/workout_page.dart';

import '../../support/fixtures.dart';

MemoryJsonStore _store({bool shrink = true}) => MemoryJsonStore()
  ..documents['settings'] =
      '{"look":"insightsMono","simple":false,"introDone":true,'
      '"dockShrink":$shrink,"birthDate":"1990-05-10","sex":"male"}';

MonoDockController _dock(WidgetTester tester) =>
    MonoDockScope.read(tester.element(find.byType(MonoDock)))!;

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = await File('assets/fonts/$file').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await loadAppFont();
    await _font('Geist Serif', ['GeistSerif-Regular.ttf']);
    await _font('Inter', ['InterVariable.ttf']);
    await _font('Inter Ext', ['InterVariableExt.ttf']);
  });

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    final w = size.width.round();

    testWidgets('search opens with the pins and finds values at $w', (
      tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        locale: const Locale('en'),
        store: _store(),
      );
      expect(find.byType(MonoDock), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await advance(tester);
      expect(_dock(tester).searchOpen, isTrue);
      expect(find.text('Pinned'), findsWidgets);
      expect(
        find.text('Edit pinned values', skipOffstage: false),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'heart');
      await advance(tester);
      expect(find.textContaining('results'), findsWidgets);
      expect(find.text('Values'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'xylophone');
      await advance(tester);
      expect(find.textContaining('Nothing found'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The × closes it and clears the text.
      await tester.tap(
        find.descendant(
          of: find.byType(MonoDock),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await advance(tester);
      expect(_dock(tester).searchOpen, isFalse);
      expect(find.text('Pinned'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('a tap on the dim layer closes the search at $w', (
      tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        locale: const Locale('en'),
        store: _store(),
      );
      await tester.tap(find.byType(TextField));
      await advance(tester);
      // Hide the keyboard so the corner is free, then tap the scrim there.
      await tester.tapAt(const Offset(4, 30));
      await advance(tester);
      expect(_dock(tester).searchOpen, isFalse);
    });

    testWidgets('the search starts a training and the pill leads back at $w', (
      tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        locale: const Locale('en'),
        store: _store(),
      );
      final handle = tester.ensureSemantics();
      // What the + held is now at the foot of the search.
      await tester.tap(find.byType(TextField));
      await advance(tester);
      expect(find.text('Workout'), findsOneWidget);
      await tester.tap(find.text('Workout'));
      await advance(tester);
      expect(find.text('Empty workout'), findsOneWidget);
      await tester.tap(find.text('Empty workout'));
      await advance(tester);
      expect(find.byType(MonoLivePage), findsOneWidget);
      // The dock steps aside on the live screen.
      expect(_dock(tester).liveOnTop, isTrue);
      await tester.tap(find.bySemanticsLabel('Back, the training goes on'));
      await advance(tester);
      expect(find.byType(MonoLivePage), findsNothing);
      final pill = find.bySemanticsLabel(
        RegExp('^Training .*back to training'),
      );
      expect(pill, findsOneWidget);
      await tester.tap(pill);
      await advance(tester);
      expect(find.byType(MonoLivePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }

  testWidgets('the dock shrinks on the way down and grows on the way up', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'), store: _store());
    final list = find.byType(Scrollable).first;
    void centred() {
      final bar = tester.getRect(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(MonoGlass),
            )
            .first,
      );
      final hint = tester.getRect(find.text('Search'));
      final icon = tester.getRect(
        find.descendant(
          of: find.byType(MonoDock),
          matching: find.byIcon(Icons.search_rounded),
        ),
      );
      debugPrint('bar $bar hint $hint icon $icon');
      expect((hint.center.dy - bar.center.dy).abs(), lessThan(1.5));
      expect(hint.left - icon.right, lessThan(14));
    }

    centred();
    await tester.drag(list, const Offset(0, -500));
    await advance(tester);
    expect(_dock(tester).shrunk, isTrue);
    centred();
    await tester.drag(list, const Offset(0, 200));
    await advance(tester);
    expect(_dock(tester).shrunk, isFalse);
  });

  testWidgets('with the setting off the dock keeps its size', (tester) async {
    await pumpApp(
      tester,
      locale: const Locale('en'),
      store: _store(shrink: false),
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await advance(tester);
    expect(_dock(tester).shrunk, isFalse);
  });

  testWidgets('the Training tab offers templates and then the next one', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      locale: const Locale('en'),
      store: _store(),
    );
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Training').first);
    await advance(tester);
    expect(find.byType(MonoTrainingPage), findsOneWidget);
    expect(find.text('No plan yet'), findsOneWidget);
    await tester.tap(find.text('Choose a split'));
    await advance(tester);
    await tester.tap(find.text('Arnold split'));
    await advance(tester);
    expect(find.text('Today · Chest & back'), findsOneWidget);
    expect(app.store.documents['training'], contains('pullover'));
    expect(app.store.documents['training'], contains('"split":"arnold"'));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('a pin can be switched off on the pins page', (tester) async {
    final app = await pumpApp(
      tester,
      locale: const Locale('en'),
      store: _store(),
    );
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const MonoSearchPinsPage(),
      ),
    );
    await advance(tester);
    expect(find.text('Search pins'), findsWidgets);
    await tester.tap(find.text('Unpin').first);
    await advance(tester);
    expect(app.store.documents['settings'], isNot(contains('"recovery"')));
  });

  testWidgets('a strength workout logs its sets and then shows them', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'), store: _store());
    final training = AppScope.of(tester.element(find.byType(MonoDock)))
        .training;
    await training.applySplit(TrainingSplit.pushPullLegs, const {});
    final workout = Workout(
      type: WorkoutType.strength,
      start: DateTime(2026, 10, 5, 18),
      minutes: 50,
    );
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => MonoWorkoutPage(workout: workout),
      ),
    );
    Finder page() => find
        .descendant(
          of: find.byType(MonoWorkoutPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await advance(tester);
    final log = find.textContaining('Log as');
    await tester.scrollUntilVisible(log, 200, scrollable: page());
    await tester.tap(log);
    await advance(tester);
    // The sets open to be corrected; no training runs.
    expect(find.byType(MonoSessionPage), findsOneWidget);
    expect(training.active, isNull);
    expect(find.text('Done'), findsWidgets);
    navigator.pop();
    await advance(tester);
    await tester.scrollUntilVisible(
      find.text('Open training'),
      200,
      scrollable: page(),
    );
    expect(find.text('Barbell bench press'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chip ticks its supplement and the ring counts it', (
    tester,
  ) async {
    var taken = false;
    late StateSetter set;
    await tester.pumpWidget(
      MaterialApp(
        theme: monoTheme(ThemeData()),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return MonoSupplementBoard(
                countLabel: taken ? '1 of 1' : '0 of 1',
                entries: [
                  MonoSupplementEntry(
                    key: 'd',
                    name: 'Vitamin D',
                    detail: '1000 IU · Morning',
                    taken: taken,
                    onToggle: () => set(() => taken = !taken),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('0/1', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Vitamin D'));
    await advance(tester);
    expect(taken, isTrue);
    expect(find.text('1/1', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the live screen keeps a set and starts the rest', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      locale: const Locale('en'),
      store: _store(),
    );
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Training').first);
    await advance(tester);
    await tester.tap(find.text('Choose a split'));
    await advance(tester);
    await tester.tap(find.text('Push · Pull · Legs'));
    await advance(tester);
    await tester.tap(find.text('Start training'));
    await advance(tester);
    expect(find.byType(MonoLivePage), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Set done').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rest'), findsOneWidget);
    expect(app.store.documents['training'], contains('"done":true'));
    handle.dispose();
    // Ends the rest's timer before the test is over.
    await tester.tap(find.text('Skip'));
    await tester.pump();
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    MemoryJsonStore store() => MemoryJsonStore()
      ..documents['settings'] =
          '{"look":"insightsMono","simple":false,"introDone":true,'
          '"birthDate":"1990-05-10","sex":"male",'
          '"themeMode":"${dark ? 'dark' : 'light'}"}';

    testWidgets('the dock and the open search in $mode', (tester) async {
      await pumpApp(tester, locale: const Locale('en'), store: store());
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dock_$mode.png'),
      );
      await tester.tap(find.byType(TextField));
      await advance(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/search_pinned_$mode.png'),
      );
      await tester.enterText(find.byType(TextField), 'heart');
      await advance(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/search_results_$mode.png'),
      );
    });

    testWidgets('the supplements card in $mode', (tester) async {
      await pumpApp(
        tester,
        size: const Size(412, 3000),
        locale: const Locale('en'),
        store: store(),
      );
      final supplements = AppScope.of(tester.element(find.byType(MonoDock)))
          .supplements;
      for (final id in ['vitaminD', 'creatine', 'omega3', 'magnesium']) {
        await supplements.addPreset(id);
      }
      await supplements.take(supplements.data.byKey('vitaminD')!);
      await supplements.take(supplements.data.byKey('creatine')!);
      await advance(tester);
      final card = find.ancestor(
        of: find.byType(MonoSupplementBoard),
        matching: find.byType(MonoCard),
      );
      expect(card, findsOneWidget);
      await expectLater(
        card,
        matchesGoldenFile('goldens/supplements_card_$mode.png'),
      );
    });

    testWidgets('the live screen in $mode', (tester) async {
      await pumpApp(tester, locale: const Locale('en'), store: store());
      final handle = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Training').first);
      await advance(tester);
      await tester.tap(find.text('Choose a split'));
      await advance(tester);
      await tester.tap(find.text('Push · Pull · Legs'));
      await advance(tester);
      await tester.tap(find.text('Start training'));
      await advance(tester);
      await tester.tap(find.bySemanticsLabel('Set done').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/live_$mode.png'),
      );
      await tester.tap(find.bySemanticsLabel('Back, the training goes on'));
      await advance(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/training_pill_$mode.png'),
      );
      final training = MonoCtxProbe.training(tester);
      await training.stopRest();
      await tester.pump();
      handle.dispose();
    });
  }
}

abstract final class MonoCtxProbe {
  static TrainingController training(WidgetTester tester) =>
      AppScope.of(tester.element(find.byType(MonoDock))).training;
}
