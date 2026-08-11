import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AtelierTheme {
  // Colors
  static const Color bone = Color(0xFFF6F2EA);
  static const Color navy = Color(0xFF1C2430);
  static const Color brass = Color(0xFFB8863A);
  static const Color waxRed = Color(0xFF9E3B3B);
  
  // Specific semantic colors from MCP
  static const Color background = bone;
  static const Color surface = bone;
  static const Color surfaceContainer = Color(0xFFF7ECE2);
  static const Color surfaceContainerLow = Color(0xFFFDF2E8);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEBE1D7);
  static const Color onSurface = navy;
  static const Color onSurfaceVariant = Color(0xFF504538);
  static const Color primary = brass;
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFF9A6C22);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color error = waxRed;
  static const Color outline = Color(0xFF827566);
  static const Color outlineVariant = Color(0xFFD4C4B3);
  static const Color dividerColor = Color(0x1A1C2430); // 10% opacity Navy

  // Shadows and Borders
  static const BoxShadow tactileShadow = BoxShadow(
    color: Color(0x141C2430), // rgba(28, 36, 48, 0.08)
    blurRadius: 12,
    offset: Offset(0, 4),
  );
  
  static final Border tactileBorder = Border.all(
    color: const Color(0x1A1C2430), // rgba(28, 36, 48, 0.10)
    width: 1,
  );
  
  static final Border inkRule = Border(
    bottom: BorderSide(
      color: const Color(0x1A1C2430), // rgba(28, 36, 48, 0.10)
      width: 1,
    ),
  );

  // Spacing (4px rhythm)
  static const double unit = 4.0;
  static const double stackSm = 8.0;
  static const double stackMd = 16.0;
  static const double gutter = 24.0;
  static const double stackLg = 32.0;
  static const double marginMobile = 20.0;
  static const double marginDesktop = 40.0;

  static ThemeData get lightTheme {
    final baseTextTheme = Typography.material2021().black;

    // Typography setup
    final TextTheme textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        height: 56 / 48,
        letterSpacing: -0.02 * 48,
        color: onSurface,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 40 / 32,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 32 / 24,
        color: onSurface,
      ),
      // Mapped to titleLarge for convenience if needed, but not heavily used
      titleLarge: GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      // body-lg
      bodyLarge: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
        color: onSurface,
      ),
      // body-md
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: onSurface,
      ),
      // body-sm
      bodySmall: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: onSurface,
      ),
      // data-value
      labelLarge: GoogleFonts.ibmPlexMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: onSurface,
      ),
      // data-label
      labelMedium: GoogleFonts.ibmPlexMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
        color: onSurface,
      ),
      labelSmall: GoogleFonts.ibmPlexMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: onPrimary,
        secondary: navy,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
        // ignore: deprecated_member_use
        background: background,
        // ignore: deprecated_member_use
        onBackground: onSurface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      
      // Cards (Minimal borders, subtle shadows)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: navy,
          elevation: 2,
          shadowColor: const Color(0x141C2430), // 8% opacity 0px 4px 12px roughly
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: navy, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: navy,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Input Decoration (Bottom border only)
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: dividerColor, width: 1),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: dividerColor, width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: textTheme.labelMedium,
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: onSurface),
      ),
      
      // Divider
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = Typography.material2021().white;

    final Color darkBackground = navy;
    final Color darkSurface = navy;
    final Color darkOnSurface = bone;
    final Color darkPrimary = brass;
    final Color darkDivider = const Color(0x33F6F2EA); // 20% Bone
    final Color darkSurfaceVariant = const Color(0xFF2A3441);

    // Typography setup
    final TextTheme textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        height: 56 / 48,
        letterSpacing: -0.02 * 48,
        color: darkOnSurface,
      ),
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 40 / 32,
        color: darkOnSurface,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 32 / 24,
        color: darkOnSurface,
      ),
      titleLarge: GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: darkOnSurface,
      ),
      bodyLarge: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
        color: darkOnSurface,
      ),
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: darkOnSurface,
      ),
      bodySmall: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: darkOnSurface,
      ),
      labelLarge: GoogleFonts.ibmPlexMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: darkOnSurface,
      ),
      labelMedium: GoogleFonts.ibmPlexMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.05 * 12,
        color: darkOnSurface,
      ),
      labelSmall: GoogleFonts.ibmPlexMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: darkOnSurface,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: darkPrimary,
        primary: darkPrimary,
        onPrimary: darkBackground,
        secondary: bone,
        onSecondary: darkBackground,
        error: error,
        onError: Colors.white,
        surface: darkSurface,
        onSurface: darkOnSurface,
        background: darkBackground,
        onBackground: darkOnSurface,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: textTheme,
      
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: darkDivider, width: 1),
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkBackground,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkOnSurface,
          side: BorderSide(color: darkOnSurface, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: darkBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: darkDivider, width: 1),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: darkDivider, width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: darkPrimary, width: 2),
        ),
        labelStyle: textTheme.labelMedium,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkOnSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: darkOnSurface),
      ),
      
      dividerTheme: DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
