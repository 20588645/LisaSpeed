import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/model/subscription_alert.dart';

void main() {
  SubscriptionInfo info({
    DateTime? expire,
    int upload = 0,
    int download = 0,
    int total = 100,
  }) {
    return SubscriptionInfo(
      upload: upload,
      download: download,
      total: total,
      expire: expire ?? DateTime(2099, 1, 1),
    );
  }

  test('expired wins over traffic', () {
    final now = DateTime(2026, 8, 16);
    final alert = evaluateSubscriptionAlert(
      profileId: 'p1',
      profileName: 'Lisa',
      info: info(expire: DateTime(2026, 8, 15), download: 99, total: 100),
      now: now,
    );
    expect(alert?.kind, SubscriptionAlertKind.expired);
  });

  test('warns three days before expiry', () {
    final now = DateTime(2026, 8, 16, 10);
    final alert = evaluateSubscriptionAlert(
      profileId: 'p1',
      profileName: 'Lisa',
      info: info(expire: DateTime(2026, 8, 18, 23)),
      now: now,
    );
    expect(alert?.kind, SubscriptionAlertKind.expiringSoon);
    expect(alert?.daysLeft, 2);
  });

  test('ignores placeholder far-future expiry', () {
    final now = DateTime(2026, 8, 16);
    expect(
      evaluateSubscriptionAlert(
        profileId: 'p1',
        profileName: 'Lisa',
        info: info(expire: DateTime(2200, 1, 1), download: 10, total: 100),
        now: now,
      ),
      isNull,
    );
  });

  test('traffic at 90 percent', () {
    final now = DateTime(2026, 8, 16);
    final alert = evaluateSubscriptionAlert(
      profileId: 'p1',
      profileName: 'Lisa',
      info: info(download: 90, total: 100),
      now: now,
    );
    expect(alert?.kind, SubscriptionAlertKind.trafficHigh);
    expect(alert?.percent, 90);
  });

  test('unlimited total is not a traffic alert', () {
    final now = DateTime(2026, 8, 16);
    expect(
      evaluateSubscriptionAlert(
        profileId: 'p1',
        profileName: 'Lisa',
        info: info(download: 90, total: 0),
        now: now,
      ),
      isNull,
    );
  });

  test('dedupe key is once per day per kind', () {
    final a = SubscriptionAlert(
      kind: SubscriptionAlertKind.expiringSoon,
      profileId: 'p1',
      profileName: 'Lisa',
      daysLeft: 2,
    );
    final k1 = subscriptionAlertDedupeKey(a, DateTime(2026, 8, 16, 9));
    final k2 = subscriptionAlertDedupeKey(a, DateTime(2026, 8, 16, 21));
    final k3 = subscriptionAlertDedupeKey(a, DateTime(2026, 8, 17, 9));
    expect(k1, k2);
    expect(k1, isNot(k3));
  });
}
