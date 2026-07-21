import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Left-panel brand experience for desktop login (Smart Login gateway).
class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key});

  static const _stats = [
    (LucideIcons.building2, '50+', 'Estates delivered'),
    (LucideIcons.users, '2k+', 'Happy clients'),
    (LucideIcons.shieldCheck, '100%', 'Escrow protected'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepBlack,
            AppColors.charcoal,
            Color(0xFF2A2418),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -40,
            bottom: -40,
            child: Icon(
              LucideIcons.home,
              size: 280,
              color: AppColors.gold.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  AppTheme.logoAsset,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'HD Homes',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Secure access to your property journey',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'One identity across the Client Dashboard, Investor Portal, '
                  'and Enterprise Admin — protected by enterprise-grade session security.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.base,
                  children: _stats
                      .map(
                        (s) => SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(s.$1, color: AppColors.gold, size: 22),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                s.$2,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: AppColors.white),
                              ),
                              Text(
                                s.$3,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondaryDark),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
