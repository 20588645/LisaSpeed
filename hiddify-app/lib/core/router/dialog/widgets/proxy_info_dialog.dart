import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hiddify/features/proxy/overview/proxy_display.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProxyInfoDialog extends HookConsumerWidget {
  const ProxyInfoDialog({super.key, required this.outboundInfo});

  final OutboundInfo outboundInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final locale = ref.watch(localePreferencesProvider);
    final chinese = locale == AppLocale.zhCn || locale == AppLocale.zhTw;
    final title = proxyDisplayTitle(outboundInfo, chinese: chinese, autoLabel: t.pages.proxies.autoSelect);
    return TechDialog.alert(
      title: SelectionArea(child: Text(title)),
      content: OutboundInfoWidget(outboundInfo: outboundInfo),
      actions: [TechDialogActions.ok(context, onPressed: context.pop, label: t.common.close)],
    );
  }
}

class OutboundInfoWidget extends HookConsumerWidget {
  final OutboundInfo outboundInfo;

  const OutboundInfoWidget({super.key, required this.outboundInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final delayText = proxyDelayLabel(
      outboundInfo.urlTestDelay,
      testing: t.pages.home.delayTesting,
      timeout: t.pages.proxies.delay.timeout,
    );
    final testTime = outboundInfo.urlTestTime.toDateTime().toLocal();
    final hasTestTime = testTime.year >= 2000;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoRow(t.dialogs.proxyInfo.fullTag, outboundInfo.tag),
          _buildInfoRow(t.dialogs.proxyInfo.type, outboundInfo.type),
          if (hasTestTime)
            _buildInfoRow(t.dialogs.proxyInfo.testTime, DateFormat('yyyy-MM-dd HH:mm:ss').format(testTime)),
          _buildInfoRow(t.dialogs.proxyInfo.testDelay, delayText),
          _buildIpInfo(outboundInfo.ipinfo, ref),
          _buildInfoRow(t.dialogs.proxyInfo.upload, formatBytes(outboundInfo.upload.toInt())),
          _buildInfoRow(t.dialogs.proxyInfo.download, formatBytes(outboundInfo.download.toInt())),
          _buildInfoRow(t.dialogs.proxyInfo.isSelected, outboundInfo.isSelected ? t.dialogs.proxyInfo.yes : t.dialogs.proxyInfo.no),
          _buildInfoRow(t.dialogs.proxyInfo.isGroup, outboundInfo.isGroup ? t.dialogs.proxyInfo.yes : t.dialogs.proxyInfo.no),
          _buildInfoRow(
            t.dialogs.proxyInfo.isSecure,
            proxyLooksEncrypted(outboundInfo) ? t.dialogs.proxyInfo.yes : t.dialogs.proxyInfo.no,
          ),
          _buildInfoRow(t.dialogs.proxyInfo.port, outboundInfo.port == 0 ? '' : outboundInfo.port.toString()),
          _buildInfoRow(t.dialogs.proxyInfo.host, outboundInfo.isGroup ? '' : outboundInfo.host),
        ],
      ),
    );
  }

  String formatBytes(int bytes, {int decimals = 3}) {
    if (bytes <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final decimals2 = switch (unitIndex) {
      0 => 0,
      1 => 0,
      2 => 1,
      _ => decimals,
    };

    return '${size.toStringAsFixed(decimals2)} ${units[unitIndex]}';
  }

  Widget _buildInfoRow(String title, String value, {Future<bool>? Function()? onTap}) {
    if (value.isEmpty || value == '0.0, 0.0') {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8.0),
          Flexible(
            child: onTap != null
                ? GestureDetector(
                    onTap: onTap,
                    child: SelectableText(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(decoration: TextDecoration.underline),
                    ),
                  )
                : SelectableText(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildIpInfo(IpInfo ipInfo, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(t.dialogs.proxyInfo.ip, ipInfo.ip),
        _buildInfoRow(t.dialogs.proxyInfo.countryCode, ipInfo.countryCode),
        _buildInfoRow(t.dialogs.proxyInfo.region, ipInfo.region),
        _buildInfoRow(t.dialogs.proxyInfo.city, ipInfo.city),
        _buildInfoRow(t.dialogs.proxyInfo.asn, ipInfo.asn == 0 ? '' : ipInfo.asn.toString()),
        _buildInfoRow(t.dialogs.proxyInfo.organization, ipInfo.org),
        _buildInfoRow(
          t.dialogs.proxyInfo.location,
          "${ipInfo.latitude}, ${ipInfo.longitude}",
          onTap: () => launchUrl(
            Uri.parse(
              !PlatformUtils.isInAppStore
                  ? 'https://maps.apple.com/?ll=${ipInfo.latitude},${ipInfo.longitude}'
                  : 'https://www.google.com/maps/@${ipInfo.latitude},${ipInfo.longitude},18z',
            ),
          ),
        ),
        _buildInfoRow(t.dialogs.proxyInfo.postalCode, ipInfo.postalCode),
      ],
    );
  }
}
