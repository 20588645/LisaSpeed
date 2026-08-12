import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/notifier/profiles_update_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProfilesPage extends HookConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final asyncProfiles = ref.watch(profilesNotifierProvider);

    ref.listen(hasAnyProfileProvider, (_, next) {
      if (next.value == false) {
        context.goNamed('home');
      }
    });

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
                      eyebrow: 'Subscriptions',
                      title: t.pages.profiles.title,
                      subtitle: t.pages.profiles.subtitle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref.read(foregroundProfilesUpdateNotifierProvider.notifier).trigger(),
                    icon: const Icon(Icons.update_rounded),
                    tooltip: t.pages.profiles.updateSubscriptions,
                  ),
                  IconButton(
                    onPressed: () => ref.read(dialogNotifierProvider.notifier).showSortProfiles(),
                    icon: const Icon(Icons.sort_rounded),
                    tooltip: t.common.sort,
                  ),
                  FilledButton.icon(
                    onPressed: () async => await ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
                    style: FilledButton.styleFrom(
                      backgroundColor: ConnectionButtonTheme.brandMint,
                      foregroundColor: const Color(0xFF041016),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(t.pages.profiles.add),
                  ),
                  const Gap(8),
                ],
              ),
            ),
          ),
          Expanded(
            child: asyncProfiles.when(
              data: (data) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                separatorBuilder: (context, index) => const Gap(10),
                itemBuilder: (context, index) => ProfileTile(profile: data[index]),
                itemCount: data.length,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(t.presentShortError(error)),
            ),
          ),
        ],
      ),
    );
  }
}
