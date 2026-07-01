import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// AppBar with the brand gradient background and white foreground.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      bottom: bottom,
      automaticallyImplyLeading: automaticallyImplyLeading,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      // NOTE: use Container (not DecoratedBox) — a childless DecoratedBox
      // collapses to zero size in flexibleSpace, so the gradient never paints.
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      ),
    );
  }
}

/// A titled section wrapper used across the app.
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const SectionHeader(
      {super.key, required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.primary)),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Friendly empty-state placeholder.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const EmptyState(
      {super.key, required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: cs.onSurface.withOpacity(0.22)),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// Small rounded status pill (paid / unpaid / payment method).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusPill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

Color paymentColor(String status) {
  switch (status) {
    case 'Paid':
      return AppTheme.success;
    case 'Partial':
      return AppTheme.warning;
    case 'Unpaid':
      return AppTheme.danger;
    default:
      return AppTheme.brandMid;
  }
}
