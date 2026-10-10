import 'dart:ui';

import 'package:flutter/foundation.dart' show mapEquals;

import '../data/day_insights.dart';
import '../data/health_history.dart' show dayKey;
import '../data/json_store.dart';
import '../data/models.dart';
import '../data/morning.dart';
import '../data/night_insights.dart';
import '../data/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';

/// What the morning's notification says.
typedef MorningNotice = ({String title, String body});

/// When the morning is said without a night, where the nights before do not
/// tell when this person gets up.
const int _plainWakeMinute = 7 * 60;

/// The notification for the morning of [now], or null when none is due:
/// switched off, the morning not begun or over, already said today, or the
/// cards already seen in the app. With the night of today it tells of it;
/// without, it only greets, from the time the nights before usually ended:
/// the watch may write the night long after getting up, and the cards read
/// it when they open. [settings] and [state] are the stored documents;
/// [language] is the system's.
MorningNotice? morningNoticeFor({
  required Object? settings,
  required Object? state,
  required List<SleepNight> nights,
  required DateTime now,
  required String language,
}) {
  final saved = savedMorning(settings);
  if (!saved.on) return null;
  final today = dayKey(now);
  if (state case {'notified': final int day} when day == today) return null;
  if (settings case {'morningSeen': final int day} when day == today) {
    return null;
  }
  final window = morningWindow(nights, now);
  if (!window.holds(now)) return null;
  final night = nightOn(nights, DateTime(now.year, now.month, now.day));
  if (night == null) {
    final usual = usualWakeMinute(nights, now) ?? _plainWakeMinute;
    // Still asleep, as far as anyone knows; the next run looks again.
    if (now.hour * 60 + now.minute < usual) return null;
  }
  final goal = switch (settings) {
    {'sleepGoalHours': final num hours} when hours >= 1 && hours <= 16 =>
      hours.toDouble(),
    _ => 8.0,
  };
  final l10n = _l10n(saved.language ?? language);
  return (
    title: _greeting(l10n, saved.name),
    body: night == null
        ? l10n.morningNoticePlain
        : l10n.morningNoticeBody(
            _duration(l10n, night.asleepMinutes),
            '${sleepScore(night, goal, nights).total}',
          ),
  );
}

AppLocalizations _l10n(String code) => lookupAppLocalizations(
  Locale(appLanguages.contains(code) ? code : appLanguages.first),
);

String _greeting(AppLocalizations l10n, String? name) =>
    name == null ? l10n.morningTitle : l10n.morningGreetingName(name);

/// What the platform's alarm says and at which minute of the day.
typedef MorningAlarm = ({int minute, String title, String body});

/// The alarm that greets at the time the nights before usually ended, for
/// the mornings on which no background run comes in time: the system gives
/// a seldom opened app few of them. Null when the morning is switched off
/// or that time lies outside the plain morning. Whether it has been said or
/// seen on its day is the platform's to check when the alarm goes off.
MorningAlarm? morningAlarmFor({
  required Object? settings,
  required List<SleepNight> nights,
  required DateTime now,
  required String language,
}) {
  final saved = savedMorning(settings);
  if (!saved.on) return null;
  final minute = usualWakeMinute(nights, now) ?? _plainWakeMinute;
  final at = DateTime(now.year, now.month, now.day, 0, minute);
  if (!morningWindow(const [], now).holds(at)) return null;
  final l10n = _l10n(saved.language ?? language);
  return (
    minute: minute,
    title: _greeting(l10n, saved.name),
    body: l10n.morningNoticePlain,
  );
}

/// Leaves the alarm of [morningAlarmFor] for the platform to set, or takes
/// it away. Says whether that changed what is stored, so the platform need
/// only be told then. [settings] is the stored document or its like.
Future<bool> leaveMorningAlarm(
  JsonStore store, {
  required Object? settings,
  required List<SleepNight> nights,
  required DateTime now,
  required String language,
}) async {
  final alarm = morningAlarmFor(
    settings: settings,
    nights: nights,
    now: now,
    language: language,
  );
  final stored = await store.read(StoreKeys.morningAlarm);
  if (alarm == null) {
    if (stored == null) return false;
    await store.delete(StoreKeys.morningAlarm);
    return true;
  }
  final document = <String, Object?>{
    'minute': alarm.minute,
    'title': alarm.title,
    'body': alarm.body,
  };
  if (stored is Map<String, Object?> && mapEquals(stored, document)) {
    return false;
  }
  await store.write(StoreKeys.morningAlarm, document);
  return true;
}

/// 444 becomes "7 h 24 min". Not through the app's formats: they need the
/// date symbols of the language, which nobody loads in the background.
String _duration(AppLocalizations l10n, int minutes) => minutes < 60
    ? l10n.durationMinutes(minutes)
    : l10n.durationHoursMinutes(minutes ~/ 60, minutes % 60);

/// Leaves the notification that is due for the platform to show once the
/// background run has ended, and remembers the day so it is said once.
Future<void> leaveMorningNotice(
  JsonStore store,
  List<SleepNight> nights,
  DateTime now,
  String language,
) async {
  final notice = morningNoticeFor(
    settings: await store.read(StoreKeys.settings),
    state: await store.read(StoreKeys.morning),
    nights: nights,
    now: now,
    language: language,
  );
  if (notice == null) return;
  await store.write(StoreKeys.morningNotice, {
    'title': notice.title,
    'body': notice.body,
  });
  await store.write(StoreKeys.morning, {'notified': dayKey(now)});
}
