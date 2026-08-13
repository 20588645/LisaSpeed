import 'package:flutter/material.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/gen/fonts.gen.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxyTile extends HookConsumerWidget with PresLogger {
  const ProxyTile(this.proxy, {super.key, required this.selected, required this.onTap});

  final OutboundInfo proxy;
  final bool selected;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: () async =>
              await ref.read(dialogNotifierProvider.notifier).showProxyInfo(outboundInfo: proxy),
          child: Ink(
            decoration: TechUi.panelDecoration(context, selected: selected),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: selected ? ConnectionButtonTheme.accentOf(context) : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    if (selected) ...[
                                      TechUi.currentBadge(context),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: Text(
                                        proxy.tagDisplay,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontFamily: PlatformUtils.isWindows ? FontFamily.emoji : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                // Region + mono protocol tag chips, mirroring the prototype rows.
                                Row(
                                  children: [
                                    if (proxy.ipinfo.countryCode.trim().isNotEmpty) ...[
                                      TechUi.tag(context, proxy.ipinfo.countryCode.trim()),
                                      const SizedBox(width: 6),
                                    ],
                                    TechUi.tag(context, proxy.type, monoFont: true),
                                    if (proxy.isGroup && proxy.groupSelectedTagDisplay.trim().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: TechUi.tag(context, proxy.groupSelectedTagDisplay.trim()),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (proxy.urlTestDelay != 0) TechUi.latencyPill(context, proxy.urlTestDelay),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
