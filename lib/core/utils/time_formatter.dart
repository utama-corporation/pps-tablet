// lib/core/utils/time_helpers.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Parse "HH:mm" → TimeOfDay? (null if invalid)
TimeOfDay? parseHHmm(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// Format TimeOfDay as "HH:mm"
String formatHHmm(TimeOfDay t) {
  final dt = DateTime(0, 1, 1, t.hour, t.minute);
  return DateFormat('HH:mm').format(dt);
}

/// Show a 24h time picker, returns TimeOfDay?
Future<TimeOfDay?> pickTime24h(BuildContext context, {TimeOfDay? initial}) {
  return showTimePicker(
    context: context,
    initialTime: initial ?? const TimeOfDay(hour: 8, minute: 0),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      );
    },
  );
}

/// Minutes since midnight (0..1439)
int minutesSinceMidnight(TimeOfDay t) => t.hour * 60 + t.minute;

/// Whether minute [m] falls inside the shift window [startMin]..[endMin].
///
/// Wraps around midnight, so an overnight shift 23:00-07:00 (1380..420)
/// accepts both 23:30 and 02:00. Returns false when the window is empty.
bool isWithinMinuteWindow(int m, int startMin, int endMin) {
  if (startMin == endMin) return false;
  final span = (endMin - startMin + 1440) % 1440;
  final offset = (m - startMin + 1440) % 1440;
  return offset <= span;
}

/// Duration between two "HH:mm" strings with midnight wrap.
/// Returns null if one is invalid or duration == 0 minutes.
Duration? durationBetweenHHmmWrap(String? startHHmm, String? endHHmm) {
  final s = parseHHmm(startHHmm);
  final e = parseHHmm(endHHmm);
  if (s == null || e == null) return null;

  final sMin = minutesSinceMidnight(s);
  final eMin = minutesSinceMidnight(e);
  final diff = (eMin - sMin + 1440) % 1440; // 0..1439
  if (diff == 0) return null;
  return Duration(minutes: diff);
}

/// Combine a date + time; if end < start, add 1 day to end (overnight)
({DateTime? start, DateTime? end}) combineDayWithStartEnd(
    DateTime day,
    String? startHHmm,
    String? endHHmm,
    ) {
  final s = parseHHmm(startHHmm);
  final e = parseHHmm(endHHmm);
  if (s == null || e == null) return (start: null, end: null);

  DateTime start = DateTime(day.year, day.month, day.day, s.hour, s.minute);
  DateTime end   = DateTime(day.year, day.month, day.day, e.hour, e.minute);
  if (minutesSinceMidnight(e) <= minutesSinceMidnight(s)) {
    end = end.add(const Duration(days: 1)); // overnight
  }
  return (start: start, end: end);
}

/// Short human format: "3j 15m", "45 m", "3 j"
String formatDurationShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (m == 0) return '$h j';
  if (h == 0) return '$m m';
  return '${h}j ${m}m';
}




