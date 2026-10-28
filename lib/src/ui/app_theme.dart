import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const electricBlue = Color(0xff087ff5);
  static const cyan = Color(0xff00c8ff);
  static const orange = Color(0xffff9f43);

  static ThemeData dark() => _theme(Brightness.dark);
  static ThemeData light() => _theme(Brightness.light);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: electricBlue,
      brightness: brightness,
      surface: dark ? const Color(0xff101f30) : const Color(0xfff5f8fc),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xff07111f) : const Color(0xffeaf0f7),
      cardColor: dark ? const Color(0xff101f30) : Colors.white,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: dark ? const Color(0xff07111f) : null,
        foregroundColor: dark ? Colors.white : null,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xff0b1827) : Colors.white,
        indicatorColor: electricBlue.withValues(alpha: 0.2),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xff0d1a29) : Colors.white,
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xff122235) : const Color(0xfff2f6fb),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
