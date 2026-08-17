import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/stats/model/office_media_traffic.dart';

void main() {
  group('matchOfficeMediaApp', () {
    const apps = ['汽水音乐', '抖音', '哔哩哔哩'];

    test('matches bundle path', () {
      expect(
        matchOfficeMediaApp('/Applications/汽水音乐.app/Contents/MacOS/汽水音乐', apps),
        '汽水音乐',
      );
    });

    test('matches electron helper', () {
      expect(
        matchOfficeMediaApp('/Applications/抖音.app/Contents/Frameworks/抖音 Helper (GPU).app/Contents/MacOS/抖音 Helper (GPU)', apps),
        '抖音',
      );
    });

    test('ignores unrelated apps', () {
      expect(matchOfficeMediaApp('/Applications/WeChat.app/Contents/MacOS/WeChat', apps), isNull);
    });
  });

  test('parseClashConnections reads process and outbound', () {
    final conns = parseClashConnections({
      'connections': [
        {
          'id': 'a',
          'upload': 10,
          'download': 20,
          'chains': ['socks-out'],
          'metadata': {'processPath': '/Applications/汽水音乐.app/Contents/MacOS/汽水音乐'},
        },
        {
          'id': 'b',
          'upload': 1,
          'download': 2,
          'chains': ['direct-out'],
          'metadata': {'processPath': '/Applications/WeChat.app/Contents/MacOS/WeChat'},
        },
      ],
    });
    expect(conns, hasLength(2));
    expect(conns.first.viaNode, isTrue);
    expect(conns.last.viaDirect, isTrue);
    expect(matchOfficeMediaApp(conns.first.processPath, ['汽水音乐']), '汽水音乐');
  });
}
