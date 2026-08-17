import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/line_health/model/line_health_verdict.dart';

void main() {
  LineHealthSnapshot snap({
    bool connected = true,
    bool tunnelOk = true,
    bool cnOk = true,
    bool intlOk = true,
    int? intlLatencyMs,
  }) {
    return LineHealthSnapshot(
      connected: connected,
      tunnelOk: tunnelOk,
      cnOk: cnOk,
      intlOk: intlOk,
      intlLatencyMs: intlLatencyMs,
    );
  }

  test('idle session is not-connected, not a local-network fail', () {
    expect(concludeLineHealth(snap(connected: false, tunnelOk: false, cnOk: false, intlOk: false)), LineHealthVerdict.notConnected);
  });

  test('all three probes pass with a fast overseas hop', () {
    expect(concludeLineHealth(snap(intlLatencyMs: 180)), LineHealthVerdict.ok);
  });

  test('overseas 400–999ms is sluggish, not a pass', () {
    expect(concludeLineHealth(snap(intlLatencyMs: 400)), LineHealthVerdict.sluggish);
    expect(concludeLineHealth(snap(intlLatencyMs: 999)), LineHealthVerdict.sluggish);
  });

  test('overseas ≥1s still responding is switch-node', () {
    expect(concludeLineHealth(snap(intlLatencyMs: 1000)), LineHealthVerdict.switchNode);
    expect(concludeLineHealth(snap(intlLatencyMs: 1064)), LineHealthVerdict.switchNode);
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

  test('go-switch is for node problems, not local-network restore', () {
    expect(lineHealthShouldSwitchNode(LineHealthVerdict.ok), isFalse);
    expect(lineHealthShouldSwitchNode(LineHealthVerdict.notConnected), isFalse);
    expect(lineHealthShouldSwitchNode(LineHealthVerdict.localFail), isFalse);
    expect(lineHealthShouldSwitchNode(LineHealthVerdict.sluggish), isTrue);
    expect(lineHealthShouldSwitchNode(LineHealthVerdict.switchNode), isTrue);
    expect(lineHealthShouldSwitchNode(LineHealthVerdict.nodeDead), isTrue);
    expect(lineHealthShouldSwitchNode(LineHealthVerdict.intlFail), isTrue);
    expect(lineHealthShouldSwitchNode(LineHealthVerdict.mixed), isTrue);
  });
}
