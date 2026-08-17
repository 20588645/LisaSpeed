import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/settings/data/restore_network.dart';

void main() {
  test('skips the legend line and strips disabled-service stars', () {
    const stdout = '''
An asterisk (*) denotes that a network service is disabled.
USB 10/100/1000 LAN
*Wi-Fi
Thunderbolt Bridge
iPhone USB
''';
    expect(parseNetworkServiceNames(stdout), [
      'USB 10/100/1000 LAN',
      'Wi-Fi',
      'Thunderbolt Bridge',
      'iPhone USB',
    ]);
  });

  test('turns off proxies on every listed service', () async {
    final calls = <(String, List<String>)>[];
    await restoreLocalNetwork(
      run: (executable, arguments) async {
        calls.add((executable, arguments));
        if (executable == 'networksetup' && arguments.first == '-listallnetworkservices') {
          return ProcessResult(0, 0, 'An asterisk (*) denotes that a network service is disabled.\nWi-Fi\n', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );
    expect(calls.first.$1, 'networksetup');
    expect(calls.first.$2, ['-listallnetworkservices']);
    bool has(String flag) =>
        calls.any((c) => c.$1 == 'networksetup' && c.$2.length == 3 && c.$2[0] == flag && c.$2[1] == 'Wi-Fi' && c.$2[2] == 'off');
    expect(has('-setwebproxystate'), isTrue);
    expect(has('-setsecurewebproxystate'), isTrue);
    expect(has('-setsocksfirewallproxystate'), isTrue);
    expect(has('-setproxyautodiscovery'), isTrue);
    expect(calls.last.$1, 'dscacheutil');
    expect(calls.last.$2, ['-flushcache']);
  });
}
