import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/floating_nav_bar.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/features/profile/color_style_row.dart';
import 'package:pulse/features/sleep/sleep_page.dart';
import 'package:pulse/features/today/today_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/theme/app_theme.dart';
import 'package:pulse/theme/color_style.dart';

import 'support/fixtures.dart';

double _hue(Color color) => HSLColor.fromColor(color).hue;

double _hueDistance(Color a, Color b) {
  final d = (_hue(a) - _hue(b)).abs();
  return math.min(d, 360 - d);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

ThemeData _theme(ColorStyle style, Brightness brightness) =>
    brightness == Brightness.dark
    ? AppTheme.dark(style: style)
    : AppTheme.light(style: style);

MemoryJsonStore _settings(String json) =>
    MemoryJsonStore()..documents['settings'] = json;

void main() {
  setUpAll(loadAppFont);

  group('the schemes', () {
    for (final brightness in Brightness.values) {
      test('keep the primary at the hue of the seed in ${brightness.name}', () {
        for (final style in ColorStyle.values) {
          final seed = style.seed;
          if (seed == null) continue;
          final scheme = _theme(style, brightness).colorScheme;
          expect(
            _hueDistance(scheme.primary, seed),
            lessThan(30),
            reason: style.name,
          );
        }
      });

      test('keep what is written readable in ${brightness.name}', () {
        final schemes = [
          for (final style in ColorStyle.values)
            if (style.seed != null) _theme(style, brightness).colorScheme,
          for (final tone in Tone.values)
            _theme(
              ColorStyle.colourful,
              brightness,
            ).extension<PageSchemes>()!.of(tone).colorScheme,
        ];
        for (final scheme in schemes) {
          for (final (on, ground) in [
            (scheme.onPrimary, scheme.primary),
            (scheme.onPrimaryContainer, scheme.primaryContainer),
            (scheme.onSecondaryContainer, scheme.secondaryContainer),
            (scheme.onTertiaryContainer, scheme.tertiaryContainer),
            (scheme.onSurface, scheme.surface),
            (scheme.onSurfaceVariant, scheme.surfaceContainer),
          ]) {
            expect(_contrast(on, ground), greaterThanOrEqualTo(4.5));
          }
        }
      });
    }

    test('are the standard style where the wallpaper gives none', () {
      expect(
        AppTheme.light(style: ColorStyle.wallpaper),
        same(AppTheme.light(style: ColorStyle.standard)),
      );
      final system = ColorScheme.fromSeed(seedColor: const Color(0xFF00FF00));
      expect(
        AppTheme.light(style: ColorStyle.wallpaper, system: system).colorScheme,
        system,
      );
      // A chosen colour is not replaced by the wallpaper's.
      expect(
        AppTheme.light(style: ColorStyle.pink, system: system),
        same(AppTheme.light(style: ColorStyle.pink)),
      );
    });

    test('give every page a colour of its own in the colourful style', () {
      final pages = AppTheme.light(style: ColorStyle.colourful)
          .extension<PageSchemes>()!;
      final primaries = {
        for (final tone in [
          Tone.primary,
          Tone.secondary,
          Tone.tertiary,
          Tone.error,
        ])
          pages.of(tone).colorScheme.primary,
      };
      expect(primaries, hasLength(4));
      expect(pages.of(Tone.neutral), same(pages.of(Tone.primary)));
      expect(AppTheme.light().extension<PageSchemes>(), isNull);
    });

    test('give every element a colour of its own in the mixed style', () {
      for (final brightness in Brightness.values) {
        final scheme = _theme(ColorStyle.mixed, brightness).colorScheme;
        final pages = _theme(
          ColorStyle.colourful,
          brightness,
        ).extension<PageSchemes>()!;
        // The same four colours as the pages', in one scheme.
        expect(scheme.primary, pages.of(Tone.primary).colorScheme.primary);
        expect(scheme.secondary, pages.of(Tone.secondary).colorScheme.primary);
        expect(scheme.tertiary, pages.of(Tone.tertiary).colorScheme.primary);
        expect(scheme.error, pages.of(Tone.error).colorScheme.primary);
        for (final tone in Tone.values) {
          final colors = scheme.tone(tone);
          expect(
            _contrast(colors.onContainer, colors.container),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(colors.onAccent, colors.accent),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
      expect(
        AppTheme.light(style: ColorStyle.mixed).extension<PageSchemes>(),
        isNull,
      );
    });
  });

  group('the setting', () {
    test('reads the old switch for the wallpaper as a style', () async {
      for (final (json, style) in [
        ('{"dynamicColor":true}', ColorStyle.wallpaper),
        ('{"dynamicColor":false}', ColorStyle.standard),
        ('{}', ColorStyle.wallpaper),
        ('{"dynamicColor":true,"colorStyle":"green"}', ColorStyle.green),
        ('{"colorStyle":"nothing"}', ColorStyle.wallpaper),
      ]) {
        final settings = SettingsController(_settings(json));
        await settings.load();
        expect(settings.colorStyle, style, reason: json);
      }
    });
  });

  group('the row of colours', () {
    for (final language in ['de', 'en', 'pl']) {
      for (final size in const [Size(360, 640), Size(412, 915)]) {
        testWidgets('offers every style in $language at ${size.width}', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(Locale(language));
          await pumpApp(tester, size: size, locale: Locale(language));
          await tester.tap(find.bySemanticsLabel(l10n.profile));
          await advance(tester);
          await bringIntoView(tester, find.byType(ColorStyleRow));

          // The tests have no wallpaper palette, so its dot is not there.
          expect(find.bySemanticsLabel(l10n.colorWallpaper), findsNothing);
          for (final style in ColorStyle.values) {
            if (style == ColorStyle.wallpaper) continue;
            expect(find.bySemanticsLabel(style.label(l10n)), findsAtLeast(1));
          }
          expect(
            find.descendant(
              of: find.byType(ColorStyleRow),
              matching: find.text(l10n.colorBlue),
            ),
            findsOneWidget,
          );
        });
      }
    }

    testWidgets('paints the app in the colour that is tapped', (tester) async {
      final app = await pumpApp(tester);
      final l10n = lookupAppLocalizations(const Locale('de'));
      await tester.tap(find.bySemanticsLabel(l10n.profile));
      await advance(tester);
      await tapInView(tester, find.bySemanticsLabel(l10n.colorGreen));

      final row = tester.element(find.byType(ColorStyleRow));
      expect(
        Theme.of(row).colorScheme.primary,
        AppTheme.light(style: ColorStyle.green).colorScheme.primary,
      );
      expect(app.store.documents['settings'], contains('"colorStyle":"green"'));
    });

    testWidgets('gives a page its own theme in the colourful style, and the '
        'bar follows it', (tester) async {
      await pumpApp(tester, store: _settings('{"colorStyle":"colourful"}'));
      final l10n = lookupAppLocalizations(const Locale('de'));
      final pages = AppTheme.light(style: ColorStyle.colourful)
          .extension<PageSchemes>()!;
      Color primaryAt(Finder finder) =>
          Theme.of(tester.element(finder)).colorScheme.primary;

      final day = pages.of(Tone.primary).colorScheme.primary;
      final sleep = pages.of(Tone.tertiary).colorScheme.primary;
      expect(day, isNot(sleep));
      expect(primaryAt(find.byType(TodayPage)), day);
      expect(primaryAt(find.byType(FloatingNavBar)), day);

      await tester.tap(find.bySemanticsLabel(l10n.groupSleep));
      await advance(tester);
      expect(primaryAt(find.byType(SleepPage)), sleep);
      expect(primaryAt(find.byType(FloatingNavBar)), sleep);
    });
  });
}
