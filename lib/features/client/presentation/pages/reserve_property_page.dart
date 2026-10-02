import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shows a reservation dialog for a property. Call via:
/// `ReservePropertyDialog.show(context, ref, propertyId: '...')`
class ReservePropertyDialog {
  ReservePropertyDialog._();

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String propertyId,
    String? propertyTitle,
    double? propertyPrice,
  }) async {
    final session = ref.read(identitySessionProvider);
    if (session.userId == null) {
      context.go(RoutePaths.login);
      return;
    }

    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    var selectedPlan = 'outright';

    final plans = {
      'outright': _PlanInfo(
        'Outright Payment',
        'Pay 100% upfront within 7 days',
        1.0,
        1,
      ),
      '3_months': _PlanInfo(
        '3-Month Plan',
        '40% deposit + 2 monthly installments',
        0.40,
        3,
      ),
      '6_months': _PlanInfo(
        '6-Month Plan',
        '30% deposit + 5 monthly installments',
        0.30,
        6,
      ),
      '12_months': _PlanInfo(
        '12-Month Plan',
        '20% deposit + 11 monthly installments',
        0.20,
        12,
      ),
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final plan = plans[selectedPlan]!;
          final deposit = (propertyPrice ?? 0) * plan.depositPct;

          return AlertDialog(
            backgroundColor: AppColors.darkSurface,
            title: Row(
              children: [
                const Icon(LucideIcons.home, color: AppColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reserve ${propertyTitle ?? 'Property'}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (propertyPrice != null && propertyPrice > 0) ...[
                    ClientPortalCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Property price'),
                          Text(
                            fmt.format(propertyPrice),
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Select payment plan',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...plans.entries.map((entry) {
                    final isSelected = selectedPlan == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isSelected
                            ? AppColors.gold.withValues(alpha: 0.1)
                            : AppColors.neutral800.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () =>
                              setDialogState(() => selectedPlan = entry.key),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.gold
                                    : AppColors.neutral700
                                        .withValues(alpha: 0.4),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  size: 18,
                                  color: isSelected
                                      ? AppColors.gold
                                      : AppColors.slate500,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.value.title,
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        entry.value.description,
                                        style: const TextStyle(
                                          color: AppColors.slate400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (propertyPrice != null && propertyPrice > 0) ...[
                    const SizedBox(height: 12),
                    ClientPortalCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Initial deposit',
                                style: TextStyle(color: AppColors.slate400),
                              ),
                              Text(
                                fmt.format(deposit),
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (plan.months > 1) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Monthly installment',
                                  style: TextStyle(
                                    color: AppColors.slate400,
                                  ),
                                ),
                                Text(
                                  fmt.format(
                                    (propertyPrice - deposit) /
                                        (plan.months - 1),
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    Navigator.pop(ctx);

                    final service = ref.read(clientServiceProvider);
                    await service.reserveProperty(
                      propertyId: propertyId,
                      paymentPlan: selectedPlan,
                    );

                    ref.invalidate(clientPropertiesProvider);
                    ref.invalidate(clientPaymentsProvider);
                    ref.invalidate(clientApplicationsProvider);
                    ref.invalidate(clientDashboardProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Application submitted successfully. Track it in Applications.',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      context.go(RoutePaths.clientApplications);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Reservation failed: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(LucideIcons.checkCircle2, size: 16),
                label: const Text('Confirm Reservation'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.charcoal,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanInfo {
  const _PlanInfo(this.title, this.description, this.depositPct, this.months);
  final String title;
  final String description;
  final double depositPct;
  final int months;
}
