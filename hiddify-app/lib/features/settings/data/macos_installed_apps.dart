import 'dart:convert';
import 'dart:io';

/// A top-level `.app` in `/Applications` or `~/Applications`.
class MacInstalledApp {
  const MacInstalledApp({
    required this.bundleName,
    required this.displayName,
    required this.path,
  });

  /// Folder name without `.app` — this is what ProcessPath contains.
  final String bundleName;
  final String displayName;
  final String path;
}

const _blockedBundleNames = {'LisaSpeed', 'Hiddify'};

/// Resolves a stored bundle folder name (`哔哩哔哩`) to `/Applications/….app`.
String? pathForMacBundleName(String bundleName) {
  final trimmed = bundleName.trim();
  if (trimmed.isEmpty) return null;
  final home = Platform.environment['HOME'];
  final candidates = <String>[
    '/Applications/$trimmed.app',
    if (home != null && home.isNotEmpty) '$home/Applications/$trimmed.app',
  ];
  for (final path in candidates) {
    if (Directory(path).existsSync()) return path;
  }
  return null;
}

Future<List<MacInstalledApp>> listMacInstalledApps() async {
  final home = Platform.environment['HOME'];
  final roots = <Directory>[
    Directory('/Applications'),
    if (home != null && home.isNotEmpty) Directory('$home/Applications'),
  ];

  final seen = <String>{};
  final apps = <MacInstalledApp>[];
  for (final root in roots) {
    if (!root.existsSync()) continue;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final folder = entity.path.split('/').last;
      if (!folder.endsWith('.app') || folder.startsWith('.')) continue;
      final bundleName = folder.substring(0, folder.length - 4);
      if (bundleName.isEmpty || _blockedBundleNames.contains(bundleName) || seen.contains(bundleName)) {
        continue;
      }
      seen.add(bundleName);
      final displayName = await _displayNameFor(entity.path) ?? bundleName;
      apps.add(MacInstalledApp(bundleName: bundleName, displayName: displayName, path: entity.path));
    }
  }
  apps.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  return apps;
}

Future<String?> _displayNameFor(String appPath) async {
  final file = File('$appPath/Contents/Info.plist');
  if (!file.existsSync()) return null;
  try {
    final bytes = await file.readAsBytes();
    if (bytes.length >= 8 && utf8.decode(bytes.sublist(0, 8), allowMalformed: true) == 'bplist00') {
      return null;
    }
    final xml = utf8.decode(bytes, allowMalformed: true);
    final name = _plistString(xml, 'CFBundleDisplayName') ?? _plistString(xml, 'CFBundleName');
    if (name == null || name.contains('\$')) return null;
    return name;
  } catch (_) {
    return null;
  }
}

String? _plistString(String xml, String key) {
  final match = RegExp('<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>').firstMatch(xml);
  final value = match?.group(1)?.trim();
  return (value == null || value.isEmpty) ? null : value;
}
