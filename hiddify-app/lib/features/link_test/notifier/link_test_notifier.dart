import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/link_test/data/link_test_catalog.dart';
import 'package:hiddify/features/link_test/data/link_tester.dart';
import 'package:hiddify/features/link_test/model/link_test_target.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LinkTestState {
  const LinkTestState({
    this.results = const {},
    this.testingIds = const {},
    this.filter,
  });

  final Map<String, LinkTestOutcome> results;
  final Set<String> testingIds;
  final LinkTestGroup? filter;

  bool get testingAll => testingIds.length > 1;

  bool isTesting(String id) => testingIds.contains(id);

  LinkTestState copyWith({
    Map<String, LinkTestOutcome>? results,
    Set<String>? testingIds,
    LinkTestGroup? filter,
    bool clearFilter = false,
  }) {
    return LinkTestState(
      results: results ?? this.results,
      testingIds: testingIds ?? this.testingIds,
      filter: clearFilter ? null : (filter ?? this.filter),
    );
  }
}

final linkTestProvider = NotifierProvider<LinkTestNotifier, LinkTestState>(LinkTestNotifier.new);

class LinkTestNotifier extends Notifier<LinkTestState> {
  static const _parallelism = 5;
  static const _tester = LinkTester();

  int _runId = 0;

  @override
  LinkTestState build() => const LinkTestState();

  void setFilter(LinkTestGroup? group) {
    state = state.copyWith(filter: group, clearFilter: group == null);
  }

  List<LinkTestTarget> get visibleTargets {
    final filter = state.filter;
    if (filter == null) return kLinkTestCatalog;
    return kLinkTestCatalog.where((t) => t.group == filter).toList();
  }

  Future<void> testOne(String id) async {
    final matches = kLinkTestCatalog.where((t) => t.id == id);
    if (matches.isEmpty) return;
    final target = matches.first;
    final gen = ++_runId;
    state = state.copyWith(testingIds: {...state.testingIds, id});
    await _probe(target, gen);
  }

  Future<void> testAll({LinkTestGroup? group}) async {
    final gen = ++_runId;
    final targets = group == null
        ? List<LinkTestTarget>.from(kLinkTestCatalog)
        : kLinkTestCatalog.where((t) => t.group == group).toList();
    state = state.copyWith(testingIds: {for (final t in targets) t.id});
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        if (gen != _runId) return;
        if (cursor >= targets.length) return;
        final target = targets[cursor++];
        await _probe(target, gen);
      }
    }

    await Future.wait(List.generate(_parallelism, (_) => worker()));
  }

  Future<void> _probe(LinkTestTarget target, int gen) async {
    if (gen != _runId) return;
    final useProxy = linkTestUsesProxy(target.group, ref.read(serviceRunningProvider));
    final mixedPort = ref.read(httpClientProvider).port;
    final fallbackPort = ref.read(ConfigOptions.mixedPort);
    final outcome = await _tester.probe(
      target: target,
      mixedPort: mixedPort > 0 ? mixedPort : fallbackPort,
      useProxy: useProxy,
    );
    if (gen != _runId) return;
    final nextTesting = {...state.testingIds}..remove(target.id);
    state = state.copyWith(
      results: {...state.results, target.id: outcome},
      testingIds: nextTesting,
    );
  }
}
