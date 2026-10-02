import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared building blocks for the Admin "Website" CMS surfaces — mirrors
/// the visual language of `investor_portal_widgets.dart` but namespaced
/// for the CMS admin feature.

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                            height: 1.5,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

class AdminKpi extends StatelessWidget {
  const AdminKpi({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent = AppColors.gold,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.08),
              accent.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: accent.withValues(alpha: 0.2)),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
            if (icon != null) const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate500,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      );
}

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.15)),
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        hoverColor: AppColors.gold.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = LucideIcons.inbox,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.slate400.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: AppColors.slate400),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate500,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 24),
                action!,
              ],
            ],
          ),
        ),
      );
}

class AdminErrorView extends StatelessWidget {
  const AdminErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AdminEmptyState(
        title: 'Something went wrong',
        message: message,
        icon: LucideIcons.alertCircle,
        action: onRetry != null
            ? FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('Try again'),
              )
            : null,
      );
}

class AdminLoadingView extends StatelessWidget {
  const AdminLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
}

/// Small "not connected" banner for when Supabase isn't configured.
class AdminSupabaseNotConfigured extends StatelessWidget {
  const AdminSupabaseNotConfigured({super.key});

  @override
  Widget build(BuildContext context) => const AdminEmptyState(
        title: 'Supabase is not configured',
        message:
            'Connect Supabase credentials to manage live website content.',
        icon: LucideIcons.database,
      );
}

/// A compact status pill (Published / Draft / Featured / Hidden…).
class AdminStatusPill extends StatelessWidget {
  const AdminStatusPill({
    super.key,
    required this.label,
    this.color = AppColors.slate400,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppRadius.buttonBorder,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

/// Reusable section divider with optional label.
class AdminDivider extends StatelessWidget {
  const AdminDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Divider(color: AppColors.slate400.withValues(alpha: 0.15)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.slate400.withValues(alpha: 0.15))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.slate500,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.slate400.withValues(alpha: 0.15))),
        ],
      ),
    );
  }
}
