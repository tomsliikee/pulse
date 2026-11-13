import '../../../data/day_insights.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../data/training/exercise_library.dart';
import '../../../data/training/training_insights.dart';
import '../../../data/training/training_splits.dart';
import '../../../features/activity/workout_style.dart';
import '../../../features/detail/metric_spec.dart';
import '../../../features/profile/profile_page.dart' show ProfileSection;
import '../../../features/supplements/supplement_format.dart';
import '../../../features/today/day_format.dart' show dayGoalsOf;
import '../data/mono_data.dart';
import '../pages/metric_page.dart';
import '../widgets/mono_gauge.dart';
import '../widgets/mono_category.dart';
import '../pages/training/training_text.dart';
import 'search_index.dart';

/// The id of recovery among the values; the metrics go by their names.
const String recoveryId = 'recovery';

/// The settings the search finds, each with the section of the profile it
/// lives in.
enum SearchSetting {
  aboutYou,
  goals,
  notifications,
  measures,
  appearance,
  glass,
  dockShrink,
  language,
  haptics,
  searchPins,
  simple,
  backup,
  about,
  trainingTemplates,
  weeklyGoal,
  split,
}

/// Everything the search can find right now, worded in the app's language.
/// Built when the panel opens; nothing of it is kept.
List<SearchItem> buildSearchIndex(MonoCtx c) => [
  ...valueItems(c),
  ..._exerciseItems(c),
  ..._workoutItems(c),
  ..._supplementItems(c),
  ..._dayItems(c),
  ..._settingItems(c),
];

/// The values, each with its latest reading of the last 90 days.
List<SearchItem> valueItems(MonoCtx c) {
  final l10n = c.l10n;
  final items = <SearchItem>[];
  final percent = c.recovery.total;
  final band = percent == null ? null : monoGaugeBand(percent);
  items.add(
    SearchItem(
      kind: SearchKind.value,
      id: recoveryId,
      title: l10n.recovery,
      group: l10n.recovery,
      valueText: percent == null ? null : '${c.formats.integer(percent)} %',
      subtitle: [
        c.formats.relativeDay(c.today, c.today),
        ?switch (band) {
          0 => l10n.monoBandRecover,
          1 => l10n.monoBandPace,
          2 => l10n.monoBandReady,
          3 => l10n.monoBandGo,
          _ => null,
        },
      ].join(' · '),
    ),
  );
  for (final metric in Metric.listed) {
    if (metric == Metric.diastolic) continue;
    double? value;
    DateTime? day;
    for (var back = 0; back < 90 && value == null; back++) {
      day = DateTime(c.today.year, c.today.month, c.today.day - back);
      value = c.health.valueOn(metric, day);
    }
    if (value == null) continue;
    items.add(
      SearchItem(
        kind: SearchKind.value,
        id: metric.name,
        title: metric.title(l10n),
        group: monoCategoryOf(metric).label(l10n),
        valueText: monoValueText(c, metric, value, day!),
        subtitle: [
          c.formats.relativeDay(day, c.today),
          monoCategoryOf(metric).label(l10n),
        ].join(' · '),
      ),
    );
  }
  return items;
}

/// A value as a result shows it: sleep as hours and minutes, blood pressure
/// as both numbers, the rest with its unit.
String monoValueText(MonoCtx c, Metric metric, double value, DateTime day) {
  if (metric == Metric.sleep) return c.formats.duration((value * 60).round());
  if (metric == Metric.systolic) {
    final low = c.health.valueOn(Metric.diastolic, day);
    final top = c.formats.integer(value.round());
    return low == null
        ? '$top mmHg'
        : '$top/${c.formats.integer(low.round())} mmHg';
  }
  return metric.formatWithUnit(c.formats, value);
}

List<SearchItem> _exerciseItems(MonoCtx c) {
  final training = c.scope.training.data;
  final language = c.l10n.localeName;
  final items = <SearchItem>[];
  for (final e in [...exerciseLibrary, ...training.customExercises]) {
    final last = lastSetOf(e.id, training.sessions);
    final muscle = e.muscle == null ? null : muscleLabel(c.l10n, e.muscle!);
    items.add(
      SearchItem(
        kind: SearchKind.exercise,
        id: e.id,
        title: e.name(language),
        group: muscle ?? '',
        terms: [
          ...e.names.values,
          for (final m in [...e.primary, ...e.secondary])
            muscleLabel(c.l10n, m),
          equipmentLabel(c.l10n, e.equipment),
        ],
        valueText: last == null ? null : setText(c.formats, last.$1),
        subtitle: [
          ?muscle,
          if (last != null) c.formats.relativeDay(last.$2.start, c.today),
        ].join(' · '),
      ),
    );
  }
  return items;
}

List<SearchItem> _workoutItems(MonoCtx c) {
  final l10n = c.l10n;
  final sessions = c.scope.training.data.sessions;
  final items = <SearchItem>[
    for (final s in sessions.reversed.take(30))
      SearchItem(
        kind: SearchKind.workout,
        id: 'session:${s.id}',
        title: s.name.isEmpty ? l10n.trainingSession : s.name,
        group: l10n.workouts,
        terms: [WorkoutType.strength.label(l10n)],
        valueText: c.formats.duration(s.duration.inMinutes),
        subtitle: [
          c.formats.relativeDay(s.start, c.today),
          l10n.trainingSetsCount(s.countingSets.length),
        ].join(' · '),
      ),
  ];
  final linked = {for (final s in sessions) ?s.linkedWorkout};
  for (final w in c.health.workouts.reversed.take(40)) {
    if (linked.contains(w.key)) continue;
    items.add(
      SearchItem(
        kind: SearchKind.workout,
        id: w.key,
        title: w.type.label(l10n),
        group: l10n.workouts,
        valueText: w.distanceKm != null
            ? '${c.formats.decimal(w.distanceKm!)} km'
            : c.formats.duration(w.minutes),
        subtitle: [
          c.formats.relativeDay(w.start, c.today),
          if (w.avgBpm != null) l10n.searchAvgHeart('${w.avgBpm}'),
        ].join(' · '),
      ),
    );
  }
  return items;
}

List<SearchItem> _supplementItems(MonoCtx c) {
  final data = c.scope.supplements.data;
  final now = c.health.now;
  return [
    for (final s in data.mine)
      SearchItem(
        kind: SearchKind.supplement,
        id: s.key,
        title: s.title(c.l10n),
        group: c.l10n.supplements,
        valueText: data.takenOn(s.key, now) != null
            ? c.l10n.searchTaken
            : c.l10n.searchOpen,
        subtitle: [
          ?doseText(c.formats, s.amount, s.unit),
          s.time.label(c.l10n),
        ].join(' · '),
      ),
  ];
}

List<SearchItem> _dayItems(MonoCtx c) {
  final goals = dayGoalsOf(c.settings);
  final items = <SearchItem>[];
  for (var back = 0; back < 30; back++) {
    final day = DateTime(c.today.year, c.today.month, c.today.day - back);
    final score = dayScore(
      day: day,
      valueOf: c.health.valueOn,
      nights: c.health.nights,
      goals: goals,
    ).total;
    if (score == null) continue;
    final steps = c.health.valueOn(Metric.steps, day);
    final sleep = c.health.valueOn(Metric.sleep, day);
    items.add(
      SearchItem(
        kind: SearchKind.day,
        id: dayId(day),
        title: c.formats.shortDate(day),
        group: c.l10n.searchDays,
        terms: [c.formats.longDate(day), c.formats.relativeDay(day, c.today)],
        valueText: c.l10n.searchScore('$score'),
        subtitle: [
          if (sleep != null)
            '${Metric.sleep.title(c.l10n)} ${c.formats.duration((sleep * 60).round())}',
          if (steps != null) Metric.steps.formatWithUnit(c.formats, steps),
        ].join(', '),
      ),
    );
  }
  return items;
}

/// "2026-11-10" for a day.
String dayId(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

List<SearchItem> _settingItems(MonoCtx c) {
  final l10n = c.l10n;
  final s = c.settings;
  final training = c.scope.training.data;
  String onOff(bool v) => v ? l10n.searchOn : l10n.searchOff;
  final entries = <(SearchSetting, String, String?)>[
    (SearchSetting.aboutYou, l10n.aboutYou, null),
    (SearchSetting.goals, l10n.settingsGoalsSupps, null),
    (SearchSetting.notifications, l10n.settingsNotifications, null),
    (SearchSetting.measures, l10n.settingsValues, null),
    (SearchSetting.appearance, l10n.appearance, null),
    (SearchSetting.glass, l10n.searchGlass, onOff(s.glassBlur)),
    (SearchSetting.dockShrink, l10n.dockShrink, onOff(s.dockShrink)),
    (SearchSetting.language, l10n.searchLanguage, null),
    (SearchSetting.haptics, l10n.searchHaptics, onOff(s.haptics)),
    (
      SearchSetting.searchPins,
      l10n.searchPinsTitle,
      l10n.searchPinnedCount(s.searchPins.length),
    ),
    (SearchSetting.simple, l10n.simpleTitle, onOff(s.simple)),
    (SearchSetting.backup, l10n.settingsDataBackup, null),
    (SearchSetting.about, l10n.settingsAbout, null),
    (
      SearchSetting.trainingTemplates,
      l10n.trainingTemplates,
      '${training.templates.length}',
    ),
    (
      SearchSetting.weeklyGoal,
      l10n.trainingWeeklyGoal,
      '${training.weeklyGoal}',
    ),
    (
      SearchSetting.split,
      l10n.trainingSplit,
      TrainingSplit.values
          .where((x) => x.name == training.split)
          .map((x) => splitText(l10n, x).$1)
          .firstOrNull,
    ),
  ];
  return [
    for (final (id, title, value) in entries)
      SearchItem(
        kind: SearchKind.setting,
        id: id.name,
        title: title,
        group: l10n.searchSettings,
        valueText: value,
        subtitle: id.index >= SearchSetting.trainingTemplates.index
            ? l10n.navTraining
            : l10n.profile,
      ),
  ];
}

/// The label of [kind] as a group heading.
String searchGroupLabel(MonoCtx c, SearchKind kind) => switch (kind) {
  SearchKind.value => c.l10n.searchValues,
  SearchKind.exercise => c.l10n.searchExercises,
  SearchKind.workout => c.l10n.workouts,
  SearchKind.supplement => c.l10n.supplements,
  SearchKind.day => c.l10n.searchDays,
  SearchKind.setting => c.l10n.searchSettings,
};

/// The category icon of a value result.
MonoCategory searchValueCategory(String id) {
  if (id == recoveryId) return MonoCategory.recovery;
  for (final m in Metric.values) {
    if (m.name == id) return monoCategoryOf(m);
  }
  return MonoCategory.activity;
}

/// The section of the profile [setting] lives in.
ProfileSection? profileSectionOf(SearchSetting setting) => switch (setting) {
  SearchSetting.aboutYou => ProfileSection.aboutYou,
  SearchSetting.goals => ProfileSection.goals,
  SearchSetting.notifications => ProfileSection.notifications,
  SearchSetting.measures => ProfileSection.measures,
  SearchSetting.appearance ||
  SearchSetting.glass ||
  SearchSetting.dockShrink ||
  SearchSetting.language ||
  SearchSetting.haptics ||
  SearchSetting.searchPins => ProfileSection.appearance,
  SearchSetting.simple => ProfileSection.simple,
  SearchSetting.backup => ProfileSection.backup,
  SearchSetting.about => ProfileSection.about,
  SearchSetting.trainingTemplates ||
  SearchSetting.weeklyGoal ||
  SearchSetting.split => null,
};
