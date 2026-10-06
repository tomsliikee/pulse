import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../data/health_controller.dart';
import '../data/settings_controller.dart';
import '../theme/system_palette.dart';

/// Hands the app-wide controllers down the tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.health,
    required this.settings,
    required this.systemPalette,
    required super.child,
  });

  final HealthController health;
  final SettingsController settings;
  final ValueListenable<SystemPalette?> systemPalette;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      health != oldWidget.health ||
      settings != oldWidget.settings ||
      systemPalette != oldWidget.systemPalette;
}
