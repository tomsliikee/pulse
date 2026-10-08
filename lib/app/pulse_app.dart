import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/health_controller.dart';
import '../data/health_repository.dart';
import '../data/json_store.dart';
import '../data/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/system_palette.dart';
import 'app_language.dart';
import 'app_scope.dart';
import 'app_shell.dart';
import 'layout.dart';

class PulseApp extends StatefulWidget {
  const PulseApp({
    super.key,
    required this.repository,
    required this.store,
    this.paletteLoader = loadSystemPalette,
    this.clock = DateTime.now,
  });

  final HealthRepository repository;
  final JsonStore store;
  final SystemPaletteLoader paletteLoader;

  /// Tests pass a fixed time.
  final DateTime Function() clock;

  @override
  State<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends State<PulseApp> with WidgetsBindingObserver {
  late final HealthController _health = HealthController(
    repository: widget.repository,
    store: widget.store,
    clock: widget.clock,
  );
  late final SettingsController _settings = SettingsController(widget.store);
  late final LanguageController _language = LanguageController(_settings);
  final ValueNotifier<SystemPalette?> _palette = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.load();
    _language.refresh();
    _health.start();
    _loadPalette();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back in the foreground: other apps may have written new data, and the
    // wallpaper or the app's language may have changed in the system.
    if (state == AppLifecycleState.resumed) {
      _language.refresh();
      _health.refreshIfStale();
      _loadPalette();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // The system's settings may just have set another language for the app.
    _language.refresh();
  }

  Future<void> _loadPalette() async {
    final palette = await widget.paletteLoader();
    if (mounted) _palette.value = palette;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _health.dispose();
    _language.dispose();
    _settings.dispose();
    _palette.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      health: _health,
      settings: _settings,
      language: _language,
      systemPalette: _palette,
      child: ListenableBuilder(
        listenable: Listenable.merge([_settings, _language, _palette]),
        builder: (context, _) {
          final system = _settings.dynamicColor ? _palette.value : null;
          final language = _language.forced;
          return MaterialApp(
            navigatorObservers: [appRouteObserver],
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            locale: language == null ? null : Locale(language),
            // The first entry is used when the system's language is not offered.
            supportedLocales: [for (final code in appLanguages) Locale(code)],
            // Not the generated list: that one names the SDK's Material
            // translations, and the app's widgets come from material_ui.
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(system: system?.light),
            darkTheme: AppTheme.dark(system: system?.dark),
            themeMode: _settings.themeMode,
            // No page has an app bar, so the status bar is styled here: clear,
            // with icons that stand out from the theme.
            builder: (context, child) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              return FlexType(
                enabled: _settings.flexFont,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value:
                      (dark
                              ? SystemUiOverlayStyle.light
                              : SystemUiOverlayStyle.dark)
                          .copyWith(
                            statusBarColor: Colors.transparent,
                            systemNavigationBarColor: Colors.transparent,
                          ),
                  child: child!,
                ),
              );
            },
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
