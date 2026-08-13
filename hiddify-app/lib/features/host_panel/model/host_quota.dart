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
