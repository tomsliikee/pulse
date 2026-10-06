import 'package:material_ui/material_ui.dart';

import '../data/health_controller.dart';
import '../data/health_repository.dart';
import '../data/json_store.dart';
import '../data/settings_controller.dart';
import '../theme/app_theme.dart';
import '../theme/system_palette.dart';
import 'app_scope.dart';
import 'app_shell.dart';

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
  final ValueNotifier<SystemPalette?> _palette = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.load();
    _health.start();
    _loadPalette();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back in the foreground: other apps may have written new data and the
    // wallpaper may have changed.
    if (state == AppLifecycleState.resumed) {
      _health.refresh();
      _loadPalette();
    }
  }

  Future<void> _loadPalette() async {
    final palette = await widget.paletteLoader();
    if (mounted) _palette.value = palette;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _health.dispose();
    _settings.dispose();
    _palette.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      health: _health,
      settings: _settings,
      systemPalette: _palette,
      child: ListenableBuilder(
        listenable: Listenable.merge([_settings, _palette]),
        builder: (context, _) {
          final system = _settings.dynamicColor ? _palette.value : null;
          return MaterialApp(
            title: 'Pulse',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(system: system?.light),
            darkTheme: AppTheme.dark(system: system?.dark),
            themeMode: _settings.themeMode,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
