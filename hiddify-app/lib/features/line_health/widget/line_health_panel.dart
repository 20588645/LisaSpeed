import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/line_health/model/line_health_verdict.dart';
import 'package:hiddify/features/line_health/notifier/line_health_notifier.dart';
import 'package:hiddify/features/link_test/model/probe_grade.dart';
import 'package:hiddify/features/link_test/notifier/link_test_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/speed_test/notifier/speed_test_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

class LineHealthPanel extends ConsumerWidget {
  const LineHealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final state = ref.watch(lineHealthProvider);
    final siteBusy = ref.watch(linkTestProvider).testingIds.isNotEmpty;
    final speedBusy = ref.watch(speedTestProvider).running;
    final theme = Theme.of(context);
    final snapshot = state.snapshot;
    final verdict = state.verdict;
    final overseasGrade = snapshot != null && snapshot.intlOk
        ? gradeLatencyMs(snapshot.intlLatencyMs ?? 0)
        : null;

    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.pages.lineHealth.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TechUi.tinyButton(
                context,
                label: state.running ? t.pages.lineHealth.running : t.pages.lineHealth.run,
                onPressed: state.running || siteBusy || speedBusy
                    ? null
                    : () => ref.read(lineHealthProvider.notifier).run(),
              ),
            ],
          ),
          const Gap(6),
          Text(
            t.pages.lineHealth.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (verdict != null) ...[
            const Gap(12),
            Text(
              lineHealthVerdictText(t, verdict),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: switch (verdict) {
                  LineHealthVerdict.ok => ConnectionButtonTheme.accentOf(context),
                  LineHealthVerdict.sluggish => TechUi.warnOf(context),
                  LineHealthVerdict.notConnected => theme.colorScheme.onSurfaceVariant,
                  _ => theme.colorScheme.error,
                },
              ),
            ),
            if (snapshot != null && snapshot.connected) ...[
              const Gap(10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TechUi.statusChip(
                    context,
                    '${t.pages.lineHealth.tunnel} · ${snapshot.tunnelOk ? t.pages.lineHealth.pass : t.pages.lineHealth.fail}',
                    active: snapshot.tunnelOk,
                  ),
                  TechUi.statusChip(
                    context,
                    '${t.pages.lineHealth.domestic} · ${snapshot.cnOk ? t.pages.lineHealth.pass : t.pages.lineHealth.fail}',
                    active: snapshot.cnOk,
                  ),
                  TechUi.statusChip(
                    context,
                    '${t.pages.lineHealth.overseas} · ${_overseasLabel(t, snapshot.intlOk, overseasGrade)}',
                    active: snapshot.intlOk && overseasGrade == ProbeGrade.ok,
                  ),
                ],
              ),
            ],
            if (state.testedAt != null) ...[
              const Gap(8),
              Text(
                '${t.pages.lineHealth.lastTested} ${DateFormat.Hm().format(state.testedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (lineHealthShouldSwitchNode(verdict)) ...[
              const Gap(12),
              Align(
                alignment: Alignment.centerLeft,
                child: TechUi.tinyButton(
                  context,
                  label: t.pages.lineHealth.goSwitch,
                  onPressed: () => _goSwitchNode(context, ref),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _overseasLabel(Translations t, bool ok, ProbeGrade? grade) {
    if (!ok || grade == null) return t.pages.lineHealth.fail;
    return switch (grade) {
      ProbeGrade.ok => t.pages.lineHealth.pass,
      ProbeGrade.sluggish => t.pages.linkTest.gradeSluggish,
      ProbeGrade.switchNode => t.pages.linkTest.gradeSwitch,
    };
  }

  Future<void> _goSwitchNode(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(proxiesOverviewNotifierProvider.notifier);
    context.goNamed('proxies');
    try {
      await notifier.urlTest('select');
    } catch (_) {}
  }
}
