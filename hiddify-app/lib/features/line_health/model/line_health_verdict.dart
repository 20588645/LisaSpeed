/// One-shot line check: tunnel through the node, a domestic site direct, an
/// overseas site through the node. Not a bandwidth test and not a home-Wi-Fi
/// diagnostic — it only answers "is this LisaSpeed session usable".
enum LineHealthVerdict {
  notConnected,
  ok,
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
  });

  final bool connected;
  final bool tunnelOk;
  final bool cnOk;
  final bool intlOk;
}

LineHealthVerdict concludeLineHealth(LineHealthSnapshot snapshot) {
  if (!snapshot.connected) return LineHealthVerdict.notConnected;
  if (snapshot.tunnelOk && snapshot.cnOk && snapshot.intlOk) {
    return LineHealthVerdict.ok;
  }
  if (!snapshot.tunnelOk && snapshot.cnOk) return LineHealthVerdict.nodeDead;
  if (snapshot.cnOk && !snapshot.intlOk) return LineHealthVerdict.intlFail;
  if (!snapshot.cnOk && !snapshot.intlOk) return LineHealthVerdict.localFail;
  return LineHealthVerdict.mixed;
}
