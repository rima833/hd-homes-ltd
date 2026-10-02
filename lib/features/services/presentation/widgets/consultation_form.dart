import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium consultation CTA — routes into the live `/book-consultation` flow.
class ConsultationForm extends StatelessWidget {
  const ConsultationForm({
    super.key,
    this.preselectedService,
    this.onSubmitted,
  });

  /// Optional service label used as a booking query hint.
  final String? preselectedService;
  final VoidCallback? onSubmitted;

  void _openBooking(BuildContext context) {
    onSubmitted?.call();
    final service = preselectedService?.trim();
    if (service != null && service.isNotEmpty) {
      final q = Uri.encodeComponent(service);
      context.go('${RoutePaths.bookConsultation}?service=$q');
      return;
    }
    context.go(RoutePaths.bookConsultation);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkSurface,
            AppColors.charcoal.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  LucideIcons.calendarCheck,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book a private consultation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preselectedService == null
                          ? 'Choose department, meeting type, and a live slot.'
                          : 'Continue with ${preselectedService!} — pick a live slot next.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _Pill(icon: LucideIcons.phone, label: 'Phone'),
              _Pill(icon: LucideIcons.video, label: 'Video'),
              _Pill(icon: LucideIcons.mapPin, label: 'On-site'),
              _Pill(icon: LucideIcons.shieldCheck, label: 'Instant confirm'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PrimaryButton(
                label: 'Start booking',
                icon: LucideIcons.calendarPlus,
                onPressed: () => _openBooking(context),
              ),
              PrimaryButton(
                label: 'Contact hub',
                variant: ButtonVariant.ghost,
                icon: LucideIcons.messageCircle,
                onPressed: () => context.go(RoutePaths.contact),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}
