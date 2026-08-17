import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/features/settings/data/macos_installed_apps.dart';
import 'package:hiddify/utils/platform_utils.dart';

/// Cached PNG bytes from [NSWorkspace.icon(forFile:)] on macOS.
class MacAppIconLoader {
  MacAppIconLoader._();

  static const _channel = MethodChannel('com.lisaspeed/apps');
  static const _pixelSize = 128;
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

  static Uint8List? cached(String path) => _cache[path];

  static Future<Uint8List?> load(String path) {
    if (path.isEmpty) return Future<Uint8List?>.value();
    final hit = _cache[path];
    if (hit != null) return Future<Uint8List?>.value(hit);
    return _inflight.putIfAbsent(path, () async {
      if (!PlatformUtils.isMacOS) return null;
      try {
        final bytes = await _channel.invokeMethod<Uint8List>('icon', {
          'path': path,
          'size': _pixelSize,
        });
        if (bytes != null && bytes.isNotEmpty) {
          _cache[path] = bytes;
          return bytes;
        }
      } catch (_) {
        // Older native build without the channel; letter fallback stays.
      }
      return null;
    }).whenComplete(() => _inflight.remove(path));
  }

  static Future<void> loadMany(Iterable<String> paths) async {
    if (!PlatformUtils.isMacOS) return;
    for (final path in paths) {
      if (path.isEmpty || _cache.containsKey(path)) continue;
      await load(path);
    }
  }
}

/// Finder-quality app icon, with a letter tile until the PNG arrives.
class MacAppIcon extends StatefulWidget {
  const MacAppIcon({
    super.key,
    required this.bundleName,
    this.path,
    this.size = 36,
    this.fallbackColor,
  });

  final String bundleName;
  final String? path;
  final double size;
  final Color? fallbackColor;

  @override
  State<MacAppIcon> createState() => _MacAppIconState();
}

class _MacAppIconState extends State<MacAppIcon> {
  Uint8List? _bytes;
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(MacAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bundleName != widget.bundleName || oldWidget.path != widget.path) {
      _bytes = null;
      _sync();
    }
  }

  void _sync() {
    final path = widget.path ?? pathForMacBundleName(widget.bundleName);
    _resolvedPath = path;
    if (path == null) return;
    final cached = MacAppIconLoader.cached(path);
    if (cached != null) {
      _bytes = cached;
      return;
    }
    MacAppIconLoader.load(path).then((bytes) {
      if (!mounted || _resolvedPath != path) return;
      if (bytes == null) return;
      setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: bytes == null
          ? _letter(context)
          : Image.memory(
              bytes,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _letter(context),
            ),
    );
  }

  Widget _letter(BuildContext context) {
    final glyph = widget.bundleName.isEmpty ? '?' : String.fromCharCode(widget.bundleName.runes.first);
    final color = widget.fallbackColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(widget.size * 0.28),
      ),
      child: Text(
        glyph,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: widget.size * 0.42,
          height: 1,
        ),
      ),
    );
  }
}
