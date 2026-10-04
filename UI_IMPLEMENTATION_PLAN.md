# Kardo UI Redesign — Implementation Plan

## Overview

This document provides a complete, step-by-step plan to redesign the Kardo Flutter app's UI. The app currently uses a `LiquidGlassTheme` (ice blue + navy) with glassmorphism containers. The redesign supports multiple visual themes (Corporate variants + Liquid Glass variants) selectable via the existing dark mode toggle mechanism.

**CRITICAL: This plan touches ONLY the UI layer. Services, providers, database, AI extraction, and all business logic remain 100% untouched.**

---

## Architecture Analysis

### Current File Map (what exists)

```
lib/
  main.dart                          -- MaterialApp, theme selection, auth routing
  firebase_options.dart              -- Firebase config (DO NOT TOUCH)
  theme/
    liquid_glass_theme.dart          -- Main theme: LiquidGlassTheme.lightTheme / darkTheme
    atelier_theme.dart               -- Backup theme (unused, DO NOT TOUCH)
  widgets/
    ios_components.dart              -- GlassmorphismContainer, IOSSearchBar, IOSBorderedButton,
                                        IOSegmentedControl, IOSNavBar, IOSBottomNavBar,
                                        IOSFloatingActionButton, IOSListTile, Squircles
    zoomable_image_viewer.dart       -- Image zoom overlay (DO NOT TOUCH)
    selected_image*.dart             -- Platform-specific image display (DO NOT TOUCH)
  screens/
    home_screen.dart                 -- Home dashboard with tabs, search, stats, recent cards
    login_screen.dart                -- Google sign-in screen
    scanner_screen.dart              -- Camera/gallery picker + processing
    camera_screen.dart               -- Live camera viewfinder (DO NOT TOUCH camera logic)
    result_screen.dart               -- Extracted card review + edit + save
    contact_detail_screen.dart       -- Full contact view with actions (call, email, NFC, QR)
    sheet_data_screen.dart           -- Library: List / Gallery / Kanban views
    export_screen.dart               -- Export to PDF/Excel/CSV/vCard
    settings_screen.dart             -- Google Drive backup/restore, dark mode toggle
    insights_screen.dart             -- Analytics dashboard
    qr_share_screen.dart             -- QR code generation for vCard
    batch_processing_screen.dart     -- Multi-image batch OCR
    batch_result_screen.dart         -- Batch results display
    batch_test_screen.dart           -- Batch testing (DO NOT TOUCH)
  providers/
    config_provider.dart             -- ConfigState (serverHost, serverPort, selectedModel, isDark)
    data_provider.dart               -- localCardsProvider, sheetDataProvider, localDbServiceProvider
  services/
    groq_service.dart                -- Groq cloud AI extraction (DO NOT TOUCH)
    local_transformer_service.dart   -- On-device ML Kit OCR (DO NOT TOUCH)
    offline_transformer_service.dart -- Offline extraction (DO NOT TOUCH)
    image_processor_service.dart     -- Image preprocessing + dominant color (DO NOT TOUCH)
    local_db_service.dart            -- SQLCipher database (DO NOT TOUCH)
    export_service.dart              -- PDF/Excel/CSV generation (DO NOT TOUCH)
    nfc_service.dart                 -- NFC tap-to-share (DO NOT TOUCH)
    google_drive_service.dart        -- Google Drive backup (DO NOT TOUCH)
```

### What the Redesign Changes

| Layer | Change | Risk |
|-------|--------|------|
| `theme/liquid_glass_theme.dart` | Rewrite with new color tokens, typography, component themes | Medium — must preserve `GlassmorphismExtension` interface |
| `widgets/ios_components.dart` | Update colors to use theme tokens instead of hardcoded values | Low — internal only |
| All screen files | Replace hardcoded colors with theme tokens | Low — visual only |
| `main.dart` | No changes needed (already reads `configProvider.isDark`) | None |
| `providers/config_provider.dart` | No changes needed | None |
| All services | **ZERO changes** | None |

---

## Phase 1: Design Token System (theme/tokens.dart)

**Create a new file `lib/theme/tokens.dart`** that defines all design tokens as abstract constants. Both Corporate and Glass themes will implement these same tokens.

### File: `lib/theme/tokens.dart` (NEW)

```dart
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
  final double radiusSmall;   // 8-12px
  final double radiusMedium;  // 14-16px
  final double radiusLarge;   // 20-24px
  final double radiusPill;    // 30-50px
  
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
}
```

---

## Phase 2: Theme Definitions

**Rewrite `lib/theme/liquid_glass_theme.dart`** to contain all 8 theme variants (4 Corporate + 4 Glass). Each returns a `ThemeData` + `KardoTokens` pair.

### File: `lib/theme/liquid_glass_theme.dart` (REWRITE)

Key requirements:
1. Keep the class name `LiquidGlassTheme` so `main.dart` does not need to change
2. Keep `lightTheme` and `darkTheme` static getters (main.dart reads these)
3. Add `static KardoTokens currentTokens(BuildContext context)` that reads from theme extensions
4. Each variant defines its own complete `ThemeData`
5. The `GlassmorphismExtension` must be preserved (ios_components.dart depends on it)

### Corporate Classic (Light) — Default

```dart
// Colors
static const _bg = Color(0xFFFFFFFF);        // white
static const _surface = Color(0xFFFFFFFF);   // white
static const _card = Color(0xFFFFFFFF);      // white
static const _textPrimary = Color(0xFF1B2559);   // navy
static const _textSecondary = Color(0xFF334155);
static const _textTertiary = Color(0xFF64748B);
static const _accent = Color(0xFF2563EB);    // blue
static const _border = Color(0xFFE2E8F0);
static const _borderSubtle = Color(0xFFF1F5F9);
// Typography: Inter
// Card radius: 12px
// Card shadow: 0 1px 3px rgba(0,0,0,0.06)
```

### Corporate Charcoal (Dark)

```dart
static const _bg = Color(0xFF111318);
static const _surface = Color(0xFF1A1D25);
static const _card = Color(0xFF1A1D25);
static const _textPrimary = Color(0xFFF1F5F9);
static const _textSecondary = Color(0xFF94A3B8);
static const _textTertiary = Color(0xFF64748B);
static const _accent = Color(0xFF60A5FA);    // sky blue
static const _border = Color(0xFF2D3440);
// Typography: Inter
// Card radius: 12px
```

### Corporate Sage (Light)

```dart
static const _bg = Color(0xFFF5F7F6);
static const _card = Color(0xFFFFFFFF);
static const _textPrimary = Color(0xFF1C3D2E);   // forest green
static const _textSecondary = Color(0xFF3D5A4A);
static const _textTertiary = Color(0xFF7A9484);
static const _accent = Color(0xFF2D7A54);
static const _border = Color(0xFFD5DDD8);
// Typography: DM Sans
// Card radius: 14px
```

### Corporate Warm (Light)

```dart
static const _bg = Color(0xFFFAF8F5);        // warm cream
static const _card = Color(0xFFFFFFFF);
static const _textPrimary = Color(0xFF3D2B1F);   // espresso
static const _textSecondary = Color(0xFF5C4A3D);
static const _textTertiary = Color(0xFF9C8B7E);
static const _accent = Color(0xFFBD5D38);    // burnt orange
static const _border = Color(0xFFE8E0D4);
// Typography: DM Sans
// Card radius: 14px
```

### Glass Light

```dart
// Background: gradient #F0F4FF -> #E8F0FE
static const _card = Color(0xA6FFFFFF);       // rgba(255,255,255,0.65)
static const _textPrimary = Color(0xFF1D1D1F);
static const _textSecondary = Color(0xFF3C3C43);
static const _textTertiary = Color(0xFF8E8E93);
static const _accent = Color(0xFF007AFF);    // system blue
static const _border = Color(0x14000000);    // rgba(0,0,0,0.08)
// blurSigma: 40.0
// Card radius: 22px
// Typography: Inter, letter-spacing: -0.02em on headers
```

### Glass Dark

```dart
static const _bg = Color(0xFF000000);
static const _card = Color(0xBF1C1C1E);      // rgba(28,28,30,0.75)
static const _textPrimary = Color(0xFFFFFFFF);
static const _textSecondary = Color(0xD9EBEBF5); // rgba(235,235,245,0.85)
static const _textTertiary = Color(0xFF8E8E93);
static const _accent = Color(0xFF0A84FF);
static const _border = Color(0x14FFFFFF);    // rgba(255,255,255,0.08)
// blurSigma: 40.0
// Card radius: 22px
```

### Glass Violet

```dart
// Background: gradient #F3F0FF -> #EDE8FE
static const _card = Color(0x99FFFFFF);       // rgba(255,255,255,0.6)
static const _textPrimary = Color(0xFF1A1523);
static const _textSecondary = Color(0xFF3D3554);
static const _textTertiary = Color(0xFF8B83A6);
static const _accent = Color(0xFF6E56CF);
static const _border = Color(0x1A6E56CF);    // violet-tinted
// blurSigma: 40.0
// Card radius: 22px
```

### Glass Mint

```dart
// Background: gradient #ECFDF5 -> #E6F9F0
static const _card = Color(0x99FFFFFF);
static const _textPrimary = Color(0xFF064E3B);
static const _textSecondary = Color(0xFF1E4038);
static const _textTertiary = Color(0xFF6B9E8C);
static const _accent = Color(0xFF10B981);
static const _border = Color(0x1A10B981);
// blurSigma: 40.0
// Card radius: 22px
```

### Theme Extension for Tokens

Add a `KardoTokensExtension` to every `ThemeData.extensions` list:

```dart
class KardoTokensExtension extends ThemeExtension<KardoTokensExtension> {
  final KardoTokens tokens;
  const KardoTokensExtension({required this.tokens});
  
  @override
  KardoTokensExtension copyWith({KardoTokens? tokens}) => KardoTokensExtension(tokens: tokens ?? this.tokens);
  
  @override
  KardoTokensExtension lerp(covariant KardoTokensExtension other, double t) => this;
}
```

Usage in any screen:
```dart
final tokens = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
```

---

## Phase 3: Widget Updates (widgets/ios_components.dart)

**File: `lib/widgets/ios_components.dart`** — Update to use theme tokens instead of hardcoded colors.

### Changes Required

1. **GlassmorphismContainer**: Already reads from `GlassmorphismExtension` — update to also read `KardoTokens` for border color and background color when not in glass mode.

2. **IOSSearchBar**: Replace `Colors.grey.shade100` / `Colors.grey.shade800` with `tokens.surfaceBackground`, replace `Colors.grey.shade600` with `tokens.textTertiary`.

3. **IOSBorderedButton**: Replace `colorScheme.primary` references with `tokens.accent`, replace hardcoded text colors with `tokens.textOnAccent` / `tokens.textPrimary`.

4. **IOSegmentedControl**: Replace hardcoded grey backgrounds with `tokens.borderSubtle`, replace `theme.colorScheme.primary` with `tokens.accent`.

5. **IOSNavBar**: Replace `Colors.black` / `Colors.white` with `tokens.textPrimary`.

6. **IOSBottomNavBar**: Replace hardcoded colors with `tokens.cardBackground` for bar, `tokens.accent` for active, `tokens.textTertiary` for inactive.

7. **IOSFloatingActionButton**: Replace `theme.colorScheme.primary` with `tokens.accent`.

8. **IOSListTile**: Replace hardcoded colors with tokens.

### DO NOT CHANGE
- Widget class names
- Widget constructor parameters
- Widget public API
- Any gesture/tap handlers
- Any navigation logic

---

## Phase 4: Screen-by-Screen Migration

Each screen currently hardcodes colors like `Color(0xFFCAF0F8)`, `Color(0xFF0A0A0A)`, `Colors.black`, `Colors.white`. These must be replaced with `tokens.xxx` reads.

### Migration Pattern (apply to every screen)

**BEFORE (current code):**
```dart
backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFCAF0F8),
```

**AFTER (themed code):**
```dart
final tokens = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
backgroundColor: tokens.scaffoldBackground,
```

**BEFORE:**
```dart
style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)
```

**AFTER:**
```dart
style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.bold)
```

### Screen Checklist

For each screen, the implementing model must:
1. Add `import '../theme/tokens.dart';` at top (if not already present via theme import)
2. Add `final tokens = Theme.of(context).extension<KardoTokensExtension>()!.tokens;` in the `build()` method
3. Search-replace every hardcoded color with the appropriate token
4. Search-replace every hardcoded TextStyle color with the appropriate token
5. Search-replace every hardcoded BoxDecoration color/border with appropriate tokens
6. **DO NOT change any business logic, navigation, state management, or service calls**

#### 4.1 `login_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `Color(0xFFCAF0F8)` | `tokens.scaffoldBackground` |
| `Color(0xFF111111)` | `tokens.textPrimary` |
| `Colors.grey.shade600` | `tokens.textSecondary` |
| `Color(0xFF536DFE)` | `tokens.accent` |
| `Colors.white` (button text) | `tokens.textOnAccent` |
| `GoogleFonts.inter(...)` | Keep as-is OR use `tokens.titleLarge` |

**Navigation logic to preserve:** `_signInWithGoogle()`, `GoogleDriveService.signIn()`, `FirebaseAuth`, `SharedPreferences`, `Navigator.pushReplacement` to HomeScreen.

#### 4.2 `home_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `Color(0xFF0A0A0A)` / `Color(0xFFCAF0F8)` | `tokens.scaffoldBackground` |
| `Colors.black` / `Colors.white` (text) | `tokens.textPrimary` |
| `Colors.grey.shade400` / `Colors.grey.shade600` | `tokens.textSecondary` or `tokens.textTertiary` |
| `Colors.grey.shade300` / `Colors.grey.shade700` | `tokens.borderDefault` or `tokens.surfaceBackground` |
| `theme.colorScheme.primary` | `tokens.accent` |
| `Colors.grey` (icons) | `tokens.textTertiary` |

**Navigation to preserve:** ScannerScreen, ContactDetailScreen, SheetDataScreen, ExportScreen.

#### 4.3 `scanner_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `Color(0xFF0A0A0A)` / `Color(0xFFCAF0F8)` | `tokens.scaffoldBackground` |
| Gradient colors in `_buildOptionCard` | Use `tokens.accent` and `tokens.accentDark` |
| `Colors.amber` (badge) | `tokens.warning` |
| `Colors.white` (text on gradient) | `tokens.textOnAccent` |

**Logic to preserve:** `_processImage()`, `_openLiveCamera()`, `_pickImage()`, all Groq/ML Kit calls, ImageProcessorService.

#### 4.4 `contact_detail_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `Color(0xFF0A0A0A)` / `Color(0xFFCAF0F8)` | `tokens.scaffoldBackground` |
| `Color(0xFF1A1A2E)` / `Colors.white` | `tokens.cardBackground` / `tokens.textPrimary` |
| `Color(0xFFB0C4D8)` / `Color(0xFF4A5568)` | `tokens.textTertiary` |
| `theme.colorScheme.primary` | `tokens.accent` |
| `theme.colorScheme.outlineVariant` | `tokens.borderDefault` |
| `Color(0xFF00897B)` (NFC) | `tokens.accent` |

**Logic to preserve:** `_launchPhone()`, `_launchEmail()`, `_launchUrl()`, `_deleteCard()`, `_nfcShare()`, `_addToContacts()`, NFC bottom sheet, all contact insertion logic.

#### 4.5 `sheet_data_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `Color(0xFF0A0A0A)` / `LiquidGlassTheme.iceBlue` | `tokens.scaffoldBackground` |
| `Colors.black` / `Colors.white` | `tokens.textPrimary` |
| `Colors.grey.*` variants | `tokens.textSecondary` / `tokens.textTertiary` |
| `theme.colorScheme.primary` | `tokens.accent` |
| Kanban column colors | `tokens.kanbanNewLead`, etc. |
| `Color(0xFF5E35B1)` etc. (kanban) | `tokens.kanbanNewLead`, `tokens.kanbanContacted`, etc. |

**Logic to preserve:** All Riverpod providers, filter logic, Kanban drag-and-drop, carousel PageController, view mode switching.

#### 4.6 `export_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `Color(0xFF0A0A0A)` / `LiquidGlassTheme.iceBlue` | `tokens.scaffoldBackground` |
| `Colors.grey.shade800` / `Colors.white` | `tokens.cardBackground` |
| `theme.colorScheme.primary` | `tokens.accent` |
| `Colors.grey.shade400` / `Colors.grey.shade600` | `tokens.textSecondary` |

**Logic to preserve:** All export functions (PDF, Excel, CSV, vCard), file sharing, open_file calls.

#### 4.7 `settings_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `Color(0xFF0A0A0A)` / `LiquidGlassTheme.iceBlue` | `tokens.scaffoldBackground` |
| `Colors.white` / `Colors.black` | `tokens.textPrimary` |
| `Colors.grey.shade400` / `Colors.grey.shade600` | `tokens.textSecondary` |
| `theme.colorScheme.primary` | `tokens.accent` |

**Logic to preserve:** Google sign-in/out, backup/restore, SharedPreferences, all GoogleDriveService calls.

#### 4.8 `result_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `theme.scaffoldBackgroundColor` | Already correct (reads from theme) |
| `Color(0xFF536DFE)` | `tokens.accent` |
| `Colors.grey.shade400` / `Colors.grey.shade500` | `tokens.textTertiary` |
| `Colors.orange.shade700` | `tokens.warning` |
| `Colors.green.shade600` | `tokens.success` |

**Logic to preserve:** All TextEditingController logic, `_saveCard()`, duplicate checking, card data assembly.

#### 4.9 `insights_screen.dart`

| Current Hardcoded | Replace With |
|---|---|
| `Theme.of(context).colorScheme.surface` | `tokens.cardBackground` |
| `Theme.of(context).colorScheme.surfaceVariant` | `tokens.surfaceBackground` |
| `Theme.of(context).colorScheme.primaryContainer` | `tokens.accentLight` |
| Hardcoded stat colors (blueAccent, etc.) | `tokens.accent`, `tokens.success`, `tokens.info`, etc. |

**Logic to preserve:** All `_computeInsights()` logic, all provider watches, all chart data.

#### 4.10 `qr_share_screen.dart`

Minimal UI changes — mostly uses `theme.colorScheme`. Replace with tokens.

#### 4.11 `batch_processing_screen.dart` & `batch_result_screen.dart`

Replace hardcoded colors with tokens. **Preserve all batch processing logic.**

---

## Phase 5: Main App Integration

### `main.dart` — No Changes Required

The current code already reads `configProvider.isDark` and switches between `LiquidGlassTheme.lightTheme` and `LiquidGlassTheme.darkTheme`. As long as the rewritten `LiquidGlassTheme` maintains these two static getters, `main.dart` needs zero changes.

### Theme Variant Selection (Future Enhancement)

To allow users to choose between Corporate/Glass variants (not just light/dark), add to `ConfigState`:

```dart
class ConfigState {
  // ... existing fields
  final String themeVariant; // 'corp', 'corpd', 'corps', 'corpw', 'glass', 'glassd', 'glassv', 'glassm'
}
```

Then in `LiquidGlassTheme`:

```dart
static ThemeData getTheme(String variant, bool isDark) {
  switch (variant) {
    case 'corp': return _corpClassicLight;
    case 'corpd': return _corpCharcoalDark;
    // ... etc
  }
}
```

And in `main.dart`:
```dart
theme: LiquidGlassTheme.getTheme(config.themeVariant, false),
darkTheme: LiquidGlassTheme.getTheme(config.themeVariant, true),
```

**This is optional and can be added after the core redesign is complete.**

---

## Phase 6: Typography Mapping

### Corporate Family
- **Headings**: Inter (weights 500-700)
- **Body**: Inter (weight 400)
- **Labels/Data**: IBM Plex Mono (weights 400-500)
- **Letter spacing**: Default (no special tracking)

### Glass Family
- **Headings**: Inter (weights 500-700, letter-spacing: -0.02em on large text)
- **Body**: Inter (weight 400)
- **Labels/Data**: Space Mono or IBM Plex Mono
- **Letter spacing**: -0.02em on display/headline sizes

### All themes should load fonts via `GoogleFonts.inter()`, `GoogleFonts.dmSans()`, `GoogleFonts.ibmPlexMono()` etc.

---

## Phase 7: Glassmorphism Handling

### Glass Variants (E, F, G, H)
- Cards use `BackdropFilter` with `ImageFilter.blur(sigmaX: 40, sigmaY: 40)`
- Semi-transparent card backgrounds: `rgba(255,255,255,0.6)` for light, `rgba(28,28,30,0.75)` for dark
- Ultra-thin borders: 0.5px with 8% opacity
- The existing `GlassmorphismContainer` widget already handles this — it reads `GlassmorphismExtension` from the theme

### Corporate Variants (A, B, C, D)
- NO glassmorphism — solid card backgrounds
- Cards use solid colors with 1px borders and subtle box-shadows
- `GlassmorphismContainer` should detect corporate theme and use opaque backgrounds instead

**Implementation:** In `GlassmorphismContainer.fromTheme()`, check if `blurSigma` is 0 (corporate) and skip `BackdropFilter`:

```dart
factory GlassmorphismContainer.fromTheme(BuildContext context, {required Widget child}) {
  final glassExt = theme.extension<GlassmorphismExtension>()!;
  if (glassExt.config.blurSigmaX <= 0) {
    // Corporate mode — no blur, solid background
    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        border: Border.all(color: tokens.borderDefault),
        borderRadius: BorderRadius.circular(glassExt.mediumRadius),
      ),
      child: child,
    );
  }
  // Glass mode — existing blur logic
  return GlassmorphismContainer(/* ... */);
}
```

---

## Phase 8: Dark Mode Toggle

The existing `configProvider.isDark` toggle in `SettingsScreen` already works. The new theme system just needs to ensure:

1. **Corporate themes**: `isDark=false` → Classic/Sage/Warm, `isDark=true` → Charcoal
2. **Glass themes**: `isDark=false` → Light/Violet/Mint, `isDark=true` → Glass Dark

The toggle in `settings_screen.dart` calls `ref.read(configProvider.notifier).toggleTheme()`. This saves to SharedPreferences. `main.dart` reads `configProvider.isDark` and passes `ThemeMode.dark` or `ThemeMode.light` to `MaterialApp`.

**No changes needed to this flow.**

---

## Phase 9: Color Constants to Remove

After migration, search the entire `lib/` directory for these patterns and ensure they are all replaced:

```bash
# Search patterns that indicate hardcoded colors (should find ZERO matches after migration):
grep -rn "Color(0xFFCAF0F8" lib/          # ice blue
grep -rn "Color(0xFF0A0A0A" lib/          # near black
grep -rn "Color(0xFF1A1A2E" lib/          # dark surface
grep -rn "Color(0xFF536DFE" lib/          # old accent blue
grep -rn "Color(0xFF03045E" lib/          # old navy
grep -rn "Color(0xFF0077B6" lib/          # old medium blue
grep -rn "Color(0xFFFF7054" lib/          # old coral
grep -rn "LiquidGlassTheme.iceBlue" lib/  # old background
```

After migration, every one of these should return zero results (except in `tokens.dart` definitions and the old `atelier_theme.dart` which is unused).

---

## Phase 10: Verification Checklist

After implementation, verify:

- [ ] `flutter analyze` passes with no errors
- [ ] `flutter build apk --debug` succeeds
- [ ] App launches and shows Login screen
- [ ] Login with Google works
- [ ] Home screen displays cards from database
- [ ] Search filters cards correctly
- [ ] Tap card → Contact Detail opens with correct data
- [ ] Contact Detail: Call/Email/NFC/QR buttons work
- [ ] Scanner: Camera opens, processes image, shows result
- [ ] Scanner: Gallery pick works for single + multi-image
- [ ] Result Screen: Edit fields, save card, duplicate detection works
- [ ] Library: List/Gallery/Kanban views all render
- [ ] Kanban: Drag-and-drop changes lead status
- [ ] Export: PDF/Excel/CSV/vCard generation works
- [ ] Settings: Dark mode toggle switches themes correctly
- [ ] Settings: Google Drive backup/restore works
- [ ] No hardcoded colors remain (grep check)
- [ ] Glassmorphism blurs work on Glass variants
- [ ] Corporate variants show solid cards (no blur)
- [ ] All text is readable (contrast ratio >= 4.5:1)

---

## Execution Order

The implementing model should execute in this exact order:

1. **Create `lib/theme/tokens.dart`** — Token data class
2. **Rewrite `lib/theme/liquid_glass_theme.dart`** — All 8 variants with `KardoTokensExtension`
3. **Update `lib/widgets/ios_components.dart`** — Use tokens instead of hardcoded colors
4. **Update `lib/screens/login_screen.dart`** — Simplest screen, good for testing
5. **Update `lib/screens/home_screen.dart`** — Main screen, most complex
6. **Update `lib/screens/scanner_screen.dart`** — Gradient cards
7. **Update `lib/screens/result_screen.dart`** — Form fields
8. **Update `lib/screens/contact_detail_screen.dart`** — Action buttons
9. **Update `lib/screens/sheet_data_screen.dart`** — Three view modes + kanban
10. **Update `lib/screens/export_screen.dart`** — Format selection
11. **Update `lib/screens/settings_screen.dart`** — Backup/restore
12. **Update `lib/screens/insights_screen.dart`** — Charts/stats
13. **Update remaining screens** (qr_share, batch_processing, batch_result)
14. **Run `flutter analyze`** and fix any issues
15. **Run verification checklist** above

---

## What NOT to Touch

| File | Reason |
|------|--------|
| `firebase_options.dart` | Auto-generated by FlutterFire CLI |
| `services/*.dart` | Business logic — zero UI |
| `providers/data_provider.dart` | Data layer — zero UI |
| `widgets/zoomable_image_viewer.dart` | Standalone utility |
| `widgets/selected_image*.dart` | Platform-specific image display |
| `screens/camera_screen.dart` | Camera hardware logic |
| `screens/batch_test_screen.dart` | Testing utility |
| `theme/atelier_theme.dart` | Unused backup theme |
| `pubspec.yaml` | No new dependencies needed |
