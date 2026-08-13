import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/features/route_rules/widget/setting_detail_chips.dart';
import 'package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart';
import 'package:hiddify/utils/platform_utils.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:protobuf/protobuf.dart';

class RuleTile extends HookConsumerWidget {
  const RuleTile({super.key, required this.index, required this.rule});

  final Rule rule;
  final int index;

  Map detailChipsValue() {
    final map = rule.toProto3Json()! as Map<String, dynamic>;
    map.removeWhere((key, value) => ['list_order', 'enabled', 'name', 'outbound'].contains(key));
    map.updateAll(
      (key, value) => value is List
          ? value.length
          : value is ProtobufEnum
          ? value.name
          : value,
    );
    return map;
  }

  Map<String, String> mergeTranslation(List<Map<String, String>> translations) {
    return Map.fromEntries(translations.expand((map) => map.entries).toList());
  }

  Future handleDelete(BuildContext context, WidgetRef ref) async {
    final t = ref.watch(translationsProvider).requireValue;
    final result = await ref
        .read(dialogNotifierProvider.notifier)
        .showConfirmation(
          title: t.dialogs.confirmation.routeRule.delete.title,
          message: t.dialogs.confirmation.routeRule.delete.msg(rulename: rule.name),
          positiveBtnTxt: t.common.delete,
        );
    if (result == true) {
      await ref.read(rulesNotifierProvider.notifier).deleteRule(rule.listOrder);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final accent = ConnectionButtonTheme.accentOf(context);
    final scrollController = useScrollController();
    ref.listen(rulesNotifierProvider, (_, _) {
      if (scrollController.offset > 0) scrollController.jumpTo(0);
    });
    final chips = detailChipsValue();

    // Same `.list-row` shell as the nodes/subscriptions lists — enabled rules
    // carry the accent border + inset stripe the way active rows do there.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onSecondaryTapUp: PlatformUtils.isDesktop
            ? (details) {
                final offset = details.globalPosition;
                showMenu(
                  context: context,
                  position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx, offset.dy),
                  items: [
                    PopupMenuItem(
                      child: Text(t.pages.settings.routing.routeRule.delete),
                      onTap: () async => await handleDelete(context, ref),
                    ),
                  ],
                );
              }
            : null,
        child: TechUi.listRow(
          context,
          selected: rule.enabled,
          padding: EdgeInsets.zero,
          onTap: () {
            context.goNamed('rule', pathParameters: {'orderId': rule.listOrder.toString()});
          },
          onLongPress: () async => await handleDelete(context, ref),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 10, 0),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.pages.settings.routing.routeRule.rule.outbound[rule.outbound.name] ??
                                rule.outbound.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            rule.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: rule.enabled,
                        onChanged: (value) async =>
                            await ref.read(rulesNotifierProvider.notifier).updateEnabled(value, rule.listOrder),
                      ),
                    ),
                  ],
                ),
              ),
              if (chips.isNotEmpty) ...[
                const Gap(6),
                SettingDetailChips<MapEntry>(
                  values: chips.entries.toList(),
                  scrollController: scrollController,
                  horizontalPadding: 14,
                  t: mergeTranslation([
                    t.pages.settings.routing.routeRule.rule.tileTitle,
                    t.pages.settings.routing.routeRule.rule.network,
                    t.pages.settings.routing.routeRule.rule.outbound,
                  ]),
                ),
              ] else
                const Gap(11),
            ],
          ),
        ),
      ),
    );
  }
}
