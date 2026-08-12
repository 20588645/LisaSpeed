import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/animated_text.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// LisaSpeed Tech-style connect control: soft aura + ring + gradient arc + L disc.
class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final delay = activeProxy.valueOrNull?.urlTestDelay ?? 0;
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;

    const buttonTheme = ConnectionButtonTheme.light;

    final isConnected = connectionStatus.valueOrNull is Connected &&
        requiresReconnect != true &&
        delay > 0 &&
        delay < 65000;
    final isConnecting = switch (connectionStatus) {
      AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => true,
      AsyncLoading() => true,
      AsyncData(value: Connecting()) => true,
      AsyncData(value: Disconnecting()) => true,
      _ => false,
    };

    final arcController = useAnimationController(
      duration: Duration(milliseconds: isConnecting ? 1200 : 10000),
    );
    useEffect(() {
      if (isConnected || isConnecting) {
        arcController.repeat();
      } else {
        arcController.stop();
        arcController.value = 0;
      }
      return null;
    }, [isConnected, isConnecting]);

    // Keep duration in sync when state flips between connecting/connected.
    useEffect(() {
      arcController.duration = Duration(milliseconds: isConnecting ? 1200 : 10000);
      if (arcController.isAnimating) {
        arcController.repeat();
      }
      return null;
    }, [isConnecting]);

    final secureLabel = (delay <= 0 || delay > 65000 || connectionStatus.value != const Connected())
        ? ''
        : '';

    return _ConnectionButton(
      onTap: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => () async {
          final activeProfile = await ref.read(activeProfileProvider.future);
          return await ref.read(connectionNotifierProvider.notifier).reconnect(activeProfile);
        },
        AsyncData(value: Disconnected()) || AsyncError() => () async {
          if (ref.read(activeProfileProvider).valueOrNull == null) {
            await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
            ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
          }
          if (await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
          }
        },
        AsyncData(value: Connected()) => () async {
          if (requiresReconnect == true &&
              await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            return await ref
                .read(connectionNotifierProvider.notifier)
                .reconnect(await ref.read(activeProfileProvider.future));
          }
          return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        },
        _ => () {},
      },
      enabled: switch (connectionStatus) {
        AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
        _ => false,
      },
      label: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => t.connection.reconnect,
        AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => t.connection.connecting,
        AsyncData(value: final status) => status.present(t),
        _ => '',
      },
      accent: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => ConnectionButtonTheme.accentOf(context),
        AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => ConnectionButtonTheme.accent2Of(context),
        AsyncData(value: Connected()) => ConnectionButtonTheme.accentOf(context),
        AsyncData(value: _) => buttonTheme.idleColor!,
        _ => Colors.red,
      },
      accentSecondary: ConnectionButtonTheme.accent2Of(context),
      isConnected: isConnected,
      isConnecting: isConnecting,
      arcAnimation: arcController,
      secureLabel: secureLabel,
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.accent,
    required this.accentSecondary,
    required this.isConnected,
    required this.isConnecting,
    required this.arcAnimation,
    required this.secureLabel,
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;
  final Color accent;
  final Color accentSecondary;
  final bool isConnected;
  final bool isConnecting;
  final Animation<double> arcAnimation;
  final String secureLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final faceTop = isDark ? const Color(0xFF152636) : Colors.white;
    final faceBottom = isDark ? const Color(0xFF0E1A28) : const Color(0xFFF2F6FA);
    final auraOpacity = isConnected ? 0.55 : (isConnecting ? 0.4 : 0.18);
    final arcOpacity = isConnected || isConnecting ? 1.0 : 0.72;

    Widget button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: 168,
        height: 168,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft aura
            AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              opacity: auraOpacity,
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.28 : 0.2),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // Thin ring
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: isConnected ? 0.55 : 0.22),
                  width: 1,
                ),
                boxShadow: isConnected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 28,
                        ),
                      ]
                    : null,
              ),
            ),
            // Gradient arc (Tech conic rim)
            AnimatedBuilder(
              animation: arcAnimation,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(148, 148),
                  painter: _ConnectArcPainter(
                    rotation: arcAnimation.value * math.pi * 2,
                    accent: accent,
                    accentSecondary: accentSecondary,
                    opacity: arcOpacity,
                  ),
                );
              },
            ),
            // Disc + L mark
            Material(
              key: const ValueKey('home_connection_button'),
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: const Alignment(-0.6, -0.8),
                      end: const Alignment(0.7, 0.9),
                      colors: [
                        Color.lerp(faceTop, accent, isConnected ? 0.12 : 0.04)!,
                        faceBottom,
                      ],
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: isConnected ? 0.5 : 0.28),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                      if (isConnected)
                        BoxShadow(
                          color: accent.withValues(alpha: 0.12),
                          blurRadius: 1,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                  child: Center(
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isConnected
                              ? [Colors.white, accent]
                              : isConnecting
                                  ? [accentSecondary, accent]
                                  : [
                                      theme.colorScheme.onSurface,
                                      Color.lerp(theme.colorScheme.onSurface, accent, 0.55)!,
                                    ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'L',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          height: 1,
                          color: Colors.white,
                          shadows: isConnected
                              ? [
                                  Shadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Keep the control crisp while connecting: scale only, no blur.
        button.animate(target: enabled ? 0 : 1).scaleXY(end: .97, curve: Curves.easeIn),
        const Gap(18),
        ExcludeSemantics(
          child: Column(
            children: [
              AnimatedText(
                label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: isConnected ? accent : theme.colorScheme.onSurface,
                ),
              ),
              if (secureLabel.isNotEmpty) ...[
                const Gap(6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FontAwesomeIcons.shieldHalved, size: 14, color: theme.colorScheme.secondary),
                    const Gap(4),
                    Text(
                      secureLabel,
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectArcPainter extends CustomPainter {
  _ConnectArcPainter({
    required this.rotation,
    required this.accent,
    required this.accentSecondary,
    required this.opacity,
  });

  final double rotation;
  final Color accent;
  final Color accentSecondary;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: GradientRotation(rotation + 3.665), // ~210deg
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0),
          accent.withValues(alpha: opacity),
          accentSecondary.withValues(alpha: opacity),
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.11, 0.30, 0.42, 0.53, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectArcPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.accent != accent ||
        oldDelegate.accentSecondary != accentSecondary ||
        oldDelegate.opacity != opacity;
  }
}
