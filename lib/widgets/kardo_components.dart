import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'ios_components.dart';

KardoTokens _t(BuildContext context) =>
    Theme.of(context).extension<KardoTokensExtension>()!.tokens;

/// The standard glass surface. Padding, radius and blur come from the theme
/// so every card in the app is built the same way.
class KardoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const KardoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KardoSpacing.lg),
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = GlassmorphismContainer.fromTheme(
      context,
      child: Padding(padding: padding, child: child),
    );
    if (onTap != null) {
      card = GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
    }
    if (margin != null) card = Padding(padding: margin!, child: card);
    return card;
  }
}

/// Icon + tracked caps label above every section group.
class KardoSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const KardoSectionHeader(this.title, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: t.textTertiary),
          const SizedBox(width: KardoSpacing.sm),
        ],
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: t.textTertiary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Circle icon + title + message + optional call to action.
/// Used everywhere a list or screen has nothing to show yet.
class KardoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const KardoEmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KardoSpacing.xl,
          vertical: KardoSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: t.accentLight, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: t.accent),
            ),
            const SizedBox(height: KardoSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: KardoSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: t.textSecondary, height: 1.4),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: KardoSpacing.xl),
              SizedBox(
                width: 220,
                child: IOSBorderedButton(
                  text: actionLabel!,
                  icon: actionIcon ?? Icons.add_rounded,
                  onPressed: onAction!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly failure state with an optional retry — never shows raw
/// exception text to users.
class KardoErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  const KardoErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.retryLabel = 'Try Again',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KardoSpacing.xl,
          vertical: KardoSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.error.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 32, color: t.error),
            ),
            const SizedBox(height: KardoSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: KardoSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textSecondary, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KardoSpacing.xl),
              SizedBox(
                width: 180,
                child: IOSBorderedButton(
                  text: retryLabel,
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry!,
                  isPrimary: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// iOS-style toggle backed by CupertinoSwitch.
class KardoSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const KardoSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return CupertinoSwitch(value: value, onChanged: onChanged, activeColor: t.accent);
  }
}

enum KardoSnackKind { success, error, warning, info }

/// Themed floating snackbar — every transient message in the app goes
/// through this so colors stay on-token.
void showKardoSnack(
  BuildContext context,
  String message, {
  KardoSnackKind kind = KardoSnackKind.info,
}) {
  final t = _t(context);
  final Color color = switch (kind) {
    KardoSnackKind.success => t.success,
    KardoSnackKind.error => t.error,
    KardoSnackKind.warning => t.warning,
    KardoSnackKind.info => t.accent,
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Themed confirmation dialog — returns true when the user confirms.
Future<bool> showKardoConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final t = _t(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.textPrimary),
      ),
      content: Text(
        message,
        style: TextStyle(fontSize: 14, color: t.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            cancelLabel,
            style: TextStyle(fontSize: 15, color: t.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(destructive ? t.error : t.accent),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
