import 'package:hiddify/features/profile/model/profile_entity.dart';

enum SubscriptionAlertKind { expired, expiringSoon, trafficHigh }

class SubscriptionAlert {
  const SubscriptionAlert({
    required this.kind,
    required this.profileId,
    required this.profileName,
    this.daysLeft,
    this.percent,
  });

  final SubscriptionAlertKind kind;
  final String profileId;
  final String profileName;
  final int? daysLeft;
  final int? percent;
}

const subscriptionTrafficWarnRatio = 0.9;
const subscriptionExpiringDays = 3;

/// Far-future placeholders (empty expire in the subscription header) are not
/// real due dates — don't nag about them.
bool subscriptionHasFiniteExpiry(DateTime expire) => expire.year > 1971 && expire.year < 2100;

SubscriptionAlert? evaluateSubscriptionAlert({
  required String profileId,
  required String profileName,
  required SubscriptionInfo info,
  required DateTime now,
  int expiringDays = subscriptionExpiringDays,
  double trafficRatio = subscriptionTrafficWarnRatio,
}) {
  if (subscriptionHasFiniteExpiry(info.expire)) {
    if (!info.expire.isAfter(now)) {
      return SubscriptionAlert(
        kind: SubscriptionAlertKind.expired,
        profileId: profileId,
        profileName: profileName,
      );
    }
    final days = info.expire.difference(now).inDays;
    if (days <= expiringDays) {
      return SubscriptionAlert(
        kind: SubscriptionAlertKind.expiringSoon,
        profileId: profileId,
        profileName: profileName,
        daysLeft: days,
      );
    }
  }
  if (info.total > 0 && info.ratio >= trafficRatio) {
    return SubscriptionAlert(
      kind: SubscriptionAlertKind.trafficHigh,
      profileId: profileId,
      profileName: profileName,
      percent: (info.ratio * 100).round(),
    );
  }
  return null;
}

/// One native banner per kind per day (or per 5% traffic bucket) so a keep-alive
/// listener does not spam Notification Center.
String subscriptionAlertDedupeKey(SubscriptionAlert alert, DateTime now) {
  final day = '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  return switch (alert.kind) {
    SubscriptionAlertKind.expired => '${alert.profileId}|expired|$day',
    SubscriptionAlertKind.expiringSoon => '${alert.profileId}|expiring|$day',
    SubscriptionAlertKind.trafficHigh =>
      '${alert.profileId}|traffic|${(alert.percent ?? 0) ~/ 5}|$day',
  };
}
