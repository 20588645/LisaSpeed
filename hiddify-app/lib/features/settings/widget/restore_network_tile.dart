import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/restore_network.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RestoreNetworkTile extends ConsumerStatefulWidget {
  const RestoreNetworkTile({super.key});

  @override
  ConsumerState<RestoreNetworkTile> createState() => _RestoreNetworkTileState();
}

class _RestoreNetworkTileState extends ConsumerState<RestoreNetworkTile> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final t = ref.read(translationsProvider).requireValue;
    try {
      await ref.read(connectionNotifierProvider.notifier).abortConnection();
      await ref.read(Preferences.startedByUser.notifier).update(false);
      await restoreLocalNetwork();
      if (!mounted) return;
      ref.read(inAppNotificationControllerProvider).showSuccessToast(t.pages.settings.general.restoreNetworkDone);
    } catch (e) {
      if (!mounted) return;
      ref.read(inAppNotificationControllerProvider).showErrorToast(
        t.pages.settings.general.restoreNetworkFailed(error: e.toString()),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: TechUi.formRowDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _busy ? null : _run,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.pages.settings.general.restoreNetwork,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.pages.settings.general.restoreNetworkMsg,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
