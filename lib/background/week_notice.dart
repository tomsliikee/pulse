import 'dart:ui';

import 'package:flutter/foundation.dart' show mapEquals;

import '../data/day_insights.dart';
import '../data/goals.dart' show weekStart;
import '../data/health_history.dart' show dayKey;
import '../data/json_store.dart';
import '../data/models.dart';
import '../data/settings_controller.dart';
import '../data/week_report.dart';
import '../l10n/generated/app_localizations.dart';

/// What the platform's alarm says on Sunday evening: [body] tells the
/// week's score as it stood on [day] (a day key), [plain] is said when that
/// is not today, because nothing has run since.
typedef WeekAlarm = ({String title, String body, String plain, int day});

/// What the days are judged against in the saved settings [json], with the
/// app's own goals where it names none.
DayGoals savedDayGoals(Object? json) {
  T read<T extends num>(String key, T fallback) =>
      json is Map<String, Object?> && json[key] is T
      ? json[key] as T
      : fallback;
  return DayGoals(
    steps: read<int>('stepGoal', 10000),
    activeEnergy: read<int>('activeEnergyGoal', 500),
    waterMl: read<int>('waterGoalMl', 2400),
    sleepHours: read<num>('sleepGoalHours', 8).toDouble(),
  );
}

/// The alarm for the report of the week [now] lies in, or null when the
/// report is switched off. [valueOf] and [nights] need to reach back two
/// weeks. [settings] is the stored document or its like; [language] is the
/// system's.
WeekAlarm? weekAlarmFor({
  required Object? settings,
  required DayValue valueOf,
  required List<SleepNight> nights,
  required DateTime now,
  required String language,
}) {
  if (settings case {'weekReport': false}) return null;
  final saved = savedMorning(settings).language;
  final code = saved ?? language;
  final l10n = lookupAppLocalizations(
    Locale(appLanguages.contains(code) ? code : appLanguages.first),
  );
  final goals = savedDayGoals(settings);
  final today = DateTime(now.year, now.month, now.day);
  final monday = weekStart(today);
  int? scoreOf(DateTime from) => weekScoreOf(
    weekDayScores(
      monday: from,
      valueOf: valueOf,
      nights: nights,
      goals: goals,
      today: today,
    ),
  );
  final score = scoreOf(monday);
  final previous = scoreOf(DateTime(monday.year, monday.month, monday.day - 7));
  return (
    title: l10n.weekNoticeTitle,
    body: score == null
        ? l10n.weekNoticePlain
        : previous == null || previous == score
        ? l10n.weekNoticeScore(score)
        : l10n.weekNoticeScoreDiff(
            score,
            (score - previous).abs(),
            score > previous ? 'more' : 'less',
          ),
    plain: l10n.weekNoticePlain,
    day: dayKey(today),
  );
}

/// Leaves the alarm of [weekAlarmFor] for the platform to set, or takes it
/// away. Says whether that changed what is stored, so the platform need
/// only be told then.
Future<bool> leaveWeekAlarm(
  JsonStore store, {
  required Object? settings,
  required DayValue valueOf,
  required List<SleepNight> nights,
  required DateTime now,
  required String language,
}) async {
  final alarm = weekAlarmFor(
    settings: settings,
    valueOf: valueOf,
    nights: nights,
    now: now,
    language: language,
  );
  final stored = await store.read(StoreKeys.weekAlarm);
  if (alarm == null) {
    if (stored == null) return false;
    await store.delete(StoreKeys.weekAlarm);
    return true;
  }
  final document = <String, Object?>{
    'title': alarm.title,
    'body': alarm.body,
    'plain': alarm.plain,
    'day': alarm.day,
  };
  if (stored is Map<String, Object?> && mapEquals(stored, document)) {
    return false;
  }
  await store.write(StoreKeys.weekAlarm, document);
  return true;
}
