import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/app_update/notifier/app_update_notifier.dart';
import 'package:hiddify/features/app_update/notifier/app_update_state.dart';
import 'package:hiddify/features/dev_update/widget/local_update_dialog.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AboutPage extends HookConsumerWidget {
  const AboutPage({super.key});

  String _presentPlatform(String os) => switch (os.toLowerCase()) {
    'macos' => 'macOS',
    'windows' => 'Windows',
    'linux' => 'Linux',
    'android' => 'Android',
    'ios' => 'iOS',
    _ => os,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final appInfo = ref.watch(appInfoProvider).requireValue;
    final appUpdate = ref.watch(appUpdateNotifierProvider);
    final accent = ConnectionButtonTheme.accentOf(context);

    ref.listen(appUpdateNotifierProvider, (_, next) async {
      if (!context.mounted) return;
      switch (next) {
        case AppUpdateStateAvailable(:final versionInfo) || AppUpdateStateIgnored(:final versionInfo):
          return await ref
              .read(dialogNotifierProvider.notifier)
              .showNewVersion(currentVersion: appInfo.presentVersion, newVersion: versionInfo, canIgnore: false);
        case AppUpdateStateError(:final error):
          return CustomToast.error(t.presentShortError(error)).show(context);
        case AppUpdateStateNotAvailable():
          return CustomToast.success(t.pages.about.notAvailableMsg).show(context);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.subPageHeader(
              context,
              title: t.pages.about.title,
              subtitle: '${t.common.appTitle} ${appInfo.presentVersion}',
              onBack: () => context.pop(),
              actions: [
                if (appInfo.release.allowCustomUpdateChecker)
                  appUpdate is AppUpdateStateChecking
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : TechUi.ghostButton(
                          context,
                          label: t.pages.about.checkForUpdate,
                          onPressed: () async {
                            await ref.read(appUpdateNotifierProvider.notifier).check();
                          },
                        ),
                if (PlatformUtils.isMacOS)
                  TechUi.primaryButton(
                    context,
                    label: t.pages.about.localUpdate,
                    onPressed: () => LocalUpdateDialog.show(context),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      decoration: TechUi.panelDecoration(context),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        children: [
                          // Prototype `.about-logo`: XL logo mark with soft glow ring.
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: accent.withValues(alpha: 0.08), spreadRadius: 6),
                                BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 24),
                              ],
                            ),
                            child: TechUi.logoMark(size: 72),
                          ),
                          const Gap(12),
                          Text(
                            t.common.appTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const Gap(8),
                          Text(
                            t.pages.about.lead,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const Gap(20),
                          // Prototype `.about-meta`: version / channel / platform grid.
                          Container(
                            decoration: TechUi.formRowDecoration(context).copyWith(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                _MetaCell(label: t.common.version, value: appInfo.presentVersion),
                                _MetaCell(label: t.pages.about.channel, value: appInfo.environment.name),
                                _MetaCell(label: t.pages.about.platform, value: _presentPlatform(appInfo.operatingSystem)),
                              ],
                            ),
                          ),
                          const Gap(18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (PlatformUtils.isDesktop)
                                TechUi.ghostButton(
                                  context,
                                  label: t.pages.about.workingDir,
                                  onPressed: () async {
                                    final path = ref.read(appDirectoriesProvider).requireValue.workingDir.uri;
                                    await UriUtils.tryLaunch(path);
                                  },
                                ),
                              TechUi.ghostButton(
                                context,
                                label: t.pages.about.openLogs,
                                onPressed: () => context.goNamed('logs'),
                              ),
                              TechUi.ghostButton(
                                context,
                                label: t.pages.about.sourceCode,
                                onPressed: () async {
                                  await UriUtils.tryLaunch(Uri.parse(Constants.githubUrl));
                                },
                              ),
                              TechUi.ghostButton(
                                context,
                                label: t.pages.about.copyInfo,
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: appInfo.format()));
                                  ref
                                      .read(inAppNotificationControllerProvider)
                                      .showSuccessToast(t.common.msg.export.clipboard.success);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
