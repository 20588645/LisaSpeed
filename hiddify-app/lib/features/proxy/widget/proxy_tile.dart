import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/features/proxy/overview/proxy_display.dart';
import 'package:hiddify/features/proxy/overview/proxy_list_filter.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxyTile extends HookConsumerWidget with PresLogger {
  const ProxyTile(this.proxy, {super.key, required this.selected, required this.onTap});

  final OutboundInfo proxy;
  final bool selected;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    final locale = ref.watch(localePreferencesProvider);
    final chinese = locale == AppLocale.zhCn || locale == AppLocale.zhTw;
    final title = proxyDisplayTitle(proxy, chinese: chinese, autoLabel: t.pages.proxies.autoSelect);
    final country = proxyFlagCountryCode(proxy);
    final protocolChip = isInjectedAutoGroup(proxy)
        ? ''
        : (proxyProtocolLabel(proxyRemark(proxy), proxy.type) ?? proxy.type);
    final selectedMember = proxy.isGroup
        ? stripProxyVendorNoise(
            proxy.groupSelectedTagDisplay.isNotEmpty ? proxy.groupSelectedTagDisplay : proxy.host,
          )
        : '';
    final showProtocol = protocolChip.isNotEmpty && !title.contains(protocolChip);
    final showSubtitle = showProtocol || selectedMember.isNotEmpty;

    return TechUi.listRow(
      context,
      selected: selected,
      onTap: onTap,
      onLongPress: () async =>
          await ref.read(dialogNotifierProvider.notifier).showProxyInfo(outboundInfo: proxy),
      child: Row(
        children: [
          if (country.isNotEmpty) ...[
            IPCountryFlag(countryCode: country, size: 24),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (selected) ...[
                      TechUi.currentBadge(context, t.pages.proxies.current),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (showSubtitle) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      if (showProtocol) ...[
                        TechUi.tag(context, protocolChip, monoFont: true),
                        if (selectedMember.isNotEmpty) const SizedBox(width: 6),
                      ],
                      if (selectedMember.isNotEmpty) Flexible(child: TechUi.tag(context, selectedMember)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (proxy.urlTestDelay != 0)
            TechUi.latencyPill(
              context,
              proxy.urlTestDelay,
              emptyLabel: proxy.urlTestDelay >= 65000 ? t.pages.proxies.delay.timeout : null,
            ),
        ],
      ),
    );
  }
}
