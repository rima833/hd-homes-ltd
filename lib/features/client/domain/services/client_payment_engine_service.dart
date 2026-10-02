import 'dart:convert';
import 'dart:typed_data';

import 'package:hdhomesproject/features/client/domain/entities/client_payment_engine_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client payment verification engine — Supabase RPCs + tables.
class ClientPaymentEngineService {
  ClientPaymentEngineService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const proofBucket = 'payment-proofs';

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) throw StateError('Supabase is not configured');
    return c;
  }

  String _requireAuthUserId() {
    final uid = _requireClient.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated');
    return uid;
  }

  Future<void> _requireApprovedKyc() async {
    final uid = _requireAuthUserId();
    final profile = await _requireClient
        .from('kyc_profiles')
        .select('status')
        .eq('user_id', uid)
        .maybeSingle();
    final status = profile?['status']?.toString() ?? '';
    if (status == 'approved' || status == 'partially_approved') return;
    throw StateError(
      'Finish identity verification before you submit a bank transfer. Open Settings and complete KYC.',
    );
  }

  Map<String, dynamic>? _coerceMap(dynamic row) {
    if (row == null) return null;
    if (row is Map<String, dynamic>) return row;
    if (row is Map) return Map<String, dynamic>.from(row);
    if (row is List && row.isNotEmpty) return _coerceMap(row.first);
    if (row is String) {
      try {
        return _coerceMap(jsonDecode(row));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Maps RPC / Postgrest exception codes to client-facing messages.
  static String friendlyError(Object error) {
    final raw = error is PostgrestException
        ? '${error.message} ${error.details ?? ''} ${error.code ?? ''}'
        : '$error';
    final msg = raw.toLowerCase();

    if (msg.contains('partial_payments_disabled')) {
      return 'Partial payments are not allowed. Please pay the full amount due.';
    }
    if (msg.contains('overpayment_not_allowed')) {
      return 'That amount exceeds what is due. Reduce the amount and try again.';
    }
    if (msg.contains('proof_required')) {
      return 'A transfer proof (receipt image or PDF) is required.';
    }
    if (msg.contains('payment_method_unavailable')) {
      return 'Bank transfer is temporarily unavailable. Please contact Finance.';
    }
    if (msg.contains('no_receiving_account')) {
      return 'No official receiving account is available. Please contact Finance.';
    }
    if (msg.contains('invalid_amount')) {
      return 'Enter a valid payment amount greater than zero.';
    }
    if (msg.contains('invalid_transfer_date')) {
      return 'Transfer date is invalid. Use today or a recent past date.';
    }
    if (msg.contains('sender_required')) {
      return 'Sender name and bank are required.';
    }
    if (msg.contains('transaction_reference_required')) {
      return 'Your bank transaction reference is required.';
    }
    if (msg.contains('installment_not_found')) {
      return 'That installment could not be found.';
    }
    if (msg.contains('installment_not_payable')) {
      return 'This installment is no longer payable.';
    }
    if (msg.contains('property_not_owned')) {
      return 'That property is not linked to your account.';
    }
    if (msg.contains('client_not_found')) {
      return 'Your client account could not be resolved. Sign out and sign in again.';
    }
    if (msg.contains('not_authenticated')) {
      return 'Please sign in to submit a payment.';
    }
    if (msg.contains('forbidden')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('failed host')) {
      return 'Network error. Check your connection and try again.';
    }
    if (error is StateError) return error.message;
    return 'We could not submit your payment. Please try again or contact support.';
  }

  Future<ClientPaymentSummary> fetchPaymentSummary({String? clientId}) async {
    try {
      final row = await _requireClient.rpc(
        'client_payment_summary',
        params: {'p_client_id': clientId},
      );
      final map = _coerceMap(row);
      if (map == null) {
        throw StateError('Payment summary was empty');
      }
      return ClientPaymentSummary.fromJson(map);
    } on PostgrestException catch (e) {
      throw StateError(friendlyError(e));
    }
  }

  Future<List<ClientPaymentMethodOption>> listClientPaymentMethods() async {
    final rows = await _requireClient
        .from('payment_methods')
        .select()
        .eq('is_active', true)
        .eq('client_enabled', true)
        .order('is_recommended', ascending: false)
        .order('sort_order');
    final list = rows
        .map(
          (e) =>
              ClientPaymentMethodOption.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
    list.sort((a, b) {
      if (a.isRecommended != b.isRecommended) {
        return a.isRecommended ? -1 : 1;
      }
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return list;
  }

  Future<List<CompanyReceivingAccount>> listReceivingAccounts() async {
    final rows = await _requireClient
        .from('company_receiving_accounts')
        .select()
        .eq('is_deleted', false)
        .eq('is_active', true)
        .eq('available_for_clients', true)
        .order('is_default', ascending: false)
        .order('sort_order');
    return rows
        .map(
          (e) => CompanyReceivingAccount.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<ClientPaymentIntentRecord>> listPaymentIntents(
    String clientId, {
    int limit = 50,
  }) async {
    final rows = await _requireClient
        .from('client_payment_intents')
        .select('*, properties (title)')
        .eq('client_id', clientId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map(
          (e) =>
              ClientPaymentIntentRecord.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<List<ClientPaymentCharge>> listCharges(
    String clientId, {
    int limit = 100,
  }) async {
    final rows = await _requireClient
        .from('payment_charges')
        .select('*, properties (title)')
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => ClientPaymentCharge.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Receipts for the client via finance_receipts ↔ payments join.
  Future<List<ClientFinanceReceipt>> listReceipts(
    String clientId, {
    int limit = 50,
  }) async {
    final rows = await _requireClient
        .from('finance_receipts')
        .select('*, payments!inner(client_id, properties(title))')
        .eq('payments.client_id', clientId)
        .order('issued_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => ClientFinanceReceipt.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Uploads proof to `payment-proofs/{userId}/{filename}`. Returns storage path.
  Future<String> uploadProof({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final userId = _requireAuthUserId();
    final safeName = filename
        .replaceAll(RegExp(r'[^\w.\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _requireClient.storage
        .from(proofBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
    return path;
  }

  Future<BankTransferSubmissionResult> submitBankTransfer({
    required double amount,
    required DateTime transferDate,
    required String senderName,
    required String senderBank,
    required String transactionReference,
    String? propertyId,
    String? installmentId,
    String? transferNote,
    String? proofStoragePath,
    String? receivingAccountId,
  }) async {
    try {
      await _requireApprovedKyc();
      final row = await _requireClient.rpc(
        'submit_client_bank_transfer',
        params: {
          'p_property_id': propertyId,
          'p_installment_id': installmentId,
          'p_amount': amount,
          'p_transfer_date': transferDate.toIso8601String().split('T').first,
          'p_sender_name': senderName.trim(),
          'p_sender_bank': senderBank.trim(),
          'p_transaction_reference': transactionReference.trim(),
          'p_transfer_note': transferNote?.trim().isEmpty ?? true
              ? null
              : transferNote!.trim(),
          'p_proof_storage_path': proofStoragePath,
          'p_receiving_account_id': receivingAccountId,
        },
      );
      final map = _coerceMap(row);
      if (map == null) {
        throw StateError('Empty response from payment submission');
      }
      return BankTransferSubmissionResult.fromJson(map);
    } on PostgrestException catch (e) {
      throw StateError(friendlyError(e));
    }
  }
}
