import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

/// Shared LisaSpeed Tech dialog chrome — matches `prototype/tech` `.modal-card`.
class TechDialog extends StatelessWidget {
  const TechDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.icon,
    this.iconWidget,
    required this.content,
    this.actions,
    this.width = 440,
    this.maxHeight,
    this.showClose = false,
    this.onClose,
    this.scrollable = true,
  });

  /// Drop-in for Material [AlertDialog] call sites (`title`/`icon` as widgets).
  factory TechDialog.alert({
    Key? key,
    Widget? title,
    Widget? content,
    List<Widget>? actions,
    Widget? icon,
    double width = 560,
    bool scrollable = false,
  }) {
    return TechDialog(
      key: key,
      titleWidget: title,
      iconWidget: icon,
      content: content ?? const SizedBox.shrink(),
      actions: actions,
      width: width,
      scrollable: scrollable,
    );
  }

  final String? title;
  final Widget? titleWidget;
  final IconData? icon;
  final Widget? iconWidget;
  final Widget content;
  final List<Widget>? actions;
  final double width;
  final double? maxHeight;
  final bool showClose;
  final VoidCallback? onClose;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ConnectionButtonTheme.accentOf(context);
    final line = ConnectionButtonTheme.lineOf(context);
    final elev = theme.brightness == Brightness.dark
        ? ConnectionButtonTheme.bgElevDark
        : ConnectionButtonTheme.bgElevLight;

    final resolvedTitle = titleWidget ??
        (title == null
            ? null
            : Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ));
    final resolvedIcon = iconWidget ??
        (icon == null ? null : Icon(icon, size: 20, color: accent));

    final body = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: content,
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: content,
          );

    final hasHeader = resolvedTitle != null || resolvedIcon != null || showClose;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 280,
          maxWidth: width,
          maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Material(
          color: elev,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasHeader)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: line)),
                  ),
                  child: Row(
                    children: [
                      if (resolvedIcon != null) ...[
                        IconTheme.merge(
                          data: IconThemeData(color: accent, size: 20),
                          child: resolvedIcon,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          child: resolvedTitle ?? const SizedBox.shrink(),
                        ),
                      ),
                      if (showClose)
                        IconButton(
                          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                          onPressed: onClose ?? () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              Flexible(child: body),
              if (actions != null && actions!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: line)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Consistent action buttons for [TechDialog].
class TechDialogActions {
  TechDialogActions._();

  static ButtonStyle ghost(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }

  static ButtonStyle primary(BuildContext context) {
    final accent = ConnectionButtonTheme.accentOf(context);
    return FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: const Color(0xFF041016),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    );
  }

  static Widget cancel(BuildContext context, {VoidCallback? onPressed, String? label}) {
    return TextButton(
      style: ghost(context),
      onPressed: onPressed,
      child: Text(label ?? MaterialLocalizations.of(context).cancelButtonLabel),
    );
  }

  static Widget ok(BuildContext context, {VoidCallback? onPressed, String? label}) {
    return FilledButton(
      style: primary(context),
      onPressed: onPressed,
      child: Text(label ?? MaterialLocalizations.of(context).okButtonLabel),
    );
  }

  static Widget text(BuildContext context, {required String label, VoidCallback? onPressed}) {
    return TextButton(
      style: ghost(context),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
