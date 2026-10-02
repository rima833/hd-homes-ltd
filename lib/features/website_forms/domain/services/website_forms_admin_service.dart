import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/domain/services/website_forms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebsiteFormsAdminService {
  WebsiteFormsAdminService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<List<WebsiteSupportTicketRow>> listSupportTickets({
    int limit = 400,
  }) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('tickets')
        .select()
        .eq('channel', 'website')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => WebsiteSupportTicketRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<WebsiteSupportStats> fetchSupportStats() async {
    final rows = await listSupportTickets();
    var neu = 0, open = 0, inProgress = 0, resolved = 0, urgent = 0;
    for (final r in rows) {
      switch (r.status) {
        case 'new':
          neu++;
        case 'open':
          open++;
        case 'in_progress':
          inProgress++;
        case 'resolved':
          resolved++;
      }
      if (r.priority == 'urgent') urgent++;
    }
    return WebsiteSupportStats(
      total: rows.length,
      neu: neu,
      open: open,
      inProgress: inProgress,
      resolved: resolved,
      urgent: urgent,
    );
  }

  Future<void> updateTicket({
    required String id,
    String? status,
    String? priority,
    String? assignedTo,
    String? adminNotes,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_update_website_ticket',
      params: {
        'p_ticket_id': id,
        'p_status': status,
        'p_priority': priority,
        'p_assigned_to': assignedTo,
        'p_admin_notes': adminNotes,
      },
    );
  }

  Future<List<WebsiteInboxNote>> listTicketNotes(String ticketId) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('support_ticket_notes')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (e) => WebsiteInboxNote.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> addTicketNote(String ticketId, String body) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('support_ticket_notes').insert({
      'ticket_id': ticketId,
      'body': body.trim(),
      'is_internal': true,
      'author_label': 'Staff',
    });
  }

  Future<void> saveSupportSettings(WebsiteSupportSettings settings) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client
        .from('website_support_settings')
        .update(settings.toJson())
        .eq('id', settings.id);
  }

  Future<void> saveSupportType({
    required String id,
    required bool isActive,
    String? name,
    int? sortOrder,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('website_support_types').update({
      'name': ?name,
      'is_active': isActive,
      'sort_order': ?sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<List<CareerApplicationRow>> listApplications({int limit = 400}) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('career_applications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) =>
              CareerApplicationRow.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<CareerApplicationStats> fetchApplicationStats({
    int openPositions = 0,
  }) async {
    final rows = await listApplications();
    var neu = 0, interviews = 0, shortlisted = 0, hired = 0;
    for (final r in rows) {
      switch (r.status) {
        case 'new':
          neu++;
        case 'interview':
          interviews++;
        case 'shortlisted':
          shortlisted++;
        case 'hired':
          hired++;
      }
    }
    return CareerApplicationStats(
      openPositions: openPositions,
      total: rows.length,
      neu: neu,
      interviews: interviews,
      shortlisted: shortlisted,
      hired: hired,
    );
  }

  Future<void> updateApplication({
    required String id,
    String? status,
    String? assignedTo,
    String? adminNotes,
    String? reason,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_update_career_application',
      params: {
        'p_application_id': id,
        'p_status': status,
        'p_assigned_to': assignedTo,
        'p_admin_notes': adminNotes,
        'p_reason': reason,
      },
    );
  }

  Future<void> addApplicationNote(String applicationId, String body) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('career_application_notes').insert({
      'application_id': applicationId,
      'body': body.trim(),
      'author_label': 'Staff',
    });
  }

  Future<List<WebsiteInboxNote>> listApplicationNotes(String id) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('career_application_notes')
        .select()
        .eq('application_id', id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (e) => WebsiteInboxNote.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<PartnershipRequestRow>> listPartnerships({
    int limit = 400,
  }) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('partnership_requests')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => PartnershipRequestRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<PartnershipRequestStats> fetchPartnershipStats() async {
    final rows = await listPartnerships();
    var neu = 0, underReview = 0, negotiation = 0, approved = 0, closed = 0;
    for (final r in rows) {
      switch (r.status) {
        case 'new':
          neu++;
        case 'under_review':
          underReview++;
        case 'negotiation':
          negotiation++;
        case 'approved':
          approved++;
        case 'closed':
          closed++;
      }
    }
    return PartnershipRequestStats(
      total: rows.length,
      neu: neu,
      underReview: underReview,
      negotiation: negotiation,
      approved: approved,
      closed: closed,
    );
  }

  Future<void> updatePartnership({
    required String id,
    String? status,
    String? priority,
    String? assignedTo,
    String? adminNotes,
    String? reason,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_update_partnership_request',
      params: {
        'p_request_id': id,
        'p_status': status,
        'p_priority': priority,
        'p_assigned_to': assignedTo,
        'p_admin_notes': adminNotes,
        'p_reason': reason,
      },
    );
  }

  Future<void> addPartnershipNote(String requestId, String body) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('partnership_request_notes').insert({
      'request_id': requestId,
      'body': body.trim(),
      'author_label': 'Staff',
    });
  }

  Future<List<WebsiteInboxNote>> listPartnershipNotes(String id) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('partnership_request_notes')
        .select()
        .eq('request_id', id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (e) => WebsiteInboxNote.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> savePartnershipSettings(PartnershipSettings settings) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client
        .from('partnership_settings')
        .update(settings.toJson())
        .eq('id', settings.id);
  }

  Future<void> savePartnershipType({
    required String id,
    required bool isActive,
    String? name,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('partnership_types').update({
      'name': ?name,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<String?> signedUrl(String path) async {
    final client = _client;
    if (client == null || path.isEmpty) return null;
    return client.storage
        .from(WebsiteFormsService.bucket)
        .createSignedUrl(path, 3600);
  }

  Future<void> saveCareerApplicationSettings({
    required String settingsId,
    required bool enabled,
    required String confirmationTitle,
    required String confirmationMessage,
    required int maxCvBytes,
    required bool allowGeneral,
    required String disabledMessage,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('careers_settings').update({
      'applications_enabled': enabled,
      'application_confirmation_title': confirmationTitle,
      'application_confirmation_message': confirmationMessage,
      'max_cv_bytes': maxCvBytes,
      'allow_general_application': allowGeneral,
      'applications_disabled_message': disabledMessage,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', settingsId);
  }
}
