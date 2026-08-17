import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/overview/proxy_list_filter.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

void main() {
  test('hides injected auto urltest when there is a single real node', () {
    final items = [
      OutboundInfo(tag: 'auto', type: 'urltest', isGroup: true),
      OutboundInfo(tag: '美国家宽', type: 'vless'),
    ];
    final visible = visibleProxyItems(items);
    expect(visible.map((e) => e.tag), ['美国家宽']);
  });

  test('keeps auto when there are multiple real nodes', () {
    final items = [
      OutboundInfo(tag: 'auto', type: 'urltest', isGroup: true),
      OutboundInfo(tag: '美国家宽', type: 'vless'),
      OutboundInfo(tag: '日本', type: 'vless'),
    ];
    final visible = visibleProxyItems(items);
    expect(visible.map((e) => e.tag), ['auto', '美国家宽', '日本']);
  });

  test('does not hide a real node that happens to be named auto', () {
    final items = [OutboundInfo(tag: 'auto', type: 'vless')];
    expect(visibleProxyItems(items).single.type, 'vless');
  });

  test('marks the only real node as current when auto is hidden', () {
    final items = [
      OutboundInfo(tag: 'auto', type: 'urltest', isGroup: true, isSelected: true),
      OutboundInfo(tag: '美国家宽', type: 'vless'),
    ];
    expect(visibleProxyItems(items).single.isSelected, isTrue);
  });

  test('resolves injected auto to the urltest member', () {
    final groups = [
      OutboundGroup(
        tag: 'select',
        selectable: true,
        items: [
          OutboundInfo(tag: 'auto', type: 'urltest', isGroup: true, isSelected: true),
          OutboundInfo(tag: 'V20260607085289-001 xtls-reality', type: 'vless'),
        ],
      ),
      OutboundGroup(
        tag: 'auto',
        type: 'urltest',
        items: [OutboundInfo(tag: 'V20260607085289-001 xtls-reality', type: 'vless', ipinfo: IpInfo(countryCode: 'US'))],
      ),
    ];
    final active = resolveActiveProxy(groups);
    expect(active.tag, 'V20260607085289-001 xtls-reality');
    expect(active.ipinfo.countryCode, 'US');
  });

  test('resolves auto from host side-channel when urltest members are omitted', () {
    final groups = [
      OutboundGroup(
        tag: 'select',
        selectable: true,
        items: [
          OutboundInfo(
            tag: 'auto',
            type: 'urltest',
            isGroup: true,
            isSelected: true,
            host: 'V20260607085289-001 xtls-reality',
            ipinfo: IpInfo(countryCode: 'US'),
            urlTestDelay: 42,
          ),
        ],
      ),
    ];
    final active = resolveActiveProxy(groups);
    expect(active.tag, 'V20260607085289-001 xtls-reality');
    expect(active.ipinfo.countryCode, 'US');
    expect(active.urlTestDelay, 42);
  });

  test('delay sort keeps untested last and is antisymmetric', () {
    final a = OutboundInfo(tag: 'a', urlTestDelay: 0);
    final b = OutboundInfo(tag: 'b', urlTestDelay: 0);
    expect(compareProxyDelay(a, b), -compareProxyDelay(b, a));
    final fast = OutboundInfo(tag: 'fast', urlTestDelay: 20);
    final untested = OutboundInfo(tag: 'z', urlTestDelay: 0);
    expect(compareProxyDelay(fast, untested), lessThan(0));
  });
}
