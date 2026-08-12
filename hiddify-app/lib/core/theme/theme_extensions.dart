import 'package:flutter/material.dart';

/// LisaSpeed Tech colors aligned with `prototype/tech/css/tokens.css`.
class ConnectionButtonTheme extends ThemeExtension<ConnectionButtonTheme> {
  const ConnectionButtonTheme({this.idleColor, this.connectedColor});

  final Color? idleColor;
  final Color? connectedColor;

  /// Dark-scheme accent (mint).
  static const Color brandMint = Color(0xFF2EE6C5);

  /// Light-scheme accent (teal).
  static const Color brandMintLight = Color(0xFF0C9A84);

  static const Color brandMintSoft = Color(0xFF7DFFD2);
  static const Color brandBlue = Color(0xFF4D93FF);
  static const Color brandBlueLight = Color(0xFF2F6FED);
  static const Color brandNavy = Color(0xFF0B3D5C);

  static const Color bgDark = Color(0xFF06090F);
  static const Color bgElevDark = Color(0xFF0B1220);
  static const Color bgLight = Color(0xFFF3F7FB);
  static const Color bgElevLight = Color(0xFFFFFFFF);

  static Color accentOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? brandMint : brandMintLight;

  static Color accent2Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? brandBlue : brandBlueLight;

  static Color lineOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0x245EEAD0) : const Color(0x1A0F2837);
  }

  static Color panelOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF111C2C) : Colors.white;
  }

  static const ConnectionButtonTheme light = ConnectionButtonTheme(
    idleColor: brandNavy,
    connectedColor: brandMint,
  );

  @override
  ThemeExtension<ConnectionButtonTheme> copyWith({Color? idleColor, Color? connectedColor}) =>
      ConnectionButtonTheme(
        idleColor: idleColor ?? this.idleColor,
        connectedColor: connectedColor ?? this.connectedColor,
      );

  @override
  ThemeExtension<ConnectionButtonTheme> lerp(covariant ThemeExtension<ConnectionButtonTheme>? other, double t) {
    if (other is! ConnectionButtonTheme) {
      return this;
    }
    return ConnectionButtonTheme(
      idleColor: Color.lerp(idleColor, other.idleColor, t),
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t),
    );
  }
}
