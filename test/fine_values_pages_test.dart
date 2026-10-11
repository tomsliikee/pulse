import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/app_scope.dart';
import 'package:pulse/data/energy_balance.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/features/detail/energy_balance_card.dart';
import 'package:pulse/features/detail/metric_detail_page.dart';
import 'package:pulse/features/detail/metric_spec.dart';
import 'package:pulse/features/profile/profile_page.dart';
import 'package:pulse/features/today/today_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

const _profile = {'birthDate': '1992-03-07', 'sex': 'male', 'heightCm': 180};

Future<MemoryJsonStore> _storeWith(Map<String, Object?> settings) async {
  final store = MemoryJsonStore();
  await store.write('settings', settings);
  return store;
}

Future<void> _scrollThrough(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  for (final language in const ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      final label = '$language at ${size.width.round()}x${size.height.round()}';

      testWidgets('every page renders with the fine values in $label', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          store: await _storeWith({
            ..._profile,
            'fineValues': true,
            'showAllData': true,
          }),
        );
        final health = AppScope.of(tester.element(find.byType(TodayPage)))
            .health;
        expect(health.fineValues, isTrue);
        expect(
          health.value(Metric.activeEnergy),
          health.snapshot.value(
            Metric.fineActiveEnergy,
            health.snapshot.dayCount - 1,
          ),
        );
        // The calories on the page say which way they are counted.
        expect(find.textContaining(' · ${l10n.valuesFine}'), findsOneWidget);
        await _scrollThrough(tester);
        expect(tester.takeException(), isNull);

        // The three metrics say how they are counted now.
        for (final (metric, note) in [
          (Metric.activeEnergy, l10n.fineActiveNote),
          (Metric.totalEnergy, l10n.fineTotalNote),
          (Metric.intensityMinutes, l10n.fineIntensityNote),
        ]) {
          await tapInView(tester, find.text(metric.title(l10n)).last);
          expect(find.byType(MetricDetailPage), findsOneWidget);
          await tester.drag(
            find.byType(CustomScrollView).last,
            const Offset(0, -4000),
          );
          await advance(tester);
          expect(find.text(note, skipOffstage: false), findsOneWidget);
          // The active energy of the day says what it is made of.
          for (final part in [
            l10n.finePartsTitle,
            l10n.finePartWorkouts,
            l10n.finePartSteps,
          ]) {
            expect(
              find.text(part, skipOffstage: false),
              metric == Metric.activeEnergy ? findsOneWidget : findsNothing,
              reason: '$metric $part',
            );
          }
          // The total says what the real burn would need.
          expect(
            find.byType(EnergyBalanceCard, skipOffstage: false),
            metric == Metric.totalEnergy ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull, reason: '$metric');
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await advance(tester);
        }

        for (final destination in [
          l10n.groupActivity,
          l10n.groupSleep,
          l10n.navHeart,
        ]) {
          await tester.tap(find.bySemanticsLabel(destination));
          await advance(tester);
          await _scrollThrough(tester);
          expect(tester.takeException(), isNull, reason: destination);
        }
      });

      testWidgets('the profile switches between coarse and fine in $label', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language));
        // No sex in the profile, so the energy cannot be worked out.
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          store: await _storeWith({'birthDate': '1992-03-07'}),
        );
        await tester.tap(find.bySemanticsLabel(l10n.profile));
        await advance(tester);
        final scope = AppScope.of(tester.element(find.byType(ProfilePage)));
        await bringIntoView(tester, find.text(l10n.valuesCoarseNote));
        expect(find.text(l10n.valuesFineNote), findsNothing);

        await tapInView(tester, find.text(l10n.valuesFine).first);
        expect(scope.settings.fineValues, isTrue);
        expect(scope.health.fineValues, isTrue);
        expect(find.text(l10n.valuesFineNote), findsOneWidget);
        expect(find.text(l10n.valuesFineMissing(l10n.sex)), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tapInView(tester, find.text(l10n.valuesCoarse).first);
        expect(scope.settings.fineValues, isFalse);
        expect(scope.health.fineValues, isFalse);
        expect(find.text(l10n.valuesCoarseNote), findsOneWidget);
        expect(find.byType(M3EToggleButtonGroup), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final language in const ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      testWidgets('the real burn renders with and without its data in '
          '$language at ${size.width.round()}', (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Future<void> show(EnergyBalance balance) async {
          await tester.pumpWidget(
            themed(
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: EnergyBalanceCard(balance: balance),
              ),
              locale: Locale(language),
            ),
          );
          await advance(tester);
          expect(find.text(l10n.balanceTitle), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        await show(
          const EnergyBalance(
            foodDays: 9,
            weighIns: 2,
            weighedEarly: false,
            weighedLate: true,
          ),
        );
        expect(find.text(l10n.balanceIntro(balanceDays)), findsOneWidget);
        expect(
          find.text(l10n.balanceFoodDays(9, balanceFoodDays)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.balanceWeighIns(2, balanceWeighIns)),
          findsOneWidget,
        );

        await show(
          const EnergyBalance(
            foodDays: 28,
            weighIns: 12,
            weighedEarly: true,
            weighedLate: true,
            eaten: 2412,
            kgPerWeek: -0.43,
            source: 3240,
            fine: 2905,
          ),
        );
        expect(find.text(l10n.balanceIntro(balanceDays)), findsNothing);
        expect(find.text(l10n.balanceSource), findsOneWidget);
        expect(find.text(l10n.balanceFine), findsOneWidget);
        expect(find.text(l10n.balancePerDay(balanceDays)), findsOneWidget);
      });
    }
  }

  testWidgets('a workout shows its fine energy in the fine mode', (
    tester,
  ) async {
    await pumpApp(
      tester,
      store: await _storeWith({..._profile, 'fineValues': true}),
    );
    final health = AppScope.of(tester.element(find.byType(TodayPage))).health;
    final shown = health.workouts.last;
    health.fineValues = false;
    final read = health.workouts.last;
    expect(read.fineKcal, isNotNull);
    expect(shown.kcal, read.fineKcal);
    expect(read.kcal, isNot(read.fineKcal));
  });
}
