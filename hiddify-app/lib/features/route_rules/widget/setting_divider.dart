import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Group break inside the rule form panel: a plain gap, or a small warning
/// label for platform-limited groups (styled like the form section titles).
class SettingDivider extends ConsumerWidget {
  const SettingDivider({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (title == null) return const Gap(4);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Icon(size: 14, Icons.warning_rounded, color: TechUi.warnOf(context)),
          const Gap(6),
          Text(
            title!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
