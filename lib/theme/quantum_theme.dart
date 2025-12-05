import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors/quantum_colors.dart';

class QuantumTheme {
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: QuantumColors.neonCyan,
        secondary: QuantumColors.neonMagenta,
        tertiary: QuantumColors.neonGreen,
        surface: QuantumColors.surface,
        surfaceContainerHighest: QuantumColors.surfaceElevated,
        error: QuantumColors.error,
        onPrimary: QuantumColors.textOnAccent,
        onSecondary: QuantumColors.textOnAccent,
        onSurface: QuantumColors.textPrimary,
        onError: QuantumColors.textPrimary,
      ),

      // Scaffold background
      scaffoldBackgroundColor: QuantumColors.backgroundPrimary,

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: QuantumColors.backgroundSecondary,
        foregroundColor: QuantumColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: QuantumColors.textPrimary,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: QuantumColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Typography
      textTheme: _buildTextTheme(),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: QuantumColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: QuantumColors.neonCyan.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: QuantumColors.neonCyan.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: QuantumColors.neonCyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: QuantumColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: QuantumColors.textTertiary),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: QuantumColors.neonCyan,
          foregroundColor: QuantumColors.textOnAccent,
          minimumSize: const Size(120, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: QuantumColors.neonCyan,
          side: const BorderSide(color: QuantumColors.neonCyan, width: 2),
          minimumSize: const Size(120, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: QuantumColors.textSecondary,
        size: 24,
      ),

      // Bottom navigation theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: QuantumColors.backgroundSecondary,
        selectedItemColor: QuantumColors.neonCyan,
        unselectedItemColor: QuantumColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: QuantumColors.neonCyan,
        inactiveTrackColor: QuantumColors.neonCyan.withOpacity(0.3),
        thumbColor: QuantumColors.neonCyan,
        overlayColor: QuantumColors.glowCyan,
        valueIndicatorColor: QuantumColors.neonCyan,
        valueIndicatorTextStyle: GoogleFonts.orbitron(
          color: QuantumColors.textOnAccent,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        trackHeight: 6,
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return QuantumColors.neonCyan;
          }
          return QuantumColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return QuantumColors.neonCyan.withOpacity(0.5);
          }
          return QuantumColors.textTertiary.withOpacity(0.3);
        }),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: QuantumColors.surface,
        selectedColor: QuantumColors.neonCyan,
        secondarySelectedColor: QuantumColors.neonMagenta,
        labelStyle: GoogleFonts.orbitron(
          color: QuantumColors.textSecondary,
          fontSize: 14,
        ),
        secondaryLabelStyle: GoogleFonts.orbitron(
          color: QuantumColors.textOnAccent,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: QuantumColors.neonCyan.withOpacity(0.3)),
        ),
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: QuantumColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.orbitron(
          color: QuantumColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: QuantumColors.neonCyan.withOpacity(0.2),
        thickness: 1,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.orbitron(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: QuantumColors.textPrimary,
        letterSpacing: 1.2,
      ),
      displayMedium: GoogleFonts.orbitron(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: QuantumColors.textPrimary,
        letterSpacing: 1.0,
      ),
      displaySmall: GoogleFonts.orbitron(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: QuantumColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.rajdhani(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: QuantumColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.rajdhani(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: QuantumColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: QuantumColors.textPrimary,
      ),
      titleLarge: GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: QuantumColors.textPrimary,
      ),
      titleMedium: GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: QuantumColors.textPrimary,
      ),
      titleSmall: GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: QuantumColors.textSecondary,
      ),
      bodyLarge: GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: QuantumColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: QuantumColors.textPrimary,
      ),
      bodySmall: GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: QuantumColors.textSecondary,
      ),
      labelLarge: GoogleFonts.orbitron(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: QuantumColors.textPrimary,
        letterSpacing: 1.2,
      ),
      labelMedium: GoogleFonts.orbitron(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: QuantumColors.textSecondary,
        letterSpacing: 1.0,
      ),
      labelSmall: GoogleFonts.orbitron(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: QuantumColors.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}