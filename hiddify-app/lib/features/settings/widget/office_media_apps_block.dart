import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/data/macos_installed_apps.dart';
import 'package:hiddify/features/settings/widget/mac_app_icon.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

Future<void> openOfficeMediaAppPicker(BuildContext context, WidgetRef ref, List<String> selected) async {
  final result = await showDialog<List<String>>(
    context: context,
    builder: (context) => OfficeMediaAppPickerDialog(selected: selected),
  );
  if (result == null || !context.mounted) return;
  await ref.read(ConfigOptions.officeMediaApps.notifier).update(result);
}

class OfficeMediaAppPickerDialog extends ConsumerStatefulWidget {
  const OfficeMediaAppPickerDialog({super.key, required this.selected});

  final List<String> selected;

  @override
  ConsumerState<OfficeMediaAppPickerDialog> createState() => _OfficeMediaAppPickerDialogState();
}

class _OfficeMediaAppPickerDialogState extends ConsumerState<OfficeMediaAppPickerDialog> {
  final _query = TextEditingController();
  final _checked = <String>{};
  List<MacInstalledApp>? _apps;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _checked.addAll(widget.selected);
    listMacInstalledApps()
        .then((apps) {
          if (!mounted) return;
          setState(() => _apps = apps);
          final ordered = [
            ...apps.where((app) => _checked.contains(app.bundleName)),
            ...apps.where((app) => !_checked.contains(app.bundleName)),
          ];
          MacAppIconLoader.loadMany(ordered.map((app) => app.path)).then((_) {
            if (mounted) setState(() {});
          });
        })
        .catchError((Object error) {
          if (!mounted) return;
          setState(() => _error = error);
        });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final query = _query.text.trim().toLowerCase();
    final apps = _apps;
    final filtered = <MacInstalledApp>[
      if (apps != null)
        ...apps.where((app) {
          if (query.isEmpty) return true;
          return app.displayName.toLowerCase().contains(query) || app.bundleName.toLowerCase().contains(query);
        }),
    ];
    filtered.sort((a, b) {
      final aSel = _checked.contains(a.bundleName) ? 0 : 1;
      final bSel = _checked.contains(b.bundleName) ? 0 : 1;
      if (aSel != bSel) return aSel.compareTo(bSel);
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return TechDialog(
      title: t.pages.settings.general.officeMediaAppsPickerTitle,
      width: 480,
      scrollable: false,
      actions: [
        TechDialogActions.cancel(context, onPressed: () => Navigator.of(context).pop()),
        TechDialogActions.ok(
          context,
          onPressed: () {
            final order = <String>[];
            for (final name in widget.selected) {
              if (_checked.contains(name)) order.add(name);
            }
            for (final name in _checked) {
              if (!order.contains(name)) order.add(name);
            }
            Navigator.of(context).pop(order);
          },
        ),
      ],
      content: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.52,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.pages.settings.general.officeMediaAppsPickerHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: t.pages.settings.general.officeMediaAppsSearch,
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _error != null
                  ? Center(child: Text('$_error', style: theme.textTheme.bodySmall))
                  : apps == null
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        t.pages.settings.general.officeMediaAppsNoneFound,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final app = filtered[index];
                        final selected = _checked.contains(app.bundleName);
                        return CheckboxListTile(
                          dense: true,
                          value: selected,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Row(
                            children: [
                              MacAppIcon(
                                key: ValueKey(app.path),
                                bundleName: app.bundleName,
                                path: app.path,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(app.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    if (app.displayName != app.bundleName)
                                      Text(
                                        app.bundleName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                _checked.add(app.bundleName);
                              } else {
                                _checked.remove(app.bundleName);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
