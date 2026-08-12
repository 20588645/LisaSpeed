import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/widget/proxy_tile.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxiesOverviewPage extends HookConsumerWidget with PresLogger {
  const ProxiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final sortBy = ref.watch(proxiesSortNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TechUi.pageIntro(
                      context,
                      eyebrow: 'Nodes',
                      title: t.pages.proxies.title,
                      subtitle: t.pages.proxies.subtitle,
                    ),
                  ),
                  PopupMenuButton<ProxiesSort>(
                    initialValue: sortBy,
                    onSelected: ref.read(proxiesSortNotifierProvider.notifier).update,
                    icon: const Icon(FluentIcons.arrow_sort_24_regular),
                    tooltip: t.pages.proxies.sort,
                    itemBuilder: (context) {
                      return [...ProxiesSort.values.map((e) => PopupMenuItem(value: e, child: Text(e.present(t))))];
                    },
                  ),
                  IconButton(
                    tooltip: t.pages.proxies.testDelay,
                    onPressed: () async =>
                        await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest('select'),
                    icon: const Icon(FluentIcons.flash_24_filled),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF041016),
                      backgroundColor: ConnectionButtonTheme.brandMint,
                    ),
                  ),
                  const Gap(8),
                ],
              ),
            ),
          ),
          Expanded(
            child: proxies.when(
              data: (group) => group != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Text(
                            t.pages.proxies.countHint(count: group.items.length),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: group.items.length,
                            itemBuilder: (context, index) {
                              final proxy = group.items[index];
                              return ProxyTile(
                                proxy,
                                selected: group.selected == proxy.tag,
                                onTap: () async {
                                  await ref
                                      .read(proxiesOverviewNotifierProvider.notifier)
                                      .changeProxy(group.tag, proxy.tag);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : Center(child: Text(t.pages.proxies.empty)),
              error: (error, stackTrace) => Center(child: Text(t.presentShortError(error))),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
