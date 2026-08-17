import 'dart:async';

import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/notification/native_notifier.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/model/subscription_alert.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final subscriptionAlertProvider = NotifierProvider<SubscriptionAlertNotifier, int>(
  SubscriptionAlertNotifier.new,
);

class SubscriptionAlertNotifier extends Notifier<int> with AppLogger {
  static const _prefKey = 'subscription_alert_keys';
  static const _keep = 40;

  @override
  int build() {
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    if (profile is RemoteProfileEntity) {
      scheduleMicrotask(() => _maybeAlert(profile));
    }
    return 0;
  }

  Future<void> _maybeAlert(RemoteProfileEntity profile) async {
    final info = profile.subInfo;
    if (info == null) return;
    final now = DateTime.now();
    final alert = evaluateSubscriptionAlert(
      profileId: profile.id,
      profileName: profile.name,
      info: info,
      now: now,
    );
    if (alert == null) return;

    final prefs = ref.read(sharedPreferencesProvider).requireValue;
    final seen = prefs.getStringList(_prefKey) ?? const <String>[];
    final key = subscriptionAlertDedupeKey(alert, now);
    if (seen.contains(key)) return;

    final next = [...seen, key];
    while (next.length > _keep) {
      next.removeAt(0);
    }
    await prefs.setStringList(_prefKey, next);

    final t = ref.read(translationsProvider).requireValue;
    final title = switch (alert.kind) {
      SubscriptionAlertKind.expired => t.alerts.subExpiredTitle,
      SubscriptionAlertKind.expiringSoon => t.alerts.subExpiringTitle,
      SubscriptionAlertKind.trafficHigh => t.alerts.subTrafficTitle,
    };
    final body = switch (alert.kind) {
      SubscriptionAlertKind.expired => t.alerts.subExpiredBody(name: alert.profileName),
      SubscriptionAlertKind.expiringSoon => t.alerts.subExpiringBody(
        name: alert.profileName,
        days: alert.daysLeft ?? 0,
      ),
      SubscriptionAlertKind.trafficHigh => t.alerts.subTrafficBody(
        name: alert.profileName,
        percent: alert.percent ?? 0,
      ),
    };
    loggy.info('subscription alert ${alert.kind.name} for ${profile.name}');
    ref.read(inAppNotificationControllerProvider).showInfoToast(body, duration: const Duration(seconds: 6));
    await NativeNotifier.show(title, body);
  }
}
