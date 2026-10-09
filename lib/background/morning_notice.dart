import 'dart:ui';

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

/// The notification for the morning of [now], or null when none is due:
/// switched off, no night for today yet, the morning over, already said
/// today, or the cards already seen in the app. [settings] and [state] are
/// the stored documents; [language] is the system's.
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
  // Without the night there is nothing to say yet; the next run looks again.
  if (!window.fromNight || !window.holds(now)) return null;
  final night = nightOn(nights, DateTime(now.year, now.month, now.day))!;
  final goal = switch (settings) {
    {'sleepGoalHours': final num hours} when hours >= 1 && hours <= 16 =>
      hours.toDouble(),
    _ => 8.0,
  };
  final code = saved.language ?? language;
  final l10n = lookupAppLocalizations(
    Locale(appLanguages.contains(code) ? code : appLanguages.first),
  );
  return (
    title: switch (saved.name) {
      final name? => l10n.morningGreetingName(name),
      null => l10n.morningTitle,
    },
    body: l10n.morningNoticeBody(
      _duration(l10n, night.asleepMinutes),
      '${sleepScore(night, goal, nights).total}',
    ),
  );
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
