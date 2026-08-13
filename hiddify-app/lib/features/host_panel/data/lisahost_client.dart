import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hiddify/features/host_panel/model/host_quota.dart';

class LisahostAuthException implements Exception {
  const LisahostAuthException(this.message);
  final String message;

  @override
  String toString() => 'LisahostAuthException: $message';
}

/// Scrapes the LisaHost (WHMCS) client area for the VPS traffic quota.
///
/// The panel has no client API, so this signs in through `dologin.php`
/// (email + password + CSRF token, no captcha), auto-discovers the first
/// product and reads the usage figures the product page embeds both in a
/// server-side debug dump and in the visible quota widget.
class LisahostClient {
  LisahostClient({required this.email, required this.password});

  static const _base = 'https://lisahost.com';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  final String email;
  final String password;

  final Map<String, String> _cookies = {};

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 400,
      responseType: ResponseType.plain,
      // The panel HTML carries a few malformed bytes in its debug dump;
      // strict UTF-8 decoding would throw the whole fetch away.
      responseDecoder: (bytes, options, body) => utf8.decode(bytes, allowMalformed: true),
      headers: {'user-agent': _userAgent, 'accept-language': 'zh-CN,zh;q=0.9'},
    ),
  );

  Future<HostQuota> fetchQuota() async {
    var products = await _get('/clientarea.php?action=products');
    if (_isLoginPage(products)) {
      await _login(products);
      products = await _get('/clientarea.php?action=products');
      if (_isLoginPage(products)) {
        throw const LisahostAuthException('login was not accepted, check email/password');
      }
    }
    final productId = RegExp(r'productdetails&(?:amp;)?id=(\d+)').firstMatch(products)?.group(1);
    if (productId == null) {
      throw const LisahostAuthException('no product found in the client area');
    }
    final page = await _get('/clientarea.php?action=productdetails&id=$productId');
    if (_isLoginPage(page)) {
      throw const LisahostAuthException('session expired mid-fetch');
    }
    return _parseQuota(page);
  }

  bool _isLoginPage(String html) => html.contains('dologin.php');

  Future<void> _login(String loginHtml) async {
    final token = RegExp('name="token" value="([0-9a-f]+)"').firstMatch(loginHtml)?.group(1);
    if (token == null) {
      throw const LisahostAuthException('csrf token not found on login page');
    }
    final response = await _dio.post<String>(
      '/dologin.php',
      data: {'token': token, 'username': email, 'password': password, 'rememberme': 'on'},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'cookie': _cookieHeader, 'referer': '$_base/clientarea.php'},
      ),
    );
    _storeCookies(response);
    final location = response.headers.value('location') ?? '';
    if (location.contains('incorrect=true')) {
      throw const LisahostAuthException('email or password rejected');
    }
  }

  Future<String> _get(String path) async {
    var target = path;
    for (var hop = 0; hop < 4; hop++) {
      final response = await _dio.get<String>(
        target,
        options: Options(headers: {'cookie': _cookieHeader}),
      );
      _storeCookies(response);
      final status = response.statusCode ?? 0;
      if (status == 301 || status == 302 || status == 303) {
        final location = response.headers.value('location');
        if (location == null) break;
        target = location.startsWith('http') ? Uri.parse(location).path + _query(location) : location;
        continue;
      }
      return response.data ?? '';
    }
    throw const LisahostAuthException('too many redirects');
  }

  String _query(String url) {
    final uri = Uri.parse(url);
    return uri.query.isEmpty ? '' : '?${uri.query}';
  }

  String get _cookieHeader => _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  void _storeCookies(Response<dynamic> response) {
    final setCookies = response.headers['set-cookie'];
    if (setCookies == null) return;
    for (final raw in setCookies) {
      final pair = raw.split(';').first;
      final idx = pair.indexOf('=');
      if (idx <= 0) continue;
      final name = pair.substring(0, idx).trim();
      final value = pair.substring(idx + 1).trim();
      if (value.isEmpty || value == 'deleted') {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  HostQuota _parseQuota(String html) {
    double? usedGb;
    double? totalGb;

    // Primary: the server-side dump the page embeds in an HTML comment:
    //   [traffic] => stdClass Object ( [type] => 3 [total] => 2000 [used] => 234.4 GB )
    final dump = RegExp(r'\[traffic\]\s*=>\s*stdClass Object[\s\S]{0,400}?\)').firstMatch(html)?.group(0);
    if (dump != null) {
      final used = RegExp(r'\[used\]\s*=>\s*([\d.]+)\s*(TB|GB|MB|KB|B)?').firstMatch(dump);
      final total = RegExp(r'\[total\]\s*=>\s*([\d.]+)\s*(TB|GB|MB)?').firstMatch(dump);
      if (used != null) usedGb = _toGb(double.parse(used.group(1)!), used.group(2) ?? 'GB');
      if (total != null) totalGb = _toGb(double.parse(total.group(1)!), total.group(2) ?? 'GB');
    }
    totalGb ??= double.tryParse(RegExp(r'\[traffic_quota\]\s*=>\s*([\d.]+)').firstMatch(html)?.group(1) ?? '');

    // Fallback: the visible quota widget.
    if (usedGb == null || totalGb == null) {
      final widget = RegExp(
        r'流量概况[\s\S]{0,600}?class="used">\s*([\d.]+)\s*(TB|GB|MB)[\s\S]{0,200}?/\s*([\d.]+)\s*(TB|GB)',
      ).firstMatch(html);
      if (widget != null) {
        usedGb ??= _toGb(double.parse(widget.group(1)!), widget.group(2)!);
        totalGb ??= _toGb(double.parse(widget.group(3)!), widget.group(4)!);
      }
    }

    if (usedGb == null || totalGb == null) {
      throw const FormatException('traffic quota not found on product page');
    }

    final resetDay = int.tryParse(RegExp(r'\[reset_flow_day\]\s*=>\s*(\d+)').firstMatch(html)?.group(1) ?? '');
    final expiry = RegExp(r'到期时间[\s\S]{0,400}?(\d{4}-\d{2}-\d{2})').firstMatch(html)?.group(1);

    return HostQuota(
      usedGb: usedGb,
      totalGb: totalGb,
      resetDay: resetDay,
      expiryDate: expiry,
      fetchedAt: DateTime.now(),
    );
  }

  double _toGb(double value, String unit) => switch (unit.toUpperCase()) {
    'TB' => value * 1024,
    'GB' => value,
    'MB' => value / 1024,
    'KB' => value / (1024 * 1024),
    _ => value,
  };
}
