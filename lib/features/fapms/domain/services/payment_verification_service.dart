import 'package:hdhomesproject/features/fapms/domain/entities/payment_verification_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin finance service for client payment verification, receiving accounts,
/// payment methods, and late-fee rules. Verification actions go through RPCs
/// only — historical payments are never silently edited.
class PaymentVerificationService {
  PaymentVerificationService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const String proofBucket = 'payment-proofs';

  static const String _intentSelect = '''
    *,
    clients (
      id,
      client_code,
      profiles:user_id (
        first_name,
        last_name,
        preferred_name,
        email,
        phone
      )
    ),
    properties ( title ),
    company_receiving_accounts (
      account_name,
      bank_name,
      account_number
    ),
    payment_verifications (
      id,
      intent_id,
      payment_id,
      status,
      reviewer_id,
      reviewer_notes,
      decided_at,
      created_at
    )
  ''';

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    return client;
  }

  Future<List<PaymentIntentRow>> listPendingIntents({int limit = 200}) {
    return listIntents(
      statusFilter: const [
        'pending_verification',
        'info_requested',
      ],
      limit: limit,
    );
  }

  Future<List<PaymentIntentRow>> listIntents({
    String? status,
    List<String>? statusFilter,
    int limit = 200,
  }) async {
    final client = _client;
    if (client == null) return const [];

    var query = client
        .from('client_payment_intents')
        .select(_intentSelect)
        .eq('is_deleted', false);

    final statuses = statusFilter ??
        (status == null || status.isEmpty ? null : <String>[status]);
    if (statuses != null && statuses.isNotEmpty) {
      if (statuses.length == 1) {
        query = query.eq('status', statuses.first);
      } else {
        query = query.inFilter('status', statuses);
      }
    }

    final rows = await query
        .order('submitted_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map(
          (e) => PaymentIntentRow.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<PaymentIntentRow> getIntentDetail(String intentId) async {
    final client = _requireClient;
    final row = await client
        .from('client_payment_intents')
        .select(_intentSelect)
        .eq('id', intentId)
        .eq('is_deleted', false)
        .maybeSingle();
    if (row == null) {
      throw StateError('Payment intent not found');
    }
    return PaymentIntentRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>> approve(
    String intentId, {
    String? notes,
  }) async {
    final client = _requireClient;
    final result = await client.rpc(
      'approve_client_payment_intent',
      params: {
        'p_intent_id': intentId,
        'p_reviewer_notes': notes,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> reject(String intentId, String reason) async {
    final client = _requireClient;
    final result = await client.rpc(
      'reject_client_payment_intent',
      params: {
        'p_intent_id': intentId,
        'p_reason': reason,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> requestInfo(
    String intentId,
    String message,
  ) async {
    final client = _requireClient;
    final result = await client.rpc(
      'request_client_payment_info',
      params: {
        'p_intent_id': intentId,
        'p_message': message,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<Map<String, dynamic>> waiveCharge(
    String chargeId,
    String reason,
  ) async {
    final client = _requireClient;
    final result = await client.rpc(
      'waive_payment_charge',
      params: {
        'p_charge_id': chargeId,
        'p_reason': reason,
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  Future<List<CompanyReceivingAccount>> listReceivingAccounts({
    bool includeInactive = true,
  }) async {
    final client = _client;
    if (client == null) return const [];

    var query = client
        .from('company_receiving_accounts')
        .select()
        .eq('is_deleted', false);
    if (!includeInactive) {
      query = query.eq('is_active', true);
    }
    final rows =
        await query.order('sort_order').order('created_at', ascending: false);
    return (rows as List)
        .map(
          (e) => CompanyReceivingAccount.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<CompanyReceivingAccount> upsertReceivingAccount(
    CompanyReceivingAccount account,
  ) async {
    final client = _requireClient;
    final payload = account.toUpsertMap(
      idOverride: account.id.isEmpty ? null : account.id,
    );
    if (account.id.isEmpty) {
      payload.remove('id');
    }

    // Unique default constraint: clear other defaults before writing a new default.
    if (account.isDefault) {
      await client
          .from('company_receiving_accounts')
          .update({
            'is_default': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('is_deleted', false)
          .eq('is_default', true);
    }

    final row = await client
        .from('company_receiving_accounts')
        .upsert(payload)
        .select()
        .single();
    return CompanyReceivingAccount.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setDefaultAccount(String accountId) async {
    final client = _requireClient;
    final now = DateTime.now().toUtc().toIso8601String();
    await client
        .from('company_receiving_accounts')
        .update({'is_default': false, 'updated_at': now})
        .eq('is_deleted', false)
        .eq('is_default', true);
    await client.from('company_receiving_accounts').update({
      'is_default': true,
      'is_active': true,
      'available_for_clients': true,
      'updated_at': now,
    }).eq('id', accountId);
  }

  Future<List<PaymentMethodConfig>> listPaymentMethods() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('payment_methods')
        .select()
        .order('sort_order')
        .order('name');
    return (rows as List)
        .map(
          (e) =>
              PaymentMethodConfig.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> updateMethodClientEnabled(String methodId, bool enabled) async {
    final client = _requireClient;
    await client.from('payment_methods').update({
      'client_enabled': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', methodId);
  }

  Future<List<LateFeeRule>> listLateFeeRules() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('late_fee_rules')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => LateFeeRule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateLateFeeRuleEnabled({
    required String id,
    required bool enabled,
  }) async {
    final client = _requireClient;
    await client.from('late_fee_rules').update({
      'enabled': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<Map<String, dynamic>> applyOverdueLateFees({DateTime? asOf}) async {
    final client = _requireClient;
    final result = await client.rpc(
      'apply_overdue_late_fees',
      params: {
        if (asOf != null)
          'p_as_of':
              '${asOf.year.toString().padLeft(4, '0')}-'
              '${asOf.month.toString().padLeft(2, '0')}-'
              '${asOf.day.toString().padLeft(2, '0')}',
      },
    );
    return Map<String, dynamic>.from(result as Map? ?? {});
  }

  /// Creates a signed URL for [proofStoragePath] in the payment-proofs bucket.
  /// Accepts raw object paths or `payment-proofs/...` prefixes.
  Future<String?> proofSignedUrl(
    String? proofStoragePath, {
    int expiresIn = 3600,
  }) async {
    final raw = proofStoragePath?.trim();
    if (raw == null || raw.isEmpty) return null;
    final client = _requireClient;

    var path = raw;
    if (path.startsWith('storage://')) {
      path = path.substring('storage://'.length);
    }
    if (path.startsWith('$proofBucket/')) {
      path = path.substring(proofBucket.length + 1);
    }
    if (path.isEmpty) return null;

    return client.storage.from(proofBucket).createSignedUrl(path, expiresIn);
  }
}
