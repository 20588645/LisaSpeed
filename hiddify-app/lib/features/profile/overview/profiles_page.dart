import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
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
                  TechUi.ghostButton(
                    context,
                    label: t.common.update,
                    onPressed: () => ref.read(foregroundProfilesUpdateNotifierProvider.notifier).trigger(),
                  ),
                  const Gap(8),
                  TechUi.ghostButton(
                    context,
                    label: t.common.sort,
                    onPressed: () => ref.read(dialogNotifierProvider.notifier).showSortProfiles(),
                  ),
                  const Gap(8),
                  TechUi.primaryButton(
                    context,
                    label: t.common.add,
                    onPressed: () async => await ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
                  ),
                  const Gap(20),
                ],
              ),
            ),
          ),
          Expanded(
            child: asyncProfiles.when(
              data: (data) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                separatorBuilder: (context, index) => const Gap(8),
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
