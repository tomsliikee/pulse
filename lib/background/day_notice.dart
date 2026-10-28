import 'dart:ui';

import 'package:flutter/foundation.dart' show mapEquals;

import '../data/day_insights.dart';
import '../data/health_history.dart' show dayKey;
import '../data/json_store.dart';
import '../data/models.dart';
import '../data/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'week_notice.dart' show savedDayGoals;

/// What the platform's alarm says at nine in the evening: [body] tells the
/// day's score as it stood on [day] (a day key), [plain] is said when that
/// is not today, because nothing has run since. [short] is the score alone,
/// for the small chip of a live message.
typedef DayAlarm = ({
  String title,
  String body,
  String plain,
  int day,
  String? short,
});

/// The alarm for the day [now] lies in, or null when the notification is
/// switched off. It is off until the user turns it on. [settings] is the
/// stored document or its like; [language] is the system's.
DayAlarm? dayAlarmFor({
  required Object? settings,
  required DayValue valueOf,
  required List<SleepNight> nights,
  required DateTime now,
  required String language,
}) {
  if (settings is! Map<String, Object?> || settings['dayNotice'] != true) {
    return null;
  }
  final code = savedMorning(settings).language ?? language;
  final l10n = lookupAppLocalizations(
    Locale(appLanguages.contains(code) ? code : appLanguages.first),
  );
  final today = DateTime(now.year, now.month, now.day);
  final score = dayScore(
    day: today,
    valueOf: valueOf,
    nights: nights,
    goals: savedDayGoals(settings),
  ).total;
  return (
    title: l10n.dayNoticeTitle,
    body: score == null ? l10n.dayNoticePlain : l10n.dayNoticeScore(score),
    plain: l10n.dayNoticePlain,
    day: dayKey(today),
    short: score?.toString(),
  );
}

/// Leaves the alarm of [dayAlarmFor] for the platform to set, or takes it
/// away. Says whether that changed what is stored, so the platform need
/// only be told then.
Future<bool> leaveDayAlarm(
  JsonStore store, {
  required Object? settings,
  required DayValue valueOf,
  required List<SleepNight> nights,
  required DateTime now,
  required String language,
}) async {
  final alarm = dayAlarmFor(
    settings: settings,
    valueOf: valueOf,
    nights: nights,
    now: now,
    language: language,
  );
  final stored = await store.read(StoreKeys.dayAlarm);
  if (alarm == null) {
    if (stored == null) return false;
    await store.delete(StoreKeys.dayAlarm);
    return true;
  }
  final document = <String, Object?>{
    'title': alarm.title,
    'body': alarm.body,
    'plain': alarm.plain,
    'day': alarm.day,
    'short': ?alarm.short,
  };
  if (stored is Map<String, Object?> && mapEquals(stored, document)) {
    return false;
  }
  await store.write(StoreKeys.dayAlarm, document);
  return true;
}
