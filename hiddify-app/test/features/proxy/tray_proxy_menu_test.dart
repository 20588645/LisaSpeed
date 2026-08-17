import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/overview/tray_proxy_menu.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

void main() {
  test('encodes and parses tags that contain spaces and pipes', () {
    const item = TrayProxyItem(
      groupTag: 'select',
      outboundTag: '美国|家宽 01',
      label: '美国家宽',
      selected: true,
    );
    expect(TrayProxyItem.parseKey(item.menuKey), ('select', '美国|家宽 01'));
    expect(TrayProxyItem.parseKey('connection'), isNull);
    expect(TrayProxyItem.parseKey('node|only'), isNull);
  });

  test('keeps auto and current, caps the rest', () {
    final items = <OutboundInfo>[
      OutboundInfo(tag: 'auto', type: 'urltest', isGroup: true),
      OutboundInfo(tag: '日本', type: 'vless', urlTestDelay: 80, isSelected: true),
      for (var i = 0; i < 20; i++) OutboundInfo(tag: 'n$i', type: 'vless', urlTestDelay: 200 + i),
    ];
    final group = OutboundGroup(tag: 'select', items: items);
    final tray = buildTrayProxyItems(
      group: group,
      chinese: true,
      autoLabel: '自动选择',
      limit: 5,
    );
    expect(tray.length, 5);
    expect(tray.first.outboundTag, '日本');
    expect(tray.any((e) => e.outboundTag == 'auto'), isTrue);
    expect(tray.where((e) => e.selected).single.outboundTag, '日本');
  });

  test('ellipsize long labels', () {
    expect(ellipsizeTrayLabel('短'), '短');
    expect(ellipsizeTrayLabel('abcdefghijklmnopqrstuvwxyz0123456789ABC', 10).endsWith('…'), isTrue);
  });
}
