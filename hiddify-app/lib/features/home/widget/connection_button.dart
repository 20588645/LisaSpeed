import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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

/// LisaSpeed glass-orb connect control, mirroring the tech prototype v3:
/// hairline gradient ring, comet arc while connecting, glass dome disc with a
/// power glyph. Crisp in every state — no blur filters.
class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final delay = activeProxy.valueOrNull?.urlTestDelay ?? 0;
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;

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

    // Ring/comet rotation: fast eased orbit while connecting, a slow shimmer
    // once connected.
    final rotationController = useAnimationController(
      duration: Duration(milliseconds: isConnecting ? 1600 : 14000),
    );
    useEffect(() {
      rotationController.duration = Duration(milliseconds: isConnecting ? 1600 : 14000);
      if (isConnected || isConnecting) {
        rotationController.repeat();
      } else {
        rotationController.stop();
        rotationController.value = 0;
      }
      return null;
    }, [isConnected, isConnecting]);

    // Soft glyph breathing while connecting.
    final pulseController = useAnimationController(duration: const Duration(milliseconds: 1600));
    useEffect(() {
      if (isConnecting) {
        pulseController.repeat(reverse: true);
      } else {
        pulseController.stop();
        pulseController.value = 0;
      }
      return null;
    }, [isConnecting]);

    // One-shot success ripple when the tunnel comes up.
    final rippleController = useAnimationController(duration: const Duration(milliseconds: 900));
    useEffect(() {
      if (isConnected) rippleController.forward(from: 0);
      return null;
    }, [isConnected]);

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
      isConnected: isConnected,
      isConnecting: isConnecting,
      rotation: rotationController,
      pulse: pulseController,
      ripple: rippleController,
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.isConnected,
    required this.isConnecting,
    required this.rotation,
    required this.pulse,
    required this.ripple,
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;
  final bool isConnected;
  final bool isConnecting;
  final Animation<double> rotation;
  final Animation<double> pulse;
  final Animation<double> ripple;

  static const double _box = 168;
  static const double _ringSize = 160;
  static const double _discSize = 128;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = ConnectionButtonTheme.accentOf(context);
    final accent2 = ConnectionButtonTheme.accent2Of(context);
    final onSurface = theme.colorScheme.onSurface;

    final faceTop = isDark ? const Color(0xFF17293B) : Colors.white;
    final faceBottom = isDark ? const Color(0xFF0B141F) : const Color(0xFFEEF3F8);
    final auraOpacity = isConnected ? 0.5 : (isConnecting ? 0.35 : 0.15);

    final glyphColor = isConnected
        ? accent
        : isConnecting
            ? accent2
            : onSurface.withValues(alpha: 0.82);

    final Widget button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: _box,
        height: _box,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft ambient aura.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity: auraOpacity,
              child: Container(
                width: _box,
                height: _box,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.26 : 0.18),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // Halo bloom once connected.
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: _ringSize,
              height: _ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isConnected
                    ? [
                        BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 34),
                        BoxShadow(color: accent.withValues(alpha: 0.09), blurRadius: 90),
                      ]
                    : const [],
              ),
            ),
            // Hairline gradient ring.
            AnimatedBuilder(
              animation: rotation,
              builder: (context, _) => CustomPaint(
                size: const Size(_ringSize, _ringSize),
                painter: _HairlineRingPainter(
                  rotation: isConnected ? rotation.value * 2 * math.pi : 0,
                  connected: isConnected,
                  accent: accent,
                  accent2: accent2,
                ),
              ),
            ),
            // Comet arc while connecting.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isConnecting ? 1 : 0,
              child: AnimatedBuilder(
                animation: rotation,
                builder: (context, _) => CustomPaint(
                  size: const Size(_ringSize, _ringSize),
                  painter: _CometArcPainter(
                    rotation: Curves.easeInOutSine.transform(rotation.value) * 2 * math.pi,
                    accent: accent,
                    accent2: accent2,
                    visible: isConnecting,
                  ),
                ),
              ),
            ),
            // Success ripple.
            AnimatedBuilder(
              animation: ripple,
              builder: (context, _) {
                final v = ripple.value;
                if (v == 0 || v == 1) return const SizedBox();
                return Container(
                  width: _ringSize * (0.92 + 0.36 * v),
                  height: _ringSize * (0.92 + 0.36 * v),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.5 * (1 - v)),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),
            // Glass dome disc.
            Material(
              key: const ValueKey('home_connection_button'),
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  width: _discSize,
                  height: _discSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: const Alignment(-0.5, -0.9),
                      end: const Alignment(0.5, 1.0),
                      colors: [faceTop, faceBottom],
                    ),
                    border: Border.all(
                      color: isConnected
                          ? accent.withValues(alpha: 0.38)
                          : onSurface.withValues(alpha: 0.10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      if (isConnected)
                        BoxShadow(
                          color: accent.withValues(alpha: 0.13),
                          blurRadius: 22,
                        ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      // Specular top-left light.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.4, -0.64),
                            radius: 1.0,
                            colors: [
                              Colors.white.withValues(alpha: isDark ? 0.10 : 0.9),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.46],
                          ),
                        ),
                      ),
                      // Bottom accent bloom.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(0, 1.2),
                            radius: 1.1,
                            colors: [
                              accent.withValues(alpha: isDark ? 0.13 : 0.10),
                              accent.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.56],
                          ),
                        ),
                      ),
                      // Bottom inner shade (fakes an inset shadow).
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
                              Colors.black.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.38],
                          ),
                        ),
                      ),
                      // Machined chamfer ring.
                      Padding(
                        padding: const EdgeInsets.all(9),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 450),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isConnected
                                  ? accent.withValues(alpha: 0.24)
                                  : onSurface.withValues(alpha: 0.07),
                            ),
                          ),
                        ),
                      ),
                      // Power glyph.
                      Center(
                        child: AnimatedBuilder(
                          animation: pulse,
                          builder: (context, _) {
                            final opacity = isConnecting ? 1 - 0.35 * pulse.value : 1.0;
                            return CustomPaint(
                              size: const Size(34, 40),
                              painter: _PowerGlyphPainter(
                                color: glyphColor.withValues(alpha: glyphColor.a * opacity),
                                strokeWidth: 2.4,
                                glow: isConnected ? accent.withValues(alpha: 0.45) : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
        // Keep the control crisp while disabled: scale only, no blur.
        AnimatedScale(
          scale: enabled ? 1 : 0.97,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeIn,
          child: button,
        ),
        const Gap(16),
        ExcludeSemantics(
          child: AnimatedText(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: isConnected ? accent : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// 1.5px ring: a faint partial gradient when idle/connecting, a full slowly
/// shimmering accent gradient once connected.
class _HairlineRingPainter extends CustomPainter {
  _HairlineRingPainter({
    required this.rotation,
    required this.connected,
    required this.accent,
    required this.accent2,
  });

  final double rotation;
  final bool connected;
  final Color accent;
  final Color accent2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (connected) {
      paint.shader = SweepGradient(
        transform: GradientRotation(rotation),
        colors: [
          accent,
          accent2,
          Color.lerp(accent, Colors.white, 0.3)!,
          accent,
        ],
        stops: const [0.0, 0.39, 0.61, 1.0],
      ).createShader(rect);
    } else {
      paint.shader = SweepGradient(
        transform: const GradientRotation(3.665), // ~210deg
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0.36),
          accent2.withValues(alpha: 0.28),
          accent2.withValues(alpha: 0),
          accent.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.25, 0.55, 0.89, 1.0],
      ).createShader(rect);
    }
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _HairlineRingPainter old) {
    return old.rotation != rotation ||
        old.connected != connected ||
        old.accent != accent ||
        old.accent2 != accent2;
  }
}

/// Thin comet arc orbiting the ring while the tunnel is being established.
class _CometArcPainter extends CustomPainter {
  _CometArcPainter({
    required this.rotation,
    required this.accent,
    required this.accent2,
    required this.visible,
  });

  final double rotation;
  final Color accent;
  final Color accent2;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: GradientRotation(rotation),
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0),
          accent2.withValues(alpha: 0.55),
          accent,
          accent.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.69, 0.89, 0.983, 0.989],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _CometArcPainter old) {
    return old.rotation != rotation || old.visible != visible || old.accent != accent;
  }
}

/// Standby power glyph: open arc with a stem through the top gap.
class _PowerGlyphPainter extends CustomPainter {
  _PowerGlyphPainter({
    required this.color,
    required this.strokeWidth,
    this.glow,
  });

  final Color color;
  final double strokeWidth;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.42;
    final c = Offset(size.width / 2, size.height - r - strokeWidth);
    const gapHalf = 28.0 * math.pi / 180;
    const start = -math.pi / 2 + gapHalf;
    const sweep = 2 * math.pi - gapHalf * 2;
    final stemTop = Offset(c.dx, c.dy - r * 1.24);
    final stemBottom = Offset(c.dx, c.dy - r * 0.32);

    if (glow != null) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = glow!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, glowPaint);
      canvas.drawLine(stemTop, stemBottom, glowPaint);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, paint);
    canvas.drawLine(stemTop, stemBottom, paint);
  }

  @override
  bool shouldRepaint(covariant _PowerGlyphPainter old) {
    return old.color != color || old.strokeWidth != strokeWidth || old.glow != glow;
  }
}
