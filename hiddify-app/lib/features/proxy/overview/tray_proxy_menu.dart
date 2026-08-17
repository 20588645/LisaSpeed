import 'package:hiddify/features/proxy/overview/proxy_display.dart';
import 'package:hiddify/features/proxy/overview/proxy_list_filter.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

/// One row in the menu-bar node submenu. Keys are percent-encoded so remarks
/// with `|` or spaces still round-trip through `tray_manager`.
class TrayProxyItem {
  const TrayProxyItem({
    required this.groupTag,
    required this.outboundTag,
    required this.label,
    required this.selected,
  });

  final String groupTag;
  final String outboundTag;
  final String label;
  final bool selected;

  static const keyPrefix = 'node|';

  String get menuKey =>
      '$keyPrefix${Uri.encodeComponent(groupTag)}|${Uri.encodeComponent(outboundTag)}';

  static (String groupTag, String outboundTag)? parseKey(String key) {
    if (!key.startsWith(keyPrefix)) return null;
    final rest = key.substring(keyPrefix.length);
    final bar = rest.indexOf('|');
    if (bar <= 0 || bar == rest.length - 1) return null;
    return (Uri.decodeComponent(rest.substring(0, bar)), Uri.decodeComponent(rest.substring(bar + 1)));
  }
}

String ellipsizeTrayLabel(String raw, [int maxChars = 36]) {
  final text = raw.trim();
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars - 1)}…';
}

/// Compact list for the menu bar: current + auto + fastest, capped so macOS
/// menus stay usable when a subscription has dozens of nodes.
List<TrayProxyItem> buildTrayProxyItems({
  required OutboundGroup group,
  required bool chinese,
  required String autoLabel,
  int limit = 12,
}) {
  if (group.tag.isEmpty) return const [];
  final visible = visibleProxyItems(group.items);
  if (visible.isEmpty) return const [];

  final ranked = [...visible]
    ..sort((a, b) {
      if (a.isSelected != b.isSelected) return a.isSelected ? -1 : 1;
      if (isInjectedAutoGroup(a) != isInjectedAutoGroup(b)) {
        return isInjectedAutoGroup(a) ? -1 : 1;
      }
      return compareProxyDelay(a, b);
    });

  var picked = ranked.take(limit).toList();
  OutboundInfo? selected;
  for (final item in visible) {
    if (item.isSelected) {
      selected = item;
      break;
    }
  }
  if (selected != null && picked.every((e) => e.tag != selected!.tag)) {
    if (picked.isNotEmpty) picked = picked.sublist(0, picked.length - 1);
    picked.insert(0, selected);
  }

  return [
    for (final item in picked)
      TrayProxyItem(
        groupTag: group.tag,
        outboundTag: item.tag,
        label: ellipsizeTrayLabel(
          proxyDisplayTitle(item, chinese: chinese, autoLabel: autoLabel),
        ),
        selected: item.isSelected,
      ),
  ];
}
