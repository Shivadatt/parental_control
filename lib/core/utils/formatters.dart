import 'package:intl/intl.dart';

String formatDateTime(DateTime? value) {
  if (value == null) return '—';
  return DateFormat.yMMMd().add_jm().format(value);
}

String formatDate(DateTime? value) {
  if (value == null) return '—';
  return DateFormat.yMMMd().format(value);
}

String formatTime(DateTime? value) {
  if (value == null) return '—';
  return DateFormat.jm().format(value);
}

/// Human-readable distance between [value] and [now] (defaults to the current
/// time).
///
/// Past values read `Just now` (< 60 s), `N min ago`, `N h ago`, `N d ago`,
/// then an absolute date after a week.
///
/// Future values are never described as `Just now`: they read
/// `in a few seconds` (< 60 s), `in N min`, `in N h`, or `in N d`. Callers
/// that prefix the value with `expires` therefore render `expires in 5 min`,
/// not `expires Just now`.
///
/// [now] exists so tests and countdown widgets can pin the reference instant;
/// production callers should leave it unset.
String relativeTime(DateTime? value, {DateTime? now}) {
  if (value == null) return 'Never';
  final reference = now ?? DateTime.now();
  final difference = reference.difference(value);
  if (difference.isNegative) {
    final ahead = value.difference(reference);
    if (ahead.inSeconds < 60) return 'in a few seconds';
    if (ahead.inMinutes < 60) return 'in ${ahead.inMinutes} min';
    if (ahead.inHours < 24) return 'in ${ahead.inHours} h';
    return 'in ${ahead.inDays} d';
  }
  if (difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays < 7) return '${difference.inDays} d ago';
  return formatDate(value);
}

String formatDurationMs(int milliseconds) {
  final safe = milliseconds < 0 ? 0 : milliseconds;
  final duration = Duration(milliseconds: safe);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m';
  return '${duration.inSeconds}s';
}

String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

String formatBattery(int? level, bool? charging) {
  if (level == null) return 'Unknown';
  return charging == true ? '$level% (charging)' : '$level%';
}

String formatTimeOfDayMinutes(int minutes) {
  final normalized = ((minutes % 1440) + 1440) % 1440;
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}
