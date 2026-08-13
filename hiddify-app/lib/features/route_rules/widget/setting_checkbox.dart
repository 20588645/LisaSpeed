import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:protobuf/protobuf.dart';

class SettingCheckbox extends ConsumerWidget {
  const SettingCheckbox({
    super.key,
    required this.title,
    required this.values,
    required this.selectedValues,
    required this.setValue,
    this.defaultValue,
    this.t,
  });

  final String title;
  final List<ProtobufEnum> values;
  final List<ProtobufEnum> selectedValues;
  final Function(List<ProtobufEnum> value) setValue;
  final List<ProtobufEnum>? defaultValue;
  final Map<String, String>? t;

  String textWithTranslation(List<ProtobufEnum> e, WidgetRef ref) {
    if (t == null) {
      return e.map((e) => '$e').toList().join(', ');
    } else {
      if (e.isEmpty) return t![''] ?? ref.watch(translationsProvider).requireValue.common.empty;
      return e.map((e) => t!['$e'] ?? '$e').toList().join(', ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Same bordered form row as the settings pages.
    return PreferenceRow(
      title: title,
      valueText: textWithTranslation(selectedValues, ref),
      onTap: () async {
        final result = await ref
            .read(dialogNotifierProvider.notifier)
            .showSettingCheckbox(
              title: title,
              values: values,
              selectedValues: selectedValues,
              defaultValue: defaultValue,
              t: t,
            );
        if (result is List<ProtobufEnum>) setValue(result);
      },
    );
  }
}
