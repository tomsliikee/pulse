import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'body_age.dart' show ageOn;
import 'fine_values.dart';
import 'goals.dart';
import 'health_history.dart' show dayKey;
import 'json_store.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'step_counting.dart';
import 'weather.dart';
import '../theme/color_style.dart';

/// The Today tile that shows the latest workout instead of a measurement.
const String workoutTileId = 'workout';

/// The Today tiles about the day as a whole: its scene and score, the
/// hints, last night, the goals and the days before.
const String dayTileId = 'hero';
const String tipsTileId = 'tips';
const String nightTileId = 'lastNight';
const String goalsTileId = 'goals';
const String daysTileId = 'recentDays';

/// The Today tile that says good morning and opens the morning's cards.
const String morningTileId = 'morning';

/// The Today tile that says the week's report is ready, and the one that
/// leads to what goes together in the user's numbers.
const String weekTileId = 'week';
const String linksTileId = 'links';

/// The Today tile of the supplements taken and open today, and the one of
/// the day's caffeine.
const String supplementsTileId = 'supplements';
const String caffeineTileId = 'caffeine';

/// The tiles that came with the reworked Today page, and where they go on a
/// page that was arranged before: these to the top, in this order.
const List<String> _dayTilesOnTop = [
  dayTileId,
  tipsTileId,
  nightTileId,
  goalsTileId,
];

/// Counts the changes to what a saved [SettingsController.todayTiles]
/// means; see [SettingsController.load].
const int _todayTilesVersion = 5;

/// A tile of the Today page is named by its metric, or is one of the tiles
/// that show no single measurement.
bool isTodayTileId(String id) =>
    id == workoutTileId ||
    id == daysTileId ||
    id == morningTileId ||
    id == weekTileId ||
    id == linksTileId ||
    id == supplementsTileId ||
    id == caffeineTileId ||
    _dayTilesOnTop.contains(id) ||
    Metric.byName(id) != null;

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
  // Below the day's tile: only as the first one does that give its scene to
  // the page.
  dayTileId,
  morningTileId,
  weekTileId,
  ..._dayTilesOnTop.skip(1),
  linksTileId,
  workoutTileId,
  Metric.steps.name,
  Metric.heartRate.name,
  Metric.water.name,
  Metric.totalEnergy.name,
  Metric.weight.name,
  Metric.oxygenSaturation.name,
  Metric.energyIntake.name,
  supplementsTileId,
  daysTileId,
]);

final Set<String> defaultLargeTiles = Set.unmodifiable({
  Metric.energyIntake.name,
});

/// The languages the app is translated into. The first is shown when the
/// system's language is none of them.
const List<String> appLanguages = ['en', 'de', 'pl'];

/// Whether [date] can be a living user's date of birth.
/// The birth date in the saved settings [json], if there is a plausible one.
DateTime? savedBirthDate(Object? json) {
  if (json is! Map<String, Object?>) return null;
  if (json['birthDate'] case final String v) {
    final date = DateTime.tryParse(v);
    if (date != null && isPlausibleBirthDate(date)) {
      return DateTime(date.year, date.month, date.day);
    }
  }
  return null;
}

/// What the fine values need of the profile in the saved settings [json],
/// if it holds a birth date.
FineProfile? savedFineProfile(
  Object? json,
  DateTime now, {
  double? weightKg,
  Set<String> removedWorkouts = const {},
}) {
  final birthDate = savedBirthDate(json);
  if (birthDate == null || json is! Map<String, Object?>) return null;
  return FineProfile(
    age: ageOn(birthDate, now).floorToDouble(),
    sex: switch (json['sex']) {
      'female' => Sex.female,
      'male' => Sex.male,
      _ => null,
    },
    heightCm: switch (json['heightCm']) {
      final int v when v >= minHeightCm && v <= maxHeightCm => v,
      _ => null,
    },
    weightKg: weightKg,
    removedWorkouts: removedWorkouts,
  );
}

bool isPlausibleBirthDate(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return date.year >= 1900 && date.isBefore(today);
}

/// The longest name the profile accepts.
const int maxNameLength = 30;

/// What the background task needs to say good morning, from the saved
/// settings [json]: whether it may, the name and the language.
({bool on, String? name, String? language}) savedMorning(Object? json) {
  if (json is! Map<String, Object?>) {
    return (on: true, name: null, language: null);
  }
  return (
    on: json['morningBrief'] != false,
    name: switch (json['name']) {
      final String name when name.isNotEmpty => name,
      _ => null,
    },
    language: switch (json['language']) {
      final String language when appLanguages.contains(language) => language,
      _ => null,
    },
  );
}

/// The heights the profile accepts, in cm.
const int minHeightCm = 100;
const int maxHeightCm = 250;

/// The lightest and the heaviest weight the profile accepts as a target.
const double minTargetWeightKg = 20;
const double maxTargetWeightKg = 400;

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
  bool _loaded = false;

  /// Whether the saved settings have been read.
  bool get loaded => _loaded;

  int _stepGoal = 10000;
  double _sleepGoalHours = 8;
  int _waterGoalMl = 2400;
  int _activeEnergyGoal = 500;
  DateTime? _birthDate;
  Sex? _sex;
  int? _heightCm;
  double? _targetWeightKg;
  String? _name;
  Place? _place;
  bool _morningBrief = true;
  bool _morningTileAllDay = false;
  bool _weekReport = true;
  bool _dayNotice = false;
  bool _liveMorning = false;
  bool _liveSupplements = false;
  bool _liveWeek = false;
  bool _liveDay = false;
  bool _routeSplits = true;
  bool _routeClimb = true;
  bool _routeOnTiles = true;
  bool _fineValues = false;
  StepCounting _stepCounting = StepCounting.store;
  bool _simple = false;
  int? _morningSeen;
  ThemeMode _themeMode = ThemeMode.system;
  ColorStyle _colorStyle = ColorStyle.wallpaper;
  bool _showAllData = false;
  bool _liquidGlass = false;
  bool _edgeToEdgeHero = false;
  bool _flexFont = false;
  bool _mascot = false;
  bool _calm = false;
  bool _expressive = false;
  bool _haptics = true;
  bool _introDone = true;
  String? _language;
  Map<String, List<String>> _tileOrder = {};
  List<String> _todayTiles = defaultTodayTiles;
  Set<String> _largeTiles = defaultLargeTiles;
  Map<String, Set<String>> _hiddenTiles = {};
  List<Goal> _goals = defaultGoals;
  Map<Goal, double> _goalTargets = {};

  int get stepGoal => _stepGoal;
  double get sleepGoalHours => _sleepGoalHours;
  int get waterGoalMl => _waterGoalMl;

  /// The day's goal for active calories, in kcal.
  int get activeEnergyGoal => _activeEnergyGoal;

  /// Date of birth and sex are asked for because Health Connect has
  /// neither; the body age is counted from them.
  DateTime? get birthDate => _birthDate;
  Sex? get sex => _sex;

  /// The height as typed into the profile, for when the store holds none.
  int? get heightCm => _heightCm;

  /// The weight the user wants to reach; null where none is set.
  double? get targetWeightKg => _targetWeightKg;
  ThemeMode get themeMode => _themeMode;

  /// Whether colours follow the system palette when the system offers one.
  /// What the app calls the user; null when none was given.
  String? get name => _name;

  /// Where the weather is asked for; null means no weather and no network.
  Place? get place => _place;

  /// Whether the app says good morning by itself.
  bool get morningBrief => _morningBrief;

  /// Whether the app says on Sunday evening that the week's report is
  /// ready: with a tile on the Today page and a notification.
  bool get weekReport => _weekReport;

  /// A notification with the day's score at nine in the evening.
  bool get dayNotice => _dayNotice;

  /// Which notifications stay on top as live messages until they are swiped
  /// away or the app is opened. Read by the platform from the saved file.
  bool get liveMorning => _liveMorning;
  bool get liveSupplements => _liveSupplements;
  bool get liveWeek => _liveWeek;
  bool get liveDay => _liveDay;

  /// Whether a workout with a route shows the time of each kilometre.
  bool get routeSplits => _routeSplits;

  /// Whether it shows what it climbed, and the line of its altitude.
  bool get routeClimb => _routeClimb;

  /// Whether the tiles and rows of workouts show the line of their route.
  bool get routeOnTiles => _routeOnTiles;

  /// Whether the Today page keeps the morning's tile after the morning.
  bool get morningTileAllDay => _morningTileAllDay;

  /// Whether active energy, total energy and intensity minutes are shown as
  /// the app works them out itself, more strictly than the sources do.
  bool get fineValues => _fineValues;

  /// How the steps are counted where several sources wrote them.
  StepCounting get stepCounting => _stepCounting;

  /// Whether the large cards of the four main pages show their few most
  /// important numbers only. Tiles and detail pages show all in both modes.
  bool get simple => _simple;

  /// The day (as a day key) the morning's cards last opened by themselves.
  int? get morningSeen => _morningSeen;

  ColorStyle get colorStyle => _colorStyle;

  /// Whether the list of every measurement is appended to the Today page.
  bool get showAllData => _showAllData;

  /// Whether the navigation bar and the tiles are drawn as liquid glass.
  bool get liquidGlass => _liquidGlass;

  /// Whether the scene of a main page runs to the edges of the screen
  /// instead of sitting in a card.
  bool get edgeToEdgeHero => _edgeToEdgeHero;

  /// Whether the type uses the axes of the variable font: width, weight,
  /// slant and grade. Off, the font is a plain typeface.
  bool get flexFont => _flexFont;

  /// Whether the scenes show the turtle instead of the stick figure.
  bool get mascot => _mascot;

  /// Whether the scenes, with their figures, are left out: the heroes keep
  /// their numbers and nothing on them moves.
  bool get calm => _calm;

  /// Whether the app wears the expressive rework: wide type, more shapes,
  /// large headers.
  bool get expressive => _expressive;

  /// Whether the app gives haptic signals.
  bool get haptics => _haptics;

  /// Whether the introduction of the first start is over. False only on a
  /// new installation that has not been through it.
  bool get introDone => _introDone;

  /// The chosen language, or null to follow the system. Only used where the
  /// system keeps no language per app; see `LanguageController`.
  String? get language => _language;

  /// The saved order of tile ids on [page]; empty if never rearranged.
  List<String> tileOrder(String page) => _tileOrder[page] ?? const [];

  /// The tiles on the Today page. Their order is in [tileOrder].
  List<String> get todayTiles => _todayTiles;

  /// The tiles the user has removed from [page]. The Today page keeps its
  /// own list in [todayTiles] instead.
  Set<String> hiddenTiles(String page) => _hiddenTiles[page] ?? const {};

  /// The goals the user follows, in the order of the catalog.
  List<Goal> get goals => _goals;

  bool isGoalOn(Goal goal) => _goals.contains(goal);

  /// What [goal] is to reach, in the goal's own unit. Steps, active
  /// calories, sleep and water keep the targets they always had, which the
  /// rings, the day score and the body age read as well.
  double goalTarget(Goal goal) => switch (goal) {
    Goal.steps => _stepGoal.toDouble(),
    Goal.activeEnergy => _activeEnergyGoal.toDouble(),
    Goal.sleepDuration => _sleepGoalHours,
    Goal.water => _waterGoalMl / 1000,
    _ => _goalTargets[goal] ?? goal.defaultTarget,
  };

  /// Whether the tile [id] is shown in its large form.
  bool isLargeTile(String id) => _largeTiles.contains(id);

  Future<void> load() async {
    final json = await _store.read(StoreKeys.settings);
    if (_disposed) return;
    _loaded = true;
    if (json is! Map<String, Object?>) {
      // Nothing saved yet: a new installation starts with the few numbers.
      // One that saved its settings before the mode existed keeps them all.
      _simple = true;
      _introDone = false;
      notifyListeners();
      return;
    }
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
    _birthDate = savedBirthDate(json) ?? _birthDate;
    if (json['sex'] case final String v) {
      for (final sex in Sex.values) {
        if (sex.name == v) _sex = sex;
      }
    }
    if (json['heightCm'] case final int v
        when v >= minHeightCm && v <= maxHeightCm) {
      _heightCm = v;
    }
    if (json['targetWeightKg'] case final num v
        when v >= minTargetWeightKg && v <= maxTargetWeightKg) {
      _targetWeightKg = v.toDouble();
    }
    if (json['name'] case final String v
        when v.isNotEmpty && v.length <= maxNameLength) {
      _name = v;
    }
    _place = Place.fromJson(json['place']) ?? _place;
    if (json['morningBrief'] case final bool v) _morningBrief = v;
    if (json['morningTileAllDay'] case final bool v) _morningTileAllDay = v;
    if (json['weekReport'] case final bool v) _weekReport = v;
    if (json['dayNotice'] case final bool v) _dayNotice = v;
    if (json['liveMorning'] case final bool v) _liveMorning = v;
    if (json['liveSupplements'] case final bool v) _liveSupplements = v;
    if (json['liveWeek'] case final bool v) _liveWeek = v;
    if (json['liveDay'] case final bool v) _liveDay = v;
    if (json['routeSplits'] case final bool v) _routeSplits = v;
    if (json['routeClimb'] case final bool v) _routeClimb = v;
    if (json['routeOnTiles'] case final bool v) _routeOnTiles = v;
    if (json['fineValues'] case final bool v) _fineValues = v;
    _stepCounting = savedStepCounting(json);
    // Settings from before the mode existed, a restored backup too, keep
    // every number.
    _simple = json['simple'] == true;
    if (json['morningSeen'] case final int v) _morningSeen = v;
    if (json['themeMode'] case final String v) {
      for (final mode in ThemeMode.values) {
        if (mode.name == v) _themeMode = mode;
      }
    }
    // Settings from before the styles knew the wallpaper's colours as a
    // switch alone.
    if (json['dynamicColor'] case final bool v) {
      _colorStyle = v ? ColorStyle.wallpaper : ColorStyle.standard;
    }
    if (json['colorStyle'] case final String v) {
      for (final style in ColorStyle.values) {
        if (style.name == v) _colorStyle = style;
      }
    }
    if (json['showAllData'] case final bool v) _showAllData = v;
    if (json['liquidGlass'] case final bool v) _liquidGlass = v;
    if (json['edgeToEdgeHero'] case final bool v) _edgeToEdgeHero = v;
    if (json['flexFont'] case final bool v) _flexFont = v;
    if (json['mascot'] case final bool v) _mascot = v;
    if (json['calm'] case final bool v) _calm = v;
    if (json['expressive'] case final bool v) _expressive = v;
    if (json['haptics'] case final bool v) _haptics = v;
    if (json['introDone'] case final bool v) _introDone = v;
    if (json['language'] case final String v when appLanguages.contains(v)) {
      _language = v;
    }
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
      // A list saved before the page was reworked does not know the tiles
      // about the day; it gets them once, and keeps everything it had.
      final version = json['todayTilesVersion'];
      if (version is! int || version < 2) {
        _todayTiles = {..._dayTilesOnTop, ..._todayTiles, daysTileId}.toList();
      }
      // The morning's tile came later still. It goes below the day's,
      // which only as the first tile gives its scene to the page.
      if ((version is! int || version < 3) &&
          !_todayTiles.contains(morningTileId)) {
        final at = _todayTiles.firstOrNull == dayTileId ? 1 : 0;
        _todayTiles = [..._todayTiles]..insert(at, morningTileId);
      }
      // The week's tile and the connections came after that: the first
      // below the morning's, the second below the goals or at the end.
      if (version is! int || version < 4) {
        if (!_todayTiles.contains(weekTileId)) {
          final morning = _todayTiles.indexOf(morningTileId);
          final at = morning >= 0
              ? morning + 1
              : (_todayTiles.firstOrNull == dayTileId ? 1 : 0);
          _todayTiles = [..._todayTiles]..insert(at, weekTileId);
        }
        if (!_todayTiles.contains(linksTileId)) {
          final goals = _todayTiles.indexOf(goalsTileId);
          _todayTiles = [..._todayTiles]
            ..insert(goals >= 0 ? goals + 1 : _todayTiles.length, linksTileId);
        }
      }
      // The supplements came after that: below the nutrition, or before
      // the earlier days, or at the end.
      if ((version is! int || version < 5) &&
          !_todayTiles.contains(supplementsTileId)) {
        final food = _todayTiles.indexOf(Metric.energyIntake.name);
        final days = _todayTiles.indexOf(daysTileId);
        final at = food >= 0
            ? food + 1
            : (days >= 0 ? days : _todayTiles.length);
        _todayTiles = [..._todayTiles]..insert(at, supplementsTileId);
      }
    }
    if (json['largeTiles'] case final List<Object?> ids) {
      _largeTiles = ids
          .whereType<String>()
          .where((id) => isTodayTileId(id) || _isPageTileId(id))
          .toSet();
    }
    if (json['goals'] case final List<Object?> names) {
      final on = {for (final name in names) ?Goal.byName(name)};
      _goals = [
        for (final goal in Goal.values)
          if (on.contains(goal)) goal,
      ];
    }
    if (json['goalTargets'] case final Map<String, Object?> targets) {
      _goalTargets = {
        for (final MapEntry(:key, :value) in targets.entries)
          if ((Goal.byName(key), value) case (final Goal goal, final num v)
              when v >= goal.min && v <= goal.max)
            goal: v.toDouble(),
      };
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

  void setGoalOn(Goal goal, bool on) {
    if (on == isGoalOn(goal)) return;
    _update(
      () => _goals = [
        for (final other in Goal.values)
          if (other == goal ? on : isGoalOn(other)) other,
      ],
    );
  }

  void setGoalTarget(Goal goal, double value) {
    final target = value.clamp(goal.min, goal.max).toDouble();
    switch (goal) {
      case Goal.steps:
        setStepGoal(target.round());
      case Goal.activeEnergy:
        setActiveEnergyGoal(target.round());
      case Goal.sleepDuration:
        setSleepGoalHours(target);
      case Goal.water:
        setWaterGoalMl((target * 1000).round());
      default:
        _update(() => _goalTargets = {..._goalTargets, goal: target});
    }
  }

  void setBirthDate(DateTime? value) => _update(
    () => _birthDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day),
  );

  void setSex(Sex? value) => _update(() => _sex = value);

  void setHeightCm(int? value) {
    if (value != null && (value < minHeightCm || value > maxHeightCm)) return;
    _update(() => _heightCm = value);
  }

  void setTargetWeightKg(double? value) {
    if (value != null &&
        (value < minTargetWeightKg || value > maxTargetWeightKg)) {
      return;
    }
    _update(() => _targetWeightKg = value);
  }

  void setName(String? value) {
    final name = value?.trim();
    if (name != null && name.length > maxNameLength) return;
    _update(() => _name = name == null || name.isEmpty ? null : name);
  }

  void setPlace(Place? value) => _update(() => _place = value);

  void setMorningBrief(bool value) => _update(() => _morningBrief = value);

  void setWeekReport(bool value) => _update(() => _weekReport = value);

  void setDayNotice(bool value) => _update(() => _dayNotice = value);

  void setLiveMorning(bool value) => _update(() => _liveMorning = value);

  void setLiveSupplements(bool value) =>
      _update(() => _liveSupplements = value);

  void setLiveWeek(bool value) => _update(() => _liveWeek = value);

  void setLiveDay(bool value) => _update(() => _liveDay = value);

  void setRouteSplits(bool value) => _update(() => _routeSplits = value);

  void setRouteClimb(bool value) => _update(() => _routeClimb = value);

  void setRouteOnTiles(bool value) => _update(() => _routeOnTiles = value);

  void setMorningTileAllDay(bool value) =>
      _update(() => _morningTileAllDay = value);

  void setFineValues(bool value) => _update(() => _fineValues = value);

  void setStepCounting(StepCounting value) =>
      _update(() => _stepCounting = value);

  void setSimple(bool value) => _update(() => _simple = value);

  /// Remembers that the morning's cards opened by themselves on [day].
  void setMorningSeen(DateTime day) =>
      _update(() => _morningSeen = dayKey(day));

  void setThemeMode(ThemeMode value) => _update(() => _themeMode = value);

  void setColorStyle(ColorStyle value) => _update(() => _colorStyle = value);

  void setShowAllData(bool value) => _update(() => _showAllData = value);

  void setLiquidGlass(bool value) => _update(() => _liquidGlass = value);

  void setEdgeToEdgeHero(bool value) => _update(() => _edgeToEdgeHero = value);

  void setFlexFont(bool value) => _update(() => _flexFont = value);
  void setMascot(bool value) => _update(() => _mascot = value);
  void setCalm(bool value) => _update(() => _calm = value);
  void setExpressive(bool value) => _update(() => _expressive = value);

  void setHaptics(bool value) => _update(() => _haptics = value);

  void setIntroDone(bool value) => _update(() => _introDone = value);

  void setLanguage(String? value) {
    if (value != null && !appLanguages.contains(value)) return;
    _update(() => _language = value);
  }

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
            'heightCm': ?_heightCm,
            'targetWeightKg': ?_targetWeightKg,
            'name': ?_name,
            'place': ?_place?.toJson(),
            'morningBrief': _morningBrief,
            'morningTileAllDay': _morningTileAllDay,
            'weekReport': _weekReport,
            'dayNotice': _dayNotice,
            'liveMorning': _liveMorning,
            'liveSupplements': _liveSupplements,
            'liveWeek': _liveWeek,
            'liveDay': _liveDay,
            'routeSplits': _routeSplits,
            'routeClimb': _routeClimb,
            'routeOnTiles': _routeOnTiles,
            'fineValues': _fineValues,
            'stepCounting': _stepCounting.name,
            'simple': _simple,
            'morningSeen': ?_morningSeen,
            'themeMode': _themeMode.name,
            'colorStyle': _colorStyle.name,
            'showAllData': _showAllData,
            'liquidGlass': _liquidGlass,
            'edgeToEdgeHero': _edgeToEdgeHero,
            'flexFont': _flexFont,
            'mascot': _mascot,
            'calm': _calm,
            'expressive': _expressive,
            'haptics': _haptics,
            'introDone': _introDone,
            'language': ?_language,
            'tileOrder': _tileOrder,
            'todayTiles': _todayTiles,
            'todayTilesVersion': _todayTilesVersion,
            'largeTiles': _largeTiles.toList(),
            'goals': [for (final goal in _goals) goal.name],
            'goalTargets': {
              for (final MapEntry(:key, :value) in _goalTargets.entries)
                key.name: value,
            },
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
