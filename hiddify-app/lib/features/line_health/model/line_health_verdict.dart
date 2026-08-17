import 'package:hiddify/features/link_test/model/probe_grade.dart';

/// One-shot line check: tunnel through the node, a domestic site direct, an
/// overseas site through the node. Not a bandwidth test and not a home-Wi-Fi
/// diagnostic — it only answers "is this LisaSpeed session usable".
enum LineHealthVerdict {
  notConnected,
  ok,
  sluggish,
  switchNode,
  nodeDead,
  intlFail,
  localFail,
  mixed,
}

class LineHealthSnapshot {
  const LineHealthSnapshot({
    required this.connected,
    required this.tunnelOk,
    required this.cnOk,
    required this.intlOk,
    this.intlLatencyMs,
  });

  final bool connected;
  final bool tunnelOk;
  final bool cnOk;
  final bool intlOk;
  final int? intlLatencyMs;
}

LineHealthVerdict concludeLineHealth(LineHealthSnapshot snapshot) {
  if (!snapshot.connected) return LineHealthVerdict.notConnected;
  if (snapshot.tunnelOk && snapshot.cnOk && snapshot.intlOk) {
    return switch (gradeLatencyMs(snapshot.intlLatencyMs ?? 0)) {
      ProbeGrade.ok => LineHealthVerdict.ok,
      ProbeGrade.sluggish => LineHealthVerdict.sluggish,
      ProbeGrade.switchNode => LineHealthVerdict.switchNode,
    };
  }
  if (!snapshot.tunnelOk && snapshot.cnOk) return LineHealthVerdict.nodeDead;
  if (snapshot.cnOk && !snapshot.intlOk) return LineHealthVerdict.intlFail;
  if (!snapshot.cnOk && !snapshot.intlOk) return LineHealthVerdict.localFail;
  return LineHealthVerdict.mixed;
}

bool lineHealthShouldSwitchNode(LineHealthVerdict verdict) => switch (verdict) {
  LineHealthVerdict.sluggish ||
  LineHealthVerdict.switchNode ||
  LineHealthVerdict.nodeDead ||
  LineHealthVerdict.intlFail ||
  LineHealthVerdict.mixed => true,
  _ => false,
};
