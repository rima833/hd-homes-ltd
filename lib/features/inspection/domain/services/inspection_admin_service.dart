import 'package:hdhomesproject/features/inspection/domain/entities/inspection_admin_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class InspectionAdminService {
  InspectionAdminService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  final Uuid _uuid = const Uuid();

  Future<List<AdminInspectionRow>> listInspections({int limit = 500}) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('property_inspections')
        .select('*, properties(title)')
        .order('scheduled_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => AdminInspectionRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AdminInspectionStats> fetchStats() async {
    final client = _client;
    if (client == null) return const AdminInspectionStats();

    final rows = await client
        .from('property_inspections')
        .select('status, scheduled_at');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var total = 0;
    var todayCount = 0;
    var upcoming = 0;
    var scheduled = 0;
    var confirmed = 0;
    var completed = 0;
    var cancelled = 0;
    var noShow = 0;

    for (final raw in rows as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      total++;
      final status = '${map['status'] ?? ''}';
      final at = DateTime.parse('${map['scheduled_at']}').toLocal();
      final day = DateTime(at.year, at.month, at.day);

      if (day == today) todayCount++;
      if (at.isAfter(now) && (status == 'scheduled' || status == 'confirmed')) {
        upcoming++;
      }
      switch (status) {
        case 'scheduled':
          scheduled++;
        case 'confirmed':
          confirmed++;
        case 'completed':
          completed++;
        case 'cancelled':
          cancelled++;
        case 'no_show':
          noShow++;
      }
    }

    return AdminInspectionStats(
      total: total,
      today: todayCount,
      upcoming: upcoming,
      scheduled: scheduled,
      confirmed: confirmed,
      completed: completed,
      cancelled: cancelled,
      noShow: noShow,
    );
  }

  Future<List<InspectionStatusHistoryEntry>> fetchStatusHistory(
    String inspectionId,
  ) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('inspection_status_history')
        .select()
        .eq('inspection_id', inspectionId)
        .order('changed_at', ascending: false);

    return (rows as List)
        .map(
          (e) => InspectionStatusHistoryEntry.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<InspectionPropertyOption>> listPropertyOptions({
    int limit = 200,
  }) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('properties')
          .select('id, title, estate_id')
          .eq('is_deleted', false)
          .order('title')
          .limit(limit);
      return (rows as List)
          .map(
            (e) => InspectionPropertyOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      final rows = await client
          .from('properties')
          .select('id, title')
          .order('title')
          .limit(limit);
      return (rows as List)
          .map(
            (e) => InspectionPropertyOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }
  }

  Future<List<InspectionAdvisorOption>> listAdvisorOptions() async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('consultation_advisors')
        .select('id, full_name, title, is_active')
        .order('full_name');

    return (rows as List)
        .map(
          (e) => InspectionAdvisorOption.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .where((a) => a.isActive)
        .toList();
  }

  /// Creates a consultation advisor and optionally assigns them as an
  /// inspection agent in one step.
  Future<String> createAdvisorAndAssignAgent({
    required String fullName,
    required String title,
    String? email,
    String? phone,
    int maxDailyInspections = 4,
    bool isActive = true,
    List<String>? estateIds,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    final advisor = await client
        .from('consultation_advisors')
        .insert({
          'full_name': fullName.trim(),
          'title': title.trim().isEmpty ? 'Inspection Agent' : title.trim(),
          'email': email?.trim().isEmpty == true ? null : email?.trim(),
          'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
          'is_active': true,
          'sort_order': 0,
        })
        .select('id')
        .single();

    final advisorId = advisor['id'] as String;
    await saveAgent(
      advisorId: advisorId,
      maxDailyInspections: maxDailyInspections,
      isActive: isActive,
      estateIds: estateIds,
    );
    return advisorId;
  }

  Future<String> upsertInspection(AdminInspectionDraft draft) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    final result = await client.rpc(
      'admin_upsert_inspection',
      params: {
        'p_id': draft.id,
        'p_property_id': draft.propertyId,
        'p_scheduled_at': draft.scheduledAt.toUtc().toIso8601String(),
        'p_status': draft.status,
        'p_inspection_type': draft.inspectionType,
        'p_visitor_name': draft.visitorName,
        'p_visitor_email': draft.visitorEmail,
        'p_visitor_phone': draft.visitorPhone,
        'p_advisor_id': draft.advisorId,
        'p_preferred_language': draft.preferredLanguage,
        'p_meeting_url': draft.meetingUrl,
        'p_reason': draft.reason,
        'p_clear_advisor': draft.clearAdvisor,
      },
    );

    if (result is Map) {
      return '${result['id']}';
    }
    return draft.id ?? '';
  }

  Future<void> deleteInspection(String inspectionId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_delete_inspection',
      params: {'p_inspection_id': inspectionId},
    );
  }

  Future<void> updateStatus(
    String inspectionId,
    String status, {
    String? reason,
    String? meetingUrl,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_update_inspection_status',
      params: {
        'p_inspection_id': inspectionId,
        'p_status': status,
        'p_reason': reason,
        'p_meeting_url': meetingUrl,
      },
    );
    // Best-effort client notification for status changes.
    try {
      final row = await client
          .from('property_inspections')
          .select('visitor_profile_id, reference, scheduled_at')
          .eq('id', inspectionId)
          .maybeSingle();
      if (row != null) {
        final map = Map<String, dynamic>.from(row);
        final userId = map['visitor_profile_id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          final ref = map['reference']?.toString() ?? 'inspection';
          final when = map['scheduled_at'] != null
              ? DateTime.tryParse('${map['scheduled_at']}')
              : null;
          final whenLabel = when == null
              ? null
              : '${when.toLocal().day}/${when.toLocal().month}/${when.toLocal().year} ${when.toLocal().hour.toString().padLeft(2, '0')}:${when.toLocal().minute.toString().padLeft(2, '0')}';
          final hasMeetingLink =
              meetingUrl != null && meetingUrl.trim().isNotEmpty;
          final prettyStatus = status.replaceAll('_', ' ');
          await client.from('notifications').insert({
            'user_id': userId,
            'title': hasMeetingLink
                ? 'Inspection confirmed: meeting link sent'
                : 'Inspection update',
            'body': hasMeetingLink
                ? (whenLabel == null
                    ? 'Your inspection ($ref) is confirmed. Open your meeting link to join.'
                    : 'Your inspection ($ref) on $whenLabel is confirmed. Open your meeting link to join.')
                : (whenLabel == null
                    ? 'Your inspection ($ref) is now $prettyStatus.'
                    : 'Your inspection ($ref) on $whenLabel is now $prettyStatus.'),
            'category': 'bookings',
            'type': status == 'cancelled'
                ? 'warning'
                : (hasMeetingLink ? 'action_required' : 'information'),
            'priority': hasMeetingLink ? 'high' : 'normal',
            'template_slug': 'inspection_status_update',
            'metadata': {
              'inspection_id': inspectionId,
              'status': status,
              if (reason != null) 'reason': reason,
              if (meetingUrl != null) 'meeting_url': meetingUrl,
            },
            'is_read': false,
            'delivery_status': 'delivered',
          });
        }
      }
    } catch (_) {
      // Do not block status updates if notifications insert fails.
    }
  }

  Future<InspectionSettingsRow?> fetchSettings() async {
    final client = _client;
    if (client == null) return null;

    dynamic row;
    try {
      row = await client
          .from('inspection_settings')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      try {
        row = await client
            .from('inspection_settings')
            .select()
            .limit(1)
            .maybeSingle();
      } catch (_) {
        return InspectionSettingsRow(id: _uuid.v4());
      }
    }

    if (row == null) return InspectionSettingsRow(id: _uuid.v4());
    return InspectionSettingsRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> saveSettings(InspectionSettingsRow settings) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'id': settings.id,
      ...settings.toJson(),
    };
    await client.from('inspection_settings').upsert(payload);
  }

  Future<List<InspectionWorkingHourRow>> listWorkingHours() async {
    final client = _client;
    if (client == null) return const [];

    late final dynamic rows;
    try {
      rows = await client
          .from('inspection_working_hours')
          .select()
          .order('weekday');
    } catch (_) {
      return _defaultWorkingHours();
    }

    final mapped = (rows as List)
        .map(
          (e) => InspectionWorkingHourRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    if (mapped.isEmpty) return _defaultWorkingHours();
    return mapped;
  }

  Future<void> saveWorkingHour(InspectionWorkingHourRow hour) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('inspection_working_hours').upsert({
      'id': hour.id.startsWith('default-') ? _uuid.v4() : hour.id,
      ...hour.toJson(),
    }, onConflict: 'weekday');
  }

  Future<List<InspectionHolidayRow>> listHolidays() async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('inspection_holidays')
        .select()
        .order('holiday_date');

    return (rows as List)
        .map(
          (e) => InspectionHolidayRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> addHoliday(DateTime date, String name) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('inspection_holidays').insert({
      'holiday_date': date.toIso8601String().split('T').first,
      'name': name,
    });
  }

  Future<void> updateHoliday({
    required String id,
    required DateTime date,
    required String name,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('inspection_holidays').update({
      'holiday_date': date.toIso8601String().split('T').first,
      'name': name,
    }).eq('id', id);
  }

  Future<void> deleteHoliday(String id) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('inspection_holidays').delete().eq('id', id);
  }

  Future<List<InspectionBlockedSlotRow>> listBlockedSlots() async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('inspection_blocked_slots')
        .select()
        .order('blocked_at', ascending: false)
        .limit(100);

    return (rows as List)
        .map(
          (e) => InspectionBlockedSlotRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> addBlockedSlot({
    required DateTime blockedAt,
    required String reason,
    String? propertyId,
    String? estateId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('inspection_blocked_slots').insert({
      'blocked_at': blockedAt.toUtc().toIso8601String(),
      'reason': reason,
      if (propertyId != null) 'property_id': propertyId,
      if (estateId != null) 'estate_id': estateId,
    });
  }

  Future<void> updateBlockedSlot({
    required String id,
    required DateTime blockedAt,
    required String reason,
    String? propertyId,
    String? estateId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('inspection_blocked_slots').update({
      'blocked_at': blockedAt.toUtc().toIso8601String(),
      'reason': reason,
      'property_id': propertyId,
      'estate_id': estateId,
    }).eq('id', id);
  }

  Future<void> deleteBlockedSlot(String id) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('inspection_blocked_slots').delete().eq('id', id);
  }

  Future<List<InspectionAgentRow>> listAgents() async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('inspection_agents')
        .select('*, consultation_advisors(full_name, title)')
        .order('created_at');

    final mapped = (rows as List)
        .map(
          (e) => InspectionAgentRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    return mapped.where((a) => a.advisorId.isNotEmpty).toList();
  }

  Future<void> saveAgent({
    required String advisorId,
    required int maxDailyInspections,
    required bool isActive,
    List<String>? estateIds,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'advisor_id': advisorId,
      'max_daily_inspections': maxDailyInspections,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (estateIds != null) {
      payload['estate_ids'] = estateIds;
    }
    await client.from('inspection_agents').upsert(
          payload,
          onConflict: 'advisor_id',
        );
  }

  Future<List<InspectionEstateOption>> listEstateOptions({
    int limit = 100,
  }) async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('estates')
          .select('id, name')
          .eq('is_deleted', false)
          .order('name')
          .limit(limit);
      return (rows as List)
          .map(
            (e) => InspectionEstateOption.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      try {
        final rows = await client
            .from('estates')
            .select('id, name, title')
            .order('name')
            .limit(limit);
        return (rows as List)
            .map(
              (e) => InspectionEstateOption.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  Future<void> removeAgent(String advisorId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('inspection_agents').delete().eq('advisor_id', advisorId);
  }

  Future<PropertyInspectionConfigRow?> fetchPropertyConfig(
    String propertyId,
  ) async {
    final client = _client;
    if (client == null) return null;

    final row = await client
        .from('property_inspection_config')
        .select()
        .eq('property_id', propertyId)
        .maybeSingle();
    if (row == null) {
      return PropertyInspectionConfigRow(propertyId: propertyId);
    }
    return PropertyInspectionConfigRow.fromJson(
      Map<String, dynamic>.from(row),
    );
  }

  Future<void> savePropertyConfig(PropertyInspectionConfigRow config) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('property_inspection_config').upsert(config.toJson());
  }

  List<InspectionWorkingHourRow> _defaultWorkingHours() {
    return const [
      InspectionWorkingHourRow(
        id: 'default-mon',
        weekday: 0,
        startTime: '08:00',
        endTime: '18:00',
        isActive: true,
      ),
      InspectionWorkingHourRow(
        id: 'default-tue',
        weekday: 1,
        startTime: '08:00',
        endTime: '18:00',
        isActive: true,
      ),
      InspectionWorkingHourRow(
        id: 'default-wed',
        weekday: 2,
        startTime: '08:00',
        endTime: '18:00',
        isActive: true,
      ),
      InspectionWorkingHourRow(
        id: 'default-thu',
        weekday: 3,
        startTime: '08:00',
        endTime: '18:00',
        isActive: true,
      ),
      InspectionWorkingHourRow(
        id: 'default-fri',
        weekday: 4,
        startTime: '08:00',
        endTime: '18:00',
        isActive: true,
      ),
      InspectionWorkingHourRow(
        id: 'default-sat',
        weekday: 5,
        startTime: '09:00',
        endTime: '16:00',
        isActive: true,
      ),
      InspectionWorkingHourRow(
        id: 'default-sun',
        weekday: 6,
        startTime: '00:00',
        endTime: '00:00',
        isActive: false,
      ),
    ];
  }
}
