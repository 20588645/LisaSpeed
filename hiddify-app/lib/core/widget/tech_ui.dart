import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

/// Shared LisaSpeed Tech visual primitives aligned with the Tech prototype.
class TechUi {
  TechUi._();

  /// One gutter for every top-level page header and body. Extra wrapping
  /// padding on some pages used to shift titles by 8–28px and made tab
  /// switches flash.
  static const double pageInset = 20;
  static const double pageIntroTop = 8;
  static const double pageIntroBottom = 4;
  static const double pageBodyTop = 8;
  static const double pageBodyBottom = 24;
  static const EdgeInsets pageIntroPadding = EdgeInsets.fromLTRB(pageInset, pageIntroTop, pageInset, pageIntroBottom);
  static const EdgeInsets pageBodyPadding = EdgeInsets.fromLTRB(pageInset, pageBodyTop, pageInset, pageBodyBottom);

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

  /// Prototype `--warn` (dark f0b429 / light c98500).
  static Color warnOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF0B429) : const Color(0xFFC98500);

  static Color delayColor(BuildContext context, int delayMs) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final accent2 = ConnectionButtonTheme.accent2Of(context);
    if (delayMs <= 0 || delayMs > 65000) return Theme.of(context).colorScheme.onSurfaceVariant;
    if (delayMs < 100) return accent;
    if (delayMs < 200) return accent2;
    if (delayMs < 400) return warnOf(context);
    return dangerOf(context);
  }

  static Widget latencyPill(BuildContext context, int delayMs, {String? emptyLabel, String? suffix}) {
    final color = delayColor(context, delayMs);
    final base = delayMs <= 0 || delayMs >= 65000 ? (emptyLabel ?? '—') : '$delayMs ms';
    final label = suffix == null || suffix.isEmpty ? base : '$base · $suffix';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
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
            style: mono(context, size: 12, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  /// Compact inline label next to titles (e.g. 使用中 / 本地). Not paired
  /// with action buttons — those use [statusChip] so height matches 36px.
  static Widget tag(BuildContext context, String text, {bool active = false, bool monoFont = false}) {
    final color = active ? ConnectionButtonTheme.accentOf(context) : Theme.of(context).colorScheme.onSurfaceVariant;
    final base = Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700);
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
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
      child: Text(text, style: mono(context, size: 11, color: accent)),
    );
  }

  /// One control size for every text / icon / dialog button.
  /// Material's default 48px tap target is opted out so visual height stays 36.
  static const double buttonHeight = 36;
  static const double buttonRadius = 11;
  static const double buttonFontSize = 13.5;
  static const double buttonIconSize = 18;
  static const Size buttonMinSize = Size(0, buttonHeight);
  static const Size buttonMaxSize = Size(double.infinity, buttonHeight);
  static const Size iconButtonSize = Size(buttonHeight, buttonHeight);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 12);
  static const double actionGap = 8;
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(14, 12, 14, 12);
  static const OutlinedBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(buttonRadius)),
  );

  /// Status control sitting beside [iconButton] / [tinyButton]: same 36×11
  /// box so 直连 / 空闲 no longer look like a tiny caption glued to a button.
  static Widget statusChip(BuildContext context, String text, {bool active = false, Color? color}) {
    final resolved =
        color ?? (active ? ConnectionButtonTheme.accentOf(context) : Theme.of(context).colorScheme.onSurfaceVariant);
    final side = active ? resolved.withValues(alpha: 0.55) : ConnectionButtonTheme.lineOf(context);
    return Container(
      height: buttonHeight,
      padding: buttonPadding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: active ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(buttonRadius),
        border: Border.all(color: side),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.w700, height: 1.1, color: resolved),
      ),
    );
  }

  /// Horizontal trailing cluster: status + actions, 8px gutters, no wrap.
  static Widget trailingRow(List<Widget> children) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(width: actionGap), child],
      ],
    );
  }

  /// Shared size lock used by [ghostButton], [primaryButton], [tinyButton]
  /// and theme-level Material buttons so nothing can drift to 27 / 32 / 48.
  static ButtonStyle lockButtonSize({
    FontWeight weight = FontWeight.w500,
    EdgeInsetsGeometry padding = buttonPadding,
    Size minimumSize = buttonMinSize,
    Size maximumSize = buttonMaxSize,
  }) {
    return ButtonStyle(
      padding: WidgetStatePropertyAll(padding),
      minimumSize: WidgetStatePropertyAll(minimumSize),
      maximumSize: WidgetStatePropertyAll(maximumSize),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      alignment: Alignment.center,
      shape: const WidgetStatePropertyAll(buttonShape),
      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: buttonFontSize, fontWeight: weight, height: 1.1)),
    );
  }

  static ButtonStyle outlinedStyle(BuildContext context, {bool danger = false, Color? background}) {
    final fg = danger ? dangerOf(context) : Theme.of(context).colorScheme.onSurface;
    final side = danger
        ? Color.lerp(dangerOf(context), ConnectionButtonTheme.lineOf(context), 0.6)!
        : ConnectionButtonTheme.lineOf(context);
    return OutlinedButton.styleFrom(
      foregroundColor: fg,
      side: BorderSide(color: side),
      backgroundColor: background ?? Colors.transparent,
      disabledForegroundColor: fg.withValues(alpha: 0.38),
    ).merge(lockButtonSize());
  }

  static ButtonStyle filledStyle(BuildContext context) {
    final accent = ConnectionButtonTheme.accentOf(context);
    return FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: const Color(0xFF041016),
      disabledBackgroundColor: accent.withValues(alpha: 0.4),
      disabledForegroundColor: const Color(0xFF041016).withValues(alpha: 0.55),
    ).merge(lockButtonSize(weight: FontWeight.w700));
  }

  static ButtonStyle textStyle(BuildContext context, {bool danger = false}) {
    final fg = danger ? dangerOf(context) : Theme.of(context).colorScheme.onSurfaceVariant;
    return TextButton.styleFrom(foregroundColor: fg).merge(lockButtonSize());
  }

  static ButtonStyle iconStyle(BuildContext context, {bool danger = false}) {
    return outlinedStyle(
      context,
      danger: danger,
    ).merge(lockButtonSize(padding: EdgeInsets.zero, minimumSize: iconButtonSize, maximumSize: iconButtonSize));
  }

  /// Theme defaults so raw [TextButton] / [FilledButton] / [OutlinedButton]
  /// in dialogs match [ghostButton] / [primaryButton].
  static OutlinedButtonThemeData outlinedButtonTheme(ColorScheme scheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
      ).merge(lockButtonSize()),
    );
  }

  static FilledButtonThemeData filledButtonTheme(Color accent) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: const Color(0xFF041016),
        disabledBackgroundColor: accent.withValues(alpha: 0.4),
      ).merge(lockButtonSize(weight: FontWeight.w700)),
    );
  }

  static ElevatedButtonThemeData elevatedButtonTheme(Color accent) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: const Color(0xFF041016),
        elevation: 0,
        shadowColor: Colors.transparent,
      ).merge(lockButtonSize(weight: FontWeight.w700)),
    );
  }

  static TextButtonThemeData textButtonTheme(ColorScheme scheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant).merge(lockButtonSize()),
    );
  }

  static IconButtonThemeData iconButtonTheme(ColorScheme scheme) {
    return IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        iconSize: buttonIconSize,
        padding: EdgeInsets.zero,
        minimumSize: iconButtonSize,
        maximumSize: iconButtonSize,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        shape: buttonShape,
      ),
    );
  }

  /// Prototype `.btn.ghost`: transparent, hairline border, 11px radius.
  static Widget ghostButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    bool danger = false,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: outlinedStyle(context, danger: danger),
      child: Text(label),
    );
  }

  /// Prototype `.btn.primary`: accent fill, dark ink text, soft glow.
  static Widget primaryButton(BuildContext context, {required String label, VoidCallback? onPressed}) {
    final accent = ConnectionButtonTheme.accentOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(buttonRadius),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 20)],
      ),
      child: FilledButton(onPressed: onPressed, style: filledStyle(context), child: Text(label)),
    );
  }

  /// Row action button — same 36×11 metrics as [ghostButton], panel fill so
  /// it stays readable on list rows. Formerly a smaller 27px control.
  static Widget tinyButton(
    BuildContext context, {
    required String label,
    VoidCallback? onPressed,
    bool danger = false,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: outlinedStyle(context, danger: danger, background: ConnectionButtonTheme.panelOf(context)),
      child: Text(label),
    );
  }

  /// Square icon control, same 36px box and 11px radius as text buttons.
  static Widget iconButton(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip,
    Color? iconColor,
  }) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: iconStyle(context),
      child: Icon(icon, size: buttonIconSize, color: iconColor ?? Theme.of(context).colorScheme.onSurface),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  /// Prototype sub-page `.page-head`: back icon-btn + eyebrow/title/subtitle
  /// on the left, action buttons on the right.
  static Widget subPageHeader(
    BuildContext context, {
    String? eyebrow,
    required String title,
    String? subtitle,
    VoidCallback? onBack,
    List<Widget> actions = const [],
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(pageInset, 16, pageInset, 12),
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
                if (eyebrow != null && eyebrow.isNotEmpty) ...[
                  Text(
                    eyebrow.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
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
    double height = buttonHeight,
    double fontSize = buttonFontSize,
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
              borderRadius: BorderRadius.circular(TechUi.buttonRadius),
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
                        // Prototype `.seg`: active button bold (700), rest lighter.
                        fontWeight: option == selected ? FontWeight.w700 : FontWeight.w500,
                        color: option == selected ? const Color(0xFF041016) : Theme.of(context).colorScheme.onSurface,
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  /// Prototype `.panel` / `.setting-card` shell (16px radius). List rows use
  /// the tighter 14px `.list-row` radius via [listRow].
  static BoxDecoration panelDecoration(BuildContext context, {bool selected = false, double radius = 16}) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: ConnectionButtonTheme.glassOf(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: selected ? accent : ConnectionButtonTheme.lineOf(context)),
      // Prototype `.panel` soft depth (`--shadow`). List rows (radius < 16)
      // stay flat, matching the prototype's shadowless `.list-row`.
      boxShadow: radius >= 16
          ? [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.28) : const Color(0xFF102033).withValues(alpha: 0.08),
                blurRadius: isDark ? 28 : 24,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    );
  }

  /// Prototype `.list-row`: glass fill, hairline border, 14px radius.
  /// Active rows use a full-accent border only — no inset color stripe.
  static Widget listRow(
    BuildContext context, {
    required Widget child,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(14, 13, 14, 13),
  }) {
    final accent = ConnectionButtonTheme.accentOf(context);
    return _HoverRegion(
      builder: (hovered) => Container(
        decoration: panelDecoration(context, selected: selected, radius: 14).copyWith(
          border: Border.all(
            color: selected
                ? accent
                : hovered
                ? accent.withValues(alpha: 0.28)
                : ConnectionButtonTheme.lineOf(context),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(padding: padding, child: child),
          ),
        ),
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
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.42, height: 1),
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
    return _HoverRegion(
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        // Prototype `.setting-card:hover`: accent border, soft glow, 1px lift.
        transform: Matrix4.translationValues(0, hovered ? -1 : 0, 0),
        decoration: panelDecoration(context).copyWith(
          border: Border.all(color: hovered ? accent : ConnectionButtonTheme.lineOf(context)),
          boxShadow: hovered ? [BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 24)] : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
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
                            style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            child: subtitle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('›', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 20, height: 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Prototype `.form.panel.form-card`: one glass panel, 12px row rhythm.
  static Widget preferencePanel(BuildContext context, {required List<Widget> children}) {
    return ListView(
      padding: pageBodyPadding,
      children: [
        Container(
          decoration: panelDecoration(context),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(height: 10), child],
            ],
          ),
        ),
      ],
    );
  }

  static Widget pageIntro(
    BuildContext context, {
    String? eyebrow,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null && eyebrow.isNotEmpty) ...[
          Text(
            eyebrow.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
        ],
        Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
    return Padding(
      padding: pageIntroPadding,
      child: action == null
          ? copy
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 12),
                Padding(padding: const EdgeInsets.only(top: 18), child: action),
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

/// Tracks pointer hover so cards and rows can show a desktop hover state
/// (accent border / glow / lift), matching the prototype's `:hover` rules.
class _HoverRegion extends StatefulWidget {
  const _HoverRegion({required this.builder});

  final Widget Function(bool hovered) builder;

  @override
  State<_HoverRegion> createState() => _HoverRegionState();
}

class _HoverRegionState extends State<_HoverRegion> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
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
