import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_payment_engine_models.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PaymentDetailsStep extends StatelessWidget {
  const PaymentDetailsStep({
    super.key,
    required this.installment,
    required this.properties,
    required this.propertyId,
    required this.onPropertyChanged,
    required this.amountCtrl,
    required this.amountDue,
    required this.charges,
    required this.chargesTotal,
    required this.fmt,
  });

  final ClientInstallment? installment;
  final List<ClientProperty> properties;
  final String? propertyId;
  final ValueChanged<String?> onPropertyChanged;
  final TextEditingController amountCtrl;
  final double amountDue;
  final List<ClientPaymentCharge> charges;
  final double chargesTotal;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final total = amountDue + chargesTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (installment != null)
          ClientPortalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  installment!.propertyTitle ?? 'Installment',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Due ${DateFormat.yMMMd().format(installment!.dueDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ],
            ),
          )
        else ...[
          if (properties.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: propertyId,
              decoration: const InputDecoration(labelText: 'Property'),
              items: properties
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.propertyId,
                      child: Text(p.title, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onPropertyChanged,
            ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (NGN)',
              prefixText: '₦ ',
            ),
          ),
        ],
        const SizedBox(height: 16),
        ClientPortalCard(
          child: Column(
            children: [
              _kv(context, 'Amount due', fmt.format(amountDue)),
              if (charges.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...charges.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _kv(context, c.description, c.formattedAmount),
                  ),
                ),
              ],
              const Divider(height: 20, color: Color(0xFF2A3140)),
              _kv(
                context,
                'Total to pay',
                fmt.format(total),
                emphasize: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: emphasize ? AppColors.gold : AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class PaymentMethodStep extends StatelessWidget {
  const PaymentMethodStep({
    super.key,
    required this.methods,
    required this.selected,
    required this.onSelect,
  });

  final List<ClientPaymentMethodOption> methods;
  final ClientPaymentMethodOption? selected;
  final ValueChanged<ClientPaymentMethodOption> onSelect;

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty) {
      return const ClientEmptyState(
        title: 'No payment methods available',
        message:
            'Finance has not enabled bank transfer yet. That is the payment path this portal can submit for confirmation.',
        icon: LucideIcons.wallet,
      );
    }
    return Column(
      children: methods.map((m) {
        final selectedNow = selected?.id == m.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClientPortalCard(
            onTap: () => onSelect(m),
            child: Row(
              children: [
                Icon(
                  m.isBankTransfer
                      ? LucideIcons.landmark
                      : LucideIcons.creditCard,
                  color: AppColors.gold,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (m.isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (m.clientDescription != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          m.clientDescription!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selectedNow
                      ? LucideIcons.checkCircle2
                      : LucideIcons.circle,
                  color: selectedNow ? AppColors.gold : AppColors.neutral600,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class BankInstructionsStep extends StatelessWidget {
  const BankInstructionsStep({
    super.key,
    required this.account,
    required this.accounts,
    required this.onSelectAccount,
    required this.amountPreview,
    required this.fmt,
  });

  final CompanyReceivingAccount? account;
  final List<CompanyReceivingAccount> accounts;
  final ValueChanged<CompanyReceivingAccount> onSelectAccount;
  final double amountPreview;
  final NumberFormat fmt;

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (account == null) {
      return const ClientEmptyState(
        title: 'No receiving account',
        message: 'Official HD Homes bank details are not available yet.',
        icon: LucideIcons.landmark,
      );
    }
    final a = account!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (accounts.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: a.id,
            decoration: const InputDecoration(labelText: 'Receiving account'),
            items: accounts
                .map(
                  (acc) => DropdownMenuItem(
                    value: acc.id,
                    child: Text('${acc.bankName} · ${acc.accountNumber}'),
                  ),
                )
                .toList(),
            onChanged: (id) {
              final match = accounts.where((e) => e.id == id);
              if (match.isNotEmpty) onSelectAccount(match.first);
            },
          ),
          const SizedBox(height: 12),
        ],
        ClientPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer exactly ${fmt.format(amountPreview)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              _copyRow(context, 'Bank', a.bankName),
              _copyRow(context, 'Account name', a.accountName),
              _copyRow(context, 'Account number', a.accountNumber),
              if (a.paymentInstructions != null) ...[
                const SizedBox(height: 12),
                Text(
                  a.paymentInstructions!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.35,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClientPortalCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.info, size: 18, color: AppColors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'After you transfer, you will receive a unique HDH-PAY '
                  'reference when you submit. Use that reference as narration '
                  'on future transfers when possible. Finance verifies every '
                  'submission — payment is never marked completed here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _copyRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            onPressed: () => _copy(context, label, value),
            icon: const Icon(LucideIcons.copy, size: 18, color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}

class SubmitTransferStep extends StatelessWidget {
  const SubmitTransferStep({
    super.key,
    required this.amountCtrl,
    required this.senderNameCtrl,
    required this.senderBankCtrl,
    required this.txnRefCtrl,
    required this.noteCtrl,
    required this.transferDate,
    required this.onPickDate,
    required this.proofName,
    required this.onPickProof,
    required this.onClearProof,
  });

  final TextEditingController amountCtrl;
  final TextEditingController senderNameCtrl;
  final TextEditingController senderBankCtrl;
  final TextEditingController txnRefCtrl;
  final TextEditingController noteCtrl;
  final DateTime transferDate;
  final VoidCallback onPickDate;
  final String? proofName;
  final VoidCallback onPickProof;
  final VoidCallback onClearProof;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount transferred (NGN)',
            prefixText: '₦ ',
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onPickDate,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Transfer date'),
            child: Text(DateFormat.yMMMd().format(transferDate)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: senderNameCtrl,
          decoration: const InputDecoration(labelText: 'Sender name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: senderBankCtrl,
          decoration: const InputDecoration(labelText: 'Sender bank'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: txnRefCtrl,
          decoration: const InputDecoration(
            labelText: 'Bank transaction reference',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        ClientPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer proof',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'PDF or image (JPG, PNG, WebP). Max 10 MB.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
              const SizedBox(height: 12),
              if (proofName != null)
                Row(
                  children: [
                    const Icon(
                      LucideIcons.paperclip,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        proofName!,
                        style: const TextStyle(color: AppColors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: onClearProof,
                      icon: const Icon(LucideIcons.x, size: 16),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: onPickProof,
                  icon: const Icon(LucideIcons.upload, size: 16),
                  label: const Text('Upload proof'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class PaymentConfirmationStep extends StatelessWidget {
  const PaymentConfirmationStep({super.key, required this.result});

  final BankTransferSubmissionResult? result;

  @override
  Widget build(BuildContext context) {
    return ClientPortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.clock, color: AppColors.warning, size: 32),
          const SizedBox(height: 12),
          Text(
            'Pending verification',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transfer was submitted to Finance. It is not completed yet. '
            'You will be notified when verification finishes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.4,
                ),
          ),
          if (result != null) ...[
            const SizedBox(height: 16),
            _row(context, 'Reference', result!.paymentReference),
            _row(context, 'Amount', result!.formattedAmount),
            _row(context, 'Status', 'Pending verification'),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
