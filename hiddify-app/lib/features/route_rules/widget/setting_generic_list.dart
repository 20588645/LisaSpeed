import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/route_rules/widget/setting_detail_chips.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingGenericList<T extends Object> extends ConsumerWidget {
  const SettingGenericList({
    super.key,
    required this.title,
    required this.values,
    required this.onTap,
    this.useEllipsis = false,
    this.isPackageName = false,
    this.showPlatformWarning = false,
  });

  final String title;
  final List<T> values;
  final GestureTapCallback? onTap;
  final bool useEllipsis;
  final bool isPackageName;
  final bool showPlatformWarning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    // Bordered form row (same shell as the settings pages) with a count chip
    // and the chip strip flowing inside the row.
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: TechUi.formRowDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showPlatformWarning) ...[
                            Row(
                              children: [
                                Icon(size: 14, Icons.warning_rounded, color: TechUi.warnOf(context)),
                                const Gap(4),
                                Flexible(
                                  child: Text(
                                    t.pages.settings.routing.routeRule.rule.notAvailabeInThisPlatform,
                                    style: theme.textTheme.labelSmall!.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(2),
                          ],
                          Text(title, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const Gap(8),
                    TechUi.countChip(context, '${values.length}'),
                    const Gap(8),
                    Text(
                      '›',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (values.isNotEmpty) ...[
                const Gap(8),
                SettingDetailChips<T>(
                  values: values,
                  useEllipsis: useEllipsis,
                  isPackageName: isPackageName,
                  horizontalPadding: 12,
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
