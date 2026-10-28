import 'dart:ui';

import 'package:flutter/foundation.dart' show mapEquals;

import '../data/day_insights.dart';
import '../data/health_history.dart' show dayKey;
import '../data/json_store.dart';
import '../data/metric_catalog.dart';
import '../data/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import 'week_notice.dart' show savedDayGoals;

/// What the widget on the home screen shows: steps, active calories and water
/// of the day [now] lies in against their goals, with the words to name them
/// in. A value the app does not know is left out. [settings] is the stored
/// document or its like; [language] is the system's.
Map<String, Object?> widgetDataFor({
  required Object? settings,
  required DayValue valueOf,
  required DateTime now,
  required String language,
}) {
  final code = savedMorning(settings).language ?? language;
  final l10n = lookupAppLocalizations(
    Locale(appLanguages.contains(code) ? code : appLanguages.first),
  );
  final goals = savedDayGoals(settings);
  final today = DateTime(now.year, now.month, now.day);
  Map<String, Object?>? row(
    String label,
    Metric metric,
    num goal,
    String unit,
  ) {
    final value = valueOf(metric, today);
    if (value == null) return null;
    return {'label': label, 'value': value, 'goal': goal, 'unit': unit};
  }

  return {
    'day': dayKey(today),
    'rows': [
      ?row(l10n.metricSteps, Metric.steps, goals.steps, ''),
      ?row(
        l10n.metricActiveEnergy,
        Metric.activeEnergy,
        goals.activeEnergy,
        'kcal',
      ),
      ?row(l10n.metricWater, Metric.water, goals.waterMl / 1000, 'l'),
    ],
  };
}

/// Leaves the document of [widgetDataFor] for the platform to draw the widget
/// by. Says whether that changed what is stored, so the platform need only
/// be told then.
Future<bool> leaveWidgetData(
  JsonStore store, {
  required Object? settings,
  required DayValue valueOf,
  required DateTime now,
  required String language,
}) async {
  final document = widgetDataFor(
    settings: settings,
    valueOf: valueOf,
    now: now,
    language: language,
  );
  final stored = await store.read(StoreKeys.widget);
  if (stored is Map<String, Object?> && _same(stored, document)) return false;
  await store.write(StoreKeys.widget, document);
  return true;
}

// Documents read back from files hold lists and maps of their own.
bool _same(Map<String, Object?> a, Map<String, Object?> b) {
  if (!mapEquals({...a}..remove('rows'), {...b}..remove('rows'))) return false;
  final x = a['rows'];
  final y = b['rows'];
  if (x is! List || y is! List || x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] is! Map<String, Object?> ||
        !mapEquals(
          x[i] as Map<String, Object?>,
          y[i] as Map<String, Object?>,
        )) {
      return false;
    }
  }
  return true;
}
