import 'dart:convert';
import 'dart:io';

import 'package:dartx/dartx_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rules_notifier.g.dart';

@riverpod
class RulesNotifier extends _$RulesNotifier with AppLogger {
  late File file;

  @override
  List<Rule> build() {
    final directories = ref.watch(appDirectoriesProvider).requireValue;
    file = File('${directories.baseDir.path}/route_rule.proto');
    final loaded = file.existsSync() ? RouteRule.fromBuffer(file.readAsBytesSync()).rules : <Rule>[];
    final merged = _withClientProxyRules(loaded);
    if (merged.$2) {
      Future.microtask(_updateFile);
    }
    return merged.$1;
  }

  /// Desktop clients that office networks commonly block on the China-direct
  /// path. Seeded once (by stable name) so a reset can still drop them.
  static List<Rule> _clientProxyRules() => [
    Rule(
      enabled: true,
      name: '哔哩哔哩客户端',
      outbound: Outbound.proxy,
      processNames: const [
        '哔哩哔哩',
        '哔哩哔哩 Helper',
        '哔哩哔哩 Helper (GPU)',
        '哔哩哔哩 Helper (Plugin)',
        '哔哩哔哩 Helper (Renderer)',
        '哔哩哔哩 Login Helper',
      ],
      domainSuffixes: const [
        'bilibili.com',
        'bilivideo.com',
        'hdslb.com',
        'biliapi.net',
        'biliapi.com',
        'b23.tv',
        'acgvideo.com',
      ],
    ),
    Rule(
      enabled: true,
      name: '抖音客户端',
      outbound: Outbound.proxy,
      processNames: const [
        '抖音',
        '抖音 Helper',
        '抖音 Helper (GPU)',
        '抖音 Helper (Plugin)',
        '抖音 Helper (Renderer)',
        '抖音 Login Helper',
      ],
      domainSuffixes: const [
        'douyin.com',
        'douyinpic.com',
        'douyinstatic.com',
        'douyinvod.com',
        'douyincdn.com',
        'iesdouyin.com',
        'amemv.com',
        'snssdk.com',
        'bytedance.com',
        'byteimg.com',
        'bytescm.com',
        'bytegoofy.com',
        'bytegecko.com',
        'bytednsdoc.com',
        'pstatp.com',
        'toutiao.com',
        'toutiaoapi.com',
        'ixigua.com',
        'zijieapi.com',
        'tiktokv.com',
      ],
      domainKeywords: const [
        'douyin',
        'snssdk',
        'amemv',
        'zijieapi',
        'toutiao',
        'bytedance',
        'byteimg',
      ],
    ),
  ];

  /// Returns the merged rule list and whether it grew vs disk (new seed or
  /// extra process/domain entries on an existing seeded rule).
  (List<Rule>, bool) _withClientProxyRules(List<Rule> current) {
    final byName = {for (final rule in current) rule.name: rule};
    final extra = <Rule>[];
    var changed = false;
    for (final seed in _clientProxyRules()) {
      final existing = byName[seed.name];
      if (existing == null) {
        extra.add(seed);
        changed = true;
        continue;
      }
      if (_unionStrings(existing.processNames, seed.processNames) |
          _unionStrings(existing.domainSuffixes, seed.domainSuffixes) |
          _unionStrings(existing.domainKeywords, seed.domainKeywords)) {
        changed = true;
      }
    }
    if (extra.isEmpty) return (current, changed);
    return (_updateListOrder([...extra, ...current]), true);
  }

  bool _unionStrings(List<String> dest, List<String> extra) {
    var changed = false;
    for (final item in extra) {
      if (dest.contains(item)) continue;
      dest.add(item);
      changed = true;
    }
    return changed;
  }

  Future<void> addRule(Rule rule) async {
    final current = state;
    assert(rule.hasName() && rule.hasOutbound());
    rule
      ..listOrder = current.length
      ..enabled = true;
    state = [...current, rule];
    await _updateFile();
  }

  /// Inserts a rule at the TOP of the list, so quick per-site rules take
  /// precedence over the broad region presets below them.
  Future<void> addRuleFirst(Rule rule) async {
    assert(rule.hasName() && rule.hasOutbound());
    rule.enabled = true;
    state = _updateListOrder([rule, ...state]);
    await _updateFile();
  }

  Future<void> updateRule(Rule rule) async {
    final current = state;
    final index = current.indexWhere((element) => element.listOrder == rule.listOrder);
    if (index == -1) return;
    current[index] = rule;
    state = current.toList();
    await _updateFile();
  }

  Future<void> deleteRule(int listOrder) async {
    final current = state;
    state = _updateListOrder(current.where((element) => element.listOrder != listOrder).toList());
    await _updateFile();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state;
    final rule = current.removeAt(oldIndex);
    current.insert(oldIndex < newIndex ? newIndex - 1 : newIndex, rule);
    state = _updateListOrder(current).toList();
    await _updateFile();
  }

  Future<void> updateEnabled(bool enabled, int listOrder) async {
    final current = state;
    current.firstWhere((rule) => rule.listOrder == listOrder).enabled = enabled;
    state = current.toList();
    await _updateFile();
  }

  //export Clipboard
  Future<bool> exportJsonToClipboard() async {
    final t = ref.read(translationsProvider).requireValue;
    try {
      final routeRules = RouteRule(rules: state);
      final base64Data = base64.encode(utf8.encode(jsonEncode(routeRules.writeToJson())));
      await Clipboard.setData(ClipboardData(text: 'lisaspeed:///settings/routing-options?routeRule=$base64Data'));
      ref.read(inAppNotificationControllerProvider).showSuccessToast(t.common.msg.export.clipboard.success);
      return true;
    } on PlatformException {
      ref
          .read(inAppNotificationControllerProvider)
          .showInfoToast(t.common.msg.export.clipboard.contentTooLarge, duration: const Duration(seconds: 5));
      return false;
    } catch (e, st) {
      loggy.warning("error exporting route rules to clipboard", e, st);
      ref.read(inAppNotificationControllerProvider).showErrorToast(t.common.msg.export.clipboard.failure);
      return false;
    }
  }

  //import clipboard
  Future<bool> importRulesFromClipboard() async {
    final t = ref.read(translationsProvider).requireValue;
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain).then((value) => value?.text);
      if (clipboardData == null) return false;
      final encodedBase64 = Uri.parse(clipboardData).queryParameters['routeRule'];
      if (encodedBase64 == null) return false;
      return await importRules(encodedBase64);
    } catch (e, st) {
      loggy.warning("error importing route rules from clipboard", e, st);
      ref.read(inAppNotificationControllerProvider).showErrorToast(t.common.msg.import.failure);
      return false;
    }
  }

  //import deep link
  Future<bool> importRulesFromDeepLink(String encodedBase64) async {
    final t = ref.read(translationsProvider).requireValue;
    try {
      final isConfirmed = await ref
          .read(dialogNotifierProvider.notifier)
          .showConfirmation(
            title: t.dialogs.confirmation.importRouteRuleByDeepLinkWarning.title,
            message: t.dialogs.confirmation.importRouteRuleByDeepLinkWarning.message,
          );
      if (isConfirmed) {
        return await importRules(encodedBase64);
      }
      return false;
    } catch (e, st) {
      loggy.warning("error importing route rules from deep link", e, st);
      ref.read(inAppNotificationControllerProvider).showErrorToast(t.common.msg.import.failure);
      return false;
    }
  }

  //import
  Future<bool> importRules(String encodedBase64) async {
    final t = ref.read(translationsProvider).requireValue;
    final base64Content = base64.decode(encodedBase64);
    final routeRules = RouteRule.fromJson(jsonDecode(utf8.decode(base64Content)) as String);
    state = routeRules.rules;
    await _updateFile();
    ref.read(inAppNotificationControllerProvider).showSuccessToast(t.common.msg.import.success);
    return true;
  }

  //export JSON
  Future<bool> saveRulesAsJsonFile() async {
    final t = ref.read(translationsProvider).requireValue;
    try {
      final bytes = utf8.encode(RouteRule(rules: state).writeToJson());
      final outputFile = await FilePicker.platform.saveFile(
        fileName: 'route_rules.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (outputFile == null) return false;
      if (PlatformUtils.isDesktop) {
        final file = File(outputFile);
        if (file.extension != '.json') return false;
        if (!await file.exists()) await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
      ref.read(inAppNotificationControllerProvider).showSuccessToast(t.common.msg.export.file.success);
      return true;
    } catch (e, st) {
      loggy.warning("error exporting route rules to json file", e, st);
      ref.read(inAppNotificationControllerProvider).showErrorToast(t.common.msg.export.file.failure);
      return false;
    }
  }

  //import JSON
  Future<bool> importRulesFromJsonFile() async {
    final t = ref.read(translationsProvider).requireValue;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null) return false;
      final file = File(result.files.single.path!);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final routeRules = RouteRule.fromJson(utf8.decode(bytes));
      state = routeRules.rules;
      await _updateFile();
      ref.read(inAppNotificationControllerProvider).showSuccessToast(t.common.msg.import.success);
      return true;
    } catch (e, st) {
      loggy.warning("error importing route rules from json file", e, st);
      ref.read(inAppNotificationControllerProvider).showErrorToast(t.common.msg.import.failure);
      return false;
    }
  }

  Future<void> resetRules() async {
    if (await file.exists()) {
      await file.delete(recursive: true);
      state = <Rule>[];
    }
  }

  Future<void> _updateFile() async {
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
    }
    final sortedRules = state..sort((a, b) => a.listOrder.compareTo(b.listOrder));
    final routeRules = RouteRule(rules: sortedRules);
    await file.writeAsBytes(routeRules.writeToBuffer());
  }

  List<Rule> _updateListOrder(List<Rule> rules) {
    for (var i = 0; i < rules.length; i++) {
      rules[i].listOrder = i;
    }
    return rules;
  }
}
