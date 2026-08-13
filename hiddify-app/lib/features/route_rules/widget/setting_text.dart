import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingText extends ConsumerWidget {
  const SettingText({
    super.key,
    required this.title,
    required this.value,
    required this.setValue,
    this.defaultValue,
    this.validator,
  });

  final String title;
  final String value;
  final Function(String value) setValue;
  final String? defaultValue;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // Same bordered form row as the settings pages.
    return PreferenceRow(
      title: title,
      valueText: value.isEmpty ? t.common.empty : value,
      onTap: () async {
        final result = await ref
            .read(dialogNotifierProvider.notifier)
            .showSettingText(lable: title, value: value, defaultValue: defaultValue, validator: validator);
        if (result is String) setValue(result);
      },
    );
  }
}
