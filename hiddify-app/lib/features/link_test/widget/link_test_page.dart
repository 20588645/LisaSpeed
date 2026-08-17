import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/line_health/notifier/line_health_notifier.dart';
import 'package:hiddify/features/line_health/widget/line_health_panel.dart';
import 'package:hiddify/features/link_test/data/link_test_catalog.dart';
import 'package:hiddify/features/link_test/model/link_test_target.dart';
import 'package:hiddify/features/link_test/model/probe_grade.dart';
import 'package:hiddify/features/link_test/notifier/link_test_notifier.dart';
import 'package:hiddify/features/speed_test/notifier/speed_test_notifier.dart';
import 'package:hiddify/features/speed_test/widget/speed_test_panel.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

class LinkTestPage extends ConsumerWidget {
  const LinkTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final state = ref.watch(linkTestProvider);
    final notifier = ref.read(linkTestProvider.notifier);
    final connected = ref.watch(serviceRunningProvider);
    final locale = ref.watch(localePreferencesProvider);
    final chinese = locale == AppLocale.zhCn || locale == AppLocale.zhTw;
    final busy = state.testingIds.isNotEmpty;
    final speedBusy = ref.watch(speedTestProvider).running;
    final healthBusy = ref.watch(lineHealthProvider).running;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.pageIntro(
              context,
              title: t.pages.linkTest.title,
              subtitle: t.pages.linkTest.subtitle,
              action: TechUi.primaryButton(
                context,
                label: busy ? t.pages.linkTest.testing : t.pages.linkTest.testAll,
                onPressed: busy || speedBusy || healthBusy ? null : () => notifier.testAll(group: state.filter),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 720
                    ? 2
                    : 1;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(TechUi.pageInset, TechUi.pageBodyTop, TechUi.pageInset, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LineHealthPanel(),
                            const Gap(18),
                            const SpeedTestPanel(),
                            const Gap(18),
                            TechUi.formSectionTitle(context, t.pages.linkTest.sitesSection, first: true),
                            const Gap(8),
                            Text(
                              connected ? t.pages.linkTest.hintConnected : t.pages.linkTest.hintDisconnected,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            const Gap(12),
                            Row(
                              children: [
                                _FilterChip(
                                  label: t.common.all,
                                  selected: state.filter == null,
                                  onTap: () => notifier.setFilter(null),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: t.pages.linkTest.groupCn,
                                  selected: state.filter == LinkTestGroup.cn,
                                  onTap: () => notifier.setFilter(LinkTestGroup.cn),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: t.pages.linkTest.groupIntl,
                                  selected: state.filter == LinkTestGroup.intl,
                                  onTap: () => notifier.setFilter(LinkTestGroup.intl),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (state.filter == null) ...[
                      _section(context, t.pages.linkTest.groupCn),
                      _grid(context, chinese, cols, LinkTestGroup.cn, connected, speedBusy || healthBusy),
                      _section(context, t.pages.linkTest.groupIntl),
                      _grid(context, chinese, cols, LinkTestGroup.intl, connected, speedBusy || healthBusy),
                    ] else
                      _grid(context, chinese, cols, state.filter!, connected, speedBusy || healthBusy),
                    const SliverToBoxAdapter(child: SizedBox(height: TechUi.pageBodyBottom)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SliverPadding _section(BuildContext context, String title) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(TechUi.pageInset, 12, TechUi.pageInset, 8),
      sliver: SliverToBoxAdapter(
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      ),
    );
  }

  SliverPadding _grid(
    BuildContext context,
    bool chinese,
    int cols,
    LinkTestGroup group,
    bool connected,
    bool speedBusy,
  ) {
    final items = kLinkTestCatalog.where((t) => t.group == group).toList();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: TechUi.pageInset),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 126,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _SiteCard(
            target: items[index],
            chinese: chinese,
            connected: connected,
            speedBusy: speedBusy,
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final color = selected ? accent : Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TechUi.buttonRadius),
        child: Container(
          height: TechUi.buttonHeight,
          padding: TechUi.buttonPadding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(TechUi.buttonRadius),
            border: Border.all(color: selected ? accent : ConnectionButtonTheme.lineOf(context)),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: TechUi.buttonFontSize,
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SiteCard extends ConsumerWidget {
  const _SiteCard({
    required this.target,
    required this.chinese,
    required this.connected,
    required this.speedBusy,
  });

  final LinkTestTarget target;
  final bool chinese;
  final bool connected;
  final bool speedBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final state = ref.watch(linkTestProvider);
    final testing = state.isTesting(target.id);
    final outcome = state.results[target.id];
    final viaProxy = outcome?.viaProxy ?? linkTestUsesProxy(target.group, connected);

    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: TechUi.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  target.displayName(chinese: chinese),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              TechUi.trailingRow([
                TechUi.statusChip(
                  context,
                  viaProxy ? t.pages.linkTest.viaProxy : t.pages.linkTest.viaDirect,
                  active: viaProxy,
                ),
                if (testing)
                  SizedBox(
                    width: TechUi.buttonHeight,
                    height: TechUi.buttonHeight,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ConnectionButtonTheme.accentOf(context),
                        ),
                      ),
                    ),
                  )
                else
                  TechUi.iconButton(
                    context,
                    icon: Icons.refresh_rounded,
                    tooltip: t.pages.linkTest.testOne,
                    iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    onPressed: speedBusy ? null : () => ref.read(linkTestProvider.notifier).testOne(target.id),
                  ),
              ]),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            target.host,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TechUi.mono(
              context,
              size: 11,
              weight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _StatusPill(testing: testing, outcome: outcome),
              ),
              if (outcome != null) ...[
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(outcome.testedAt),
                  style: TechUi.mono(
                    context,
                    size: 10,
                    weight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends ConsumerWidget {
  const _StatusPill({required this.testing, required this.outcome});

  final bool testing;
  final LinkTestOutcome? outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    if (testing) {
      return TechUi.tag(context, t.pages.linkTest.testing, active: true);
    }
    if (outcome == null) {
      return TechUi.tag(context, t.pages.linkTest.idle);
    }
    if (outcome!.ok) {
      final ms = outcome!.latencyMs ?? 0;
      if (!outcome!.viaProxy) {
        return TechUi.latencyPill(context, ms);
      }
      final grade = gradeLatencyMs(ms);
      final gradeLabel = switch (grade) {
        ProbeGrade.ok => t.pages.linkTest.gradeOk,
        ProbeGrade.sluggish => t.pages.linkTest.gradeSluggish,
        ProbeGrade.switchNode => t.pages.linkTest.gradeSwitch,
      };
      return TechUi.latencyPill(context, ms, emptyLabel: '—', suffix: gradeLabel);
    }
    final reason = switch (outcome!.failure) {
      LinkTestFailureKind.timeout => t.pages.linkTest.failTimeout,
      LinkTestFailureKind.network => t.pages.linkTest.failNetwork,
      LinkTestFailureKind.tls => t.pages.linkTest.failTls,
      _ => t.pages.linkTest.failUnknown,
    };
    final color = TechUi.dangerOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        '${t.pages.linkTest.fail} ($reason)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
