import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../theme/liquid_glass_theme.dart';

/// A widget that applies glassmorphism effect using BackdropFilter
class GlassmorphismContainer extends StatelessWidget {
  final Widget child;
  final double blurSigmaX;
  final double blurSigmaY;
  final double borderWidth;
  final Color backgroundColor;
  final Color borderColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassmorphismContainer({
    Key? key,
    required this.child,
    this.blurSigmaX = 10,
    this.blurSigmaY = 10,
    this.borderWidth = 1,
    this.backgroundColor = const Color.fromRGBO(255, 255, 255, 0.2),
    this.borderColor = const Color.fromRGBO(255, 255, 255, 0.3),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding = EdgeInsets.zero,
  }) : super(key: key);

  factory GlassmorphismContainer.fromTheme(
    BuildContext context, {
    required Widget child,
    double blurSigmaX = 10,
    double blurSigmaY = 10,
  }) {
    final theme = Theme.of(context);
    final glassExt = theme.extension<GlassmorphismExtension>()!;
    final glassConfig = glassExt.config;
    final borderRadius = BorderRadius.all(
        Radius.circular(glassExt.mediumRadius)); // Use extension for radius

    return GlassmorphismContainer(
      child: child,
      blurSigmaX: blurSigmaX,
      blurSigmaY: blurSigmaY,
      borderWidth: glassConfig.borderWidth,
      backgroundColor: glassConfig.backgroundColor,
      borderColor: glassConfig.borderColor,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigmaX,
          sigmaY: blurSigmaY,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            borderRadius: borderRadius,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Utility class for creating iOS-style squircles (rounded corners with continuous curvature)
class Squircles {
  /// Creates a squircle border radius that approximates Apple's squircles
  /// Values are tuned to provide a good approximation of Apple's squircle shape
  static BorderRadius squirclify(double radius) {
    // Using a slightly smaller radius for corners to mimic the continuous curve
    // of Apple's squircle rather than a perfect circular radius
    final double effectiveRadius = radius * 0.9;
    return BorderRadius.all(Radius.circular(effectiveRadius));
  }

  /// Creates a squircle border
  static BorderSide squirclarBorder({
    required Color color,
    required double width,
  }) {
    return BorderSide(
      color: color,
      width: width,
    );
  }
}

/// iOS-style recessed search field
class IOSSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final String? initialValue;
  final TextEditingController? controller;

  const IOSSearchBar({
    Key? key,
    required this.hintText,
    this.onChanged,
    this.initialValue,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final controllerToUse = controller ?? TextEditingController(text: initialValue ?? '');

    // Initialize controller if needed
    if (controller == null && initialValue != null) {
      controllerToUse.text = initialValue ?? '';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800
            : Colors.grey.shade100,
        borderRadius: Squircles.squirclify(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controllerToUse,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          isDense: true,
        ),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 16,
        ),
        cursorColor: Theme.of(context).primaryColor,
      ),
    );
  }
}

/// iOS-style button with filled and outlined variants
class IOSBorderedButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary; // true for filled, false for outlined
  final bool isLoading;
  final double width;
  final double height;

  const IOSBorderedButton({
    Key? key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 50,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(
          icon,
          color: isPrimary
              ? (isDark ? Colors.black : Colors.white)
              : (isDark ? Colors.white : colorScheme.primary),
        ),
        label: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white : colorScheme.primary),
                ),
              ),
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(
            isPrimary
                ? (isDark
                    ? Colors.grey.shade800
                    : colorScheme.primary)
                : Colors.transparent,
          ),
          foregroundColor: MaterialStateProperty.all(
            isPrimary
                ? (isDark ? Colors.black : Colors.black)
                : (isDark ? Colors.white : colorScheme.primary),
          ),
          overlayColor: MaterialStateProperty.all(
            isPrimary
                ? (isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1))
                : (isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1)),
          ),
          side: MaterialStateProperty.all(
            BorderSide(
              color: isPrimary
                  ? Colors.transparent
                  : (isDark
                      ? Colors.white.withOpacity(0.5)
                      : colorScheme.primary),
              width: 1.5,
            ),
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: Squircles.squirclify(25),
            ),
          ),
          elevation: MaterialStateProperty.all(0),
        ),
      ),
    );
  }
}

/// iOS-style segmented control (Fully Responsive & Animated)
class IOSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onValueChanged;
  final List<IconData>? icons;

  const IOSegmentedControl({
    Key? key,
    required this.segments,
    required this.selectedIndex,
    required this.onValueChanged,
    this.icons,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = segments.length;
          final double alignX = count > 1
              ? -1.0 + (selectedIndex * (2.0 / (count - 1)))
              : 0.0;

          return Stack(
            children: [
              // Animated Indicator Background Pill
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment(alignX, 0.0),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.colorScheme.primary.withOpacity(0.9)
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Segment Option Buttons
              Row(
                children: List.generate(count, (index) {
                  final isSelected = selectedIndex == index;
                  final icon = (icons != null && index < icons!.length) ? icons![index] : null;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onValueChanged(index),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(
                                icon,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  segments[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// iOS-style list tile/cell
class IOSListTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const IOSListTile({
    Key? key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Squircles.squirclify(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (showChevron)
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                  size: 20,
                ),
              if (trailing != null && !showChevron) ...[
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-style navigation bar
class IOSNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool centerTitle;

  const IOSNavBar({
    Key? key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
    this.centerTitle = false,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      centerTitle: centerTitle,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      actions: actions,
    );
  }
}

/// iOS-style tab bar
class IOSBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;

  const IOSBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade900
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: isDark
            ? Colors.grey.shade400
            : Colors.grey.shade600,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        items: items,
      ),
    );
  }
}

/// iOS-style floating action button
class IOSFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final bool isMini;

  const IOSFloatingActionButton({
    Key? key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.isMini = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: isDark ? Colors.black : Colors.white,
      child: Icon(icon),
      mini: isMini,
      tooltip: tooltip,
      shape: const CircleBorder(),
      elevation: 4,
    );
  }
}