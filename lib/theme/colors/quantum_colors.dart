import 'package:flutter/material.dart';

/// Cyberpunk color palette for QuantumTrader Pro
class QuantumColors {
  // Base colors - very dark greys for backgrounds
  static const Color backgroundPrimary = Color(0xFF050509);
  static const Color backgroundSecondary = Color(0xFF0A0A0F);
  static const Color backgroundTertiary = Color(0xFF101018);
  static const Color surface = Color(0xFF1A1A24);
  static const Color surfaceElevated = Color(0xFF1F1F2C);

  // Neon accent colors
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonCyanDim = Color(0xFF00ACC1);
  static const Color neonMagenta = Color(0xFFD500F9);
  static const Color neonMagentaDim = Color(0xFF9C27B0);
  static const Color neonGreen = Color(0xFF00FF41);
  static const Color neonGreenDim = Color(0xFF00C853);
  
  // Status colors
  static const Color success = Color(0xFF00E676);
  static const Color successDim = Color(0xFF00A152);
  static const Color warning = Color(0xFFFF6F00);
  static const Color warningDim = Color(0xFFE65100);
  static const Color error = Color(0xFFFF1744);
  static const Color errorDim = Color(0xFFD50000);
  
  // Trading specific colors
  static const Color bullish = Color(0xFF00FF41);
  static const Color bearish = Color(0xFFFF1744);
  static const Color neutral = Color(0xFF757575);
  
  // Text colors
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textOnAccent = Color(0xFF000000);
  
  // Glow effects
  static const Color glowCyan = Color(0x6600E5FF);
  static const Color glowMagenta = Color(0x66D500F9);
  static const Color glowGreen = Color(0x6600FF41);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonCyan, neonCyanDim],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonMagenta, neonMagentaDim],
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundSecondary, backgroundPrimary],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, surfaceElevated],
  );
  
  // Bevel shadows for 3D effect
  static List<BoxShadow> bevelShadow = [
    BoxShadow(
      color: Colors.white.withOpacity(0.1),
      offset: const Offset(-1, -1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      offset: const Offset(2, 2),
      blurRadius: 3,
    ),
  ];
  
  static List<BoxShadow> innerBevelShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      offset: const Offset(1, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Colors.white.withOpacity(0.05),
      offset: const Offset(-1, -1),
      blurRadius: 3,
    ),
  ];
  
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.6),
      blurRadius: 12,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 24,
      spreadRadius: 4,
    ),
  ];
}