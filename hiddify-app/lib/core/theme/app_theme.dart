import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    final ColorScheme scheme =
        lightColorScheme ??
        ColorScheme.fromSeed(
          seedColor: ConnectionButtonTheme.brandNavy,
        ).copyWith(
          primary: ConnectionButtonTheme.brandMintLight,
          secondary: ConnectionButtonTheme.brandBlueLight,
          surface: ConnectionButtonTheme.bgElevLight,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ConnectionButtonTheme.bgLight,
      fontFamily: fontFamily,
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: ConnectionButtonTheme.brandMintLight.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: ConnectionButtonTheme.brandMintLight),
        selectedLabelTextStyle: const TextStyle(
          color: ConnectionButtonTheme.brandMintLight,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: ConnectionButtonTheme.brandMintLight.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontWeight: FontWeight.w700, color: ConnectionButtonTheme.brandMintLight);
          }
          return null;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: ConnectionButtonTheme.brandMintLight.withValues(alpha: 0.12),
        thickness: 1,
        space: 1,
      ),
      switchTheme: _switchTheme(scheme, ConnectionButtonTheme.brandMintLight),
      inputDecorationTheme: _inputDecorationTheme(
        accent: ConnectionButtonTheme.brandMintLight,
        line: const Color(0x1A0F2837),
        fill: ConnectionButtonTheme.bgElevLight,
        muted: const Color(0xFF5D738A),
        danger: const Color(0xFFD93848),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ConnectionButtonTheme.brandMintLight,
        linearTrackColor: ConnectionButtonTheme.brandMintLight.withValues(alpha: 0.14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ConnectionButtonTheme.bgElevLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ConnectionButtonTheme.brandMintLight.withValues(alpha: 0.18)),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF102033),
          letterSpacing: -0.2,
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    final ColorScheme scheme =
        darkColorScheme ??
        ColorScheme.fromSeed(
          seedColor: ConnectionButtonTheme.brandNavy,
          brightness: Brightness.dark,
        ).copyWith(
          primary: ConnectionButtonTheme.brandMint,
          secondary: ConnectionButtonTheme.brandBlue,
          surface: const Color(0xFF0B1220),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mode.trueBlack ? Colors.black : const Color(0xFF06090F),
      fontFamily: fontFamily,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF0B1220),
        indicatorColor: ConnectionButtonTheme.brandMint.withValues(alpha: 0.16),
        selectedIconTheme: const IconThemeData(color: ConnectionButtonTheme.brandMint),
        selectedLabelTextStyle: const TextStyle(
          color: ConnectionButtonTheme.brandMint,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurface.withValues(alpha: 0.55)),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B1220),
        indicatorColor: ConnectionButtonTheme.brandMint.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontWeight: FontWeight.w700, color: ConnectionButtonTheme.brandMint);
          }
          return TextStyle(color: scheme.onSurface.withValues(alpha: 0.55));
        }),
      ),
      dividerTheme: DividerThemeData(
        color: ConnectionButtonTheme.brandMint.withValues(alpha: 0.14),
        thickness: 1,
        space: 1,
      ),
      switchTheme: _switchTheme(scheme, ConnectionButtonTheme.brandMint),
      inputDecorationTheme: _inputDecorationTheme(
        accent: ConnectionButtonTheme.brandMint,
        line: const Color(0x245EEAD0),
        fill: ConnectionButtonTheme.bgElevDark,
        muted: const Color(0xFF8AA0B8),
        danger: const Color(0xFFFF5D6C),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ConnectionButtonTheme.brandMint,
        linearTrackColor: ConnectionButtonTheme.brandMint.withValues(alpha: 0.14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ConnectionButtonTheme.bgElevDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ConnectionButtonTheme.brandMint.withValues(alpha: 0.18)),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEAF3FF),
          letterSpacing: -0.2,
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  /// Prototype `.form input`: bordered 10px box on the elevated surface,
  /// accent border + soft ring on focus.
  static InputDecorationTheme _inputDecorationTheme({
    required Color accent,
    required Color line,
    required Color fill,
    required Color muted,
    required Color danger,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: border(line),
      enabledBorder: border(line),
      focusedBorder: border(accent.withValues(alpha: 0.55), 1.4),
      errorBorder: border(danger.withValues(alpha: 0.55)),
      focusedErrorBorder: border(danger.withValues(alpha: 0.75), 1.4),
      hintStyle: TextStyle(color: muted, fontSize: 13),
      labelStyle: TextStyle(color: muted, fontSize: 13.5),
      floatingLabelStyle: TextStyle(color: accent),
    );
  }

  /// Tech-prototype toggle: accent track/thumb when on, muted when off.
  static SwitchThemeData _switchTheme(ColorScheme scheme, Color accent) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : scheme.onSurface.withValues(alpha: 0.7),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.32)
            : scheme.onSurface.withValues(alpha: 0.10),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accent.withValues(alpha: 0.55)
            : scheme.onSurface.withValues(alpha: 0.16),
      ),
    );
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    // final def = CupertinoThemeData(brightness: Brightness.dark);

    // return def;
    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
