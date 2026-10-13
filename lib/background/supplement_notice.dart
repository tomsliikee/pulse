import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../data/json_store.dart';
import '../data/settings_controller.dart';
import '../data/supplements.dart';
import '../features/supplements/supplement_format.dart';
import '../l10n/generated/app_localizations.dart';

/// What the platform needs to remind of supplements: for each time of day
/// with a reminder the minute it comes at and what it is about, and the
/// words to say it in. Null where nothing is to be reminded of. Whether
/// something is still open when its minute comes is the platform's to
/// check, from what the app has noted as taken by then.
Map<String, Object?>? supplementAlarmFor(
  SupplementData data, {
  required String language,
}) {
  final l10n = lookupAppLocalizations(
    Locale(appLanguages.contains(language) ? language : appLanguages.first),
  );
  final slots = [
    for (final time in SupplementTime.reminded)
      if ([
            for (final supplement in data.mine)
              if (supplement.time == time && supplement.remind)
                {'key': supplement.key, 'name': supplement.title(l10n)},
          ]
          case final items when items.isNotEmpty)
        {'minute': data.minuteOf(time), 'items': items},
  ];
  if (slots.isEmpty) return null;
  return {
    'title': l10n.supplementNoticeTitle,
    // The platform puts the names in the place of the mark.
    'body': l10n.supplementNoticeOpen(supplementNamesMark),
    'slots': slots,
  };
}

/// Stands in the body of the alarm where the open supplements are named.
const String supplementNamesMark = '%s';

/// Leaves the alarm of [supplementAlarmFor] for the platform to set, or
/// takes it away. Says whether that changed what is stored, so the
/// platform need only be told then.
Future<bool> leaveSupplementAlarm(
  JsonStore store,
  SupplementData data, {
  required String language,
}) async {
  final alarm = supplementAlarmFor(data, language: language);
  final stored = await store.read(StoreKeys.supplementAlarm);
  if (alarm == null) {
    if (stored == null) return false;
    await store.delete(StoreKeys.supplementAlarm);
    return true;
  }
  // Both are plain JSON, written in the same order.
  if (stored != null && jsonEncode(stored) == jsonEncode(alarm)) return false;
  await store.write(StoreKeys.supplementAlarm, alarm);
  return true;
}
