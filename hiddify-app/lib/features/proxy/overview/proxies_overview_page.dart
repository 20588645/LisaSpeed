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
                  MenuAnchor(
                    menuChildren: [
                      for (final sort in ProxiesSort.values)
                        MenuItemButton(
                          onPressed: () => ref.read(proxiesSortNotifierProvider.notifier).update(sort),
                          trailingIcon: sort == sortBy
                              ? Icon(Icons.check_rounded, size: 16, color: ConnectionButtonTheme.accentOf(context))
                              : null,
                          child: Text(sort.present(t)),
                        ),
                    ],
                    builder: (context, controller, child) => TechUi.ghostButton(
                      context,
                      label: t.pages.proxies.sort,
                      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                    ),
                  ),
                  const Gap(8),
                  TechUi.primaryButton(
                    context,
                    label: t.pages.proxies.testDelay,
                    onPressed: () async =>
                        await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest('select'),
                  ),
                  const Gap(20),
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
                          child: Row(
                            children: [
                              TechUi.countChip(context, '${group.items.length}'),
                              const Gap(6),
                              Text(
                                t.pages.proxies.countSuffix,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          // Same gutters/rhythm as the subscriptions list so
                          // the cards line up page to page (prototype `.list`).
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            separatorBuilder: (context, index) => const Gap(8),
                            itemCount: group.items.length,
                            itemBuilder: (context, index) {
                              final proxy = group.items[index];
                              return ProxyTile(
                                proxy,
                                // `group.selected` is typed as a string in the
                                // Dart stubs but the Go core sends a message on
                                // that field, so it never matches; the per-item
                                // `is_selected` bool is aligned on both sides.
                                selected: proxy.isSelected,
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
