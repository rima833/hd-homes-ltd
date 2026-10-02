import 'package:hdhomesproject/features/contact/domain/entities/office_directory_models.dart';

/// Calculates live open/closed status from structured hours (Africa/Lagos).
abstract final class OfficeStatusService {
  static const _closingSoonMinutes = 45;

  static OfficeStatusSnapshot compute({
    required List<OfficeHourEntry> hours,
    DateTime? now,
  }) {
    final lagos = _toLagos(now ?? DateTime.now().toUtc());
    final weekday = lagos.weekday - 1; // Mon=0
    final today = hours.where((h) => h.dayOfWeek == weekday).firstOrNull;

    if (today == null || !today.isOpen) {
      return _nextOpen(hours, lagos);
    }

    final open = _parseTimeOnDate(today.openTime, lagos);
    final close = _parseTimeOnDate(today.closeTime, lagos);

    if (lagos.isBefore(open)) {
      return OfficeStatusSnapshot(
        status: OfficeLiveStatus.opensLater,
        label: 'OPENS AT ${_format12(today.openTime)}',
        detail: 'Opens today at ${_format12(today.openTime)}',
      );
    }

    if (lagos.isAfter(close)) {
      return _nextOpen(hours, lagos);
    }

    final minsToClose = close.difference(lagos).inMinutes;
    if (minsToClose <= _closingSoonMinutes) {
      return OfficeStatusSnapshot(
        status: OfficeLiveStatus.closingSoon,
        label: 'CLOSING SOON',
        detail: 'Closes at ${_format12(today.closeTime)}',
      );
    }

    return OfficeStatusSnapshot(
      status: OfficeLiveStatus.open,
      label: 'OPEN NOW',
      detail: 'Closes at ${_format12(today.closeTime)}',
    );
  }

  static OfficeStatusSnapshot _nextOpen(
    List<OfficeHourEntry> hours,
    DateTime lagos,
  ) {
    for (var offset = 1; offset <= 7; offset++) {
      final day = (lagos.weekday - 1 + offset) % 7;
      final entry = hours.where((h) => h.dayOfWeek == day && h.isOpen).firstOrNull;
      if (entry == null) continue;
      final dayName = _dayName(day);
      final prefix = offset == 1 ? 'Opens tomorrow' : 'Opens $dayName';
      return OfficeStatusSnapshot(
        status: OfficeLiveStatus.closed,
        label: 'CLOSED',
        detail: '$prefix at ${_format12(entry.openTime)}',
      );
    }
    return const OfficeStatusSnapshot(
      status: OfficeLiveStatus.closed,
      label: 'CLOSED',
      detail: 'Currently closed',
    );
  }

  static DateTime _toLagos(DateTime utc) {
    return utc.add(const Duration(hours: 1));
  }

  static DateTime _parseTimeOnDate(String time, DateTime date) {
    final parts = time.split(':');
    final h = int.tryParse(parts.first) ?? 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  static String _format12(String time) {
    final parts = time.split(':');
    var h = int.tryParse(parts.first) ?? 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final period = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:${m.toString().padLeft(2, '0')} $period';
  }

  static String _dayName(int day) {
    return switch (day) {
      0 => 'Monday',
      1 => 'Tuesday',
      2 => 'Wednesday',
      3 => 'Thursday',
      4 => 'Friday',
      5 => 'Saturday',
      6 => 'Sunday',
      _ => 'Monday',
    };
  }

  static String hoursSummary(List<OfficeHourEntry> hours) {
    if (hours.isEmpty) return 'Hours not available';
    final openDays = hours.where((h) => h.isOpen).toList();
    if (openDays.isEmpty) return 'Closed';
    final first = openDays.first;
    final sameHours = openDays.every(
      (h) => h.openTime == first.openTime && h.closeTime == first.closeTime,
    );
    if (sameHours && openDays.length >= 5) {
      return 'Mon – Fri · ${_format12(first.openTime)} – ${_format12(first.closeTime)}';
    }
    final today = hours.where((h) => h.dayOfWeek == DateTime.now().weekday - 1).firstOrNull;
    if (today != null && today.isOpen) {
      return 'Open today · ${_format12(today.openTime)} – ${_format12(today.closeTime)}';
    }
    return 'See opening hours';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
