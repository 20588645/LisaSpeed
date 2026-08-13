
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

/// Shared LisaSpeed Tech visual primitives aligned with the Tech prototype.
class TechUi {
  TechUi._();

  /// Prototype `--mono` stack ("JetBrains Mono", ui-monospace, Menlo…).
  static TextStyle mono(
    BuildContext context, {
    double size = 13,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['JetBrains Mono', 'SF Mono', 'Consolas', 'monospace'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static Color dangerOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF5D6C) : const Color(0xFFD93848);

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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
          Text(label, style: mono(context, size: 12, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  static Widget tag(
    BuildContext context,
    String text, {
    bool active = false,
    bool monoFont = false,
  }) {
    final color = active ? ConnectionButtonTheme.accentOf(context) : Theme.of(context).colorScheme.onSurfaceVariant;
    final base = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
    );
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
        style: monoFont ? mono(context, size: 11, weight: FontWeight.w600, color: color, letterSpacing: 0.2) : base,
      ),
    );
  }

  /// Prototype `.count-chip`: mono accent counter.
  static Widget countChip(BuildContext context, String text) {
    final accent = ConnectionButtonTheme.accentOf(context);
    return Container(
      height: 22,
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: mono(context, size: 11, color: accent)),
    );
  }

  /// Prototype `.btn.ghost`: transparent, hairline border, 11px radius.
  static Widget ghostButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    bool danger = false,
  }) {
    final fg = danger ? dangerOf(context) : Theme.of(context).colorScheme.onSurface;
    final side = danger
        ? Color.lerp(dangerOf(context), ConnectionButtonTheme.lineOf(context), 0.6)!
        : ConnectionButtonTheme.lineOf(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: side),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }

  /// Prototype `.btn.primary`: accent fill, dark ink text, soft glow.
  static Widget primaryButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
  }) {
    final accent = ConnectionButtonTheme.accentOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 20)],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF041016),
          disabledBackgroundColor: accent.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }

  /// Prototype `.btn.tiny`: compact bordered action (list rows).
  static Widget tinyButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    bool danger = false,
  }) {
    final fg = danger ? dangerOf(context) : Theme.of(context).colorScheme.onSurface;
    final side = danger
        ? Color.lerp(dangerOf(context), ConnectionButtonTheme.lineOf(context), 0.6)!
        : ConnectionButtonTheme.lineOf(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: side),
        backgroundColor: ConnectionButtonTheme.panelOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        minimumSize: const Size(0, 27),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }

  /// Prototype `.btn.icon-btn`: 36px bordered square (back arrows…).
  static Widget iconButton(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    final button = SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: ConnectionButtonTheme.lineOf(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  /// Prototype sub-page `.page-head`: back icon-btn + eyebrow/title/subtitle
  /// on the left, action buttons on the right.
  static Widget subPageHeader(
    BuildContext context, {
    required String eyebrow,
    required String title,
    String? subtitle,
    VoidCallback? onBack,
    List<Widget> actions = const [],
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            iconButton(context, icon: Icons.arrow_back_rounded, onPressed: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
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
          ),
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(width: 8) else const SizedBox(width: 16),
            action,
          ],
        ],
      ),
    );
  }

  /// Prototype `.seg`: detached rounded buttons with 6px gutters; the active
  /// one fills with accent and dark ink text.
  static Widget seg<T>(
    BuildContext context, {
    required List<T> options,
    required T selected,
    required String Function(T option) label,
    required ValueChanged<T> onChanged,
    double height = 38,
    double fontSize = 12.5,
  }) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        for (final (i, option) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Material(
              color: option == selected ? accent : muted.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                hoverColor: option == selected ? null : accent.withValues(alpha: 0.12),
                onTap: () => onChanged(option),
                child: SizedBox(
                  height: height,
                  child: Center(
                    child: Text(
                      label(option),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: option == selected
                            ? const Color(0xFF041016)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Prototype `.form-section-title`: accent tick + uppercase label.
  static Widget formSectionTitle(BuildContext context, String text, {bool first = false}) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final accent2 = ConnectionButtonTheme.accent2Of(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? 2 : 12, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, accent2],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static BoxDecoration formRowDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final elev = isDark ? ConnectionButtonTheme.bgElevDark : ConnectionButtonTheme.bgElevLight;
    return BoxDecoration(
      border: Border.all(color: ConnectionButtonTheme.lineOf(context)),
      borderRadius: BorderRadius.circular(10),
      color: elev.withValues(alpha: 0.7),
    );
  }

  /// Prototype `.check.switch`: bordered row, label left, small toggle right.
  static Widget formSwitchRow(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return Container(
      decoration: formRowDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.8,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
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

  /// Prototype `.setting-card`: numbered chip + title/desc + chevron (no icon).
  static Widget hubCard(
    BuildContext context, {
    required int index,
    required String title,
    Widget? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final accent = ConnectionButtonTheme.accentOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: panelDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    style: mono(context, size: 11, weight: FontWeight.w600, color: accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        DefaultTextStyle(
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: subtitle,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '›',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 20,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Prototype `.form.panel.form-card`: one glass panel, 12px row rhythm.
  static Widget preferencePanel(BuildContext context, {required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Container(
          decoration: panelDecoration(context),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                child,
              ],
            ],
          ),
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
