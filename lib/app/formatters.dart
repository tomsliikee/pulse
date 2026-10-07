import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';

/// Numbers, dates and durations as the app's language writes them.
///
/// Handed down explicitly instead of through intl's global default locale:
/// a widget that only formats would not be rebuilt when the language changes.
class Formats {
  Formats._(this.l10n)
    : _integer = NumberFormat.decimalPattern(l10n.localeName),
      _decimalSeparator = NumberFormat.decimalPattern(l10n.localeName)
          .symbols
          .DECIMAL_SEP,
      _month = DateFormat.yMMMM(l10n.localeName),
      _day = DateFormat(l10n.patternDay, l10n.localeName),
      _shortDate = DateFormat(l10n.patternShortDate, l10n.localeName),
      _longDate = DateFormat(l10n.patternLongDate, l10n.localeName),
      _birthDate = DateFormat(l10n.patternBirthDate, l10n.localeName),
      weekdayShort = List.unmodifiable(l10n.weekdaysShort.split(',')),
      monthInitials = List.unmodifiable([
        for (var month = 1; month <= 12; month++)
          DateFormat('LLLLL', l10n.localeName).format(DateTime(2024, month)),
      ]);

  factory Formats.from(AppLocalizations l10n) =>
      _byLocale[l10n.localeName] ??= Formats._(l10n);

  static Formats of(BuildContext context) =>
      Formats.from(AppLocalizations.of(context));

  static final Map<String, Formats> _byLocale = {};

  final AppLocalizations l10n;
  final NumberFormat _integer;
  final String _decimalSeparator;
  final DateFormat _month;
  final DateFormat _day;
  final DateFormat _shortDate;
  final DateFormat _longDate;
  final DateFormat _birthDate;

  /// Monday to Sunday in two letters, for the bars of a week.
  final List<String> weekdayShort;

  /// January to December in one letter, for the bars of a year.
  final List<String> monthInitials;

  /// "Oktober 2026".
  String month(DateTime date) => _month.format(date);

  /// "29.9. bis 5.10."
  String dayRange(DateTime start, DateTime end) =>
      l10n.rangeFromTo(_day.format(start), _day.format(end));

  /// 7432 becomes "7.432".
  String integer(int value) => _integer.format(value);

  /// 1.5 becomes "1,5". No thousands separator: no decimal value in the app
  /// reaches a thousand.
  String decimal(double value, {int digits = 1}) =>
      value.toStringAsFixed(digits).replaceAll('.', _decimalSeparator);

  /// "Mittwoch, 7. Oktober".
  String longDate(DateTime date) => _longDate.format(date);

  /// "Mi, 7.10."
  String shortDate(DateTime date) => _shortDate.format(date);

  /// "7.3.1992".
  String birthDate(DateTime date) => _birthDate.format(date);

  /// 444 becomes "7 h 24 min".
  String duration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return l10n.durationMinutes(rest);
    return l10n.durationHoursMinutes(hours, rest);
  }

  /// "heute", "gestern" or the short date, for a value that may be older.
  String relativeDay(DateTime date, DateTime today) {
    final days = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(date.year, date.month, date.day)).inHours;
    // Hours, rounded, so a daylight-saving day still counts as one day.
    return switch ((days / 24).round()) {
      0 => l10n.relToday,
      1 => l10n.relYesterday,
      _ => shortDate(date),
    };
  }
}

/// 1390 becomes "23:10".
String formatClock(int minuteOfDay) {
  final minute = minuteOfDay % (24 * 60);
  return '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}

/// 6 becomes "06:00".
String formatClockHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';
