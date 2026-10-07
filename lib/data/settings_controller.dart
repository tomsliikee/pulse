import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'json_store.dart';
import 'metric_catalog.dart';
import 'models.dart';

/// The Today tile that shows the latest workout instead of a measurement.
const String workoutTileId = 'workout';

/// A tile of the Today page is named by its metric, or is the workout tile.
bool isTodayTileId(String id) =>
    id == workoutTileId || Metric.byName(id) != null;

/// The large form of a metric tile on another page is saved as
/// "page/metric".
bool _isPageTileId(String id) {
  final parts = id.split('/');
  return parts.length == 2 &&
      parts.first.isNotEmpty &&
      Metric.byName(parts.last) != null;
}

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

/// Whether [date] can be a living user's date of birth.
bool isPlausibleBirthDate(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return date.year >= 1900 && date.isBefore(today);
}

String? _isoDate(DateTime? date) => date == null
    ? null
    : '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

/// Goals, appearance and the order of the tiles on each page. Loaded once at
/// start and saved after every change.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final JsonStore _store;
  bool _disposed = false;

  int _stepGoal = 10000;
  double _sleepGoalHours = 8;
  int _waterGoalMl = 2400;
  int _activeEnergyGoal = 500;
  DateTime? _birthDate;
  Sex? _sex;
  ThemeMode _themeMode = ThemeMode.system;
  bool _dynamicColor = true;
  bool _showAllData = false;
  bool _liquidGlass = false;
  Map<String, List<String>> _tileOrder = {};
  List<String> _todayTiles = defaultTodayTiles;
  Set<String> _largeTiles = defaultLargeTiles;
  Map<String, Set<String>> _hiddenTiles = {};

  int get stepGoal => _stepGoal;
  double get sleepGoalHours => _sleepGoalHours;
  int get waterGoalMl => _waterGoalMl;

  /// The day's goal for active calories, in kcal.
  int get activeEnergyGoal => _activeEnergyGoal;

  /// Date of birth and sex are asked for because Health Connect has
  /// neither; the body age is counted from them.
  DateTime? get birthDate => _birthDate;
  Sex? get sex => _sex;
  ThemeMode get themeMode => _themeMode;

  /// Whether colours follow the system palette when the system offers one.
  bool get dynamicColor => _dynamicColor;

  /// Whether the list of every measurement is appended to the Today page.
  bool get showAllData => _showAllData;

  /// Whether the navigation bar and the tiles are drawn as liquid glass.
  bool get liquidGlass => _liquidGlass;

  /// The saved order of tile ids on [page]; empty if never rearranged.
  List<String> tileOrder(String page) => _tileOrder[page] ?? const [];

  /// The tiles on the Today page. Their order is in [tileOrder].
  List<String> get todayTiles => _todayTiles;

  /// The tiles the user has removed from [page]. The Today page keeps its
  /// own list in [todayTiles] instead.
  Set<String> hiddenTiles(String page) => _hiddenTiles[page] ?? const {};

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
    if (json['activeEnergyGoal'] case final int v when v >= 100 && v <= 3000) {
      _activeEnergyGoal = v;
    }
    if (json['birthDate'] case final String v) {
      final date = DateTime.tryParse(v);
      if (date != null && isPlausibleBirthDate(date)) {
        _birthDate = DateTime(date.year, date.month, date.day);
      }
    }
    if (json['sex'] case final String v) {
      for (final sex in Sex.values) {
        if (sex.name == v) _sex = sex;
      }
    }
    if (json['themeMode'] case final String v) {
      for (final mode in ThemeMode.values) {
        if (mode.name == v) _themeMode = mode;
      }
    }
    if (json['dynamicColor'] case final bool v) _dynamicColor = v;
    if (json['showAllData'] case final bool v) _showAllData = v;
    if (json['liquidGlass'] case final bool v) _liquidGlass = v;
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
      _largeTiles = ids
          .whereType<String>()
          .where((id) => isTodayTileId(id) || _isPageTileId(id))
          .toSet();
    }
    if (json['hiddenTiles'] case final Map<String, Object?> pages) {
      _hiddenTiles = {
        for (final MapEntry(:key, :value) in pages.entries)
          if (value is List<Object?>) key: value.whereType<String>().toSet(),
      };
    }
    notifyListeners();
  }

  void setStepGoal(int value) => _update(() => _stepGoal = value);

  void setSleepGoalHours(double value) =>
      _update(() => _sleepGoalHours = value);

  void setWaterGoalMl(int value) => _update(() => _waterGoalMl = value);

  void setActiveEnergyGoal(int value) =>
      _update(() => _activeEnergyGoal = value);

  void setBirthDate(DateTime? value) => _update(
    () => _birthDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day),
  );

  void setSex(Sex? value) => _update(() => _sex = value);

  void setThemeMode(ThemeMode value) => _update(() => _themeMode = value);

  void setDynamicColor(bool value) => _update(() => _dynamicColor = value);

  void setShowAllData(bool value) => _update(() => _showAllData = value);

  void setLiquidGlass(bool value) => _update(() => _liquidGlass = value);

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

  void hideTile(String page, String id) {
    if (hiddenTiles(page).contains(id)) return;
    _update(
      () => _hiddenTiles = {
        ..._hiddenTiles,
        page: {...hiddenTiles(page), id},
      },
    );
  }

  void showTile(String page, String id) {
    if (!hiddenTiles(page).contains(id)) return;
    _update(
      () => _hiddenTiles = {
        ..._hiddenTiles,
        page: {...hiddenTiles(page)}..remove(id),
      },
    );
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
            'activeEnergyGoal': _activeEnergyGoal,
            'birthDate': ?_isoDate(_birthDate),
            'sex': ?_sex?.name,
            'themeMode': _themeMode.name,
            'dynamicColor': _dynamicColor,
            'showAllData': _showAllData,
            'liquidGlass': _liquidGlass,
            'tileOrder': _tileOrder,
            'todayTiles': _todayTiles,
            'largeTiles': _largeTiles.toList(),
            'hiddenTiles': {
              for (final MapEntry(:key, :value) in _hiddenTiles.entries)
                key: value.toList(),
            },
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
