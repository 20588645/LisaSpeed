import 'dart:convert';

/// Traffic-quota snapshot scraped from the LisaHost (WHMCS) client area.
class HostQuota {
  const HostQuota({
    required this.usedGb,
    required this.totalGb,
    this.resetDay,
    this.expiryDate,
    required this.fetchedAt,
  });

  final double usedGb;
  final double totalGb;

  /// Day of month the panel resets the traffic counter (`reset_flow_day`).
  final int? resetDay;

  /// Product due date as shown on the panel, e.g. `2026-09-03`.
  final String? expiryDate;

  final DateTime fetchedAt;

  double get ratio => totalGb <= 0 ? 0 : (usedGb / totalGb).clamp(0.0, 1.0);

  /// Even-pace usage for the current cycle: [totalGb] spread across the
  /// days from the last reset (or a one-month window ending on expiry) to
  /// the next reset / due date. `9000G / 30d` → 300G per day; after 10 days
  /// the marker sits at 1/3 of the bar.
  double? paceRatio({DateTime? now}) {
    final cycle = currentCycle(now: now ?? DateTime.now());
    if (cycle == null) return null;
    final totalMs = cycle.end.difference(cycle.start).inMilliseconds;
    if (totalMs <= 0) return null;
    return (cycle.now.difference(cycle.start).inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  /// Inclusive calendar window used by [paceRatio]. Exposed for tests.
  HostQuotaCycle? currentCycle({required DateTime now}) {
    final n = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
    final expiry = parseHostQuotaDate(expiryDate);
    final day = resetDay;
    if (day != null && day >= 1 && day <= 31) {
      final start = _lastResetOnOrBefore(n, day);
      var end = _nextResetAfter(start, day);
      if (expiry != null && expiry.isAfter(start) && !expiry.isAfter(end)) {
        end = expiry;
      }
      if (n.isBefore(start)) return null;
      return HostQuotaCycle(start: start, end: end, now: n);
    }
    if (expiry == null) return null;
    final start = _ymd(expiry.year, expiry.month - 1, expiry.day);
    if (n.isBefore(start) || n.isAfter(expiry)) return null;
    return HostQuotaCycle(start: start, end: expiry, now: n);
  }

  String toJsonString() => jsonEncode({
    'usedGb': usedGb,
    'totalGb': totalGb,
    'resetDay': resetDay,
    'expiryDate': expiryDate,
    'fetchedAt': fetchedAt.toIso8601String(),
  });

  static HostQuota? fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return HostQuota(
        usedGb: (map['usedGb'] as num).toDouble(),
        totalGb: (map['totalGb'] as num).toDouble(),
        resetDay: map['resetDay'] as int?,
        expiryDate: map['expiryDate'] as String?,
        fetchedAt: DateTime.tryParse(map['fetchedAt'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

class HostQuotaCycle {
  const HostQuotaCycle({required this.start, required this.end, required this.now});

  final DateTime start;
  final DateTime end;
  final DateTime now;
}

DateTime? parseHostQuotaDate(String? raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw?.trim() ?? '');
  if (match == null) return null;
  return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
}

DateTime _ymd(int year, int month, int day) {
  final dim = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day.clamp(1, dim));
}

DateTime _lastResetOnOrBefore(DateTime now, int day) {
  final thisMonth = _ymd(now.year, now.month, day);
  if (!thisMonth.isAfter(DateTime(now.year, now.month, now.day))) return thisMonth;
  return _ymd(now.year, now.month - 1, day);
}

DateTime _nextResetAfter(DateTime start, int day) => _ymd(start.year, start.month + 1, day);
