import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Hub for infrequent power-user options (DNS / TLS / chain).
class AdvancedOptionsPage extends HookConsumerWidget {
  const AdvancedOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final hasProfile = ref.watch(hasAnyProfileProvider).value ?? false;

    final sections = <({String title, IconData icon, String location, Widget? subtitle})>[
      (
        title: t.pages.settings.dns.title,
        icon: Icons.dns_rounded,
        location: context.namedLocation('dnsOptions'),
        subtitle: null,
      ),
      (
        title: t.pages.settings.tlsTricks.title,
        icon: Icons.content_cut_rounded,
        location: context.namedLocation('tlsTricks'),
        subtitle: null,
      ),
      if (hasProfile)
        (
          title: t.pages.settings.chain.title,
          icon: Icons.webhook_rounded,
          location: context.namedLocation('chainOptions'),
          subtitle: Text(t.pages.settings.chain.subtitle),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.pages.settings.advanced.title)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TechUi.pageIntro(
              context,
              eyebrow: 'Advanced',
              title: t.pages.settings.advanced.title,
              subtitle: t.pages.settings.advanced.subtitle,
            ),
          ),
          for (var i = 0; i < sections.length; i++)
            TechUi.hubCard(
              context,
              index: i + 1,
              icon: sections[i].icon,
              title: sections[i].title,
              subtitle: sections[i].subtitle,
              onTap: () => context.go(sections[i].location),
            ),
        ],
      ),
    );
  }
}
