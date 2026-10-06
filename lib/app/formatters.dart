const List<String> weekdayShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

const List<String> weekdayLong = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

const List<String> _months = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

const List<String> monthInitials = [
  'J',
  'F',
  'M',
  'A',
  'M',
  'J',
  'J',
  'A',
  'S',
  'O',
  'N',
  'D',
];

/// "Oktober 2026".
String formatMonth(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// "29.9. bis 5.10."
String formatDayRange(DateTime start, DateTime end) =>
    '${start.day}.${start.month}. bis ${end.day}.${end.month}.';

/// 7432 becomes "7.432".
String formatInt(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 1.5 becomes "1,5".
String formatDecimal(double value, {int digits = 1}) =>
    value.toStringAsFixed(digits).replaceAll('.', ',');

String formatLongDate(DateTime date) =>
    '${weekdayLong[date.weekday - 1]}, ${date.day}. ${_months[date.month - 1]}';

String formatShortDate(DateTime date) =>
    '${weekdayShort[date.weekday - 1]}, ${date.day}.${date.month}.';

/// 444 becomes "7 h 24 min".
String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  return '$hours h $rest min';
}

/// 1390 becomes "23:10".
String formatClock(int minuteOfDay) {
  final minute = minuteOfDay % (24 * 60);
  return '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}

/// 6 becomes "06:00".
String formatClockHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

/// "heute", "gestern" or the short date, for a value that may be older.
String formatRelativeDay(DateTime date, DateTime today) {
  final days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(date.year, date.month, date.day)).inHours;
  // Hours, rounded, so a daylight-saving day still counts as one day.
  return switch ((days / 24).round()) {
    0 => 'heute',
    1 => 'gestern',
    _ => formatShortDate(date),
  };
}
