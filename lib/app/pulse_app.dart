import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../background/morning_notice.dart';
import '../background/supplement_notice.dart';
import '../background/week_notice.dart';
import '../data/health_controller.dart';
import '../data/health_repository.dart';
import '../data/json_store.dart';
import '../data/settings_controller.dart';
import '../data/supplement_controller.dart';
import '../data/weather.dart';
import '../data/weather_controller.dart';
import '../features/week/week_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/system_palette.dart';
import 'app_language.dart';
import 'app_scope.dart';
import 'app_shell.dart';
import 'backup_files.dart';
import 'frame_log.dart';
import 'layout.dart';
import 'morning_notices.dart';

class PulseApp extends StatefulWidget {
  const PulseApp({
    super.key,
    required this.repository,
    required this.store,
    this.paletteLoader = loadSystemPalette,
    this.clock = DateTime.now,
    this.files = const SystemBackupFiles(),
    this.weatherSource = const OpenMeteoWeather(),
  });

  final HealthRepository repository;
  final JsonStore store;
  final SystemPaletteLoader paletteLoader;

  /// Tests pass a fixed time.
  final DateTime Function() clock;
  final BackupFiles files;

  /// Asked only once the profile has a place.
  final WeatherSource weatherSource;

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
  late final WeatherController _weather = WeatherController(
    store: widget.store,
    source: widget.weatherSource,
    clock: widget.clock,
  );
  late final SupplementController _supplements = SupplementController(
    widget.store,
    clock: widget.clock,
  );
  final ValueNotifier<SystemPalette?> _palette = ValueNotifier(null);
  final FrameLog _frames = FrameLog();
  final GlobalKey<NavigatorState> _navigator = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // What can make the app rebuild widely, for the report of slow frames.
    _frames.start();
    _health.addListener(() => _frames.mark('health'));
    _settings.addListener(() => _frames.mark('settings'));
    _settings.addListener(() {
      _health
        ..birthDate = _settings.birthDate
        ..sex = _settings.sex
        ..heightCm = _settings.heightCm
        ..fineValues = _settings.fineValues
        ..stepCounting = _settings.stepCounting;
    });
    _settings.addListener(() => _weather.place = _settings.place);
    _palette.addListener(() => _frames.mark('palette'));
    _health.addListener(_keepMorningAlarm);
    _settings.addListener(_keepMorningAlarm);
    // The alarms speak the app's language, which Android may keep itself.
    _language.addListener(_keepMorningAlarm);
    _supplements.addListener(_keepMorningAlarm);
    _settings.load();
    _supplements.load();
    _language.refresh();
    _health.start();
    _loadPalette();
    _openNotice();
  }

  /// Opens the page a tapped notification was about. The morning's needs
  /// none: its cards open by themselves on the Today page.
  Future<void> _openNotice() async {
    if (await MorningNotices.opened() != 'week' || !mounted) return;
    // Not before the first frame has built the navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigator.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const WeekPage()),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back in the foreground: other apps may have written new data, and the
    // wallpaper or the app's language may have changed in the system.
    if (state == AppLifecycleState.resumed) {
      _frames.mark('resumed');
      _language.refresh();
      _health.refreshIfStale();
      _weather.refresh();
      _loadPalette();
      _openNotice();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // The system's settings may just have set another language for the app.
    _language.refresh();
  }

  bool _alarmBusy = false;
  bool _alarmAgain = false;
  bool _alarmSet = false;

  /// Keeps the alarms for the morning and for the week's report in step
  /// with the nights, the name, the language, the goals and the switches. One at a time: both listeners call often.
  Future<void> _keepMorningAlarm() async {
    if (!_settings.loaded || _health.refreshing) return;
    if (_alarmBusy) {
      _alarmAgain = true;
      return;
    }
    _alarmBusy = true;
    try {
      final changed = await leaveMorningAlarm(
        widget.store,
        settings: {
          'morningBrief': _settings.morningBrief,
          'name': _settings.name,
          'language': _settings.language,
        },
        nights: _health.nights,
        now: widget.clock(),
        language:
            WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      );
      final weekChanged = await leaveWeekAlarm(
        widget.store,
        settings: {
          'weekReport': _settings.weekReport,
          'language': _settings.language,
          'stepGoal': _settings.stepGoal,
          'activeEnergyGoal': _settings.activeEnergyGoal,
          'waterGoalMl': _settings.waterGoalMl,
          'sleepGoalHours': _settings.sleepGoalHours,
        },
        valueOf: _health.valueOn,
        nights: _health.nights,
        now: widget.clock(),
        language:
            WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      );
      final supplementsChanged = await leaveSupplementAlarm(
        widget.store,
        _supplements.data,
        language:
            _settings.language ??
            WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      );
      // Once in every start as well: an alarm does not outlive everything
      // that can happen to the app while it is closed.
      if (changed || weekChanged || supplementsChanged || !_alarmSet) {
        await MorningNotices.schedule();
      }
      _alarmSet = true;
    } finally {
      _alarmBusy = false;
    }
    if (_alarmAgain && mounted) {
      _alarmAgain = false;
      unawaited(_keepMorningAlarm());
    }
  }

  Future<void> _loadPalette() async {
    final palette = await widget.paletteLoader();
    if (mounted) _palette.value = palette;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frames.stop();
    _health.dispose();
    _language.dispose();
    _weather.dispose();
    _supplements.dispose();
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
      weather: _weather,
      supplements: _supplements,
      systemPalette: _palette,
      files: widget.files,
      child: ListenableBuilder(
        listenable: Listenable.merge([_settings, _language, _palette]),
        builder: (context, _) {
          final system = _palette.value;
          final style = _settings.colorStyle;
          final language = _language.forced;
          return MaterialApp(
            navigatorKey: _navigator,
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
            theme: AppTheme.light(style: style, system: system?.light),
            darkTheme: AppTheme.dark(style: style, system: system?.dark),
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
