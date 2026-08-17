import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hiddify/features/speed_test/data/speed_test_targets.dart';
import 'package:hiddify/features/speed_test/model/speed_test_math.dart';
import 'package:hiddify/features/speed_test/model/speed_test_report.dart';

const _kBrowserUa =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

const kSpeedTestPingCount = 8;
const kSpeedTestTransfer = Duration(seconds: 10);
const kSpeedTestWarmup = Duration(milliseconds: 2000);
const kSpeedTestDownloadStreamsDirect = 8;
const kSpeedTestDownloadStreamsProxy = 6;
const kSpeedTestUploadStreams = 4;
const kSpeedTestDownloadBytes = 80000000;
const kSpeedTestUploadChunk = 512 * 1024;
const kSpeedTestScorePercentile = 0.9;

SpeedTestFailureKind classifySpeedTestError(Object error) {
  if (error is SpeedTestCancelled) return SpeedTestFailureKind.cancelled;
  if (error is SpeedTestException) return error.kind;
  if (error is TimeoutException) return SpeedTestFailureKind.timeout;
  if (error is HandshakeException || error is TlsException || error is CertificateException) {
    return SpeedTestFailureKind.tls;
  }
  if (error is SocketException) {
    final msg = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
    if (msg.contains('timed out') || msg.contains('timeout')) {
      return SpeedTestFailureKind.timeout;
    }
    return SpeedTestFailureKind.network;
  }
  final s = error.toString().toLowerCase();
  if (s.contains('timed out') || s.contains('timeout')) return SpeedTestFailureKind.timeout;
  if (s.contains('handshake') || s.contains('certificate')) return SpeedTestFailureKind.tls;
  return SpeedTestFailureKind.unknown;
}

class SpeedTester {
  HttpClient? _client;
  HttpClient? _pingClient;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    final clients = [_client, _pingClient];
    _client = null;
    _pingClient = null;
    for (final client in clients) {
      client?.close(force: true);
    }
  }

  Future<SpeedTestReport> run({
    required int mixedPort,
    required bool useProxy,
    void Function(SpeedTestProgress progress)? onProgress,
  }) async {
    _cancelled = false;
    if (useProxy && mixedPort <= 0) {
      throw const SpeedTestException(SpeedTestFailureKind.network, 'no mixed port');
    }

    final client = _openClient(mixedPort: mixedPort, useProxy: useProxy, maxPerHost: 16);
    final pingClient = _openClient(mixedPort: mixedPort, useProxy: useProxy, maxPerHost: 2);
    _client = client;
    _pingClient = pingClient;

    var phase = SpeedTestPhase.ping;
    SpeedTestTarget target = kCloudflareSpeedTarget;
    Uri? downloadUri;
    CloudflareTrace? trace;
    var idlePingMs = 0;
    var jitterMs = 0.0;
    double? downloadMbps;
    double? uploadMbps;
    int? downLoadedPing;
    int? upLoadedPing;
    var uploadFailed = false;

    void emit({double fraction = 0, double? liveDownload, double? liveUpload, int? livePing}) {
      onProgress?.call(
        SpeedTestProgress(
          phase: phase,
          fraction: fraction.clamp(0, 1),
          downloadMbps: liveDownload ?? downloadMbps,
          uploadMbps: liveUpload ?? uploadMbps,
          idlePingMs: livePing ?? (idlePingMs > 0 ? idlePingMs : null),
          downloadLoadedPingMs: downLoadedPing,
          uploadLoadedPingMs: upLoadedPing,
          jitterMs: jitterMs > 0 ? jitterMs : null,
          trace: trace,
          serverId: target.id,
          viaProxy: useProxy,
          uploadFailed: uploadFailed,
        ),
      );
    }

    try {
      _throwIfCancelled();
      target = await _selectTarget(pingClient, useProxy: useProxy);
      emit(fraction: 0.05);

      if (target.cloudflare) {
        trace = await _readTrace(client);
        emit(fraction: 0.08);
      }

      downloadUri = await _resolveDownloadUri(client, target);
      emit(fraction: 0.1);

      final pings = <int>[];
      for (var i = 0; i < kSpeedTestPingCount; i++) {
        _throwIfCancelled();
        try {
          pings.add(await _pingTarget(pingClient, target));
          emit(
            fraction: 0.1 + 0.08 * ((i + 1) / kSpeedTestPingCount),
            livePing: medianInt(dropWarmupSample(pings)),
          );
        } on SpeedTestCancelled {
          rethrow;
        } catch (_) {
          if (pings.isEmpty && i >= 2) {
            throw const SpeedTestException(SpeedTestFailureKind.network, 'ping failed');
          }
        }
      }
      final idleSamples = withoutPingOutliers(dropWarmupSample(pings));
      if (idleSamples.isEmpty) {
        throw const SpeedTestException(SpeedTestFailureKind.network, 'ping failed');
      }
      idlePingMs = medianInt(idleSamples);
      jitterMs = meanSuccessiveDiff(idleSamples);
      emit(fraction: 0.18, livePing: idlePingMs);

      phase = SpeedTestPhase.download;
      emit(fraction: 0.18);
      final downStreams = useProxy ? kSpeedTestDownloadStreamsProxy : kSpeedTestDownloadStreamsDirect;
      final down = await _measureThroughput(
        client: client,
        pingClient: pingClient,
        target: target,
        downloadUri: downloadUri,
        download: true,
        streams: downStreams,
        onLive: (mbps, loaded, local) {
          downloadMbps = mbps;
          downLoadedPing = loaded;
          emit(fraction: 0.18 + 0.42 * local, liveDownload: mbps);
        },
      );
      downloadMbps = down.mbps;
      downLoadedPing = down.loadedPingMs;
      emit(fraction: 0.6, liveDownload: downloadMbps);

      _throwIfCancelled();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      _throwIfCancelled();

      phase = SpeedTestPhase.upload;
      emit(fraction: 0.6);
      if (target.uploadUri == null) {
        uploadFailed = true;
      } else {
        try {
          final up = await _measureThroughput(
            client: client,
            pingClient: pingClient,
            target: target,
            downloadUri: downloadUri,
            download: false,
            streams: kSpeedTestUploadStreams,
            onLive: (mbps, loaded, local) {
              uploadMbps = mbps;
              upLoadedPing = loaded;
              emit(fraction: 0.6 + 0.4 * local, liveUpload: mbps);
            },
          );
          uploadMbps = up.mbps;
          upLoadedPing = up.loadedPingMs;
        } on SpeedTestCancelled {
          rethrow;
        } catch (_) {
          uploadFailed = true;
        }
      }

      phase = SpeedTestPhase.done;
      emit(fraction: 1);
      return SpeedTestReport(
        testedAt: DateTime.now(),
        viaProxy: useProxy,
        downloadMbps: downloadMbps ?? 0,
        uploadMbps: uploadFailed ? 0 : (uploadMbps ?? 0),
        idlePingMs: idlePingMs,
        downloadLoadedPingMs: downLoadedPing,
        uploadLoadedPingMs: upLoadedPing,
        jitterMs: jitterMs,
        trace: trace,
        serverId: target.id,
        uploadFailed: uploadFailed,
      );
    } finally {
      if (identical(_client, client)) _client = null;
      if (identical(_pingClient, pingClient)) _pingClient = null;
      client.close(force: true);
      pingClient.close(force: true);
    }
  }

  HttpClient _openClient({required int mixedPort, required bool useProxy, required int maxPerHost}) {
    final client = HttpClient();
    client.userAgent = _kBrowserUa;
    client.autoUncompress = false;
    client.maxConnectionsPerHost = maxPerHost;
    client.connectionTimeout = const Duration(seconds: 12);
    client.idleTimeout = const Duration(seconds: 30);
    if (useProxy) {
      client.findProxy = (_) => 'PROXY 127.0.0.1:$mixedPort';
    } else {
      client.findProxy = (_) => 'DIRECT';
    }
    return client;
  }

  void _throwIfCancelled() {
    if (_cancelled) throw const SpeedTestCancelled();
  }

  Future<SpeedTestTarget> _selectTarget(HttpClient client, {required bool useProxy}) async {
    if (useProxy) return kCloudflareSpeedTarget;
    final samples = await Future.wait(
      [...kDirectSpeedTargets, kCloudflareSpeedTarget].map((target) async {
        try {
          final rtt = await _pingTarget(client, target, timeout: const Duration(seconds: 4));
          return (target, rtt);
        } on SpeedTestCancelled {
          rethrow;
        } catch (_) {
          return (target, 60000);
        }
      }),
    );
    return pickFastestTarget(samples, preferDomestic: true);
  }

  Future<Uri> _resolveDownloadUri(HttpClient client, SpeedTestTarget target) async {
    if (target.cloudflare) return target.downloadUris.first;
    for (final uri in target.downloadUris) {
      try {
        final req = await client.openUrl('HEAD', uri).timeout(const Duration(seconds: 4));
        req.followRedirects = true;
        final res = await req.close().timeout(const Duration(seconds: 4));
        unawaited(res.drain<void>());
        if (res.statusCode >= 200 && res.statusCode < 400) return uri;
      } on SpeedTestCancelled {
        rethrow;
      } catch (_) {}
    }
    return target.downloadUris.first;
  }

  Future<CloudflareTrace?> _readTrace(HttpClient client) async {
    try {
      final req = await client.getUrl(Uri.parse('https://speed.cloudflare.com/cdn-cgi/trace')).timeout(const Duration(seconds: 8));
      req.followRedirects = true;
      req.headers.set(HttpHeaders.acceptHeader, 'text/plain, */*');
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return parseCloudflareTrace(body);
    } on SpeedTestCancelled {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<int> _pingTarget(HttpClient client, SpeedTestTarget target, {Duration timeout = const Duration(seconds: 3)}) {
    if (target.rangePing) {
      return _pingGet(client, target.downloadUris.first, timeout: timeout, rangeEnd: 2047);
    }
    return _pingGet(client, target.pingUri, timeout: timeout);
  }

  Future<int> _pingGet(
    HttpClient client,
    Uri uri, {
    required Duration timeout,
    int? rangeEnd,
  }) async {
    _throwIfCancelled();
    final sw = Stopwatch()..start();
    final req = await client.getUrl(uri).timeout(timeout);
    req.followRedirects = true;
    req.headers.set(HttpHeaders.acceptHeader, '*/*');
    if (rangeEnd != null) {
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-$rangeEnd');
    }
    final res = await req.close().timeout(timeout);
    var n = 0;
    await for (final chunk in res.timeout(timeout)) {
      n += chunk.length;
      if (n >= 4096) break;
    }
    sw.stop();
    _throwIfCancelled();
    if (res.statusCode >= 400) {
      throw SpeedTestException(SpeedTestFailureKind.network, 'HTTP ${res.statusCode}');
    }
    return sw.elapsedMilliseconds;
  }

  Future<({double mbps, int? loadedPingMs})> _measureThroughput({
    required HttpClient client,
    required HttpClient pingClient,
    required SpeedTestTarget target,
    required Uri downloadUri,
    required bool download,
    required int streams,
    required void Function(double mbps, int? loadedPingMs, double local) onLive,
  }) async {
    _throwIfCancelled();
    final meter = _ByteMeter();
    final loaded = <int>[];
    final deadline = DateTime.now().add(kSpeedTestTransfer);
    final payload = download ? null : _uploadPayload();

    final timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_cancelled) return;
      meter.sampleForScore();
      final elapsed = DateTime.now().difference(meter.start);
      final local = (elapsed.inMilliseconds / kSpeedTestTransfer.inMilliseconds).clamp(0, 1).toDouble();
      onLive(meter.displayMbps(), loaded.isEmpty ? null : medianInt(loaded), local);
    });

    Future<void> loadedPings() async {
      await Future<void>.delayed(const Duration(milliseconds: 2800));
      while (!_cancelled && DateTime.now().isBefore(deadline)) {
        try {
          loaded.add(await _pingTarget(pingClient, target, timeout: const Duration(seconds: 2)));
        } on SpeedTestCancelled {
          return;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }

    try {
      await Future.wait<void>([
        ...List<Future<void>>.generate(streams, (index) {
          return download
              ? _downloadStream(client, meter, deadline, target, downloadUri, index)
              : _uploadStream(client, meter, deadline, payload!, target.uploadUri!);
        }),
        loadedPings(),
      ]).timeout(kSpeedTestTransfer + const Duration(seconds: 5));
    } on TimeoutException {
      // Keep whatever the meter already captured.
    } catch (_) {
      if (meter.total <= 0) rethrow;
    } finally {
      timer.cancel();
    }
    _throwIfCancelled();
    meter.sampleForScore();
    return (mbps: meter.score(), loadedPingMs: loaded.isEmpty ? null : medianInt(withoutPingOutliers(loaded)));
  }

  Duration _remaining(DateTime deadline) {
    final d = deadline.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  Future<void> _downloadStream(
    HttpClient client,
    _ByteMeter meter,
    DateTime deadline,
    SpeedTestTarget target,
    Uri downloadUri,
    int streamIndex,
  ) async {
    var rangeStart = streamIndex * 256 * 1024 * 1024;
    while (!_cancelled && DateTime.now().isBefore(deadline)) {
      final remaining = _remaining(deadline);
      if (remaining < const Duration(milliseconds: 250)) return;
      _throwIfCancelled();
      final uri = target.cloudflare
          ? Uri.parse('https://speed.cloudflare.com/__down?bytes=$kSpeedTestDownloadBytes')
          : downloadUri;
      final req = await client.getUrl(uri).timeout(remaining);
      req.followRedirects = true;
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      if (!target.cloudflare) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$rangeStart-');
        rangeStart += 128 * 1024 * 1024;
      }
      final res = await req.close().timeout(remaining);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        await res.drain<void>();
        throw SpeedTestException(SpeedTestFailureKind.network, 'HTTP ${res.statusCode}');
      }
      try {
        await for (final chunk in res.timeout(remaining)) {
          if (_cancelled || DateTime.now().isAfter(deadline)) break;
          meter.add(chunk.length);
        }
      } on SpeedTestCancelled {
        rethrow;
      } on TimeoutException {
        return;
      } catch (_) {
        if (_cancelled || DateTime.now().isAfter(deadline)) return;
        rethrow;
      }
    }
  }

  Future<void> _uploadStream(
    HttpClient client,
    _ByteMeter meter,
    DateTime deadline,
    Uint8List payload,
    Uri uploadUri,
  ) async {
    while (!_cancelled && DateTime.now().isBefore(deadline)) {
      final remaining = _remaining(deadline);
      if (remaining < const Duration(milliseconds: 250)) return;
      _throwIfCancelled();
      final req = await client.postUrl(uploadUri).timeout(remaining);
      req.headers.contentType = ContentType('application', 'octet-stream');
      req.contentLength = payload.length;
      req.add(payload);
      final res = await req.close().timeout(remaining);
      await res.drain<void>().timeout(remaining);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw SpeedTestException(SpeedTestFailureKind.network, 'HTTP ${res.statusCode}');
      }
      meter.add(payload.length);
    }
  }

  Uint8List _uploadPayload() {
    final chunk = Uint8List(kSpeedTestUploadChunk);
    for (var i = 0; i < chunk.length; i++) {
      chunk[i] = i & 0xff;
    }
    return chunk;
  }
}

class _Stamp {
  _Stamp(this.at, this.bytes);
  final DateTime at;
  final int bytes;
}

class _ByteMeter {
  _ByteMeter() : start = DateTime.now();

  final DateTime start;
  int total = 0;
  final List<_Stamp> _window = [];
  final List<double> samples = [];

  void add(int n) {
    if (n <= 0) return;
    total += n;
    _window.add(_Stamp(DateTime.now(), n));
    _trim(DateTime.now());
  }

  void _trim(DateTime now) {
    final cutoff = now.subtract(const Duration(seconds: 1));
    while (_window.isNotEmpty && _window.first.at.isBefore(cutoff)) {
      _window.removeAt(0);
    }
  }

  double liveMbps() {
    final now = DateTime.now();
    _trim(now);
    if (_window.isEmpty) return 0;
    final bytes = _window.fold<int>(0, (a, e) => a + e.bytes);
    final dt = now.difference(_window.first.at);
    if (dt.inMilliseconds < 120) return bytesToMbps(total, now.difference(start));
    return bytesToMbps(bytes, dt);
  }

  double displayMbps() {
    final live = liveMbps();
    if (live > 0) return live;
    return bytesToMbps(total, DateTime.now().difference(start));
  }

  void sampleForScore() {
    if (DateTime.now().difference(start) < kSpeedTestWarmup) return;
    final v = liveMbps();
    if (v >= 0.05) samples.add(v);
  }

  double score() {
    if (samples.length >= 4) return percentile(samples, kSpeedTestScorePercentile);
    return bytesToMbps(total, DateTime.now().difference(start));
  }
}
