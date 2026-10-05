import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class LiquidGlassTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // LIQUID GLASS LIGHT
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Light Colors ──
  static const Color _lightScaffold = Color(0xFFF0F4FF);
  static const Color _lightCard = Color(0xA6FFFFFF); // 65% white
  static const Color _lightCardBorder = Color(0x14000000); // 8% black
  static const Color _lightTextPrimary = Color(0xFF1D1D1F);
  static const Color _lightTextSecondary = Color(0xFF3C3C43);
  static const Color _lightTextTertiary = Color(0xFF8E8E93);
  static const Color _lightAccent = Color(0xFF007AFF);
  static const Color _lightAccentDark = Color(0xFF0056CC);
  static const Color _lightBorder = Color(0x1A000000); // 10% black
  static const Color _lightBorderSubtle = Color(0x0D000000); // 5% black
  static const Color _lightSuccess = Color(0xFF34C759);
  static const Color _lightWarning = Color(0xFFFF9500);
  static const Color _lightError = Color(0xFFFF3B30);
  static const Color _lightInfo = Color(0xFF5AC8FA);

  // ── Light Kanban ──
  static const Color _lightKanbanNew = Color(0xFF5E35B1);
  static const Color _lightKanbanContacted = Color(0xFF1565C0);
  static const Color _lightKanbanFollowed = Color(0xFF00897B);
  static const Color _lightKanbanClosed = Color(0xFF2E7D32);

  // ═══════════════════════════════════════════════════════════════════════════
  // LIQUID GLASS DARK
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Dark Colors ──
  static const Color _darkScaffold = Color(0xFF000000);
  static const Color _darkCard = Color(0xBF1C1C1E); // 75% dark
  static const Color _darkCardBorder = Color(0x14FFFFFF); // 8% white
  static const Color _darkTextPrimary = Color(0xFFFFFFFF);
  static const Color _darkTextSecondary = Color(0xD9EBEBF5); // 85% white
  static const Color _darkTextTertiary = Color(0xFF8E8E93);
  static const Color _darkAccent = Color(0xFF0A84FF);
  static const Color _darkAccentDark = Color(0xFF0060CC);
  static const Color _darkBorder = Color(0x1AFFFFFF); // 10% white
  static const Color _darkBorderSubtle = Color(0x0DFFFFFF); // 5% white
  static const Color _darkSuccess = Color(0xFF30D158);
  static const Color _darkWarning = Color(0xFFFFD60A);
  static const Color _darkError = Color(0xFFFF453A);
  static const Color _darkInfo = Color(0xFF64D2FF);

  // ── Dark Kanban ──
  static const Color _darkKanbanNew = Color(0xFF7E57C2);
  static const Color _darkKanbanContacted = Color(0xFF42A5F5);
  static const Color _darkKanbanFollowed = Color(0xFF26A69A);
  static const Color _darkKanbanClosed = Color(0xFF66BB6A);

  // ── Shared Constants ──
  static const double _blurSigma = 40.0;
  static const double _glassBorderWidth = 0.5;
  static const double _smallRadius = 12.0;
  static const double _mediumRadius = 16.0;
  static const double _largeRadius = 22.0;
  static const double _extraLargeRadius = 30.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // TOKEN DEFINITIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static KardoTokens get _lightTokens => KardoTokens(
    scaffoldBackground: _lightScaffold,
    surfaceBackground: _lightScaffold,
    cardBackground: _lightCard,
    textPrimary: _lightTextPrimary,
    textSecondary: _lightTextSecondary,
    textTertiary: _lightTextTertiary,
    textOnAccent: Colors.white,
    accent: _lightAccent,
    accentLight: _lightAccent.withOpacity(0.12),
    accentDark: _lightAccentDark,
    borderDefault: _lightBorder,
    borderSubtle: _lightBorderSubtle,
    success: _lightSuccess,
    warning: _lightWarning,
    error: _lightError,
    info: _lightInfo,
    kanbanNewLead: _lightKanbanNew,
    kanbanContacted: _lightKanbanContacted,
    kanbanFollowedUp: _lightKanbanFollowed,
    kanbanClosed: _lightKanbanClosed,
    cardShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    elevatedShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.10),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
    radiusSmall: _smallRadius,
    radiusMedium: _mediumRadius,
    radiusLarge: _largeRadius,
    radiusPill: _extraLargeRadius,
    blurSigma: _blurSigma,
    glassBackground: _lightCard,
    glassBorder: _lightCardBorder,
    glassBorderWidth: _glassBorderWidth,
    displayLarge: GoogleFonts.inter(
      fontSize: 48, fontWeight: FontWeight.w600, height: 56 / 48,
      letterSpacing: -0.02 * 48, color: _lightTextPrimary,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 32, fontWeight: FontWeight.w500, height: 40 / 32,
      color: _lightTextPrimary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 24, fontWeight: FontWeight.w500, height: 32 / 24,
      color: _lightTextPrimary,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 20, fontWeight: FontWeight.w600, color: _lightTextPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 18, fontWeight: FontWeight.w400, height: 28 / 18,
      color: _lightTextPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w400, height: 24 / 16,
      color: _lightTextPrimary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w400, height: 20 / 14,
      color: _lightTextPrimary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w500, height: 20 / 14,
      letterSpacing: 0.02, color: _lightTextPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w500, height: 16 / 12,
      letterSpacing: 0.04, color: _lightTextPrimary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 10, fontWeight: FontWeight.w500, height: 14 / 10,
      letterSpacing: 0.04, color: _lightTextPrimary,
    ),
  );

  static KardoTokens get _darkTokens => KardoTokens(
    scaffoldBackground: _darkScaffold,
    surfaceBackground: _darkScaffold,
    cardBackground: _darkCard,
    textPrimary: _darkTextPrimary,
    textSecondary: _darkTextSecondary,
    textTertiary: _darkTextTertiary,
    textOnAccent: Colors.white,
    accent: _darkAccent,
    accentLight: _darkAccent.withOpacity(0.15),
    accentDark: _darkAccentDark,
    borderDefault: _darkBorder,
    borderSubtle: _darkBorderSubtle,
    success: _darkSuccess,
    warning: _darkWarning,
    error: _darkError,
    info: _darkInfo,
    kanbanNewLead: _darkKanbanNew,
    kanbanContacted: _darkKanbanContacted,
    kanbanFollowedUp: _darkKanbanFollowed,
    kanbanClosed: _darkKanbanClosed,
    cardShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    elevatedShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.5),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
    radiusSmall: _smallRadius,
    radiusMedium: _mediumRadius,
    radiusLarge: _largeRadius,
    radiusPill: _extraLargeRadius,
    blurSigma: _blurSigma,
    glassBackground: _darkCard,
    glassBorder: _darkCardBorder,
    glassBorderWidth: _glassBorderWidth,
    displayLarge: GoogleFonts.inter(
      fontSize: 48, fontWeight: FontWeight.w600, height: 56 / 48,
      letterSpacing: -0.02 * 48, color: _darkTextPrimary,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 32, fontWeight: FontWeight.w500, height: 40 / 32,
      color: _darkTextPrimary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 24, fontWeight: FontWeight.w500, height: 32 / 24,
      color: _darkTextPrimary,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 20, fontWeight: FontWeight.w600, color: _darkTextPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 18, fontWeight: FontWeight.w400, height: 28 / 18,
      color: _darkTextPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w400, height: 24 / 16,
      color: _darkTextPrimary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w400, height: 20 / 14,
      color: _darkTextPrimary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w500, height: 20 / 14,
      letterSpacing: 0.02, color: _darkTextPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w500, height: 16 / 12,
      letterSpacing: 0.04, color: _darkTextPrimary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 10, fontWeight: FontWeight.w500, height: 14 / 10,
      letterSpacing: 0.04, color: _darkTextPrimary,
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // GLASSMORPHISM CONFIG
  // ═══════════════════════════════════════════════════════════════════════════

  static GlassmorphismConfig _glassConfig(bool isDark) => GlassmorphismConfig(
    blurSigmaX: _blurSigma,
    blurSigmaY: _blurSigma,
    borderWidth: _glassBorderWidth,
    backgroundColor: isDark ? _darkCard : _lightCard,
    borderColor: isDark ? _darkCardBorder : _lightCardBorder,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get lightTheme {
    final baseTextTheme = Typography.material2021().black;
    final tokens = _lightTokens;

    final TextTheme textTheme = baseTextTheme.copyWith(
      displayLarge: tokens.displayLarge,
      headlineLarge: tokens.headlineLarge,
      headlineMedium: tokens.headlineMedium,
      titleLarge: tokens.titleLarge,
      bodyLarge: tokens.bodyLarge,
      bodyMedium: tokens.bodyMedium,
      bodySmall: tokens.bodySmall,
      labelLarge: tokens.labelLarge,
      labelMedium: tokens.labelMedium,
      labelSmall: tokens.labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightScaffold,
      colorScheme: ColorScheme.light(
        brightness: Brightness.light,
        primary: _lightAccent,
        onPrimary: Colors.white,
        secondary: _lightAccentDark,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: _lightTextPrimary,
        surfaceVariant: const Color(0xFFF0F4FD),
        onSurfaceVariant: _lightTextSecondary,
        background: _lightScaffold,
        onBackground: _lightTextPrimary,
        error: _lightError,
        onError: Colors.white,
        outline: _lightBorder,
        outlineVariant: _lightBorderSubtle,
      ),
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        GlassmorphismExtension(
          config: _glassConfig(false),
          smallRadius: _smallRadius,
          mediumRadius: _mediumRadius,
          largeRadius: _largeRadius,
          extraLargeRadius: _extraLargeRadius,
        ),
        KardoTokensExtension(tokens: tokens),
      ],
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_largeRadius),
        ),
        elevation: 12,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _lightTextPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_mediumRadius),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get darkTheme {
    final baseTextTheme = Typography.material2021().white;
    final tokens = _darkTokens;

    final TextTheme textTheme = baseTextTheme.copyWith(
      displayLarge: tokens.displayLarge,
      headlineLarge: tokens.headlineLarge,
      headlineMedium: tokens.headlineMedium,
      titleLarge: tokens.titleLarge,
      bodyLarge: tokens.bodyLarge,
      bodyMedium: tokens.bodyMedium,
      bodySmall: tokens.bodySmall,
      labelLarge: tokens.labelLarge,
      labelMedium: tokens.labelMedium,
      labelSmall: tokens.labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkScaffold,
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: _darkAccent,
        onPrimary: Colors.black,
        secondary: const Color(0xFF64D2FF),
        onSecondary: Colors.black,
        surface: _darkCard,
        onSurface: _darkTextPrimary,
        surfaceVariant: const Color(0xFF1C1C1E),
        onSurfaceVariant: _darkTextSecondary,
        background: _darkScaffold,
        onBackground: _darkTextPrimary,
        error: _darkError,
        onError: Colors.white,
        outline: _darkBorder,
        outlineVariant: _darkBorderSubtle,
      ),
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        GlassmorphismExtension(
          config: _glassConfig(true),
          smallRadius: _smallRadius,
          mediumRadius: _mediumRadius,
          largeRadius: _largeRadius,
          extraLargeRadius: _extraLargeRadius,
        ),
        KardoTokensExtension(tokens: tokens),
      ],
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_largeRadius),
        ),
        elevation: 12,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C2C2E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_mediumRadius),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLASSMORPHISM EXTENSION (kept for backward compatibility with ios_components.dart)
// ═══════════════════════════════════════════════════════════════════════════════

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
  GlassmorphismExtension lerp(covariant GlassmorphismExtension other, double t) {
    return GlassmorphismExtension(
      config: GlassmorphismConfig.lerp(config, other.config, t),
      smallRadius: _lerpDouble(smallRadius, other.smallRadius, t),
      mediumRadius: _lerpDouble(mediumRadius, other.mediumRadius, t),
      largeRadius: _lerpDouble(largeRadius, other.largeRadius, t),
      extraLargeRadius: _lerpDouble(extraLargeRadius, other.extraLargeRadius, t),
    );
  }
}

double _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLASSMORPHISM CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

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

  static GlassmorphismConfig lerp(GlassmorphismConfig? a, GlassmorphismConfig? b, double t) {
    if (a == null && b == null) {
      return const GlassmorphismConfig(
        blurSigmaX: 0, blurSigmaY: 0, borderWidth: 0,
        backgroundColor: Colors.transparent, borderColor: Colors.transparent,
      );
    }
    if (a == null) return b! * t;
    if (b == null) return a * (1 - t);
    return GlassmorphismConfig(
      blurSigmaX: a.blurSigmaX * (1 - t) + b.blurSigmaX * t,
      blurSigmaY: a.blurSigmaY * (1 - t) + b.blurSigmaY * t,
      borderWidth: a.borderWidth * (1 - t) + b.borderWidth * t,
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t)!,
      borderColor: Color.lerp(a.borderColor, b.borderColor, t)!,
    );
  }

  GlassmorphismConfig operator *(double t) => GlassmorphismConfig(
    blurSigmaX: blurSigmaX * t,
    blurSigmaY: blurSigmaY * t,
    borderWidth: borderWidth * t,
    backgroundColor: backgroundColor.withOpacity(backgroundColor.opacity * t),
    borderColor: borderColor.withOpacity(borderColor.opacity * t),
  );
}
