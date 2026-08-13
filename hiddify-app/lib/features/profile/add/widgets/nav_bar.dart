import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class NavBar extends ConsumerWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    final freeSwitch = ref.watch(freeSwitchNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(
        AddProfileModalConst.navBarGap,
      ).copyWith(bottom: AddProfileModalConst.navBarBottomGap),
      child: Row(
        children: [
          Row(
            key: const ValueKey('free'),
            children: [
              Text(
                t.common.free,
                style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
              ),
              const Gap(8),
              Transform.scale(
                scale: 0.8,
                child: Switch(value: freeSwitch, onChanged: ref.read(freeSwitchNotifierProvider.notifier).onChange),
              ),
            ],
          ),
          const Spacer(),
          KeyedSubtree(
            key: const ValueKey("help"),
            child: TechUi.ghostButton(
              context,
              label: t.common.help,
              onPressed: () async => await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile(),
            ),
          ),
        ],
      ),
    );
  }
}
