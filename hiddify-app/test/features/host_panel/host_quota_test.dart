import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/host_panel/model/host_quota.dart';

void main() {
  HostQuota quota({int? resetDay = 3, String? expiry = '2026-09-03'}) {
    return HostQuota(
      usedGb: 412,
      totalGb: 1996.8,
      resetDay: resetDay,
      expiryDate: expiry,
      fetchedAt: DateTime(2026, 8, 15),
    );
  }

  test('ratio is used over total', () {
    expect(quota().ratio, closeTo(412 / 1996.8, 0.0001));
  });

  test('monthly reset: Aug 15 in Aug 3–Sep 3 cycle is about 41%', () {
    final now = DateTime(2026, 8, 15, 12);
    final cycle = quota().currentCycle(now: now)!;
    expect(cycle.start, DateTime(2026, 8, 3));
    expect(cycle.end, DateTime(2026, 9, 3));
    final pace = quota().paceRatio(now: now)!;
    final expected =
        DateTime(2026, 8, 15, 12).difference(DateTime(2026, 8, 3)).inMilliseconds /
        DateTime(2026, 9, 3).difference(DateTime(2026, 8, 3)).inMilliseconds;
    expect(pace, closeTo(expected, 0.0001));
    expect(pace, closeTo(12.5 / 31, 0.01));
  });

  test('before reset day this month uses previous month as start', () {
    final now = DateTime(2026, 8, 2, 9);
    final cycle = quota().currentCycle(now: now)!;
    expect(cycle.start, DateTime(2026, 7, 3));
    expect(cycle.end, DateTime(2026, 8, 3));
  });

  test('9000G over 30 days: day 10 pace is one third', () {
    final q = HostQuota(
      usedGb: 2000,
      totalGb: 9000,
      resetDay: 1,
      expiryDate: '2026-09-01',
      fetchedAt: DateTime(2026, 8, 11),
    );
    final now = DateTime(2026, 8, 11);
    final cycle = q.currentCycle(now: now)!;
    expect(cycle.start, DateTime(2026, 8, 1));
    expect(cycle.end, DateTime(2026, 9, 1));
    expect(q.paceRatio(now: now), closeTo(10 / 31, 0.01));
    expect(q.ratio, closeTo(2000 / 9000, 0.0001));
    expect(q.ratio < q.paceRatio(now: now)!, isTrue);
  });

  test('no dates means no pace marker', () {
    final q = HostQuota(usedGb: 10, totalGb: 100, fetchedAt: DateTime(2026, 8, 15));
    expect(q.paceRatio(now: DateTime(2026, 8, 15)), isNull);
  });

  test('expiry far in the future without reset day hides pace', () {
    final q = quota(resetDay: null, expiry: '2027-09-03');
    expect(q.paceRatio(now: DateTime(2026, 8, 15)), isNull);
  });

  test('json round-trip keeps reset day', () {
    final restored = HostQuota.fromJsonString(quota().toJsonString())!;
    expect(restored.resetDay, 3);
    expect(restored.expiryDate, '2026-09-03');
    expect(restored.usedGb, 412);
  });
}
