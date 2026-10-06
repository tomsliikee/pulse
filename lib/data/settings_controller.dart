import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'json_store.dart';
import 'metric_catalog.dart';

/// The Today tile that shows the latest workout instead of a measurement.
const String workoutTileId = 'workout';

/// A tile of the Today page is named by its metric, or is the workout tile.
bool isTodayTileId(String id) =>
    id == workoutTileId || Metric.byName(id) != null;

/// What the Today page shows until the user changes it.
final List<String> defaultTodayTiles = List.unmodifiable([
  Metric.steps.name,
  Metric.heartRate.name,
  Metric.sleep.name,
  Metric.totalEnergy.name,
  Metric.water.name,
  Metric.weight.name,
  Metric.oxygenSaturation.name,
  Metric.energyIntake.name,
  workoutTileId,
]);

final Set<String> defaultLargeTiles = Set.unmodifiable({
  Metric.steps.name,
  Metric.energyIntake.name,
});

/// Goals, appearance and the order of the tiles on each page. Loaded once at
/// start and saved after every change.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final JsonStore _store;
  bool _disposed = false;

  int _stepGoal = 10000;
  double _sleepGoalHours = 8;
  int _waterGoalMl = 2400;
  ThemeMode _themeMode = ThemeMode.system;
  bool _dynamicColor = true;
  bool _showAllData = false;
  Map<String, List<String>> _tileOrder = {};
  List<String> _todayTiles = defaultTodayTiles;
  Set<String> _largeTiles = defaultLargeTiles;

  int get stepGoal => _stepGoal;
  double get sleepGoalHours => _sleepGoalHours;
  int get waterGoalMl => _waterGoalMl;
  ThemeMode get themeMode => _themeMode;

  /// Whether colours follow the system palette when the system offers one.
  bool get dynamicColor => _dynamicColor;

  /// Whether the list of every measurement is appended to the Today page.
  bool get showAllData => _showAllData;

  /// The saved order of tile ids on [page]; empty if never rearranged.
  List<String> tileOrder(String page) => _tileOrder[page] ?? const [];

  /// The tiles on the Today page. Their order is in [tileOrder].
  List<String> get todayTiles => _todayTiles;

  /// Whether the tile [id] is shown in its large form.
  bool isLargeTile(String id) => _largeTiles.contains(id);

  Future<void> load() async {
    final json = await _store.read(StoreKeys.settings);
    if (_disposed || json is! Map<String, Object?>) return;
    if (json['stepGoal'] case final int v when v >= 1000 && v <= 100000) {
      _stepGoal = v;
    }
    if (json['sleepGoalHours'] case final num v when v >= 1 && v <= 16) {
      _sleepGoalHours = v.toDouble();
    }
    if (json['waterGoalMl'] case final int v when v >= 250 && v <= 10000) {
      _waterGoalMl = v;
    }
    if (json['themeMode'] case final String v) {
      for (final mode in ThemeMode.values) {
        if (mode.name == v) _themeMode = mode;
      }
    }
    if (json['dynamicColor'] case final bool v) _dynamicColor = v;
    if (json['showAllData'] case final bool v) _showAllData = v;
    if (json['tileOrder'] case final Map<String, Object?> pages) {
      _tileOrder = {
        for (final MapEntry(:key, :value) in pages.entries)
          if (value is List<Object?>) key: value.whereType<String>().toList(),
      };
    }
    if (json['todayTiles'] case final List<Object?> ids) {
      // toSet drops duplicates and keeps the order.
      _todayTiles = ids
          .whereType<String>()
          .where(isTodayTileId)
          .toSet()
          .toList();
    }
    if (json['largeTiles'] case final List<Object?> ids) {
      _largeTiles = ids.whereType<String>().where(isTodayTileId).toSet();
    }
    notifyListeners();
  }

  void setStepGoal(int value) => _update(() => _stepGoal = value);

  void setSleepGoalHours(double value) =>
      _update(() => _sleepGoalHours = value);

  void setWaterGoalMl(int value) => _update(() => _waterGoalMl = value);

  void setThemeMode(ThemeMode value) => _update(() => _themeMode = value);

  void setDynamicColor(bool value) => _update(() => _dynamicColor = value);

  void setShowAllData(bool value) => _update(() => _showAllData = value);

  void setTileOrder(String page, List<String> order) =>
      _update(() => _tileOrder = {..._tileOrder, page: List.of(order)});

  void addTodayTile(String id) {
    if (!isTodayTileId(id) || _todayTiles.contains(id)) return;
    _update(() => _todayTiles = [..._todayTiles, id]);
  }

  void removeTodayTile(String id) {
    if (!_todayTiles.contains(id)) return;
    _update(() => _todayTiles = [..._todayTiles]..remove(id));
  }

  void toggleTileSize(String id) => _update(
    () => _largeTiles = _largeTiles.contains(id)
        ? ({..._largeTiles}..remove(id))
        : {..._largeTiles, id},
  );

  void _update(VoidCallback change) {
    change();
    notifyListeners();
    // Saving is best effort: a failed write costs a preference, and the
    // value on screen is already the new one.
    unawaited(
      _store
          .write(StoreKeys.settings, {
            'stepGoal': _stepGoal,
            'sleepGoalHours': _sleepGoalHours,
            'waterGoalMl': _waterGoalMl,
            'themeMode': _themeMode.name,
            'dynamicColor': _dynamicColor,
            'showAllData': _showAllData,
            'tileOrder': _tileOrder,
            'todayTiles': _todayTiles,
            'largeTiles': _largeTiles.toList(),
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
