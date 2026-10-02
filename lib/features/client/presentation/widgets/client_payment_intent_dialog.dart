import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_payment_engine_models.dart';
import 'package:hdhomesproject/features/client/domain/services/client_payment_engine_service.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_payment_engine_providers.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/payments/payment_flow_steps.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Legacy entry — opens the multi-step payment flow sheet.
Future<void> showClientPaymentIntentDialog(
  BuildContext context,
  WidgetRef ref, {
  ClientInstallment? installment,
}) =>
    showClientPaymentFlowSheet(context, ref, installment: installment);

/// Multi-step client payment flow (bank transfer verification by default).
Future<void> showClientPaymentFlowSheet(
  BuildContext context,
  WidgetRef ref, {
  ClientInstallment? installment,
}) async {
  final record = await ref.read(clientRecordProvider.future);
  if (record == null || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.darkSurface,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return SizedBox(
        height: height * 0.94,
        child: _ClientPaymentFlowSheet(installment: installment),
      );
    },
  );
}

class _ClientPaymentFlowSheet extends ConsumerStatefulWidget {
  const _ClientPaymentFlowSheet({this.installment});

  final ClientInstallment? installment;

  @override
  ConsumerState<_ClientPaymentFlowSheet> createState() =>
      _ClientPaymentFlowSheetState();
}

class _ClientPaymentFlowSheetState
    extends ConsumerState<_ClientPaymentFlowSheet> {
  static const _stepTitles = [
    'Payment details',
    'Payment method',
    'Bank instructions',
    'Submit transfer',
    'Confirmation',
  ];

  int _step = 0;
  bool _submitting = false;
  String? _error;

  String? _propertyId;
  ClientPaymentMethodOption? _method;
  CompanyReceivingAccount? _account;

  late final TextEditingController _amountCtrl;
  late final TextEditingController _senderNameCtrl;
  late final TextEditingController _senderBankCtrl;
  late final TextEditingController _txnRefCtrl;
  late final TextEditingController _noteCtrl;
  DateTime _transferDate = DateTime.now();

  String? _proofPath;
  String? _proofName;
  BankTransferSubmissionResult? _result;

  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final inst = widget.installment;
    _propertyId = inst?.propertyId;
    final due = inst?.payableAmount ?? 0;
    _amountCtrl = TextEditingController(
      text: due > 0 ? due.toStringAsFixed(0) : '',
    );
    _senderNameCtrl = TextEditingController();
    _senderBankCtrl = TextEditingController();
    _txnRefCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _senderNameCtrl.dispose();
    _senderBankCtrl.dispose();
    _txnRefCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<ClientPaymentCharge> _relevantCharges(
    List<ClientPaymentCharge> all,
  ) {
    final instId = widget.installment?.id;
    return all.where((c) {
      if (!c.isOutstanding) return false;
      if (instId == null) return true;
      return c.installmentId == null || c.installmentId == instId;
    }).toList();
  }

  double _chargesTotal(List<ClientPaymentCharge> charges) =>
      charges.fold<double>(0, (s, c) => s + c.amount);

  double get _amountDue {
    final inst = widget.installment;
    if (inst != null) return inst.payableAmount;
    return double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
  }

  bool _canContinue({
    required List<ClientPaymentMethodOption> methods,
    required List<CompanyReceivingAccount> accounts,
  }) {
    final method = _method ?? (methods.isNotEmpty ? methods.first : null);
    final account = _account ?? (accounts.isNotEmpty ? accounts.first : null);
    switch (_step) {
      case 0:
        if (widget.installment != null) return true;
        return (_propertyId?.isNotEmpty ?? false) && _amountDue > 0;
      case 1:
        return method != null;
      case 2:
        return account != null;
      case 3:
        return !_submitting;
      default:
        return true;
    }
  }

  Future<void> _pickProof() async {
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
      final path = await ref
          .read(clientPaymentEngineServiceProvider)
          .uploadProof(
            bytes: Uint8List.fromList(bytes),
            filename: file.name,
            contentType: _mimeFor(file.extension),
          );
      if (!mounted) return;
      setState(() {
        _proofPath = path;
        _proofName = file.name;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ClientPaymentEngineService.friendlyError(e);
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

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_senderNameCtrl.text.trim().isEmpty ||
        _senderBankCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Sender name and bank are required.');
      return;
    }
    if (_txnRefCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Transaction reference is required.');
      return;
    }
    if ((_proofPath == null || _proofPath!.isEmpty) &&
        (_method == null || _method!.isBankTransfer)) {
      setState(
        () => _error =
            'Upload your transfer proof (receipt image or PDF) before submitting.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(clientPaymentEngineServiceProvider)
          .submitBankTransfer(
            propertyId: _propertyId ?? widget.installment?.propertyId,
            installmentId: widget.installment?.id,
            amount: amount,
            transferDate: _transferDate,
            senderName: _senderNameCtrl.text,
            senderBank: _senderBankCtrl.text,
            transactionReference: _txnRefCtrl.text,
            transferNote: _noteCtrl.text,
            proofStoragePath: _proofPath,
            receivingAccountId: _account?.id,
          );

      ref.invalidate(clientPaymentsProvider);
      ref.invalidate(clientPaymentSummaryProvider);
      ref.invalidate(clientPaymentIntentsProvider);
      ref.invalidate(clientPaymentHistoryProvider);
      ref.invalidate(clientDashboardProvider);

      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
        _step = 4;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ClientPaymentEngineService.friendlyError(e);
      });
    }
  }

  void _next({
    required List<ClientPaymentMethodOption> methods,
    required List<CompanyReceivingAccount> accounts,
    List<ClientPaymentCharge> charges = const [],
  }) {
    setState(() => _error = null);
    // Persist UI defaults so later steps / submit use the same selection.
    _method ??= methods.isNotEmpty ? methods.first : null;
    _account ??= accounts.isNotEmpty ? accounts.first : null;
    _propertyId ??=
        widget.installment?.propertyId ??
        (ref.read(clientPropertiesProvider).valueOrNull?.isNotEmpty == true
            ? ref.read(clientPropertiesProvider).valueOrNull!.first.propertyId
            : null);

    if (_step == 0) {
      final due = widget.installment?.payableAmount ??
          double.tryParse(_amountCtrl.text.replaceAll(',', '')) ??
          0;
      final total = due + _chargesTotal(charges);
      if (total > 0) {
        _amountCtrl.text = total.toStringAsFixed(0);
      }
    }
    if (_step == 3) {
      _submit();
      return;
    }
    if (_step < 4 && _canContinue(methods: methods, accounts: accounts)) {
      setState(() => _step += 1);
    }
  }

  void _back() {
    if (_step <= 0 || _step >= 4) return;
    setState(() {
      _error = null;
      _step -= 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(clientPaymentMethodsProvider);
    final accountsAsync = ref.watch(clientReceivingAccountsProvider);
    final chargesAsync = ref.watch(clientPaymentChargesProvider);
    final propertiesAsync = ref.watch(clientPropertiesProvider);

    final methods = [
      for (final method in methodsAsync.valueOrNull ?? const <ClientPaymentMethodOption>[])
        if (method.isBankTransfer) method,
    ];
    final accounts = accountsAsync.valueOrNull ?? const [];
    final charges = _relevantCharges(chargesAsync.valueOrNull ?? const []);
    final properties = propertiesAsync.valueOrNull ?? const [];

    final selectedMethod = _method ?? (methods.isNotEmpty ? methods.first : null);
    final selectedAccount =
        _account ?? (accounts.isNotEmpty ? accounts.first : null);
    final selectedPropertyId = _propertyId ??
        widget.installment?.propertyId ??
        (properties.isNotEmpty ? properties.first.propertyId : null);

    final primaryLabel = switch (_step) {
      3 => 'Submit for Verification',
      4 => 'Done',
      _ => 'Continue',
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              if (_step > 0 && _step < 4)
                IconButton(
                  onPressed: _back,
                  icon: const Icon(LucideIcons.arrowLeft, color: Colors.white70),
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Make a payment',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Step ${_step + 1} of 5 · ${_stepTitles[_step]}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / 5,
              minHeight: 4,
              backgroundColor: AppColors.neutral800,
              color: AppColors.gold,
            ),
          ),
        ),
        const Divider(height: 20, color: Color(0xFF2A3140)),
        Expanded(
          child: methodsAsync.isLoading || accountsAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _buildStep(
                    methods: methods,
                    accounts: accounts,
                    charges: charges,
                    properties: properties,
                    selectedMethod: selectedMethod,
                    selectedAccount: selectedAccount,
                    selectedPropertyId: selectedPropertyId,
                  ),
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting
                    ? null
                    : () {
                        if (_step == 4) {
                          Navigator.pop(context);
                          return;
                        }
                        _method ??= selectedMethod;
                        _account ??= selectedAccount;
                        _propertyId ??= selectedPropertyId;
                        _next(
                          methods: methods,
                          accounts: accounts,
                          charges: charges,
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.charcoal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(primaryLabel),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep({
    required List<ClientPaymentMethodOption> methods,
    required List<CompanyReceivingAccount> accounts,
    required List<ClientPaymentCharge> charges,
    required List<ClientProperty> properties,
    required ClientPaymentMethodOption? selectedMethod,
    required CompanyReceivingAccount? selectedAccount,
    required String? selectedPropertyId,
  }) {
    return switch (_step) {
      0 => PaymentDetailsStep(
          installment: widget.installment,
          properties: properties,
          propertyId: selectedPropertyId,
          onPropertyChanged: (v) => setState(() => _propertyId = v),
          amountCtrl: _amountCtrl,
          amountDue: _amountDue,
          charges: charges,
          chargesTotal: _chargesTotal(charges),
          fmt: _fmt,
        ),
      1 => PaymentMethodStep(
          methods: methods,
          selected: selectedMethod,
          onSelect: (m) => setState(() => _method = m),
        ),
      2 => BankInstructionsStep(
              account: selectedAccount,
              accounts: accounts,
              onSelectAccount: (a) => setState(() => _account = a),
              amountPreview: double.tryParse(
                    _amountCtrl.text.replaceAll(',', ''),
                  ) ??
                  _amountDue,
              fmt: _fmt,
            ),
      3 => SubmitTransferStep(
          amountCtrl: _amountCtrl,
          senderNameCtrl: _senderNameCtrl,
          senderBankCtrl: _senderBankCtrl,
          txnRefCtrl: _txnRefCtrl,
          noteCtrl: _noteCtrl,
          transferDate: _transferDate,
          onPickDate: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _transferDate,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) setState(() => _transferDate = picked);
          },
          proofName: _proofName,
          onPickProof: _pickProof,
          onClearProof: () => setState(() {
            _proofPath = null;
            _proofName = null;
          }),
        ),
      _ => PaymentConfirmationStep(result: _result),
    };
  }
}
