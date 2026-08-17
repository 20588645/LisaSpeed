import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/line_health/model/line_health_verdict.dart';

void main() {
  LineHealthSnapshot snap({
    bool connected = true,
    bool tunnelOk = true,
    bool cnOk = true,
    bool intlOk = true,
  }) {
    return LineHealthSnapshot(
      connected: connected,
      tunnelOk: tunnelOk,
      cnOk: cnOk,
      intlOk: intlOk,
    );
  }

  test('idle session is not-connected, not a local-network fail', () {
    expect(concludeLineHealth(snap(connected: false, tunnelOk: false, cnOk: false, intlOk: false)), LineHealthVerdict.notConnected);
  });

  test('all three probes pass', () {
    expect(concludeLineHealth(snap()), LineHealthVerdict.ok);
  });

  test('china works but tunnel is dead → switch node', () {
    expect(
      concludeLineHealth(snap(tunnelOk: false, intlOk: false)),
      LineHealthVerdict.nodeDead,
    );
  });

  test('tunnel up, china up, overseas down → switch node for exit', () {
    expect(concludeLineHealth(snap(intlOk: false)), LineHealthVerdict.intlFail);
  });

  test('china and overseas both down → leftover proxy or office block', () {
    expect(
      concludeLineHealth(snap(tunnelOk: false, cnOk: false, intlOk: false)),
      LineHealthVerdict.localFail,
    );
  });

  test('china down but overseas up is mixed', () {
    expect(concludeLineHealth(snap(cnOk: false)), LineHealthVerdict.mixed);
  });
}
