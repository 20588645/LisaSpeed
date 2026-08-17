import 'dart:async';
import 'dart:io';

import 'package:hiddify/features/link_test/model/link_test_target.dart';

const _kBrowserUa =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

LinkTestFailureKind classifyLinkTestError(Object error) {
  if (error is TimeoutException) return LinkTestFailureKind.timeout;
  if (error is HandshakeException || error is TlsException || error is CertificateException) {
    return LinkTestFailureKind.tls;
  }
  if (error is SocketException) {
    final msg = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
    if (msg.contains('timed out') || msg.contains('timeout')) {
      return LinkTestFailureKind.timeout;
    }
    return LinkTestFailureKind.network;
  }
  final s = error.toString().toLowerCase();
  if (s.contains('timed out') || s.contains('timeout')) return LinkTestFailureKind.timeout;
  if (s.contains('handshake') || s.contains('certificate')) return LinkTestFailureKind.tls;
  return LinkTestFailureKind.unknown;
}

class LinkTester {
  const LinkTester();

  Future<LinkTestOutcome> probe({
    required LinkTestTarget target,
    required int mixedPort,
    required bool useProxy,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final client = HttpClient();
    client.userAgent = _kBrowserUa;
    client.connectionTimeout = timeout;
    client.idleTimeout = timeout;
    client.autoUncompress = false;
    if (useProxy && mixedPort > 0) {
      client.findProxy = (_) => 'PROXY 127.0.0.1:$mixedPort';
    } else {
      client.findProxy = (_) => 'DIRECT';
    }

    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(target.url);
      final req = await client.getUrl(uri).timeout(timeout);
      req.followRedirects = true;
      req.maxRedirects = 5;
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      final res = await req.close().timeout(timeout);
      sw.stop();
      unawaited(res.drain<void>().catchError((_) {}));
      return LinkTestOutcome.ok(
        latencyMs: sw.elapsedMilliseconds,
        statusCode: res.statusCode,
        viaProxy: useProxy,
      );
    } catch (err) {
      return LinkTestOutcome.fail(classifyLinkTestError(err), viaProxy: useProxy);
    } finally {
      client.close(force: true);
    }
  }
}
