import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/route_rules/notifier/generic_list_notifier.dart';
import 'package:hiddify/features/route_rules/notifier/rule_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:text_scroll/text_scroll.dart';

class GenericListPage extends HookConsumerWidget {
  const GenericListPage({super.key, this.ruleListOrder, required this.ruleEnum});

  final int? ruleListOrder;
  final RuleEnum ruleEnum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final provider = genericListNotifierProvider(ruleListOrder, ruleEnum);
    final list = ref.watch(provider);

    Future<void> addNewValue() async {
      final result = await ref
          .read(dialogNotifierProvider.notifier)
          .showSettingText(
            lable: t.pages.settings.routing.routeRule.genericList.addNew,
            validator: ruleEnum.validator(t),
          );
      if (result is String) ref.read(provider.notifier).add(result);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.subPageHeader(
              context,
              eyebrow: 'Rule',
              title: ruleEnum.present(t),
              onBack: () => context.pop(),
              actions: [
                TechUi.ghostButton(
                  context,
                  label: t.common.clear,
                  onPressed: list.isEmpty
                      ? null
                      : () async {
                          final result = await ref
                              .read(dialogNotifierProvider.notifier)
                              .showConfirmation(
                                title: t.pages.settings.routing.routeRule.genericList.clearList,
                                message: t.pages.settings.routing.routeRule.genericList.clearListMsg,
                              );
                          if (result == true) ref.read(provider.notifier).reset();
                        },
                ),
                TechUi.primaryButton(
                  context,
                  label: t.pages.settings.routing.routeRule.genericList.addNew,
                  onPressed: addNewValue,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: TechUi.panelDecoration(context),
                  clipBehavior: Clip.antiAlias,
                  child: GenericListTile(
                    value: list[index],
                    onRemove: () => ref.read(provider.notifier).remove(index),
                    onUpdate: () async {
                      final result = await ref
                          .read(dialogNotifierProvider.notifier)
                          .showSettingText(
                            lable: t.pages.settings.routing.routeRule.genericList.update,
                            value: '${list[index]}',
                            validator: ruleEnum.validator(t),
                          );
                      if (result is String) ref.read(provider.notifier).update(index, result);
                    },
                  ),
                ),
              ),
              itemCount: list.length,
            ),
          ),
        ],
      ),
    );
  }
}

class GenericListTile extends ConsumerWidget {
  const GenericListTile({super.key, required this.value, required this.onRemove, required this.onUpdate});

  final dynamic value;
  final VoidCallback? onRemove;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: onUpdate,
      title: TextScroll(
        '$value',
        mode: TextScrollMode.bouncing,
        velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
        pauseOnBounce: const Duration(seconds: 2),
        pauseBetween: const Duration(seconds: 2),
      ),
      trailing: IconButton(onPressed: onRemove, icon: const Icon(Icons.remove)),
    );
  }
}
