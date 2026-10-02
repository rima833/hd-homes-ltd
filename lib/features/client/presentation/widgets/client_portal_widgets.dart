import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/feedback/loading_skeleton.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ClientSectionHeader extends StatelessWidget {
  const ClientSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
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

class ClientKpiCard extends StatelessWidget {
  const ClientKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent = AppColors.gold,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color accent;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = [
      if (label.isNotEmpty) label,
      if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
    ].join(' ');

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryDark,
                          height: 1.25,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: card,
      );
    }
    return card;
  }
}

class ClientEmptyState extends StatelessWidget {
  const ClientEmptyState({
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.neutral700.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AppColors.neutral500),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
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

class ClientErrorView extends StatelessWidget {
  const ClientErrorView({super.key, required this.message, this.onRetry});

  /// Raw exception, technical dump, or already-friendly text — always sanitized.
  final Object message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final friendly = userFacingError(message);
    final isNetwork = friendly == kNetworkErrorMessage ||
        friendly == kTimeoutErrorMessage;
    return ClientEmptyState(
      title: isNetwork ? 'Connection problem' : 'Something went wrong',
      message: friendly,
      icon: isNetwork ? LucideIcons.wifiOff : LucideIcons.alertCircle,
      action: onRetry != null
          ? FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.charcoal,
              ),
            )
          : null,
    );
  }
}

class ClientProgressBar extends StatelessWidget {
  const ClientProgressBar({
    super.key,
    required this.label,
    required this.percent,
    this.color = AppColors.gold,
    this.height = 6,
    this.showLabel = true,
  });

  final String label;
  final double percent;
  final Color color;
  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate400,
                        ),
                  ),
                  Text(
                    '${percent.clamp(0, 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: height,
              backgroundColor: AppColors.neutral800,
              color: color,
            ),
          ),
        ],
      );
}

class ClientPortalCard extends StatelessWidget {
  const ClientPortalCard({
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
    final container = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withValues(alpha: 0.6),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: AppColors.neutral700.withValues(alpha: 0.4),
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: container,
        ),
      );
    }
    return container;
  }
}

class ClientQuickAction extends StatelessWidget {
  const ClientQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.gold, size: 20),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class ClientStatusChip extends StatelessWidget {
  const ClientStatusChip({super.key, required this.status, this.label});

  final String status;

  /// Optional display text. Defaults to a humanised [status].
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? status.toLowerCase().replaceAll('_', ' ');
    final (color, bg) = switch (status.toLowerCase()) {
      'completed' || 'paid' || 'succeeded' || 'success' => (
          AppColors.success,
          AppColors.success.withValues(alpha: 0.12),
        ),
      'approved' => (
          AppColors.success,
          AppColors.success.withValues(alpha: 0.12),
        ),
      'pending_verification' || 'info_requested' => (
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.12),
        ),
      'pending' || 'applied' || 'overdue' => (
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.12),
        ),
      'documents_required' || 'payment_pending' => (
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.12),
        ),
      'cancelled' || 'failed' || 'rejected' || 'waived' => (
          AppColors.error,
          AppColors.error.withValues(alpha: 0.12),
        ),
      'scheduled' || 'confirmed' => (
          AppColors.info,
          AppColors.info.withValues(alpha: 0.12),
        ),
      'submitted' || 'payment_active' => (
          AppColors.info,
          AppColors.info.withValues(alpha: 0.12),
        ),
      'under_review' || 'contract_pending' => (
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0.14),
        ),
      'draft' => (
          AppColors.slate400,
          AppColors.neutral700.withValues(alpha: 0.35),
        ),
      _ => (AppColors.slate400, AppColors.neutral700.withValues(alpha: 0.3)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Horizontal quick-action strip matching the client home mockup.
class ClientQuickActionStrip extends StatelessWidget {
  const ClientQuickActionStrip({
    super.key,
    required this.actions,
  });

  final List<ClientQuickActionStripItem> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actions.map((action) {
        return Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: action.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            action.icon,
                            color: AppColors.gold,
                            size: 22,
                          ),
                        ),
                        if (action.badge != null && action.badge! > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                action.badge! > 99
                                    ? '99+'
                                    : '${action.badge}',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ClientQuickActionStripItem {
  const ClientQuickActionStripItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;
}

/// Circular profile completion gauge for the dashboard mockup.
class ClientCircularGauge extends StatelessWidget {
  const ClientCircularGauge({
    super.key,
    required this.percent,
    this.size = 72,
    this.strokeWidth = 6,
  });

  final double percent;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped / 100,
              strokeWidth: strokeWidth,
              backgroundColor: AppColors.neutral800,
              color: AppColors.gold,
            ),
          ),
          Text(
            '${clamped.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Bottom referrals CTA banner from the client home mockup.
class ClientReferralsBanner extends StatelessWidget {
  const ClientReferralsBanner({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurface,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.25),
            ),
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.08),
                AppColors.darkSurface,
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.users,
                  color: AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Referrals',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share HD Homes with family and friends. Get rewarded for every successful referral.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate400,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.charcoal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Invite & Earn'),
                    SizedBox(width: 4),
                    Icon(LucideIcons.chevronRight, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashboard loading chrome — mirrors investor portal skeletons.
class ClientDashboardSkeleton extends StatelessWidget {
  const ClientDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= AppBreakpoints.tablet ? 24.0 : 16.0;
    final wide = w >= AppBreakpoints.tablet;

    return Semantics(
      label: 'Loading dashboard',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          LoadingSkeleton(
            height: wide ? 220 : 200,
            borderRadius: BorderRadius.zero,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
            child: Column(
              children: [
                if (wide)
                  const Row(
                    children: [
                      Expanded(child: LoadingSkeleton(height: 88)),
                      SizedBox(width: 12),
                      Expanded(child: LoadingSkeleton(height: 88)),
                      SizedBox(width: 12),
                      Expanded(child: LoadingSkeleton(height: 88)),
                      SizedBox(width: 12),
                      Expanded(child: LoadingSkeleton(height: 88)),
                    ],
                  )
                else ...[
                  const Row(
                    children: [
                      Expanded(child: LoadingSkeleton(height: 88)),
                      SizedBox(width: 12),
                      Expanded(child: LoadingSkeleton(height: 88)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: LoadingSkeleton(height: 88)),
                      SizedBox(width: 12),
                      Expanded(child: LoadingSkeleton(height: 88)),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const LoadingSkeleton(height: 72),
                const SizedBox(height: 28),
                const LoadingSkeleton(height: 160),
                const SizedBox(height: 16),
                const LoadingSkeleton(height: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic list/page skeleton for client portal modules.
class ClientPageSkeleton extends StatelessWidget {
  const ClientPageSkeleton({
    super.key,
    this.showKpis = true,
    this.rows = 5,
  });

  final bool showKpis;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= AppBreakpoints.tablet ? 24.0 : 16.0;
    final wide = w >= AppBreakpoints.tablet;

    return Semantics(
      label: 'Loading',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(pad),
        children: [
          const LoadingSkeleton(width: 180, height: 28),
          const SizedBox(height: 8),
          const LoadingSkeleton(width: 260, height: 14),
          const SizedBox(height: 20),
          if (showKpis) ...[
            if (wide)
              const Row(
                children: [
                  Expanded(child: LoadingSkeleton(height: 88)),
                  SizedBox(width: 12),
                  Expanded(child: LoadingSkeleton(height: 88)),
                  SizedBox(width: 12),
                  Expanded(child: LoadingSkeleton(height: 88)),
                ],
              )
            else
              const Row(
                children: [
                  Expanded(child: LoadingSkeleton(height: 88)),
                  SizedBox(width: 12),
                  Expanded(child: LoadingSkeleton(height: 88)),
                ],
              ),
            const SizedBox(height: 20),
          ],
          const LoadingSkeleton(height: 44),
          const SizedBox(height: 16),
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const LoadingSkeleton(height: 88),
          ],
        ],
      ),
    );
  }
}

/// Compact card-sized skeleton for nested async sections.
class ClientCardSkeleton extends StatelessWidget {
  const ClientCardSkeleton({super.key, this.height = 88});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LoadingSkeleton(height: height),
      ),
    );
  }
}
