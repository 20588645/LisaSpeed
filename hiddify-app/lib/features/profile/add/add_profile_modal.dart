import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/profile/add/widgets/free_btns.dart';
import 'package:hiddify/features/profile/add/widgets/widgets.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AddProfileModal extends HookConsumerWidget {
  const AddProfileModal({super.key, this.url});
  // static const warpConsentGiven = "warp_consent_given";
  final String? url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(addProfileNotifierProvider).isLoading;
    final currentWidget = ref.watch(addProfilePageNotifierProvider);
    ref.listen(freeSwitchNotifierProvider, (_, _) {});
    ref.listen(addProfileNotifierProvider, (previous, next) {
      if (next case AsyncData(value: final _?)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && context.canPop()) context.pop();
        });
      }
    });

    useMemoized(() async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (url != null && context.mounted) {
        if (isLoading) return;
        ref.read(addProfileNotifierProvider.notifier).addClipboard(url!);
      }
    });
    return SafeArea(
      child: isLoading
          ? const ProfileLoading()
          : switch (currentWidget) {
              AddProfilePages.options => const AddProfileOptions(),
              AddProfilePages.manual => const AddProfileManual(),
            },
    );
  }
}

/// Prototype `add-profile` modal: stacked choice rows (clipboard / file) and
/// a nested dashed "manual add" form, plus the free-subscriptions drawer.
class AddProfileOptions extends HookConsumerWidget {
  const AddProfileOptions({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final freeSwitch = ref.watch(freeSwitchNotifierProvider);
    final isDesktop = PlatformUtils.isDesktop;
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final nameTextController = useTextEditingController();
    final urlTextController = useTextEditingController();
    final freeScrollController = useScrollController();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.pages.profiles.add,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TechUi.ghostButton(
                      context,
                      label: t.common.close,
                      onPressed: () {
                        if (context.canPop()) context.pop();
                      },
                    ),
                  ],
                ),
                const Gap(14),
                _ModalChoice(
                  key: const ValueKey('add_from_clipboard_button'),
                  title: t.pages.profiles.addModal.clipboardTitle,
                  desc: t.pages.profiles.addModal.clipboardDesc,
                  onTap: () async {
                    final cr = await Clipboard.getData(Clipboard.kTextPlain).then((value) => value?.text ?? '');
                    await ref.read(addProfileNotifierProvider.notifier).addClipboard(cr);
                  },
                ),
                const Gap(10),
                _ModalChoice(
                  key: const ValueKey('add_from_file_button'),
                  title: t.pages.profiles.addModal.fileTitle,
                  desc: t.pages.profiles.addModal.fileDesc,
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['txt', 'json'],
                    );
                    if (result == null) return;
                    final file = File(result.files.single.path!);
                    if (!await file.exists()) return;
                    final bytes = await file.readAsBytes();
                    final content = utf8.decode(bytes);
                    await ref.read(addProfileNotifierProvider.notifier).addClipboard(content);
                  },
                ),
                if (!isDesktop) ...[
                  const Gap(10),
                  _ModalChoice(
                    key: const ValueKey('add_by_qr_code_button'),
                    title: t.pages.profiles.addModal.qrTitle,
                    desc: t.pages.profiles.addModal.qrDesc,
                    onTap: () async {
                      final cr = await ref.read(dialogNotifierProvider.notifier).showQrScanner();
                      if (cr == null) return;
                      await ref.read(addProfileNotifierProvider.notifier).addClipboard(cr);
                    },
                  ),
                ],
                const Gap(10),
                // Prototype `.form.nested`: dashed border around the manual form.
                CustomPaint(
                  painter: _DashedRRectPainter(color: ConnectionButtonTheme.lineOf(context)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TechUi.formSectionTitle(context, t.pages.profiles.addModal.manualTitle, first: true),
                          const Gap(8),
                          CustomTextFormField(
                            maxLines: 1,
                            controller: nameTextController,
                            validator: (value) =>
                                (value?.isEmpty ?? true) ? t.pages.profileDetails.form.emptyName : null,
                            label: t.common.name,
                            hint: t.pages.profileDetails.form.nameHint,
                          ),
                          const Gap(10),
                          CustomTextFormField(
                            maxLines: 1,
                            controller: urlTextController,
                            validator: (value) =>
                                (value != null && !isUrl(value)) ? t.pages.profileDetails.form.invalidUrl : null,
                            label: t.common.url,
                            hint: t.pages.profileDetails.form.urlHint,
                          ),
                          const Gap(12),
                          TechUi.primaryButton(
                            context,
                            label: t.pages.profiles.addModal.confirmAdd,
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                await ref
                                    .read(addProfileNotifierProvider.notifier)
                                    .addManual(
                                      url: urlTextController.text.trim(),
                                      userOverride: UserOverride(name: nameTextController.text.trim()),
                                    );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const NavBar(),
          AnimatedSize(
            alignment: Alignment.topCenter,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: freeSwitch
                ? SizedBox(height: 260, child: FreeBtns(scrollController: freeScrollController))
                : const SizedBox.shrink(),
          ),
          const Gap(8),
        ],
      ),
    );
  }
}

/// Prototype `.modal-choice`: bold title + muted description row.
class _ModalChoice extends StatelessWidget {
  const _ModalChoice({super.key, required this.title, required this.desc, required this.onTap});

  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ConnectionButtonTheme.accentOf(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: ConnectionButtonTheme.panelOf(context),
          border: Border.all(color: ConnectionButtonTheme.lineOf(context)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          hoverColor: accent.withValues(alpha: 0.08),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Gap(4),
                Text(
                  desc,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rect border, mirroring the prototype's `border: 1px dashed`.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color});

  final Color color;
  static const double radius = 12;
  static const double dash = 5;
  static const double gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
        const Radius.circular(radius),
      ));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}

class AddProfileManual extends HookConsumerWidget {
  const AddProfileManual({super.key});

  String _genSliderText(Translations t, int sliderValue) {
    if (sliderValue == 0) {
      return t.common.auto;
    } else if (sliderValue < 24) {
      return t.common.interval.hour(n: sliderValue);
    }
    final day = t.common.interval.day(n: sliderValue ~/ 24);
    final hour = t.common.interval.hour(n: sliderValue % 24);
    return '$day $hour';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final nameTextController = useTextEditingController();
    final urlTextController = useTextEditingController();
    final isAutoUpdateDisable = useState<bool>(false);
    final updateInterval = useState(.0);
    final sliderFocusNode = useFocusNode(
      onKeyEvent: (node, event) {
        if (KeyboardConst.verticalArrows.contains(event.logicalKey) && event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            node.previousFocus();
          } else {
            node.nextFocus();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 12),
            child: Row(
              children: [
                Expanded(child: Text(t.common.manually, style: theme.textTheme.headlineMedium)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(addProfilePageNotifierProvider.notifier).goOptions(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomTextFormField(
              maxLines: 1,
              controller: nameTextController,
              validator: (value) => (value?.isEmpty ?? true) ? t.pages.profileDetails.form.emptyName : null,
              label: t.common.name,
              hint: t.pages.profileDetails.form.nameHint,
            ),
          ),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomTextFormField(
              maxLines: 1,
              controller: urlTextController,
              validator: (value) => (value != null && !isUrl(value)) ? t.pages.profileDetails.form.invalidUrl : null,
              label: t.common.url,
              hint: t.pages.profileDetails.form.urlHint,
            ),
          ),
          const Gap(12),
          SwitchListTile.adaptive(
            title: Text(
              t.pages.profileDetails.form.disableAutoUpdate,
              style: theme.textTheme.titleSmall!.copyWith(color: theme.colorScheme.onSurface),
            ),
            value: isAutoUpdateDisable.value,
            onChanged: (value) => isAutoUpdateDisable.value = value,
          ),
          AnimatedSize(
            alignment: Alignment.topCenter,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: !isAutoUpdateDisable.value
                ? Column(
                    children: [
                      const Divider(indent: 16, endIndent: 16),
                      const Gap(12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.pages.profileDetails.form.autoUpdateInterval,
                                style: theme.textTheme.titleSmall!.copyWith(color: theme.colorScheme.onSurface),
                              ),
                            ),
                            Text(
                              _genSliderText(t, updateInterval.value.round()),
                              style: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const Gap(4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Slider(
                          focusNode: sliderFocusNode,
                          value: updateInterval.value,
                          max: 96,
                          divisions: 96,
                          label: updateInterval.value.round().toString(),
                          onChanged: (double value) => updateInterval.value = value,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    child: Text(t.common.add),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final i = updateInterval.value.toInt();
                        final interval = i > 0 ? i : null;
                        await ref
                            .read(addProfileNotifierProvider.notifier)
                            .addManual(
                              url: urlTextController.text.trim(),
                              userOverride: UserOverride(
                                name: nameTextController.text.trim(),
                                isAutoUpdateDisable: isAutoUpdateDisable.value,
                                updateInterval: interval,
                              ),
                            );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // const Gap(16),
        ],
      ),
    );
  }
}
