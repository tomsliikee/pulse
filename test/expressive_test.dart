import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/features/activity/workout_detail_page.dart';
import 'package:pulse/features/activity/workout_scene.dart';
import 'package:pulse/features/activity/workout_tiles.dart';
import 'package:pulse/features/heart/heart_scene.dart';
import 'package:pulse/features/sleep/night_tiles.dart';
import 'package:pulse/features/sleep/sleep_scene.dart';
import 'package:pulse/features/today/day_detail_page.dart';
import 'package:pulse/features/today/day_scene.dart';
import 'package:pulse/features/today/day_tiles.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/theme/app_shapes.dart';
import 'package:pulse/theme/app_theme.dart';
import 'package:pulse/theme/page_accent.dart';
import 'package:pulse/theme/app_type.dart';
import 'package:pulse/widgets/animated_count.dart';
import 'package:pulse/widgets/chip_carousel.dart';
import 'package:pulse/widgets/line_chart.dart';
import 'package:pulse/widgets/page_header.dart';
import 'package:pulse/widgets/pressable.dart';
import 'package:pulse/widgets/progress_ring.dart';
import 'package:pulse/widgets/segment_group.dart';
import 'package:pulse/widgets/tile_surface.dart';

import 'support/fixtures.dart';

double? _axis(TextStyle? style, String axis) {
  for (final variation in style?.fontVariations ?? const <FontVariation>[]) {
    if (variation.axis == axis) return variation.value;
  }
  return null;
}

MemoryJsonStore _settings(String json) =>
    MemoryJsonStore()..documents['settings'] = json;

void main() {
  setUpAll(loadAppFont);

  group('shapes', () {
    test('a family goes from its plain shape to its most pronounced', () {
      for (final family in ShapeFamily.values) {
        expect(family.steps, hasLength(5));
        expect(AppShapes.of(family, null), family.steps.first);
        expect(AppShapes.of(family, 1), family.steps.first);
        expect(AppShapes.of(family, 20), family.steps.first);
        expect(AppShapes.of(family, 21), family.steps[1]);
        expect(AppShapes.of(family, 81), family.steps.last);
        expect(AppShapes.of(family, 100), family.steps.last);
      }
      expect(ShapeFamily.day.steps.last, Shapes.verySunny);
      expect(ShapeFamily.activity.steps.last, Shapes.boom);
    });

    test('a group is strongly rounded where it ends and weakly inside', () {
      const outer = Radius.circular(AppRadii.extraLarge);
      const inner = Radius.circular(AppRadii.small);
      expect(SegmentGroup.cornersOf(0, 1), const BorderRadius.all(outer));
      expect(SegmentGroup.cornersOf(0, 3).topLeft, outer);
      expect(SegmentGroup.cornersOf(0, 3).bottomLeft, inner);
      expect(SegmentGroup.cornersOf(1, 3), const BorderRadius.all(inner));
      expect(SegmentGroup.cornersOf(2, 3).bottomRight, outer);
    });
  });

  group('the type', () {
    const base = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      fontVariations: [FontVariation('wght', 500)],
    );

    test('is the style it was given while the flex font is off', () {
      const type = AppType(flex: false);
      for (final role in [
        type.hero,
        type.figure,
        type.label,
        type.title,
        type.strong,
        type.aside,
      ]) {
        expect(role(base), same(base));
      }
      expect(type.moving(base, settled: 0.2, pressed: 1), same(base));
    });

    test('uses width, weight, slant and roundness with it on', () {
      const type = AppType(flex: true, roundness: 50);
      final hero = type.hero(base);
      expect(_axis(hero, 'wght'), 800);
      expect(_axis(hero, 'wdth'), greaterThan(100));
      expect(_axis(hero, 'opsz'), 32);
      expect(_axis(hero, 'ROND'), 50);
      expect(hero?.fontWeight, FontWeight.w800);
      expect(hero?.fontFeatures, isNotEmpty);
      expect(_axis(type.label(base), 'wdth'), lessThan(100));
      expect(_axis(type.aside(base), 'slnt'), -10);
      // Bold comes from the axis, not from a synthesized weight.
      expect(_axis(type.strong(base), 'wght'), 700);
    });

    test('a number is lighter while it counts and bolder while pressed', () {
      const type = AppType(flex: true);
      final heavy = type.hero(base);
      expect(_axis(type.moving(heavy, settled: 0), 'wght'), closeTo(440, 0.01));
      expect(_axis(type.moving(heavy), 'wght'), 800);
      expect(_axis(type.moving(heavy), 'GRAD'), 0);
      expect(_axis(type.moving(heavy, pressed: 1), 'GRAD'), 100);
    });
  });

  group('the flex font', () {
    TextStyle? scoreStyle(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.descendant(
              of: find.byType(DayCard),
              matching: find.byType(AnimatedCount),
            ),
            matching: find.byType(Text),
          ),
        )
        .style;

    testWidgets('is off at first: the score is plain type', (tester) async {
      await pumpApp(tester);
      expect(_axis(scoreStyle(tester), 'wdth'), isNull);
    });

    testWidgets('is restored, and makes the score wide and heavy', (
      tester,
    ) async {
      await pumpApp(tester, store: _settings('{"flexFont":true}'));
      expect(_axis(scoreStyle(tester), 'wdth'), greaterThan(100));
      expect(_axis(scoreStyle(tester), 'wght'), 800);
    });

    testWidgets('is switched on in the profile, saved, and reaches the page '
        'below at once', (tester) async {
      final app = await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel('Profil'));
      await advance(tester);
      final row = find.ancestor(
        of: find.text('Flex-Schrift', skipOffstage: false),
        matching: find.byType(Row, skipOffstage: false),
      );
      final toggle = find.descendant(
        of: row.first,
        matching: find.byType(Switch, skipOffstage: false),
      );
      await tapInView(tester, toggle);
      expect(app.store.documents['settings'], contains('"flexFont":true'));
      Navigator.of(tester.element(find.text('Flex-Schrift'))).pop();
      await advance(tester);
      expect(_axis(scoreStyle(tester), 'wdth'), greaterThan(100));
    });
  });

  group('the scene from edge to edge', () {
    Finder sceneInCard() => find.descendant(
      of: find.byType(DayCard),
      matching: find.byType(DayScene),
    );

    testWidgets('is off at first: the scene sits in the tile', (tester) async {
      await pumpApp(tester);
      expect(find.byType(DayBackdrop), findsNothing);
      expect(sceneInCard(), findsOneWidget);
    });

    testWidgets('runs from the top of the screen to the tile and scrolls '
        'with the page', (tester) async {
      await pumpApp(tester, store: _settings('{"edgeToEdgeHero":true}'));
      final backdrop = find.byType(DayBackdrop);
      expect(backdrop, findsOneWidget);
      expect(sceneInCard(), findsNothing);
      final rect = tester.getRect(backdrop);
      expect(rect.top, 0);
      expect(rect.left, 0);
      expect(rect.width, 412);
      // It ends where the tile's own scene would.
      final card = tester.getRect(find.byType(DayCard));
      expect(rect.bottom, closeTo(card.top + DayCard.sceneHeight, 0.5));

      await tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await advance(tester);
      expect(
        tester.getRect(backdrop).bottom,
        closeTo(
          tester.getRect(find.byType(DayCard)).top + DayCard.sceneHeight,
          0.5,
        ),
      );
    });

    testWidgets('stands at the time it is and has a title that reads on its '
        'sky', (tester) async {
      Color? title() => tester
          .widget<Text>(
            find.descendant(
              of: find.byType(PageHeader),
              matching: find.text('Heute'),
            ),
          )
          .style
          ?.color;
      final scheme = AppTheme.light().colorScheme;

      await pumpApp(tester, store: _settings('{"edgeToEdgeHero":true}'));
      final scene = find.descendant(
        of: find.byType(DayBackdrop),
        matching: find.byType(DayScene),
      );
      expect(tester.widget<DayScene>(scene).untilMinute, 15 * 60 + 30);
      expect(title(), scheme.onSurface);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      // A new app, started late in the evening.
      await tester.pumpWidget(const SizedBox());
      await pumpApp(
        tester,
        store: _settings('{"edgeToEdgeHero":true}'),
        now: DateTime(2026, 10, 6, 22),
      );
      expect(tester.widget<DayScene>(scene).untilMinute, 22 * 60);
      expect(title(), const Color(0xFFEFF1FF));
      // The status bar's icons are light on the dark sky, and dark again
      // once the scene has scrolled away from under them.
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      // A page opened over the dark sky has a light surface of its own.
      await tester.tap(find.byType(DayCard));
      await advance(tester);
      expect(find.byType(DayDetailPage), findsOneWidget);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      await tester.tap(find.byType(BackButton));
      await advance(tester);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await advance(tester);
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
    });

    testWidgets('gives the scene back to the tile while the page is edited', (
      tester,
    ) async {
      await pumpApp(tester, store: _settings('{"edgeToEdgeHero":true}'));
      await tester.tap(find.byTooltip('Kacheln anordnen'));
      await advance(tester);
      expect(sceneInCard(), findsOneWidget);
      await tester.tap(find.byTooltip('Fertig'));
      await advance(tester);
      expect(sceneInCard(), findsNothing);
    });

    testWidgets('stays in the tile when the tile is not the first', (
      tester,
    ) async {
      await pumpApp(
        tester,
        store: _settings(
          '{"edgeToEdgeHero":true,'
          '"tileOrder":{"today":["goals","hero"]}}',
        ),
      );
      expect(find.byType(DayBackdrop), findsNothing);
      expect(sceneInCard(), findsOneWidget);
    });
  });

  group('the pages', () {
    Future<void> open(WidgetTester tester, String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await advance(tester);
    }

    testWidgets('each have their own accent and family of shapes', (
      tester,
    ) async {
      await pumpApp(tester);
      ({Tone tone, ShapeFamily family}) at(Finder finder) =>
          PageAccent.of(tester.element(finder));

      expect(at(find.byType(DayCard)), (
        tone: Tone.primary,
        family: ShapeFamily.day,
      ));
      await open(tester, 'Schlaf');
      expect(at(find.byType(LatestNightCard)), (
        tone: Tone.tertiary,
        family: ShapeFamily.sleep,
      ));
      await open(tester, 'Aktivität');
      expect(at(find.byType(LatestWorkoutCard)), (
        tone: Tone.secondary,
        family: ShapeFamily.activity,
      ));
      await open(tester, 'Herz');
      expect(at(find.byType(LineChart)), (
        tone: Tone.error,
        family: ShapeFamily.heart,
      ));
    });

    testWidgets('Heute shows what steps and calories are aiming at, and the '
        'hours of the day so far under each', (tester) async {
      await pumpApp(tester);
      Finder inCard(Finder what) =>
          find.descendant(of: find.byType(DayCard), matching: what);
      expect(inCard(find.text('von 10.000 Schritten')), findsOneWidget);
      expect(inCard(find.text('von 500 kcal')), findsOneWidget);
      expect(inCard(find.textContaining('km')), findsNothing);
      final bars = tester.widgetList<HourBars>(inCard(find.byType(HourBars)));
      expect(bars, hasLength(2));
      // Midnight to the hour that is running.
      expect(bars.first.hours, hasLength(fixtureNow.hour + 1));
      expect(bars.first.hours[7], 929);
      // Nothing is left behind the rings.
      expect(
        inCard(
          find.byWidgetPredicate((w) => w is M3EShape && (w.width ?? 0) > 100),
        ),
        findsNothing,
      );
    });

    testWidgets('Heute and Aktivität draw the scene from edge to edge under '
        'an order saved before their first tile existed', (tester) async {
      await pumpApp(
        tester,
        store: _settings(
          '{"edgeToEdgeHero":true,'
          '"tileOrder":{"today":["steps","water"],"activity":["chart"]}}',
        ),
      );
      expect(find.byType(DayBackdrop), findsOneWidget);
      await open(tester, 'Aktivität');
      expect(find.byType(WorkoutBackdrop), findsOneWidget);
    });

    testWidgets('Herz has a scene in its first tile, and gives it to the '
        'page when asked', (tester) async {
      Finder inCard() => find.descendant(
        of: find.byType(TileSurface),
        matching: find.byType(HeartScene),
      );
      await pumpApp(tester);
      await open(tester, 'Herz');
      expect(inCard(), findsOneWidget);
      expect(tester.widget<HeartScene>(inCard()).bpm, 75);

      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, store: _settings('{"edgeToEdgeHero":true}'));
      await open(tester, 'Herz');
      expect(inCard(), findsNothing);
      final rect = tester.getRect(find.byType(HeartScene));
      expect(rect.top, 0);
      expect(rect.width, 412);

      await tester.tap(find.byTooltip('Kacheln anordnen'));
      await advance(tester);
      expect(inCard(), findsOneWidget);
    });

    testWidgets('Herz shows the last rate on the heart, the range beside it '
        'and the curve once', (tester) async {
      await pumpApp(tester);
      await open(tester, 'Herz');
      expect(find.text('Tagesverlauf'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('55 bis 86 bpm'), findsOneWidget);
      expect(find.text('Zuletzt um 15:00'), findsOneWidget);
      // The zones are segments, the one with the most time the loud one.
      final zones = find.byType(SegmentGroup, skipOffstage: false);
      expect(tester.widget<SegmentGroup>(zones).loud, 1);
    });

    testWidgets('Aktivität has the workouts before the latest as cards to '
        'swipe, one of which opens its page', (tester) async {
      await pumpApp(tester);
      await open(tester, 'Aktivität');
      final chips = find.descendant(
        of: find.byType(RecentWorkoutsCard),
        matching: find.byType(CarouselChip, skipOffstage: false),
      );
      expect(chips, findsNWidgets(5));
      await tapInView(tester, chips.first);
      expect(find.byType(WorkoutDetailPage), findsOneWidget);
    });

    for (final (label, backdrop, card, scene) in [
      ('Schlaf', NightBackdrop, LatestNightCard, SleepScene),
      ('Aktivität', WorkoutBackdrop, LatestWorkoutCard, WorkoutScene),
    ]) {
      Finder inCard() =>
          find.descendant(of: find.byType(card), matching: find.byType(scene));

      testWidgets('$label keeps its scene in the tile at first', (
        tester,
      ) async {
        await pumpApp(tester);
        await open(tester, label);
        expect(find.byType(backdrop), findsNothing);
        expect(inCard(), findsOneWidget);
      });

      testWidgets('$label draws its scene from edge to edge when asked, and '
          'gives it back while the page is edited', (tester) async {
        await pumpApp(tester, store: _settings('{"edgeToEdgeHero":true}'));
        await open(tester, label);
        expect(inCard(), findsNothing);
        final rect = tester.getRect(find.byType(backdrop));
        expect(rect.top, 0);
        expect(rect.width, 412);
        expect(
          rect.bottom,
          closeTo(tester.getRect(find.byType(card)).top + 132, 0.5),
        );

        await tester.tap(find.byTooltip('Kacheln anordnen'));
        await advance(tester);
        expect(inCard(), findsOneWidget);
      });
    }

    testWidgets('Schlaf keeps the sky in the tile when the tile is not the '
        'first, and Heute then still has its own', (tester) async {
      await pumpApp(
        tester,
        store: _settings(
          '{"edgeToEdgeHero":true,'
          '"tileOrder":{"sleep":["tonight","hero"]}}',
        ),
      );
      expect(find.byType(DayBackdrop), findsOneWidget);
      await open(tester, 'Schlaf');
      expect(find.byType(NightBackdrop), findsNothing);
    });
  });

  group('the rings of Heute', () {
    List<RingPainter> rings(WidgetTester tester) => [
      for (final paint in tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(DayCard),
          matching: find.byType(CustomPaint),
        ),
      ))
        if (paint.painter case final RingPainter ring) ring,
    ];

    testWidgets('fill again when the page is opened from another one', (
      tester,
    ) async {
      await pumpApp(tester);
      await advance(tester);
      expect(rings(tester).first.value, closeTo(0.7432, 0.01));

      await tester.tap(find.bySemanticsLabel('Schlaf'));
      await advance(tester);
      await tester.tap(find.bySemanticsLabel('Heute'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(rings(tester).first.value, lessThan(0.3));
      await advance(tester);
      expect(rings(tester).first.value, closeTo(0.7432, 0.01));
      expect(rings(tester).last.value, closeTo(0.62, 0.01));
    });

    testWidgets('and the bars fill again when a page above is closed', (
      tester,
    ) async {
      await pumpApp(tester);
      await advance(tester);
      double grown() =>
          (tester
                      .widgetList<CustomPaint>(
                        find.descendant(
                          of: find.byType(HourBars),
                          matching: find.byType(CustomPaint),
                        ),
                      )
                      .first
                      .painter!
                  as HourBarsPainter)
              .grown;
      expect(grown(), closeTo(1, 0.01));

      await tester.tap(find.byType(DayCard));
      await advance(tester);
      expect(find.byType(DayDetailPage), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(rings(tester).first.value, lessThan(0.3));
      expect(grown(), lessThan(0.5));
      await advance(tester);
      expect(rings(tester).first.value, closeTo(0.7432, 0.01));
      expect(grown(), closeTo(1, 0.01));
    });

    testWidgets('are plain arcs below the goal and a travelling wave at it', (
      tester,
    ) async {
      await pumpApp(tester, store: _settings('{"stepGoal":5000}'));
      await advance(tester);
      final [steps, energy] = rings(tester);
      expect(steps.value, 1);
      expect(steps.wave, 1);
      expect(energy.wave, 0);
      final before = steps.travel.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(rings(tester).first.travel.value, isNot(before));
    });

    testWidgets('keep the wave still when animations are off', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpApp(tester, store: _settings('{"stepGoal":5000}'));
      await advance(tester);
      final before = rings(tester).first.travel.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(rings(tester).first.wave, 1);
      expect(rings(tester).first.travel.value, before);
    });

    testWidgets('hold the body age in the type of the numbers beside them', (
      tester,
    ) async {
      await pumpApp(
        tester,
        store: _settings('{"birthDate":"1992-03-07","flexFont":true}'),
      );
      await advance(tester);
      TextStyle? styleOf(String text) => tester
          .widget<Text>(
            find.descendant(
              of: find.byType(DayCard),
              matching: find.text(text),
            ),
          )
          .style;
      final age = find.descendant(
        of: find.byType(DayCard),
        matching: find.textContaining(RegExp(r'^\d\d,\d$')),
      );
      expect(age, findsOneWidget);
      final style = tester.widget<Text>(age).style;
      expect(
        _axis(style, 'wght'),
        closeTo(_axis(styleOf('7.432'), 'wght')!, 1),
      );
      expect(
        _axis(style, 'wdth'),
        closeTo(_axis(styleOf('7.432'), 'wdth')!, 1),
      );
    });
  });

  group('a press', () {
    testWidgets('tightens the corners of a surface', (tester) async {
      Widget surface(double pressed) => themed(
        PressState(
          pressed: pressed,
          child: const TileSurface(
            color: Color(0xFF000000),
            radius: 20,
            child: SizedBox.square(dimension: 80),
          ),
        ),
      );
      BorderRadiusGeometry? corners() =>
          tester.widget<Material>(find.byType(Material).last).borderRadius;
      await tester.pumpWidget(surface(0));
      expect(corners(), BorderRadius.circular(20));
      await tester.pumpWidget(surface(1));
      expect(corners(), BorderRadius.circular(13));
    });

    testWidgets('on the goals tile squeezes its corners and lets them spring '
        'back', (tester) async {
      await pumpApp(tester);
      final card = find.byType(GoalsCard, skipOffstage: false);
      await bringIntoView(tester, card);
      double radius() =>
          (tester
                      .widget<Material>(
                        find
                            .descendant(
                              of: card,
                              matching: find.byType(Material),
                            )
                            .first,
                      )
                      .borderRadius!
                  as BorderRadius)
              .topLeft
              .x;
      expect(radius(), AppRadii.extraLargeIncreased);
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(radius(), lessThan(AppRadii.extraLargeIncreased - 4));
      await gesture.cancel();
      await advance(tester);
      expect(radius(), AppRadii.extraLargeIncreased);
    });
  });

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    for (final language in ['de', 'en', 'pl']) {
      testWidgets('Today and a day render with the flex font and the scene '
          'from edge to edge in $language at ${size.width.round()}', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          repository: FixtureRepository()
            ..historyAccess = true
            ..olderDays = fixtureOlderDays(),
          store: _settings(
            '{"birthDate":"1992-03-07","flexFont":true,"edgeToEdgeHero":true}',
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await advance(tester);
          expect(tester.takeException(), isNull);
        }
        await tester.drag(find.byType(ListView).first, const Offset(0, 9000));
        await advance(tester);
        await tester.tap(find.text(l10n.recovery).first);
        await advance(tester);
        await tester.tap(find.text(l10n.periodYesterday));
        await advance(tester);
        final page = find.byType(DayDetailPage);
        for (var i = 0; i < 6; i++) {
          await tester.drag(
            find.descendant(of: page, matching: find.byType(CustomScrollView)),
            const Offset(0, -500),
          );
          await advance(tester);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('the other pages render with the flex font and the scene '
          'from edge to edge in $language at ${size.width.round()}', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          repository: FixtureRepository()
            ..historyAccess = true
            ..olderDays = fixtureOlderDays(),
          store: _settings(
            '{"birthDate":"1992-03-07","flexFont":true,"edgeToEdgeHero":true}',
          ),
        );
        Future<void> scroll(Finder list) async {
          for (var i = 0; i < 8; i++) {
            await tester.drag(list, const Offset(0, -500));
            await advance(tester);
            expect(tester.takeException(), isNull);
          }
        }

        for (final (page, hero) in [
          (l10n.groupSleep, l10n.lastNight),
          (l10n.groupActivity, l10n.lastActivity),
          (l10n.navHeart, l10n.metricRestingHeartRate),
        ]) {
          await tester.tap(find.bySemanticsLabel(page));
          await advance(tester);
          expect(tester.takeException(), isNull);
          await scroll(find.byType(ListView).first);
          await tester.drag(find.byType(ListView).first, const Offset(0, 9000));
          await advance(tester);
          // The page opened from it.
          await tapInView(tester, find.text(hero).first);
          expect(tester.takeException(), isNull);
          await scroll(find.byType(CustomScrollView).last);
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await advance(tester);
        }

        // Body age, profile and goals.
        await tester.tap(find.bySemanticsLabel(l10n.navToday));
        await advance(tester);
        await tester.tap(find.text(l10n.bodyAge));
        await advance(tester);
        await scroll(find.byType(CustomScrollView).last);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await advance(tester);
        await tester.tap(find.bySemanticsLabel(l10n.profile));
        await advance(tester);
        expect(tester.takeException(), isNull);
        await tapInView(tester, find.text(l10n.goalsOpen));
        await scroll(find.byType(CustomScrollView).last);
      });
    }
  }
}
