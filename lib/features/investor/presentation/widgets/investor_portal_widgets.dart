import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/feedback/loading_skeleton.dart';
import 'package:lucide_icons/lucide_icons.dart';


class InvestorSectionHeader extends StatelessWidget {
  const InvestorSectionHeader({
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
        child: Semantics(
          header: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 4),
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
        ),
      );
}

class InvestorKpiCard extends StatelessWidget {
  const InvestorKpiCard({
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
      return Semantics(
        button: true,
        label: '$label $value',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.cardBorder,
            child: card,
          ),
        ),
      );
    }
    return Semantics(
      label: '$label $value',
      child: card,
    );
  }
}

class InvestorEmptyState extends StatelessWidget {
  const InvestorEmptyState({
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.neutral500),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
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
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      );
}

class InvestorErrorView extends StatelessWidget {
  const InvestorErrorView({super.key, required this.message, this.onRetry});

  /// Raw exception, technical dump, or already-friendly text — always sanitized.
  final Object message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final friendly = userFacingError(message);
    final isNetwork = friendly == kNetworkErrorMessage ||
        friendly == kTimeoutErrorMessage;
    return InvestorEmptyState(
      title: isNetwork ? 'Connection problem' : 'Something went wrong',
      message: friendly,
      icon: isNetwork ? LucideIcons.wifiOff : LucideIcons.alertCircle,
      action: onRetry != null
          ? FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: const Text('Try again'),
            )
          : null,
    );
  }
}

class InvestorProgressBar extends StatelessWidget {
  const InvestorProgressBar({
    super.key,
    required this.label,
    required this.percent,
    this.color = AppColors.gold,
  });

  final String label;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                '${percent.clamp(0, 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.neutral700,
              color: color,
            ),
          ),
        ],
      );
}

class InvestorPortalCard extends StatelessWidget {
  const InvestorPortalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withValues(alpha: 0.55),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral700.withValues(alpha: 0.5)),
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );

    if (onTap == null) {
      if (semanticLabel == null) return card;
      return Semantics(label: semanticLabel, child: card);
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: card,
        ),
      ),
    );
  }
}

class InvestorSimpleBarChart extends StatelessWidget {
  const InvestorSimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = AppColors.gold,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const InvestorEmptyState(
        title: 'No chart data yet',
        icon: LucideIcons.barChart2,
      );
    }
    final max = values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final h = max > 0 ? (values[i] / max) * 80 : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.neutral400,
                          fontSize: 10,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class InvestorQuickAction extends StatelessWidget {
  const InvestorQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.darkSurface.withValues(alpha: 0.85),
        borderRadius: AppRadius.cardBorder,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                Icon(icon, color: AppColors.gold, size: 22),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.white,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class InvestorQuickActionStripItem {
  const InvestorQuickActionStripItem({
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

class InvestorQuickActionStrip extends StatelessWidget {
  const InvestorQuickActionStrip({
    super.key,
    required this.actions,
  });

  final List<InvestorQuickActionStripItem> actions;

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

class InvestorCircularGauge extends StatelessWidget {
  const InvestorCircularGauge({
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

/// Bottom referrals CTA banner matching the client portal home.
class InvestorReferralsBanner extends StatelessWidget {
  const InvestorReferralsBanner({
    super.key,
    required this.onTap,
    this.referralCode,
  });

  final VoidCallback onTap;
  final String? referralCode;

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
                  LucideIcons.gift,
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
                      'Investor referrals',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      referralCode != null && referralCode!.isNotEmpty
                          ? 'Share code $referralCode and earn when friends invest with HD Homes.'
                          : 'Invite fellow investors and earn commissions on successful referrals.',
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

/// Skeleton layout for the investor command center (Phase 4).
class InvestorDashboardSkeleton extends StatelessWidget {
  const InvestorDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= AppBreakpoints.tablet ? 24.0 : 16.0;
    final wide = w >= AppBreakpoints.tablet;

    return ListView(
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
    );
  }
}

/// Generic list/page skeleton for investor modules (Phase 14).
class InvestorPageSkeleton extends StatelessWidget {
  const InvestorPageSkeleton({
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
