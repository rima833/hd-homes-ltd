import 'package:hdhomesproject/core/email/email_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client-side email API — **enqueue only**. Never calls Resend.
class EmailService {
  EmailService(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  /// Queue a transactional email via SECURITY DEFINER RPC.
  Future<String?> enqueue({
    required String templateSlug,
    required String recipientEmail,
    String? userId,
    Map<String, String> variables = const {},
    String? notificationId,
    Map<String, dynamic> payload = const {},
  }) async {
    final client = _client;
    if (client == null) return null;
    final email = recipientEmail.trim().toLowerCase();
    if (!email.contains('@')) return null;

    try {
      final id = await client.rpc(
        'queue_transactional_email',
        params: {
          'p_template_slug': templateSlug,
          'p_recipient_email': email,
          'p_user_id': userId,
          'p_variables': variables,
          'p_notification_id': notificationId,
          'p_payload': payload,
        },
      );
      return id?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<EmailSystemStatus> loadSystemStatus() async {
    final client = _client;
    if (client == null) return const EmailSystemStatus();
    try {
      final raw = await client.rpc('admin_email_system_status');
      if (raw is Map) {
        return EmailSystemStatus.fromJson(Map<String, dynamic>.from(raw));
      }
      return const EmailSystemStatus();
    } catch (_) {
      return const EmailSystemStatus();
    }
  }

  Future<List<EmailDeliveryRecord>> listDeliveries({
    int limit = 50,
    String? status,
  }) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final raw = await client.rpc(
        'admin_list_email_deliveries',
        params: {'p_limit': limit, 'p_status': status},
      );
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => EmailDeliveryRecord.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<EmailTemplateRecord>> listTemplates() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('email_templates')
          .select(
            'id,name,slug,subject,body_html,text_body,category,variables,is_security,is_active',
          )
          .order('category')
          .order('name');
      return (rows as List)
          .map(
            (r) =>
                EmailTemplateRecord.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<EmailTemplateRecord?> upsertTemplate({
    required String slug,
    required String name,
    required String subject,
    required String bodyHtml,
    String? textBody,
    String category = 'system',
    List<String> variables = const [],
    bool isActive = true,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      final row = await client.rpc(
        'admin_upsert_email_template',
        params: {
          'p_slug': slug,
          'p_name': name,
          'p_subject': subject,
          'p_body_html': bodyHtml,
          'p_text_body': textBody,
          'p_category': category,
          'p_variables': variables,
          'p_is_active': isActive,
        },
      );
      if (row is Map) {
        return EmailTemplateRecord.fromJson(Map<String, dynamic>.from(row));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBrand(EmailBrandConfig brand) async {
    final client = _client;
    if (client == null) return;
    await client.from('app_settings').upsert({
      'key': 'email_brand',
      'value': brand.toJson(),
      'category': 'email',
      'is_public': true,
      'description': 'HD Homes transactional email branding (no secrets)',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'is_deleted': false,
      'status': 'active',
    });
  }

  /// Invokes Edge `send-test-email` (admin JWT). Never fakes success.
  Future<Map<String, dynamic>> sendTestEmail({
    required String to,
    required String templateSlug,
    Map<String, String> variables = const {},
  }) async {
    final client = _client;
    if (client == null) {
      return {'ok': false, 'error': 'Supabase is not configured'};
    }
    try {
      final res = await client.functions.invoke(
        'send-test-email',
        body: {
          'to': to.trim().toLowerCase(),
          'template_slug': templateSlug,
          'variables': variables,
        },
      );
      final data = res.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {'ok': false, 'error': 'Unexpected response'};
    } catch (e) {
      return {'ok': false, 'error': '$e'};
    }
  }

  Future<Map<String, dynamic>> checkProviderHealth() async {
    final client = _client;
    if (client == null) {
      return {'ok': false, 'configured': false, 'error': 'not_configured'};
    }
    try {
      final res = await client.functions.invoke('email-provider-health');
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'ok': false, 'configured': false};
    } catch (e) {
      return {'ok': false, 'configured': false, 'error': '$e'};
    }
  }

  /// Asks the Edge worker to drain queues (admin/service). Does not fabricate sends.
  Future<Map<String, dynamic>> processQueue({int limit = 25}) async {
    final client = _client;
    if (client == null) {
      return {'ok': false, 'error': 'not_configured'};
    }
    try {
      final res = await client.functions.invoke(
        'process-email-queue',
        queryParameters: {'limit': '$limit'},
      );
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'ok': true, 'raw': data};
    } catch (e) {
      return {'ok': false, 'error': '$e'};
    }
  }

  RealtimeChannel? subscribeDeliveries(
    void Function() onChange, {
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  }) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('notification_delivery:email');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notification_delivery',
          callback: (_) => onChange(),
        )
        .subscribe((status, [error]) => onStatus?.call(status, error));
    return channel;
  }
}
