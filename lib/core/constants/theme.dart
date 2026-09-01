import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0B141A);
  static const Color surface = Color(0xFF1F2C34);
  static const Color surfaceLight = Color(0xFF202C33);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F2F5);

  static const Color primary = Color(0xFF00A884);
  static const Color primaryLight = Color(0xFF25D366);
  static const Color secondary = Color(0xFF53BDEB);

  static const Color textPrimary = Color(0xFFE9EDEF);
  static const Color textSecondary = Color(0xFF8696A0);
  static const Color textMuted = Color(0xFF667781);

  static const Color lightTextPrimary = Color(0xFF111B21);
  static const Color lightTextSecondary = Color(0xFF667781);
  static const Color lightTextMuted = Color(0xFF8696A0);

  static const Color success = Color(0xFF00A884);
  static const Color error = Color(0xFFEA0038);
  static const Color warning = Color(0xFFFFD600);

  static const Color sentBubble = Color(0xFF005C4B);
  static const Color sentBubbleLight = Color(0xFFD9FDD3);
  static const Color receivedBubble = Color(0xFF202C33);
  static const Color receivedBubbleLight = Color(0xFFFFFFFF);
  static const Color chatBackground = Color(0xFF0B141A);
  static const Color chatBackgroundLight = Color(0xFFECE5DD);
  static const Color appBar = Color(0xFF1F2C34);
  static const Color appBarLight = Color(0xFF008069);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00A884), Color(0xFF008069)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF0B141A), Color(0xFF0B141A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF0F2F5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x20FFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBarLight,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: const TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        hintStyle: const TextStyle(color: AppColors.lightTextMuted),
        labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1A000000)),
    );
  }

  static ThemeData get darkTheme {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBar,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A3942)),
    );
  }
}

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  LinearGradient get scaffoldGradient =>
      isDarkMode ? AppColors.darkBackgroundGradient : AppColors.lightBackgroundGradient;

  Color get surfaceColor =>
      isDarkMode ? AppColors.surface : AppColors.lightSurface;

  Color get textPrimaryColor =>
      isDarkMode ? AppColors.textPrimary : AppColors.lightTextPrimary;

  Color get textSecondaryColor =>
      isDarkMode ? AppColors.textSecondary : AppColors.lightTextSecondary;

  Color get textMutedColor =>
      isDarkMode ? AppColors.textMuted : AppColors.lightTextMuted;

  Color get cardColor =>
      isDarkMode ? AppColors.background : AppColors.lightSurface;

  Color get inputFillColor =>
      isDarkMode ? AppColors.surfaceLight : AppColors.lightSurfaceVariant;

  Color get borderColor =>
      isDarkMode ? const Color(0xFF2A3942) : const Color(0x1A000000);

  Color get chatBackground =>
      isDarkMode ? AppColors.chatBackground : AppColors.chatBackgroundLight;

  Color get sentBubbleColor =>
      isDarkMode ? AppColors.sentBubble : AppColors.sentBubbleLight;

  Color get receivedBubbleColor =>
      isDarkMode ? AppColors.receivedBubble : AppColors.receivedBubbleLight;

  Color get appBarColor =>
      isDarkMode ? AppColors.appBar : AppColors.appBarLight;
}
