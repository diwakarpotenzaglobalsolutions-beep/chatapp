import 'package:intl/intl.dart';

class DateTimeFormatter {
  DateTimeFormatter._();

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String formatMessageTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  static String formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  static String formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seenDay = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
    final difference = today.difference(seenDay).inDays;
    final time = DateFormat('hh:mm a').format(lastSeen);

    if (difference == 0) return time;
    if (difference == 1) return 'Last seen yesterday $time';
    final date = DateFormat('dd MMM yyyy').format(lastSeen);
    return 'Last seen $date-$time';
  }

  static String formatCallHistoryDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(callDay).inDays;
    final time = DateFormat('hh:mm a').format(dateTime);

    if (difference == 0) return 'Today, $time';
    if (difference == 1) return 'Yesterday, $time';
    return '${DateFormat('dd MMM yyyy').format(dateTime)}, $time';
  }

  static String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Returns true when a date separator should appear before [index].
  static bool shouldShowDateSeparator<T>({
    required List<T> items,
    required int index,
    required DateTime Function(T item) timestampOf,
  }) {
    if (index == 0) return true;
    final current = timestampOf(items[index]);
    final previous = timestampOf(items[index - 1]);
    return !isSameDay(current, previous);
  }
}
