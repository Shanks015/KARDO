import 'package:flutter/material.dart';

/// Central design token system for all Kardo themes.
/// Every screen reads colors from here — never from hardcoded values.
class KardoTokens {
  // ── Background ──
  final Color scaffoldBackground;
  final Color surfaceBackground;
  final Color cardBackground;

  // ── Text ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;

  // ── Accent ──
  final Color accent;
  final Color accentLight;
  final Color accentDark;

  // ── Borders ──
  final Color borderDefault;
  final Color borderSubtle;

  // ── Status ──
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // ── Kanban Column Colors ──
  final Color kanbanNewLead;
  final Color kanbanContacted;
  final Color kanbanFollowedUp;
  final Color kanbanClosed;

  // ── Shadows ──
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> elevatedShadow;

  // ── Border Radius ──
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusPill;

  // ── Glassmorphism (for Glass variants) ──
  final double blurSigma;
  final Color glassBackground;
  final Color glassBorder;
  final double glassBorderWidth;

  // ── Typography ──
  final TextStyle displayLarge;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle titleLarge;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;

  const KardoTokens({
    required this.scaffoldBackground,
    required this.surfaceBackground,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.borderDefault,
    required this.borderSubtle,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.kanbanNewLead,
    required this.kanbanContacted,
    required this.kanbanFollowedUp,
    required this.kanbanClosed,
    required this.cardShadow,
    required this.elevatedShadow,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusPill,
    required this.blurSigma,
    required this.glassBackground,
    required this.glassBorder,
    required this.glassBorderWidth,
    required this.displayLarge,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.titleLarge,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  // ── Convenience shorthands ──
  Color get text => textPrimary;
  Color get grey => textTertiary;
  Color get card => cardBackground;
  Color get surfaceAlt => surfaceBackground;
  Color get secondary => textSecondary;
  Color get background => scaffoldBackground;
  Color get border => borderDefault;
}

/// ThemeExtension that makes KardoTokens accessible via Theme.of(context)
class KardoTokensExtension extends ThemeExtension<KardoTokensExtension> {
  final KardoTokens tokens;

  const KardoTokensExtension({required this.tokens});

  @override
  KardoTokensExtension copyWith({KardoTokens? tokens}) {
    return KardoTokensExtension(tokens: tokens ?? this.tokens);
  }

  @override
  KardoTokensExtension lerp(covariant KardoTokensExtension other, double t) {
    return this;
  }
}
