import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/liquid_glass_theme.dart';
import '../theme/tokens.dart';

/// Helper to get tokens from context
KardoTokens _tokens(BuildContext context) =>
    Theme.of(context).extension<KardoTokensExtension>()!.tokens;

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
    double? blurSigmaX,
    double? blurSigmaY,
  }) {
    final theme = Theme.of(context);
    final glassExt = theme.extension<GlassmorphismExtension>()!;
    final glassConfig = glassExt.config;
    final borderRadius = BorderRadius.all(Radius.circular(glassExt.largeRadius));

    // If blur is 0 or very small, use opaque card (non-glass mode)
    if (glassConfig.blurSigmaX <= 1) {
      final t = _tokens(context);
      return GlassmorphismContainer(
        child: child,
        blurSigmaX: 0,
        blurSigmaY: 0,
        borderWidth: 1,
        backgroundColor: t.cardBackground,
        borderColor: t.borderDefault,
        borderRadius: borderRadius,
      );
    }

    return GlassmorphismContainer(
      child: child,
      blurSigmaX: blurSigmaX ?? glassConfig.blurSigmaX,
      blurSigmaY: blurSigmaY ?? glassConfig.blurSigmaY,
      borderWidth: glassConfig.borderWidth,
      backgroundColor: glassConfig.backgroundColor,
      borderColor: glassConfig.borderColor,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If blur is 0, skip BackdropFilter entirely (corporate mode)
    if (blurSigmaX <= 0 && blurSigmaY <= 0) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: borderWidth),
          borderRadius: borderRadius,
        ),
        padding: padding,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigmaX, sigmaY: blurSigmaY),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: borderRadius,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Utility class for creating iOS-style squircles
class Squircles {
  static BorderRadius squirclify(double radius) {
    final double effectiveRadius = radius * 0.9;
    return BorderRadius.all(Radius.circular(effectiveRadius));
  }

  static BorderSide squirclarBorder({
    required Color color,
    required double width,
  }) {
    return BorderSide(color: color, width: width);
  }
}

/// iOS-style recessed search field
class IOSSearchBar extends StatefulWidget {
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
  State<IOSSearchBar> createState() => _IOSSearchBarState();
}

class _IOSSearchBarState extends State<IOSSearchBar> {
  late final TextEditingController _internalController;
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // An internally-owned controller must survive rebuilds, otherwise the
    // field loses focus and caret position on every parent setState.
    _internalController =
        TextEditingController(text: widget.initialValue ?? '');
    _controller = widget.controller ?? _internalController;
  }

  @override
  void dispose() {
    _internalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _tokens(context);

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceBackground,
        borderRadius: Squircles.squirclify(25),
        border: Border.all(color: t.borderDefault, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: t.textTertiary, fontSize: 16),
          prefixIcon: Icon(Icons.search, color: t.textTertiary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          isDense: true,
        ),
        style: TextStyle(color: t.textPrimary, fontSize: 16),
        cursorColor: t.accent,
      ),
    );
  }
}

/// iOS-style button with filled and outlined variants
class IOSBorderedButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
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
    final t = _tokens(context);

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(icon, color: isPrimary ? t.textOnAccent : t.accent),
        label: isLoading
            ? SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(t.textOnAccent),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? t.textOnAccent : t.accent,
                ),
              ),
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(
            isPrimary ? t.accent : Colors.transparent,
          ),
          foregroundColor: MaterialStateProperty.all(
            isPrimary ? t.textOnAccent : t.accent,
          ),
          overlayColor: MaterialStateProperty.all(
            (isPrimary ? t.accent : t.accent).withOpacity(0.1),
          ),
          side: MaterialStateProperty.all(
            BorderSide(
              color: isPrimary ? Colors.transparent : t.accent,
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

/// iOS-style segmented control
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
    final t = _tokens(context);
    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.borderSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderDefault, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = segments.length;
          final double alignX = count > 1
              ? -1.0 + (selectedIndex * (2.0 / (count - 1)))
              : 0.0;

          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment(alignX, 0.0),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: t.accent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                                icon, size: 16,
                                color: isSelected ? t.textOnAccent : t.textTertiary,
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
                                    color: isSelected ? t.textOnAccent : t.textTertiary,
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
    final t = _tokens(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Squircles.squirclify(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (subtitle != null) ...[const SizedBox(height: 4), subtitle!],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null) ...[trailing!],
              if (trailing != null && showChevron) const SizedBox(width: 8),
              if (showChevron)
                Icon(Icons.chevron_right, color: t.textTertiary, size: 20),
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
    final t = _tokens(context);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: t.textPrimary,
        ),
      ),
      centerTitle: centerTitle,
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.chevron_left, color: t.textPrimary),
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
    final t = _tokens(context);

    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: t.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
        selectedItemColor: t.accent,
        unselectedItemColor: t.textTertiary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        iconSize: 28,
        selectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
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
    final t = _tokens(context);

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: t.accent,
      foregroundColor: t.textOnAccent,
      child: Icon(icon),
      mini: isMini,
      tooltip: tooltip,
      shape: const CircleBorder(),
      elevation: 4,
    );
  }
}
