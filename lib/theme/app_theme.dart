import 'package:flutter/material.dart';

class AppTheme {
  // VLC orange
  static const orange = Color(0xFFFF7A00);
  static const orangeDark = Color(0xFFD96400);
  static const background = Color(0xFF1A1A1A);
  static const surface = Color(0xFF2A2A2A);
  static const surfaceVariant = Color(0xFF363636);
  static const onBackground = Color(0xFFEEEEEE);
  static const onSurface = Color(0xFFCCCCCC);
  static const subtitle = Color(0xFF888888);
  static const divider = Color(0xFF3A3A3A);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: orange,
          secondary: orange,
          surface: surface,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: onBackground,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: onBackground,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: orange,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: orange.withValues(alpha: 0.15),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: orange);
            }
            return const IconThemeData(color: Colors.grey);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  color: orange, fontSize: 11, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: Colors.grey, fontSize: 11);
          }),
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          iconColor: onSurface,
          textColor: onBackground,
        ),
        dividerTheme: const DividerThemeData(
          color: divider,
          thickness: 0.5,
          space: 0,
        ),
        iconTheme: const IconThemeData(color: onSurface),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
              color: onBackground, fontSize: 18, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(
              color: onBackground, fontSize: 16, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(
              color: onBackground, fontSize: 14, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: onBackground, fontSize: 15),
          bodyMedium: TextStyle(color: onSurface, fontSize: 13),
          bodySmall: TextStyle(color: subtitle, fontSize: 12),
          labelLarge: TextStyle(
              color: orange, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: orange,
          thumbColor: orange,
          inactiveTrackColor: Colors.white24,
          overlayColor: Color(0x29FF7A00),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: surfaceVariant,
          textStyle: TextStyle(color: onBackground),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: surface,
          titleTextStyle: TextStyle(
              color: onBackground, fontSize: 18, fontWeight: FontWeight.w600),
          contentTextStyle: TextStyle(color: onSurface, fontSize: 14),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: subtitle),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return orange;
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return orange.withValues(alpha: 0.4);
            }
            return Colors.grey.withValues(alpha: 0.3);
          }),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: surfaceVariant,
          contentTextStyle: TextStyle(color: onBackground),
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: orange),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: orange,
          secondary: orange,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: false,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: orange,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: orange,
          thumbColor: orange,
        ),
      );
}
