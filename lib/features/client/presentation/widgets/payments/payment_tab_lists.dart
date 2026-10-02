import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_payment_engine_models.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PaymentScheduleList extends StatelessWidget {
  const PaymentScheduleList({
    super.key,
    required this.installments,
    required this.padding,
    required this.onRefresh,
    this.onPayInstallment,
  });

  final List<ClientInstallment> installments;
  final EdgeInsets padding;
  final Future<void> Function() onRefresh;
  final void Function(ClientInstallment)? onPayInstallment;

  @override
  Widget build(BuildContext context) {
    if (installments.isEmpty) {
      return _ScrollableEmpty(
        onRefresh: onRefresh,
        child: const ClientEmptyState(
          title: 'No installments scheduled',
          message:
              'Your payment schedule will appear here once Finance sets it up.',
          icon: LucideIcons.calendar,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: installments.length,
        itemBuilder: (context, index) {
          final i = installments[index];
          final isOverdue =
              i.isPayable && i.dueDate.isBefore(DateTime.now());
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClientPortalCard(
              child: Row(
                children: [
                  Icon(
                    isOverdue
                        ? LucideIcons.alertTriangle
                        : LucideIcons.calendar,
                    color: isOverdue ? AppColors.warning : AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.propertyTitle ?? 'Installment',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Due ${DateFormat.yMMMd().format(i.dueDate)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        ClientStatusChip(status: i.status),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        i.formattedPayable,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: i.isPayable
                                  ? AppColors.gold
                                  : AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (i.isPayable && onPayInstallment != null) ...[
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => onPayInstallment!(i),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.charcoal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Pay'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PaymentHistoryList extends StatelessWidget {
  const PaymentHistoryList({
    super.key,
    required this.items,
    required this.padding,
    required this.onRefresh,
  });

  final List<ClientPaymentHistoryItem> items;
  final EdgeInsets padding;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _ScrollableEmpty(
        onRefresh: onRefresh,
        child: const ClientEmptyState(
          title: 'No payment history yet',
          message:
              'Completed payments and submissions awaiting verification appear here.',
          icon: LucideIcons.receipt,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClientPortalCard(
              child: Row(
                children: [
                  Icon(
                    item.isPendingVerification
                        ? LucideIcons.clock
                        : LucideIcons.checkCircle2,
                    color: item.isPendingVerification
                        ? AppColors.warning
                        : AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.formattedAmount,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (item.propertyTitle != null) item.propertyTitle,
                            if (item.occurredAt != null)
                              DateFormat.yMMMd().format(item.occurredAt!),
                            if (item.reference != null) item.reference,
                          ].whereType<String>().join(' · '),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        ClientStatusChip(status: item.status),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PaymentReceiptsList extends StatelessWidget {
  const PaymentReceiptsList({
    super.key,
    required this.receipts,
    required this.padding,
    required this.onRefresh,
  });

  final List<ClientFinanceReceipt> receipts;
  final EdgeInsets padding;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return _ScrollableEmpty(
        onRefresh: onRefresh,
        child: const ClientEmptyState(
          title: 'No receipts yet',
          message:
              'Official receipts appear after Finance verifies and completes a payment.',
          icon: LucideIcons.fileText,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: receipts.length,
        itemBuilder: (context, index) {
          final r = receipts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClientPortalCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  LucideIcons.fileText,
                  color: AppColors.gold,
                ),
                title: Text(r.receiptNumber),
                subtitle: Text(
                  [
                    r.formattedAmount,
                    if (r.propertyTitle != null) r.propertyTitle,
                    if (r.issuedAt != null)
                      DateFormat.yMMMd().format(r.issuedAt!),
                    if (r.methodLabel != null) r.methodLabel,
                  ].whereType<String>().join(' · '),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PaymentChargesList extends StatelessWidget {
  const PaymentChargesList({
    super.key,
    required this.charges,
    required this.padding,
    required this.onRefresh,
  });

  final List<ClientPaymentCharge> charges;
  final EdgeInsets padding;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (charges.isEmpty) {
      return _ScrollableEmpty(
        onRefresh: onRefresh,
        child: const ClientEmptyState(
          title: 'No charges',
          message: 'Late fees and other charges from Finance will show here.',
          icon: LucideIcons.badgeDollarSign,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: charges.length,
        itemBuilder: (context, index) {
          final c = charges[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClientPortalCard(
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.badgeDollarSign,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.description,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            c.chargeType.replaceAll('_', ' '),
                            if (c.propertyTitle != null) c.propertyTitle,
                            if (c.dueDate != null)
                              'Due ${DateFormat.yMMMd().format(c.dueDate!)}',
                          ].whereType<String>().join(' · '),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        ClientStatusChip(status: c.status),
                      ],
                    ),
                  ),
                  Text(
                    c.formattedAmount,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Empty tab body that still scrolls / pull-to-refresh under NestedScrollView.
class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty({
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 48),
        children: [child],
      ),
    );
  }
}
