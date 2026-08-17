import 'dart:io';

/// Parses `networksetup -listallnetworkservices`. The first line is a legend;
/// disabled services are prefixed with `*`.
List<String> parseNetworkServiceNames(String stdout) {
  final lines = stdout.split('\n');
  if (lines.isEmpty) return const [];
  final names = <String>[];
  for (var i = 1; i < lines.length; i++) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;
    if (line.startsWith('*')) line = line.substring(1).trimLeft();
    if (line.isEmpty) continue;
    names.add(line);
  }
  return names;
}

class RestoreNetworkException implements Exception {
  RestoreNetworkException(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Turns off leftover HTTP/HTTPS/SOCKS system proxies that LisaSpeed may have
/// left behind. Does not kill the app, does not disable the tunnel daemon, and
/// does not touch ISP/Wi-Fi settings.
Future<void> restoreLocalNetwork({ProcessRunner? run}) async {
  final exec = run ?? Process.run;
  final listed = await exec('networksetup', ['-listallnetworkservices']);
  if (listed.exitCode != 0) {
    throw RestoreNetworkException(listed.stderr.toString().trim());
  }
  final services = parseNetworkServiceNames(listed.stdout.toString());
  for (final service in services) {
    await exec('networksetup', ['-setwebproxystate', service, 'off']);
    await exec('networksetup', ['-setsecurewebproxystate', service, 'off']);
    await exec('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
    await exec('networksetup', ['-setproxyautodiscovery', service, 'off']);
  }
  await exec('dscacheutil', ['-flushcache']);
}
