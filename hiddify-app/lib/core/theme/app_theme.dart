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
