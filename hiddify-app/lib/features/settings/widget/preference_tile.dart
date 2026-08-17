import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/features/settings/notifier/battery_optimization/battery_optimizations_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Prototype form row: bordered 10px-radius row with the label on the left
/// and the current value + chevron on the right (mirrors `label > select`).
class PreferenceRow extends StatelessWidget {
  const PreferenceRow({
    super.key,
    required this.title,
    this.valueText,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final String title;
  final String? valueText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: TechUi.formRowDecoration(context),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 12),
                  Expanded(
                    child: valueText == null
                        ? const SizedBox.shrink()
                        : Text(
                            valueText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '›',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ValuePreferenceWidget<T> extends HookConsumerWidget {
  const ValuePreferenceWidget({
    super.key,
    required this.value,
    required this.preferences,
    this.enabled = true,
    required this.title,
    this.presentValue,
    this.formatInputValue,
    this.validateInput,
    this.inputToValue,
    this.digitsOnly = false,
    this.icon,
    this.trailing,
  });

  final T value;
  final PreferencesNotifier<T, dynamic> preferences;
  final bool enabled;
  final String title;
  final String Function(T value)? presentValue;
  final String Function(T value)? formatInputValue;
  final bool Function(String value)? validateInput;
  final T? Function(String input)? inputToValue;
  final bool digitsOnly;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PreferenceRow(
      title: title,
      valueText: presentValue?.call(value) ?? value.toString(),
      trailing: trailing,
      enabled: enabled,
      onTap: () async {
        final inputValue = await ref
            .read(dialogNotifierProvider.notifier)
            .showSettingInput(
              title: title,
              initialValue: value,
              validator: validateInput,
              valueFormatter: formatInputValue,
              onReset: preferences.reset,
              digitsOnly: digitsOnly,
              mapTo: inputToValue,
              possibleValues: preferences.possibleValues,
            );
        if (inputValue == null) {
          return;
        }
        await preferences.update(inputValue);
      },
    );
  }
}

class SwitchPreferenceWidget extends HookConsumerWidget {
  const SwitchPreferenceWidget({super.key, required this.preference});

  final StateNotifierProvider<StateNotifier<bool>, bool> preference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(preference);
    return Transform.scale(
      scale: 0.8,
      child: Switch(
        value: value,
        onChanged: (val) {
          (ref.read(preference.notifier) as dynamic).update(val);
        },
      ),
    );
  }
}

class ChoicePreferenceWidget<T> extends HookConsumerWidget {
  const ChoicePreferenceWidget({
    super.key,
    required this.selected,
    required this.preferences,
    this.enabled = true,
    required this.choices,
    required this.title,
    this.showFlag = false,
    this.icon,
    required this.presentChoice,
    this.validateInput,
    this.autoUpdate = true,
    this.onChanged,
  });

  final T selected;
  final PreferencesNotifier<T, dynamic> preferences;
  final bool enabled;
  final List<T> choices;
  final String title;
  final bool showFlag;
  final IconData? icon;
  final String Function(T value) presentChoice;
  final bool Function(String value)? validateInput;
  final bool autoUpdate;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PreferenceRow(
      title: title,
      valueText: presentChoice(selected),
      trailing: showFlag ? flagByTitle(presentChoice(selected), size: 28) : null,
      enabled: enabled,
      onTap: () async {
        final selection = await ref
            .read(dialogNotifierProvider.notifier)
            .showSettingPicker<T>(
              title: title,
              showFlag: showFlag,
              selected: selected,
              options: choices,
              getTitle: (e) => presentChoice(e),
              onReset: preferences.reset,
            );
        if (selection == null) return;
        if (autoUpdate) {
          final out = await preferences.update(selection);
          return out;
        }
        onChanged?.call(selection);
      },
    );
  }

  static Widget? flagByTitle(String title, {double size = 32}) {
    if (title.isEmpty) return null;
    try {
      final match = RegExp(r'\(([^)]+)\)$').firstMatch(title);
      final countryCode = match?.group(1);
      if (countryCode == null) return null;
      return IPCountryFlag(countryCode: countryCode, size: size);
    } catch (e) {
      return null;
    }
  }
}

class BatteryOptimizationWidget extends HookConsumerWidget {
  const BatteryOptimizationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final isIgnoringBatteryOptimizations = ref.watch(batteryOptimizationNotifierProvider);

    return isIgnoringBatteryOptimizations.when(
      data: (isIgnored) => isIgnored
          ? const SizedBox()
          : ListTile(
              title: Text(t.pages.settings.general.ignoreBatteryOptimizations),
              subtitle: Text(t.pages.settings.general.ignoreBatteryOptimizationsMsg),
              leading: const Icon(Icons.battery_saver_rounded),
              onTap: () async {
                await ref.read(batteryOptimizationNotifierProvider.notifier).requestToIgnore();
              },
            ),
      error: (_, _) => const SizedBox(),
      loading: () => const SizedBox(
        height: 48,
        child: Center(
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: LinearProgressIndicator()),
        ),
      ),
    );
  }
}
