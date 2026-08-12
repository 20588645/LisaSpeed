
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

/// Shared LisaSpeed Tech visual primitives aligned with the Tech prototype.
class TechUi {
  TechUi._();

  static Color delayColor(BuildContext context, int delayMs) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final accent2 = ConnectionButtonTheme.accent2Of(context);
    if (delayMs <= 0 || delayMs > 65000) return Theme.of(context).colorScheme.onSurfaceVariant;
    if (delayMs < 100) return accent;
    if (delayMs < 200) return accent2;
    if (delayMs < 400) return const Color(0xFFF0B429);
    return const Color(0xFFFF5D6C);
  }

  static Widget latencyPill(BuildContext context, int delayMs) {
    final color = delayColor(context, delayMs);
    final label = delayMs <= 0 || delayMs > 65000 ? '—' : '$delayMs ms';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static Widget tag(
    BuildContext context,
    String text, {
    bool active = false,
  }) {
    final color = active ? ConnectionButtonTheme.accentOf(context) : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget currentBadge(BuildContext context, [String label = '当前']) {
    return tag(context, label, active: true);
  }

  static BoxDecoration panelDecoration(BuildContext context, {bool selected = false}) {
    final accent = ConnectionButtonTheme.accentOf(context);
    return BoxDecoration(
      color: ConnectionButtonTheme.panelOf(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: selected ? accent.withValues(alpha: 0.65) : ConnectionButtonTheme.lineOf(context),
      ),
    );
  }

  /// Prototype `.main` atmosphere: soft radial washes + faint grid (no world map).
  static Widget pageShell({required BuildContext context, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ConnectionButtonTheme.accentOf(context);
    final accent2 = ConnectionButtonTheme.accent2Of(context);
    final bg = isDark ? ConnectionButtonTheme.bgDark : ConnectionButtonTheme.bgLight;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: bg),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.55, -1.05),
              radius: 1.15,
              colors: [
                accent2.withValues(alpha: isDark ? 0.16 : 0.12),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.85, -1.0),
              radius: 0.95,
              colors: [
                accent.withValues(alpha: isDark ? 0.12 : 0.10),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: isDark ? 0.05 : 0.04),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35],
            ),
          ),
        ),
        CustomPaint(
          painter: _TechGridPainter(color: accent.withValues(alpha: isDark ? 0.045 : 0.06)),
        ),
        child,
      ],
    );
  }

  static Widget logoMark({double size = 42}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ConnectionButtonTheme.brandBlue, ConnectionButtonTheme.brandMint],
        ),
      ),
      child: Text(
        'L',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
          height: 1,
        ),
      ),
    );
  }

  static Widget hubCard(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    Widget? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final accent = ConnectionButtonTheme.accentOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: panelDecoration(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          DefaultTextStyle(
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            child: subtitle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget preferencePanel(BuildContext context, {required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          decoration: panelDecoration(context),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  static Widget pageIntro(
    BuildContext context, {
    required String eyebrow,
    required String title,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  static Widget sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TechGridPainter extends CustomPainter {
  _TechGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TechGridPainter oldDelegate) => oldDelegate.color != color;
}
