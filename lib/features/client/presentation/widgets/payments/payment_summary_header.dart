import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_payment_engine_models.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PaymentSummaryHeader extends StatelessWidget {
  const PaymentSummaryHeader({
    super.key,
    required this.summary,
    this.fallbackPaid = 0,
    this.fallbackOutstanding = 0,
  });

  final ClientPaymentSummary? summary;
  final double fallbackPaid;
  final double fallbackOutstanding;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final propertyValue = summary?.propertyValue ?? 0;
    final totalPaid = summary?.totalPaid ?? fallbackPaid;
    final outstanding = summary?.outstanding ?? fallbackOutstanding;
    final next = summary?.formattedNextPayment ?? '—';
    final progress = summary?.paidProgress ??
        ((totalPaid + outstanding) > 0
            ? totalPaid / (totalPaid + outstanding)
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClientKpiCard(
                label: 'Property value',
                value: fmt.format(propertyValue),
                icon: LucideIcons.building2,
                accent: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClientKpiCard(
                label: 'Total paid',
                value: fmt.format(totalPaid),
                icon: LucideIcons.checkCircle2,
                accent: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClientKpiCard(
                label: 'Outstanding',
                value: fmt.format(outstanding),
                icon: LucideIcons.alertCircle,
                accent: AppColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClientKpiCard(
                label: 'Next payment',
                value: next,
                icon: LucideIcons.calendar,
                accent: AppColors.gold,
                subtitle: summary?.nextPayment?.dueDate != null
                    ? DateFormat.yMMMd()
                        .format(summary!.nextPayment!.dueDate!)
                    : null,
              ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 14),
          ClientPortalCard(
            child: ClientProgressBar(
              label: 'Payment progress',
              percent: progress * 100,
              color: AppColors.gold,
            ),
          ),
        ],
      ],
    );
  }
}
