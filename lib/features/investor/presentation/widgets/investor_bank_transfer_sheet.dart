import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Multi-step bank transfer confirmation — investor submits; Finance verifies.
Future<void> showInvestorBankTransferSheet({
  required BuildContext context,
  required WidgetRef ref,
  required InvestorPaymentsBundle bundle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.charcoal,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _InvestorBankTransferSheet(bundle: bundle),
  );
}

class _InvestorBankTransferSheet extends ConsumerStatefulWidget {
  const _InvestorBankTransferSheet({required this.bundle});

  final InvestorPaymentsBundle bundle;

  @override
  ConsumerState<_InvestorBankTransferSheet> createState() =>
      _InvestorBankTransferSheetState();
}

class _InvestorBankTransferSheetState
    extends ConsumerState<_InvestorBankTransferSheet> {
  int _step = 0;
  bool _submitting = false;
  String? _error;

  InvestorHolding? _holding;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _bankRefCtrl = TextEditingController();
  final _payerBankCtrl = TextEditingController();
  DateTime _transferDate = DateTime.now();

  String? _proofName;
  Map<String, dynamic>? _proof;
  InvestorPaymentIntent? _submitted;

  InvestmentReceivingAccount? get _account =>
      widget.bundle.primaryReceivingAccount;

  @override
  void initState() {
    super.initState();
    final holdings = widget.bundle.holdings;
    if (holdings.length == 1) _holding = holdings.first;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _bankRefCtrl.dispose();
    _payerBankCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final media = ref.read(mediaServiceProvider);
    if (media == null) {
      setState(() => _error = 'Media upload is unavailable right now.');
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final record = await ref.read(investorRecordProvider.future);
      final asset = await media.upload(
        UploadMediaRequest(
          bytes: Uint8List.fromList(bytes),
          contentType: _mimeFor(file.extension) ?? 'application/octet-stream',
          originalFilename: file.name,
          entityType: MediaEntityType.investment,
          entityId: record?.id,
          folder: record == null
              ? null
              : 'hdhomes/investors/${record.id}/evidence',
          role: 'evidence',
          title: 'Payment proof',
        ),
      );
      if (!mounted) return;
      setState(() {
        _proofName = file.name;
        _proof = {
          'public_id': asset.cloudinaryPublicId ?? asset.id,
          'secure_url': asset.secureUrl ?? asset.fileUrl,
          'resource_type': asset.resourceType ?? 'image',
        };
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFacingError(e);
      });
    }
  }

  String? _mimeFor(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return null;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _transferDate = picked);
  }

  bool _validateBeforeSubmit() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid transfer amount.');
      return false;
    }
    if (_bankRefCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter the bank transfer reference you used.');
      return false;
    }
    if (_payerBankCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter the bank you transferred from.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validateBeforeSubmit()) return;
    final amount = double.parse(_amountCtrl.text.replaceAll(',', ''));
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final intent = await ref.read(investorServiceProvider).submitBankTransfer(
            amount: amount,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            receivingAccountId: _account?.id,
            bankReference: _bankRefCtrl.text.trim(),
            holdingId: _holding?.id,
            transferDate: _transferDate,
            payerBank: _payerBankCtrl.text.trim(),
            proof: _proof,
          );
      ref.invalidate(investorPaymentsProvider);
      ref.invalidate(investorDashboardProvider);
      if (!mounted) return;
      setState(() {
        _submitted = intent;
        _submitting = false;
        _step = 4;
      });
      final refCode = intent.providerReference;
      if (refCode != null && refCode.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: refCode));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFacingError(e);
      });
    }
  }

  void _next() {
    setState(() => _error = null);
    if (_step == 0) {
      if (widget.bundle.holdings.isNotEmpty && _holding == null) {
        setState(() => _error = 'Select an investment for this payment.');
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
      if (amount == null || amount <= 0) {
        setState(() => _error = 'Enter a valid amount.');
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_step == 2) {
      setState(() => _step = 3);
      return;
    }
    if (_step == 3) {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.neutral700,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Text(
            _step == 4 ? 'Payment submitted' : 'Make a bank transfer',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _step == 4
                ? 'Finance will verify your transfer. You cannot mark it completed yourself.'
                : 'Step ${_step + 1} of 4 · Bank transfer only',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate400,
                ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: switch (_step) {
                0 => _stepInvestment(),
                1 => _stepAmount(),
                2 => _stepCompanyAccount(),
                3 => _stepConfirmation(),
                _ => _stepDone(),
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 14),
          if (_step < 4)
            Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _step -= 1;
                              _error = null;
                            }),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.charcoal,
                  ),
                  onPressed: _submitting ? null : _next,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_step == 3 ? 'Submit confirmation' : 'Continue'),
                ),
              ],
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.charcoal,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }

  Widget _stepInvestment() {
    final holdings = widget.bundle.holdings;
    if (holdings.isEmpty) {
      return const Text(
        'No holdings assigned yet. You can still submit a capital payment — Finance will match it to your account.',
        style: TextStyle(color: AppColors.slate400),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select investment / property',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        for (final h in holdings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InvestorPortalCard(
              onTap: () => setState(() => _holding = h),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _holding?.id == h.id
                        ? LucideIcons.checkCircle2
                        : LucideIcons.circle,
                    color: _holding?.id == h.id
                        ? AppColors.gold
                        : AppColors.slate500,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.developmentName ?? h.label,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          h.subtitle,
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
      ],
    );
  }

  Widget _stepAmount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount (NGN)',
            prefixText: '₦ ',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Payment method',
          style: TextStyle(color: AppColors.slate400, fontSize: 12),
        ),
        const SizedBox(height: 6),
        InvestorPortalCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(LucideIcons.landmark, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Bank transfer',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(color: AppColors.gold, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepCompanyAccount() {
    final account = _account;
    final previewRef =
        'INV-•••• (your unique reference is created when you submit)';
    if (account == null) {
      return const Text(
        'Company receiving accounts are not configured yet. Please contact HD Homes Finance.',
        style: TextStyle(color: AppColors.slate400),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transfer to HD Homes using these details. Use your unique payment reference when making this transfer.',
          style: TextStyle(color: AppColors.slate400),
        ),
        const SizedBox(height: 12),
        _CopyRow(label: 'Account name', value: account.accountName),
        _CopyRow(label: 'Bank', value: account.bankName),
        _CopyRow(label: 'Account number', value: account.accountNumber),
        if (account.sortCode != null)
          _CopyRow(label: 'Sort / bank code', value: account.sortCode!),
        _CopyRow(label: 'Reference', value: previewRef, copyable: false),
        if (account.instructions != null) ...[
          const SizedBox(height: 8),
          Text(
            account.instructions!,
            style: const TextStyle(color: AppColors.slate400, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _stepConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm you completed the bank transfer. Finance Admin will verify settlement.',
          style: TextStyle(color: AppColors.slate400),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _payerBankCtrl,
          decoration: const InputDecoration(labelText: 'Your bank'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bankRefCtrl,
          decoration: const InputDecoration(
            labelText: 'Transfer reference / narration',
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Transfer date',
            style: TextStyle(color: AppColors.slate400, fontSize: 12),
          ),
          subtitle: Text(
            DateFormat.yMMMd().format(_transferDate),
            style: const TextStyle(color: AppColors.white),
          ),
          trailing: IconButton(
            onPressed: _pickDate,
            icon: const Icon(LucideIcons.calendar, color: AppColors.gold),
          ),
        ),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _submitting ? null : _pickProof,
          icon: const Icon(LucideIcons.uploadCloud, size: 16),
          label: Text(_proofName ?? 'Upload proof of payment (optional)'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold),
        ),
      ],
    );
  }

  Widget _stepDone() {
    final intent = _submitted;
    final refCode = intent?.providerReference ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 36),
        const SizedBox(height: 12),
        Text(
          intent?.formattedAmount ?? '',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Status: Pending verification',
          style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (refCode.isNotEmpty) _CopyRow(label: 'Payment reference', value: refCode),
        const SizedBox(height: 8),
        const Text(
          'Keep this reference for your records. You will be notified when Finance verifies the payment.',
          style: TextStyle(color: AppColors.slate400),
        ),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    this.copyable = true,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.slate400, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copy',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied')),
                  );
                }
              },
              icon: const Icon(LucideIcons.copy, size: 16, color: AppColors.gold),
            ),
        ],
      ),
    );
  }
}
