import 'package:intl/intl.dart';

/// Converts an integer amount in cents to a display string, e.g.
/// `750` -> `"RM 7.50"`. Handles negative and large values.
String centsToRM(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign'
      'RM ${(abs / 100).toStringAsFixed(2)}';
}

/// Parses a Ringgit string (e.g. "7.50") into integer cents. Returns null
/// when the value cannot be parsed.
int? rmToCents(String value) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null) return null;
  return (parsed * 100).round();
}

final DateFormat _dateFormat = DateFormat('d MMM yyyy');
final DateFormat _timeFormat = DateFormat('h:mm a');
final DateFormat _dateTimeFormat = DateFormat('d MMM yyyy, h:mm a');

String formatDate(DateTime dt) => _dateFormat.format(dt.toLocal());

String formatTime(DateTime dt) => _timeFormat.format(dt.toLocal());

String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt.toLocal());

/// Relative time like "just now", "5 min ago", "2 h ago", else a date.
String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDate(dt);
}
