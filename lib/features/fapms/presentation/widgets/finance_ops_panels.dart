import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/payment_verification_providers.dart';
import 'package:hdhomesproject/features/fapms/presentation/widgets/finance_admin_shared.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

Future<void> showCreateInvoiceSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final partyCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FinanceAdminUi.surfaceElevated,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create invoice',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: partyCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Client / party name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Amount (NGN)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Notes (optional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: FinanceAdminUi.gold,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create & send'),
            ),
          ],
        ),
      );
    },
  );
  if (ok != true) return;
  final amount = double.tryParse(amountCtrl.text.trim());
  if (partyCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
    ref
        .read(fapmsControllerProvider.notifier)
        .setMessage('Enter a valid party name and amount.');
    return;
  }
  await ref
      .read(fapmsServiceProvider)
      .createInvoice(
        partyName: partyCtrl.text.trim(),
        amount: amount,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
  ref.read(fapmsControllerProvider.notifier).setMessage('Invoice created.');
  await ref.read(fapmsControllerProvider.notifier).refresh();
}

Future<void> showCreateExpenseSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final vendorCtrl = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FinanceAdminUi.surfaceElevated,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Submit expense',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Amount (NGN)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: vendorCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Vendor (optional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: FinanceAdminUi.gold,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit for approval'),
            ),
          ],
        ),
      );
    },
  );
  if (ok != true) return;
  final amount = double.tryParse(amountCtrl.text.trim());
  if (titleCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
    ref
        .read(fapmsControllerProvider.notifier)
        .setMessage('Enter a valid title and amount.');
    return;
  }
  await ref
      .read(fapmsServiceProvider)
      .createExpense(
        title: titleCtrl.text.trim(),
        amount: amount,
        vendorLabel: vendorCtrl.text.trim().isEmpty
            ? null
            : vendorCtrl.text.trim(),
      );
  ref.read(fapmsControllerProvider.notifier).setMessage('Expense submitted.');
  await ref.read(fapmsControllerProvider.notifier).refresh();
}

Future<void> showCreateBankAccountSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final nameCtrl = TextEditingController();
  final bankCtrl = TextEditingController();
  final maskCtrl = TextEditingController();
  final balanceCtrl = TextEditingController(text: '0');
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FinanceAdminUi.surfaceElevated,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add bank account',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Account name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bankCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Bank'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maskCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Masked number (optional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: balanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: FinanceAdminUi.fieldDecoration('Opening balance (NGN)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: FinanceAdminUi.gold),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save account'),
            ),
          ],
        ),
      );
    },
  );
  if (ok != true) return;
  final balance = double.tryParse(balanceCtrl.text.trim()) ?? 0;
  if (nameCtrl.text.trim().isEmpty || bankCtrl.text.trim().isEmpty) {
    ref
        .read(fapmsControllerProvider.notifier)
        .setMessage('Enter the account name and bank.');
    return;
  }
  await ref.read(fapmsServiceProvider).createBankAccount(
        accountName: nameCtrl.text.trim(),
        bankName: bankCtrl.text.trim(),
        accountNumberMasked:
            maskCtrl.text.trim().isEmpty ? null : maskCtrl.text.trim(),
        openingBalance: balance,
      );
  ref.read(fapmsControllerProvider.notifier).setMessage('Bank account saved.');
  await ref.read(fapmsControllerProvider.notifier).refresh();
}

Future<void> showRecordBankMovementSheet({
  required BuildContext context,
  required WidgetRef ref,
  required List<FapmsBankAccount> accounts,
}) async {
  if (accounts.isEmpty) return;
  final descCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  var accountId = accounts.first.id;
  var direction = 'credit';
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FinanceAdminUi.surfaceElevated,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Record bank movement',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  dropdownColor: FinanceAdminUi.surfaceElevated,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Account'),
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.accountName)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() => accountId = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: direction,
                  dropdownColor: FinanceAdminUi.surfaceElevated,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Direction'),
                  items: const [
                    DropdownMenuItem(value: 'credit', child: Text('Money in')),
                    DropdownMenuItem(value: 'debit', child: Text('Money out')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setLocal(() => direction = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Description'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Amount (NGN)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Reference (optional)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: FinanceAdminUi.gold,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Post movement'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  if (ok != true) return;
  final amount = double.tryParse(amountCtrl.text.trim());
  if (descCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
    ref
        .read(fapmsControllerProvider.notifier)
        .setMessage('Enter a description and amount.');
    return;
  }
  await ref.read(fapmsServiceProvider).recordBankMovement(
        bankAccountId: accountId,
        description: descCtrl.text.trim(),
        amount: amount,
        direction: direction,
        reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
      );
  ref.read(fapmsControllerProvider.notifier).setMessage('Bank movement posted.');
  await ref.read(fapmsControllerProvider.notifier).refresh();
}

Future<void> showGenerateInstallmentsSheet({
  required BuildContext context,
  required WidgetRef ref,
  FapmsDepositApplication? fromApp,
}) async {
  final clientCtrl = TextEditingController(text: fromApp?.clientId ?? '');
  final propertyCtrl = TextEditingController(text: fromApp?.propertyId ?? '');
  final totalCtrl = TextEditingController(
    text: fromApp?.amountOffered?.toStringAsFixed(0) ?? '',
  );
  final depositCtrl = TextEditingController(
    text: fromApp?.amountOffered?.toStringAsFixed(0) ?? '',
  );
  final countCtrl = TextEditingController(text: '6');
  final planCtrl = TextEditingController(text: fromApp?.paymentPlan ?? '');

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FinanceAdminUi.surfaceElevated,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fromApp == null
                    ? 'Generate installment schedule'
                    : 'Schedule from application',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              if (fromApp != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    fromApp.propertyTitle ?? 'Property',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    [
                      'Client ${fromApp.clientId.substring(0, 8)}…',
                      if (fromApp.paymentPlan != null) fromApp.paymentPlan!,
                      fromApp.amountDisplay,
                    ].join(' · '),
                    style: const TextStyle(color: FinanceAdminUi.muted),
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                TextField(
                  controller: clientCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Client ID'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: propertyCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Property ID'),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: FinanceAdminUi.fieldDecoration('Total amount'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: depositCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: FinanceAdminUi.fieldDecoration(
                  'Deposit amount (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: FinanceAdminUi.fieldDecoration(
                  'Monthly installments after deposit',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: planCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: FinanceAdminUi.fieldDecoration('Plan label'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FinanceAdminUi.gold,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Generate schedule'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (ok != true) return;
  final total = double.tryParse(totalCtrl.text.trim());
  final deposit = double.tryParse(depositCtrl.text.trim()) ?? 0;
  final count = int.tryParse(countCtrl.text.trim()) ?? 0;
  if (clientCtrl.text.trim().isEmpty ||
      propertyCtrl.text.trim().isEmpty ||
      total == null ||
      total <= 0) {
    ref
        .read(fapmsControllerProvider.notifier)
        .setMessage('Client, property, and total amount are required.');
    return;
  }
  if (fromApp != null) {
    await ref
        .read(fapmsServiceProvider)
        .createDepositFromApplication(
          applicationId: fromApp.id,
          depositAmount: deposit > 0 ? deposit : null,
          installmentCount: count,
        );
  } else {
    await ref
        .read(fapmsServiceProvider)
        .generateInstallments(
          clientId: clientCtrl.text.trim(),
          propertyId: propertyCtrl.text.trim(),
          totalAmount: total,
          depositAmount: deposit,
          installmentCount: count,
          paymentPlanLabel: planCtrl.text.trim().isEmpty
              ? null
              : planCtrl.text.trim(),
        );
  }
  ref
      .read(fapmsControllerProvider.notifier)
      .setMessage('Installment schedule generated for the client portal.');
  await ref.read(fapmsControllerProvider.notifier).refresh();
}

Future<void> showCreateDistributionSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final investorCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  var type = 'dividend';
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FinanceAdminUi.surfaceElevated,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create investor distribution',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: investorCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Investor ID'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Amount (NGN)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  dropdownColor: FinanceAdminUi.surfaceElevated,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration('Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'dividend',
                      child: Text('Dividend'),
                    ),
                    DropdownMenuItem(value: 'roi', child: Text('ROI')),
                    DropdownMenuItem(value: 'refund', child: Text('Refund')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? 'dividend'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: FinanceAdminUi.fieldDecoration(
                    'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: FinanceAdminUi.gold,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create distribution'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  if (ok != true) return;
  final amount = double.tryParse(amountCtrl.text.trim());
  if (investorCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
    ref
        .read(fapmsControllerProvider.notifier)
        .setMessage('Investor ID and amount are required.');
    return;
  }
  await ref
      .read(fapmsServiceProvider)
      .createDistribution(
        investorId: investorCtrl.text.trim(),
        amount: amount,
        distributionType: type,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
  ref
      .read(fapmsControllerProvider.notifier)
      .setMessage('Distribution created.');
  await ref.read(fapmsControllerProvider.notifier).refresh();
}

Future<void> _replyToCalculatorLead(
  BuildContext context,
  WidgetRef ref,
  FapmsCalculatorLead lead,
) async {
  final replyCtrl = TextEditingController(text: lead.adminReply);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: FinanceAdminUi.surfaceElevated,
        title: Text('Reply to ${lead.fullName}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: replyCtrl,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Reply the client sees',
              helperText:
                  'Shown under the calculator on the public site, client portal, and investor portal.',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FinanceAdminUi.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send reply'),
          ),
        ],
      );
    },
  );
  final reply = replyCtrl.text.trim();
  replyCtrl.dispose();
  if (ok != true || reply.isEmpty) return;
  await ref
      .read(fapmsServiceProvider)
      .replyCalculatorLead(
        applicationId: lead.id,
        reply: reply,
        status: lead.status == 'new' ? 'contacted' : null,
      );
  ref
      .read(fapmsControllerProvider.notifier)
      .setMessage(
        'Reply saved. The applicant can read it under the payment calculator.',
      );
  await ref.read(fapmsControllerProvider.notifier).refresh();
}

class FinanceLeadsTab extends ConsumerWidget {
  const FinanceLeadsTab({super.key, required this.snap});

  final FapmsCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref
        .watch(fapmsControllerProvider)
        .searchQuery
        .trim()
        .toLowerCase();
    final rows = snap.calculatorLeads.where((l) {
      if (q.isEmpty) return true;
      return l.fullName.toLowerCase().contains(q) ||
          (l.email?.toLowerCase().contains(q) ?? false) ||
          (l.phone?.toLowerCase().contains(q) ?? false) ||
          l.status.toLowerCase().contains(q);
    }).toList();

    if (rows.isEmpty) {
      return const FinanceEmptyState(
        title: 'No calculator leads',
        message:
            'Website payment-calculator submissions appear here for finance follow-up.',
        icon: LucideIcons.calculator,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final lead = rows[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FinanceAdminUi.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FinanceAdminUi.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lead.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FinanceStatusPill(label: lead.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (lead.email != null) lead.email!,
                  if (lead.phone != null) lead.phone!,
                  if (lead.durationMonths != null) '${lead.durationMonths} mo',
                ].join(' · '),
                style: const TextStyle(
                  color: FinanceAdminUi.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Price ${lead.priceDisplay} · Deposit ${lead.depositDisplay}'
                '${lead.monthlyPayment != null ? ' · Monthly ${formatFapmsMoney(lead.monthlyPayment)}' : ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (lead.city.isNotEmpty || lead.occupation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (lead.city.isNotEmpty) lead.city,
                    if (lead.occupation.isNotEmpty) lead.occupation,
                    'Prefers ${lead.preferredContactLabel}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: FinanceAdminUi.muted,
                    fontSize: 12,
                  ),
                ),
              ],
              if (lead.applicantMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lead.applicantMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              if (lead.hasReply) ...[
                const SizedBox(height: 8),
                Text(
                  'Reply the client sees: ${lead.adminReply}',
                  style: const TextStyle(
                    color: FinanceAdminUi.gold,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FinanceAdminUi.gold,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _replyToCalculatorLead(context, ref, lead),
                    child: const Text('Reply to client'),
                  ),
                  if (lead.canConvert) ...[
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: FinanceAdminUi.gold,
                        foregroundColor: Colors.black,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        await ref
                            .read(fapmsServiceProvider)
                            .convertCalculatorLead(
                              applicationId: lead.id,
                              status: 'converted',
                              createInvoice: true,
                            );
                        ref
                            .read(fapmsControllerProvider.notifier)
                            .setMessage(
                              'Lead converted — invoice created when amount > 0.',
                            );
                        await ref
                            .read(fapmsControllerProvider.notifier)
                            .refresh();
                      },
                      child: const Text('Convert + invoice'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        await ref
                            .read(fapmsServiceProvider)
                            .convertCalculatorLead(
                              applicationId: lead.id,
                              status: 'contacted',
                              createInvoice: false,
                            );
                        await ref
                            .read(fapmsControllerProvider.notifier)
                            .refresh();
                      },
                      child: const Text('Mark contacted'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(fapmsServiceProvider)
                            .convertCalculatorLead(
                              applicationId: lead.id,
                              status: 'closed',
                              createInvoice: false,
                            );
                        await ref
                            .read(fapmsControllerProvider.notifier)
                            .refresh();
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class FinanceCommissionsTab extends ConsumerWidget {
  const FinanceCommissionsTab({super.key, required this.snap});

  final FapmsCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref
        .watch(fapmsControllerProvider)
        .searchQuery
        .trim()
        .toLowerCase();
    final rows = snap.commissions.where((c) {
      if (q.isEmpty) return true;
      return (c.label?.toLowerCase().contains(q) ?? false) ||
          (c.referralCode?.toLowerCase().contains(q) ?? false) ||
          c.source.toLowerCase().contains(q) ||
          c.status.toLowerCase().contains(q);
    }).toList();

    if (rows.isEmpty) {
      return const FinanceEmptyState(
        title: 'No commissions',
        message:
            'Client, investor, and sales referral commissions appear here for approval and payout.',
        icon: LucideIcons.percent,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = rows[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FinanceAdminUi.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FinanceAdminUi.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.label ?? c.source,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FinanceStatusPill(label: c.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  c.source.replaceAll('_', ' '),
                  if (c.referralCode != null) c.referralCode!,
                ].join(' · '),
                style: const TextStyle(
                  color: FinanceAdminUi.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                c.amountDisplay,
                style: const TextStyle(
                  color: FinanceAdminUi.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (c.canApprove || c.canPay) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (c.canApprove)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: FinanceAdminUi.info,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          await ref
                              .read(fapmsServiceProvider)
                              .setCommissionStatus(
                                source: c.source,
                                commissionId: c.id,
                                status: 'approved',
                              );
                          ref
                              .read(fapmsControllerProvider.notifier)
                              .setMessage('Commission approved.');
                          await ref
                              .read(fapmsControllerProvider.notifier)
                              .refresh();
                        },
                        child: const Text('Approve'),
                      ),
                    if (c.canPay) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: FinanceAdminUi.success,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          await ref
                              .read(fapmsServiceProvider)
                              .setCommissionStatus(
                                source: c.source,
                                commissionId: c.id,
                                status: 'paid',
                              );
                          ref
                              .read(fapmsControllerProvider.notifier)
                              .setMessage('Commission marked paid.');
                          await ref
                              .read(fapmsControllerProvider.notifier)
                              .refresh();
                        },
                        child: const Text('Mark paid'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class FinanceInstallmentsTab extends ConsumerWidget {
  const FinanceInstallmentsTab({super.key, required this.snap});

  final FapmsCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref
        .watch(fapmsControllerProvider)
        .searchQuery
        .trim()
        .toLowerCase();
    final rows = snap.installments.where((i) {
      if (q.isEmpty) return true;
      return i.propertyTitle?.toLowerCase().contains(q) == true ||
          i.status.toLowerCase().contains(q) ||
          i.clientId?.toLowerCase().contains(q) == true;
    }).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Client schedules & deposits',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: FinanceAdminUi.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: FinanceAdminUi.gold,
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () =>
                  showGenerateInstallmentsSheet(context: context, ref: ref),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Schedule'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (snap.depositApplications.isNotEmpty) ...[
          FinanceAdminCard(
            title: 'Application deposit queue',
            subtitle:
                'Approved / payment-pending applications ready for schedules',
            child: Column(
              children: [
                for (final app in snap.depositApplications.take(12))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      app.propertyTitle ?? 'Property',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      [
                        app.status,
                        if (app.paymentPlan != null) app.paymentPlan!,
                        app.amountDisplay,
                      ].join(' · '),
                      style: const TextStyle(
                        color: FinanceAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => showGenerateInstallmentsSheet(
                        context: context,
                        ref: ref,
                        fromApp: app,
                      ),
                      child: const Text('Schedule'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (snap.charges.isNotEmpty) ...[
          FinanceAdminCard(
            title: 'Charges & late fees',
            subtitle: '${snap.openChargeCount} open',
            child: Column(
              children: [
                for (final c in snap.charges.take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      c.description,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      [
                        c.status,
                        if (c.propertyTitle != null) c.propertyTitle!,
                        c.amountDisplay,
                      ].join(' · '),
                      style: const TextStyle(
                        color: FinanceAdminUi.muted,
                        fontSize: 11,
                      ),
                    ),
                    trailing: c.canWaive
                        ? TextButton(
                            onPressed: () async {
                              final reason = await _promptReason(
                                context,
                                title: 'Waive charge',
                              );
                              if (reason == null || reason.isEmpty) return;
                              await ref
                                  .read(paymentVerificationServiceProvider)
                                  .waiveCharge(c.id, reason);
                              ref
                                  .read(fapmsControllerProvider.notifier)
                                  .setMessage('Charge waived.');
                              await ref
                                  .read(fapmsControllerProvider.notifier)
                                  .refresh();
                            },
                            child: const Text('Waive'),
                          )
                        : FinanceStatusPill(label: c.status),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (rows.isEmpty)
          const FinanceEmptyState(
            title: 'No installments',
            message:
                'Generate a schedule so clients can pay deposits and installments from the portal.',
            icon: LucideIcons.calendarDays,
          )
        else
          for (final i in rows) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FinanceAdminUi.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FinanceAdminUi.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.label,
                          style: const TextStyle(
                            color: FinanceAdminUi.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          i.propertyTitle ?? 'Property',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Due ${DateFormat('dd MMM yyyy').format(i.dueDate)} · '
                          'Outstanding ${i.outstandingDisplay}',
                          style: const TextStyle(
                            color: FinanceAdminUi.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        i.amountDisplay,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FinanceStatusPill(
                        label: i.status,
                        color: i.isOverdue || i.status == 'overdue'
                            ? FinanceAdminUi.danger
                            : FinanceAdminUi.gold,
                      ),
                      if (i.status != 'paid' && i.status != 'cancelled') ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(fapmsServiceProvider)
                                .updateInstallmentStatus(
                                  installmentId: i.id,
                                  status: 'paid',
                                );
                            ref
                                .read(fapmsControllerProvider.notifier)
                                .setMessage('Installment marked paid.');
                            await ref
                                .read(fapmsControllerProvider.notifier)
                                .refresh();
                          },
                          child: const Text('Mark paid'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}

class FinanceReceiptsSection extends StatelessWidget {
  const FinanceReceiptsSection({super.key, required this.receipts});

  final List<FapmsReceipt> receipts;

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'No receipts issued yet. They appear when client transfers are verified.',
          style: TextStyle(color: FinanceAdminUi.muted, fontSize: 13),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Receipts',
          style: TextStyle(
            color: FinanceAdminUi.muted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        for (final r in receipts.take(40))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FinanceAdminUi.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FinanceAdminUi.border),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.receipt,
                  color: FinanceAdminUi.gold,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.receiptNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        [
                          if (r.payerLabel != null) r.payerLabel!,
                          if (r.methodLabel != null) r.methodLabel!,
                          if (r.issuedAt != null)
                            DateFormat('dd MMM yyyy').format(r.issuedAt!),
                        ].join(' · '),
                        style: const TextStyle(
                          color: FinanceAdminUi.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  r.amountDisplay,
                  style: const TextStyle(
                    color: FinanceAdminUi.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class FinanceInvestorOpsTab extends ConsumerWidget {
  const FinanceInvestorOpsTab({
    super.key,
    required this.snap,
    required this.onConfirmIntent,
    required this.onRejectIntent,
  });

  final FapmsCommandCenterSnapshot snap;
  final Future<void> Function(String id) onConfirmIntent;
  final Future<void> Function(String id) onRejectIntent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        FinanceAdminCard(
          title: 'Inbound transfer queue',
          subtitle: 'Confirm investor bank transfers from the portal',
          child: snap.investorIntents.isEmpty
              ? const Text(
                  'No investor transfer intents.',
                  style: TextStyle(color: FinanceAdminUi.muted),
                )
              : Column(
                  children: [
                    for (final intent in snap.investorIntents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    intent.amountDisplay,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    [
                                      intent.status,
                                      if (intent.providerReference != null)
                                        intent.providerReference!,
                                    ].join(' · '),
                                    style: const TextStyle(
                                      color: FinanceAdminUi.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (intent.isPending) ...[
                              TextButton(
                                onPressed: () => onConfirmIntent(intent.id),
                                child: const Text('Confirm'),
                              ),
                              TextButton(
                                onPressed: () => onRejectIntent(intent.id),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(
                                    color: FinanceAdminUi.danger,
                                  ),
                                ),
                              ),
                            ] else
                              FinanceStatusPill(label: intent.status),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        FinanceAdminCard(
          title: 'Distributions',
          subtitle: 'Create and mark investor payouts from Finance',
          trailing: TextButton(
            onPressed: () =>
                showCreateDistributionSheet(context: context, ref: ref),
            child: const Text('Create'),
          ),
          child: snap.distributions.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No distributions yet.',
                      style: TextStyle(color: FinanceAdminUi.muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: FinanceAdminUi.gold,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => showCreateDistributionSheet(
                        context: context,
                        ref: ref,
                      ),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Create distribution'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (final d in snap.distributions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          d.investorName ?? d.investorId,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          [
                            d.distributionType,
                            if (d.reference != null) d.reference!,
                            d.status,
                          ].join(' · '),
                          style: const TextStyle(
                            color: FinanceAdminUi.muted,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              d.amountDisplay,
                              style: const TextStyle(
                                color: FinanceAdminUi.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (d.canMarkPaid)
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(fapmsServiceProvider)
                                      .setDistributionStatus(
                                        distributionId: d.id,
                                        status: 'paid',
                                      );
                                  ref
                                      .read(fapmsControllerProvider.notifier)
                                      .setMessage('Distribution marked paid.');
                                  await ref
                                      .read(fapmsControllerProvider.notifier)
                                      .refresh();
                                },
                                child: const Text('Pay'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        FinanceAdminCard(
          title: 'Investment receiving accounts',
          subtitle: 'Bank details shown to investors for funding',
          trailing: TextButton(
            onPressed: () => _editInvestmentAccount(context, ref),
            child: const Text('Add'),
          ),
          child: snap.investmentReceivingAccounts.isEmpty
              ? const Text(
                  'No investment receiving accounts configured.',
                  style: TextStyle(color: FinanceAdminUi.muted),
                )
              : Column(
                  children: [
                    for (final a in snap.investmentReceivingAccounts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          a.accountName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${a.bankName} · ${a.accountNumber}'
                          '${a.isPrimary ? ' · PRIMARY' : ''}'
                          '${a.isActive ? '' : ' · inactive'}',
                          style: const TextStyle(
                            color: FinanceAdminUi.muted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          color: Colors.white54,
                          onPressed: () =>
                              _editInvestmentAccount(context, ref, existing: a),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _editInvestmentAccount(
    BuildContext context,
    WidgetRef ref, {
    FapmsInvestmentReceivingAccount? existing,
  }) async {
    final bank = TextEditingController(text: existing?.bankName ?? '');
    final name = TextEditingController(text: existing?.accountName ?? '');
    final number = TextEditingController(text: existing?.accountNumber ?? '');
    final instructions = TextEditingController(
      text: existing?.instructions ?? '',
    );
    var isPrimary = existing?.isPrimary ?? false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FinanceAdminUi.surfaceElevated,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: bank,
                    style: const TextStyle(color: Colors.white),
                    decoration: FinanceAdminUi.fieldDecoration('Bank name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    style: const TextStyle(color: Colors.white),
                    decoration: FinanceAdminUi.fieldDecoration('Account name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: number,
                    style: const TextStyle(color: Colors.white),
                    decoration: FinanceAdminUi.fieldDecoration(
                      'Account number',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: instructions,
                    style: const TextStyle(color: Colors.white),
                    decoration: FinanceAdminUi.fieldDecoration('Instructions'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Primary account',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: isPrimary,
                    activeThumbColor: FinanceAdminUi.gold,
                    onChanged: (v) => setLocal(() => isPrimary = v),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: FinanceAdminUi.gold,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok != true) return;
    await ref
        .read(fapmsServiceProvider)
        .upsertInvestmentReceivingAccount(
          id: existing?.id,
          bankName: bank.text.trim(),
          accountName: name.text.trim(),
          accountNumber: number.text.trim(),
          instructions: instructions.text.trim().isEmpty
              ? null
              : instructions.text.trim(),
          isPrimary: isPrimary,
        );
    ref
        .read(fapmsControllerProvider.notifier)
        .setMessage('Investment receiving account saved.');
    await ref.read(fapmsControllerProvider.notifier).refresh();
  }
}

class FinancePaymentSettingsCard extends ConsumerWidget {
  const FinancePaymentSettingsCard({super.key, required this.settings});

  final FapmsPaymentSettings? settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    final policy = switch (s?.overpaymentPolicy) {
      'hold_for_review' || 'apply_to_next' || 'reject' => s!.overpaymentPolicy,
      _ => 'reject',
    };
    return FinanceAdminCard(
      title: 'Client payment policy',
      subtitle: 'Controls the live client portal payment engine',
      child: s == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment settings are not initialized. Create defaults to enable the live client portal payment engine.',
                  style: TextStyle(color: FinanceAdminUi.muted),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: FinanceAdminUi.gold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    await ref
                        .read(fapmsServiceProvider)
                        .updatePaymentSettings(
                          allowPartial: true,
                          overpaymentPolicy: 'reject',
                          requireTransferProof: true,
                        );
                    ref
                        .read(fapmsControllerProvider.notifier)
                        .setMessage('Payment settings initialized.');
                    await ref.read(fapmsControllerProvider.notifier).refresh();
                  },
                  child: const Text('Initialize defaults'),
                ),
              ],
            )
          : Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Allow partial payments',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: s.allowPartialPayments,
                  activeThumbColor: FinanceAdminUi.gold,
                  onChanged: (v) async {
                    await ref
                        .read(fapmsServiceProvider)
                        .updatePaymentSettings(allowPartial: v);
                    await ref.read(fapmsControllerProvider.notifier).refresh();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Require transfer proof',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: s.requireTransferProof,
                  activeThumbColor: FinanceAdminUi.gold,
                  onChanged: (v) async {
                    await ref
                        .read(fapmsServiceProvider)
                        .updatePaymentSettings(requireTransferProof: v);
                    await ref.read(fapmsControllerProvider.notifier).refresh();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Overpayment policy',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    s.overpaymentPolicy,
                    style: const TextStyle(color: FinanceAdminUi.muted),
                  ),
                  trailing: DropdownButton<String>(
                    value: policy,
                    dropdownColor: FinanceAdminUi.surfaceElevated,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: 'reject',
                        child: Text('Reject overpayment'),
                      ),
                      DropdownMenuItem(
                        value: 'hold_for_review',
                        child: Text('Hold for review'),
                      ),
                      DropdownMenuItem(
                        value: 'apply_to_next',
                        child: Text('Apply to next installment'),
                      ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await ref
                          .read(fapmsServiceProvider)
                          .updatePaymentSettings(overpaymentPolicy: v);
                      await ref
                          .read(fapmsControllerProvider.notifier)
                          .refresh();
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

Future<String?> _promptReason(BuildContext context, {required String title}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: FinanceAdminUi.surfaceElevated,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: FinanceAdminUi.fieldDecoration('Reason'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}
