import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LiquidGlassTheme {
  // Colors - Liquid Glass Palette
  static const Color iceBlue = Color(0xFFCAF0F8); // Background (Light Mode)
  static const Color deepMidnightNavy = Color(0xFF03045E); // Primary Text
  static const Color mediumBlue = Color(0xFF0077B6); // Secondary Text
  static const Color coralPeach = Color(0xFFFF7054); // High-Energy Highlights
  static const Color deepNativeBlue = Color(0xFF0077B6); // Action & Accent Color
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Semi-transparent variations for glass effect
  static const Color glassBackgroundLight = Color(0x33FFFFFF); // 20% white
  static const Color glassBackgroundDark = Color(0x33000000); // 20% black
  static const Color glassBorderLight = Color(0x66FFFFFF); // 40% white
  static const Color glassBorderDark = Color(0x66000000); // 40% black

  // Glassmorphism configuration
  static const double glassBlurSigmaX = 10.0;
  static const double glassBlurSigmaY = 10.0;
  static const double glassBorderWidth = 1.0;

  // Squircles - Using BorderRadius for smooth continuous curves
  static const double smallRadius = 12.0;
  static const double mediumRadius = 16.0;
  static const double largeRadius = 20.0;
  static const double extraLargeRadius = 24.0;

  static GlassmorphismConfig glassmorphismConfig(bool isDark) => GlassmorphismConfig(
        blurSigmaX: glassBlurSigmaX,
        blurSigmaY: glassBlurSigmaY,
        borderWidth: glassBorderWidth,
        backgroundColor: isDark ? glassBackgroundDark : glassBackgroundLight,
        borderColor: isDark ? glassBorderDark : glassBorderLight,
      );

  static ThemeData get lightTheme {
    final baseTextTheme = Typography.material2021().black;

    // TextTheme with San Francisco-like font (using Inter as closest alternative)
    final TextTheme textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        height: 56 / 48,
        letterSpacing: -0.02 * 48,
        color: deepMidnightNavy,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 40 / 32,
        color: deepMidnightNavy,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 32 / 24,
        color: deepMidnightNavy,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: deepMidnightNavy,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
        color: deepMidnightNavy,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: deepMidnightNavy,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: deepMidnightNavy,
      ),
      labelLarge: GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: deepMidnightNavy,
      ),
      labelMedium: GoogleFonts.spaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
        color: deepMidnightNavy,
      ),
      labelSmall: GoogleFonts.spaceMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: deepMidnightNavy,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: iceBlue,
      // Extended color scheme for Material 3
      colorScheme: ColorScheme.light(
        brightness: Brightness.light,
        primary: deepNativeBlue,
        onPrimary: white,
        secondary: mediumBlue,
        onSecondary: white,
        surface: white,                  // Opaque white for dialogs & cards
        onSurface: deepMidnightNavy,
        surfaceVariant: Color(0xFFE8F4FD), // Subtle light blue tint
        onSurfaceVariant: Color(0xFF4A5568),
        background: iceBlue,
        onBackground: deepMidnightNavy,
        error: Colors.redAccent,
        onError: white,
        outline: Color(0xFFB0C4D8),
        outlineVariant: Color(0xFFD0E4F0),
      ),

      // Text theme
      textTheme: textTheme,

      // Custom configurations
      extensions: <ThemeExtension<dynamic>>[
        GlassmorphismExtension(
          config: glassmorphismConfig(false),
          smallRadius: smallRadius,
          mediumRadius: mediumRadius,
          largeRadius: largeRadius,
          extraLargeRadius: extraLargeRadius,
        ),
      ],

      // Ensure dialogs always have solid background (surface is set to white above)
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 12,
      ),
      dialogBackgroundColor: white,

      // SnackBar always visible with floating behavior
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1C2430),
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = Typography.material2021().white;

    // For dark mode, we'll use a very dark background that adapts
    const Color darkBackground = Color(0xFF0A0A0A); // Near black

    // TextTheme with San Francisco-like font
    final TextTheme textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        height: 56 / 48,
        letterSpacing: -0.02 * 48,
        color: white,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 40 / 32,
        color: white,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 32 / 24,
        color: white,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: white,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
        color: white),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: white),
      bodySmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: white),
      labelLarge: GoogleFonts.spaceMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: white),
      labelMedium: GoogleFonts.spaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
        color: white),
      labelSmall: GoogleFonts.spaceMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: white),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      // Extended color scheme for Material 3
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: deepNativeBlue,
        onPrimary: darkBackground,
        secondary: mediumBlue,
        onSecondary: darkBackground,
        surface: Color(0xFF1A1A2E),       // Dark navy surface for dialogs & cards
        onSurface: white,
        surfaceVariant: Color(0xFF16213E), // Slightly lighter dark
        onSurfaceVariant: Color(0xFFB0C4D8),
        background: darkBackground,
        onBackground: white,
        error: Colors.redAccent,
        onError: white,
        outline: Color(0xFF2D3F5A),
        outlineVariant: Color(0xFF1E2D42),
      ),

      // Text theme
      textTheme: textTheme,

      // Custom configurations
      extensions: <ThemeExtension<dynamic>>[
        GlassmorphismExtension(
          config: glassmorphismConfig(true),
          smallRadius: smallRadius,
          mediumRadius: mediumRadius,
          largeRadius: largeRadius,
          extraLargeRadius: extraLargeRadius,
        ),
      ],

      // Ensure dialogs always have solid background
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20))
        ),
        elevation: 12,
      ),
      dialogBackgroundColor: const Color(0xFF1A1A2E),

      // SnackBar always visible with floating behavior
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1A1A2E),
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}

// Extension to hold glassmorphism configuration
class GlassmorphismExtension extends ThemeExtension<GlassmorphismExtension> {
  final GlassmorphismConfig config;
  final double smallRadius;
  final double mediumRadius;
  final double largeRadius;
  final double extraLargeRadius;

  const GlassmorphismExtension({
    required this.config,
    required this.smallRadius,
    required this.mediumRadius,
    required this.largeRadius,
    required this.extraLargeRadius,
  });

  @override
  GlassmorphismExtension copyWith({
    GlassmorphismConfig? config,
    double? smallRadius,
    double? mediumRadius,
    double? largeRadius,
    double? extraLargeRadius,
  }) {
    return GlassmorphismExtension(
      config: config ?? this.config,
      smallRadius: smallRadius ?? this.smallRadius,
      mediumRadius: mediumRadius ?? this.mediumRadius,
      largeRadius: largeRadius ?? this.largeRadius,
      extraLargeRadius: extraLargeRadius ?? this.extraLargeRadius,
    );
  }

  @override
  GlassmorphismExtension lerp(
      covariant GlassmorphismExtension other, double t) {
    if (other is! GlassmorphismExtension) return this;
    return GlassmorphismExtension(
      config: GlassmorphismConfig.lerp(config, other.config, t)!,
      smallRadius: _lerpDouble(smallRadius, other.smallRadius, t) ?? smallRadius,
      mediumRadius: _lerpDouble(mediumRadius, other.mediumRadius, t) ?? mediumRadius,
      largeRadius: _lerpDouble(largeRadius, other.largeRadius, t) ?? largeRadius,
      extraLargeRadius:
          _lerpDouble(extraLargeRadius, other.extraLargeRadius, t) ?? extraLargeRadius,
    );
  }
}

// Helper function for linear interpolation of doubles
double _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

// Glassmorphism configuration class
class GlassmorphismConfig {
  final double blurSigmaX;
  final double blurSigmaY;
  final double borderWidth;
  final Color backgroundColor;
  final Color borderColor;

  const GlassmorphismConfig({
    required this.blurSigmaX,
    required this.blurSigmaY,
    required this.borderWidth,
    required this.backgroundColor,
    required this.borderColor,
  });

  static GlassmorphismConfig lerp(
      GlassmorphismConfig? a, GlassmorphismConfig? b, double t) {
    if (a == null && b == null) return const GlassmorphismConfig(
      blurSigmaX: 0,
      blurSigmaY: 0,
      borderWidth: 0,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
    );
    if (a == null) return b! * t;
    if (b == null) return a! * (1 - t);
    return GlassmorphismConfig(
      blurSigmaX: a.blurSigmaX * (1 - t) + b!.blurSigmaX * t,
      blurSigmaY: a.blurSigmaY * (1 - t) + b!.blurSigmaY * t,
      borderWidth: a.borderWidth * (1 - t) + b!.borderWidth * t,
      backgroundColor: _colorLerp(a.backgroundColor, b!.backgroundColor, t)!,
      borderColor: _colorLerp(a.borderColor, b!.borderColor, t)!,
    );
  }

  GlassmorphismConfig operator *(double t) => GlassmorphismConfig(
        blurSigmaX: blurSigmaX * t,
        blurSigmaY: blurSigmaY * t,
        borderWidth: borderWidth * t,
        backgroundColor: _colorScale(backgroundColor, t),
        borderColor: _colorScale(borderColor, t),
      );
}

/// Helper to lerp colors since Color.lerp can return null
Color? _colorLerp(Color? a, Color? b, double t) {
  if (a == null && b == null) return null;
  if (a == null) return b;
  if (b == null) return a;
  return Color.lerp(a, b, t);
}

/// Helper to scale color opacity
Color _colorScale(Color color, double t) {
  return color.withOpacity(color.opacity * t);
}