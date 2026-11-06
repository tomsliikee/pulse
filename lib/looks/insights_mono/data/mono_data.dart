import 'package:material_ui/material_ui.dart';

import '../../../app/app_scope.dart';
import '../../../app/formatters.dart';
import '../../../data/health_controller.dart';
import '../../../features/detail/metric_spec.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/recovery.dart';
import '../../../data/settings_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../theme/mono_tokens.dart';

/// What a page of the look needs to hand: the controllers, the language and
/// the colours. It reads the app's existing data; nothing is calculated here
/// that the app does not calculate elsewhere.
class MonoCtx {
  MonoCtx._(this.context)
    : scope = AppScope.of(context),
      formats = Formats.of(context),
      t = MonoTokens.of(context);

  factory MonoCtx.of(BuildContext context) => MonoCtx._(context);

  final BuildContext context;
  final AppScope scope;
  final Formats formats;
  final MonoTokens t;

  HealthController get health => scope.health;
  SettingsController get settings => scope.settings;
  AppLocalizations get l10n => formats.l10n;
  bool get simple => settings.simple;

  DateTime get today => health.today;

  /// "14:05".
  String clock(DateTime time) => formatClock(time.hour * 60 + time.minute);

  /// When the data was read, as the time on the cards.
  String get updated => clock(health.snapshot.loadedAt);

  /// The recovery of today.
  Recovery get recovery => recoveryOf(
    day: today,
    valueOf: health.valueOn,
    nights: health.nights,
    sleepGoalHours: settings.sleepGoalHours,
  );

  /// The value of [metric] on each of the last [days] days, today last.
  List<double?> days(Metric metric, int days) => [
    for (var back = days - 1; back >= 0; back--)
      health.valueOn(
        metric,
        DateTime(today.year, today.month, today.day - back),
      ),
  ];

  /// The 24 hourly totals of today, if the store has them.
  List<double?>? hours(Metric metric) =>
      health.snapshot.hoursOf(metric, health.todayIndex);

  double? valueToday(Metric metric) => health.valueOn(metric, today);

  /// A number in the language, without unit.
  String num(Metric metric, double? value) => metric.format(formats, value);

  /// A day, such as "Thursday, 5 November".
  String get dateText => formats.longDate(today);

  Future<T?> push<T>(Widget page) => monoPush(context, page);
}

/// Pushes [page] with the keyboard put away first: a field that kept its
/// focus would bring the keyboard back when the page is left.
Future<T?> monoPush<T>(BuildContext context, Widget page) {
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context).push(MaterialPageRoute<T>(builder: (_) => page));
}

/// "23:10" for a minute of the day, wrapping past midnight.
String formatClockOf(int minute) {
  final m = minute % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}
