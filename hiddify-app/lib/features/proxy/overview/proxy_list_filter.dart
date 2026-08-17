import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

/// Core always injects a urltest outbound tagged `auto` into the selector.
/// That is not a host-provided node.
bool isInjectedAutoGroup(OutboundInfo item) {
  if (item.tag != 'auto') return false;
  final type = item.type.toLowerCase();
  return item.isGroup || type == 'urltest';
}

/// Hide the synthetic `auto` row when it would duplicate the only real node.
/// The remaining node is marked current so the list is not empty of「当前」.
List<OutboundInfo> visibleProxyItems(Iterable<OutboundInfo> items) {
  final list = items.toList();
  final real = list.where((e) => !isInjectedAutoGroup(e)).toList();
  if (real.length <= 1) {
    if (real.length == 1) real.single.isSelected = true;
    return real;
  }
  return list;
}

/// Home / tray should show the leaf node, not the injected urltest group.
OutboundInfo? proxyByTag(Iterable<OutboundGroup> groups, String tag) {
  if (tag.isEmpty) return null;
  for (final group in groups) {
    for (final item in group.items) {
      if (item.tag == tag) return item;
    }
  }
  return null;
}

OutboundInfo resolveActiveProxy(List<OutboundGroup> groups) {
  if (groups.isEmpty) return OutboundInfo();
  OutboundGroup pick = groups.first;
  for (final group in groups) {
    if (group.tag == 'select' || group.selectable) {
      pick = group;
      break;
    }
  }
  OutboundInfo? current;
  for (final item in pick.items) {
    if (item.isSelected) {
      current = item;
      break;
    }
  }
  current ??= pick.items.isEmpty ? null : pick.items.first;
  if (current == null) return OutboundInfo();
  if (!isInjectedAutoGroup(current)) return current;
  final hinted = current.groupSelectedTag.isNotEmpty ? current.groupSelectedTag : current.host;
  final fromHint = proxyByTag(groups, hinted);
  if (fromHint != null && fromHint.tag != current.tag) return fromHint;
  for (final group in groups) {
    final isAutoGroup = group.tag == current.tag || group.type.toLowerCase() == 'urltest';
    if (!isAutoGroup) continue;
    for (final item in group.items) {
      if (item.tag != current.tag) return item;
    }
  }
  if (hinted.isNotEmpty && hinted != current.tag) {
    return OutboundInfo(
      tag: hinted,
      tagDisplay: hinted,
      urlTestDelay: current.urlTestDelay,
      ipinfo: current.ipinfo,
      isSecure: current.isSecure,
    );
  }
  return current;
}

int compareProxyDelay(OutboundInfo a, OutboundInfo b) {
  if (a.isGroup && !b.isGroup) return -1;
  if (!a.isGroup && b.isGroup) return 1;
  final ai = a.urlTestDelay;
  final bi = b.urlTestDelay;
  final aMissing = ai <= 0;
  final bMissing = bi <= 0;
  if (aMissing && bMissing) return a.tag.compareTo(b.tag);
  if (aMissing) return 1;
  if (bMissing) return -1;
  return ai.compareTo(bi);
}
