import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/features/age/body_age_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/floating_surface.dart';
import 'package:pulse/widgets/page_header.dart';
import 'package:pulse/widgets/sub_page.dart';

import 'support/fixtures.dart';

const double _statusBar = 48;

Future<MemoryJsonStore> _store({bool glass = false}) async {
  final store = MemoryJsonStore();
  await store.write(StoreKeys.settings, {
    'birthDate': '1992-03-07',
    'sex': 'male',
    'liquidGlass': glass,
  });
  return store;
}

/// Gives the screen a status bar, as a phone has one.
void _addStatusBar(WidgetTester tester) {
  tester.view.padding = FakeViewPadding(
    top: _statusBar * tester.view.devicePixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

Finder _onAgePage(Finder finder) =>
    find.descendant(of: find.byType(BodyAgePage), matching: finder);

final Finder _pencilIcon = find.byIcon(Icons.edit_rounded);

/// The round surface the pencil floats on.
final Finder _pencil = find.ancestor(
  of: _pencilIcon,
  matching: find.byType(FloatingSurface),
);

void main() {
  setUpAll(loadAppFont);

  for (final glass in [false, true]) {
    final look = glass ? 'glass' : 'solid';

    testWidgets('a sub page shows its $look title pill only once the large '
        'title has scrolled away', (tester) async {
      await pumpApp(tester, store: await _store(glass: glass));
      await tester.tap(find.bySemanticsLabel(RegExp('Körperalter')));
      await advance(tester);
      final title = _onAgePage(find.text('Körperalter'));
      expect(find.byType(AppBar), findsNothing);
      expect(title, findsOneWidget);

      await tester.drag(
        _onAgePage(find.byType(CustomScrollView)),
        const Offset(0, -300),
      );
      await advance(tester);
      final pill = find.descendant(
        of: find.byType(FloatingSurface),
        matching: find.text('Körperalter'),
      );
      expect(pill, findsOneWidget);
      // Next to the back button, in its row.
      final button = tester.getRect(find.byType(BackButton));
      expect(tester.getRect(pill).left, greaterThan(button.right));
      expect(tester.getRect(pill).center.dy, closeTo(button.center.dy, 1));

      await tester.drag(
        _onAgePage(find.byType(CustomScrollView)),
        const Offset(0, 2000),
      );
      await advance(tester);
      expect(pill, findsNothing);
      expect(title, findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await advance(tester);
      expect(find.byType(BodyAgePage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a sub page starts below the status bar and scrolls behind it', (
    tester,
  ) async {
    await pumpApp(tester, store: await _store());
    _addStatusBar(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('Körperalter')));
    await advance(tester);
    final title = _onAgePage(find.text('Körperalter'));
    final button = tester.getRect(find.byType(BackButton));
    expect(button.top, _statusBar + SubPage.buttonTop);
    expect(tester.getRect(title).top, greaterThan(button.bottom));

    await tester.drag(
      _onAgePage(find.byType(CustomScrollView)),
      const Offset(0, -80),
    );
    await advance(tester);
    expect(tester.getRect(title).top, lessThan(_statusBar + 56));
    expect(tester.getRect(find.byType(BackButton)), button);
  });

  testWidgets('a top-level page starts below the status bar and scrolls '
      'behind it, under the floating pencil and profile', (tester) async {
    await pumpApp(tester, store: await _store());
    _addStatusBar(tester);
    await advance(tester);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final title = find.descendant(
      of: find.byType(PageHeader),
      matching: find.text('Heute'),
    );
    final profile = find.bySemanticsLabel('Profil');
    expect(tester.getRect(title).top, greaterThanOrEqualTo(_statusBar));
    final pencil = tester.getRect(_pencil);
    final profileAt = tester.getRect(profile);
    expect(pencil.top, _statusBar + SubPage.buttonTop);
    expect(profileAt.right, width - 16);
    expect(pencil.right, lessThan(profileAt.left));
    expect(profileAt.center.dy, closeTo(pencil.center.dy, 1));

    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await advance(tester);
    // Above the list's own edge a finder takes it for hidden; it is painted
    // all the same, because the list does not clip.
    final scrolled = find.descendant(
      of: find.byType(PageHeader, skipOffstage: false),
      matching: find.text('Heute', skipOffstage: false),
    );
    expect(tester.getRect(scrolled).top, lessThan(_statusBar));
    expect(
      tester.widget<ListView>(find.byType(ListView).first).clipBehavior,
      Clip.none,
    );
    expect(tester.getRect(_pencil), pencil);
    expect(tester.getRect(profile), profileAt);

    // Both still work down there.
    await tester.tap(_pencil);
    await advance(tester);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check_rounded));
    await advance(tester);
    expect(_pencilIcon, findsOneWidget);
    await tester.tap(profile);
    await advance(tester);
    expect(find.text('Ziele'), findsOneWidget);
  });

  testWidgets('without a profile button the pencil floats at the right edge', (
    tester,
  ) async {
    await pumpApp(tester, store: await _store());
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final destination in ['Aktivität', 'Schlaf', 'Herz']) {
      await tester.tap(find.bySemanticsLabel(destination));
      await advance(tester);
      expect(tester.getRect(_pencil).right, width - 16, reason: destination);
    }
  });

  for (final language in ['de', 'en', 'pl']) {
    testWidgets(
      'at 360 px no $language title lies under the floating buttons',
      (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(
          tester,
          size: const Size(360, 640),
          locale: Locale(language),
          store: await _store(),
        );
        Future<void> check(String title) async {
          final text = find.descendant(
            of: find.byType(PageHeader),
            matching: find.text(title),
          );
          expect(
            tester.getRect(text).right,
            lessThanOrEqualTo(tester.getRect(_pencil).left),
            reason: title,
          );
        }

        await check(l10n.navToday);
        for (final destination in [
          l10n.groupActivity,
          l10n.groupSleep,
          l10n.navHeart,
        ]) {
          await tester.tap(find.bySemanticsLabel(destination));
          await advance(tester);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a long title is cut short in the pill at 360 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const title = 'Zmienność rytmu serca podczas snu w ostatnich nocach';
    await tester.pumpWidget(
      themed(
        const SubPage(title: title, child: SizedBox(height: 2000)),
        locale: const Locale('pl'),
      ),
    );
    await advance(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await advance(tester);
    final pill = find.byType(FloatingSurface).last;
    expect(
      find.descendant(of: pill, matching: find.text(title)),
      findsOneWidget,
    );
    expect(tester.getRect(pill).right, lessThanOrEqualTo(360 - 16));
    expect(tester.takeException(), isNull);
  });
}
