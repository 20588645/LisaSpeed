import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class NavBar extends ConsumerWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    return Padding(
      padding: const EdgeInsets.all(
        AddProfileModalConst.navBarGap,
      ).copyWith(bottom: AddProfileModalConst.navBarBottomGap),
      child: Row(
        children: [
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
