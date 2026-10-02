import 'package:hdhomesproject/features/callback/domain/entities/callback_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallbackAdminService {
  CallbackAdminService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static String slugify(String name) {
    final s = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'item' : s;
  }

  Future<List<AdminCallbackRow>> listRequests({int limit = 300}) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('callback_requests')
        .select(
          '*, callback_departments(name), callback_priorities(name)',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    final list = (rows as List)
        .map(
          (e) => AdminCallbackRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final assigneeIds = list
        .map((r) => r.assignedTo)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (assigneeIds.isEmpty) return list;

    final profiles = await client
        .from('profiles')
        .select('id, first_name, last_name, email')
        .inFilter('id', assigneeIds);
    final names = <String, String>{};
    for (final raw in profiles as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = '${m['id']}';
      final first = '${m['first_name'] ?? ''}'.trim();
      final last = '${m['last_name'] ?? ''}'.trim();
      final email = '${m['email'] ?? ''}'.trim();
      final full = '$first $last'.trim();
      names[id] = full.isNotEmpty ? full : (email.isNotEmpty ? email : id);
    }

    return list
        .map(
          (r) => r.assignedTo == null
              ? r
              : r.copyWith(assignedToName: names[r.assignedTo]),
        )
        .toList();
  }

  Future<AdminCallbackStats> fetchStats() async {
    final client = _client;
    if (client == null) return const AdminCallbackStats();

    final rows = await client.from('callback_requests').select('status');
    var total = 0;
    var neu = 0;
    var assigned = 0;
    var contacted = 0;
    var scheduled = 0;
    var completed = 0;
    var cancelled = 0;

    for (final raw in rows as List) {
      final status = '${(raw as Map)['status'] ?? ''}';
      total++;
      switch (status) {
        case 'new':
          neu++;
        case 'assigned':
          assigned++;
        case 'contacted':
          contacted++;
        case 'scheduled':
          scheduled++;
        case 'completed':
          completed++;
        case 'cancelled':
          cancelled++;
      }
    }

    return AdminCallbackStats(
      total: total,
      neu: neu,
      assigned: assigned,
      contacted: contacted,
      scheduled: scheduled,
      completed: completed,
      cancelled: cancelled,
    );
  }

  Future<List<CallbackStatusHistoryEntry>> fetchHistory(
    String callbackId,
  ) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('callback_status_history')
        .select()
        .eq('callback_id', callbackId)
        .order('changed_at', ascending: false);
    return (rows as List)
        .map(
          (e) => CallbackStatusHistoryEntry.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Staff profiles that can be assigned callbacks (active role holders).
  Future<List<CallbackStaffMember>> listAssignableStaff() async {
    final client = _client;
    if (client == null) return const [];

    final roleRows = await client
        .from('user_roles')
        .select('user_id')
        .eq('is_deleted', false)
        .eq('status', 'active')
        .limit(200);
    final ids = <String>{};
    for (final raw in roleRows as List) {
      final id = '${(raw as Map)['user_id'] ?? ''}';
      if (id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return const [];

    final profiles = await client
        .from('profiles')
        .select('id, first_name, last_name, email')
        .inFilter('id', ids.toList())
        .order('first_name');

    return (profiles as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final first = '${m['first_name'] ?? ''}'.trim();
      final last = '${m['last_name'] ?? ''}'.trim();
      final email = '${m['email'] ?? ''}'.trim();
      final full = '$first $last'.trim();
      return CallbackStaffMember(
        id: '${m['id']}',
        displayName: full.isNotEmpty ? full : (email.isNotEmpty ? email : 'Staff'),
        email: email.isEmpty ? null : email,
      );
    }).toList();
  }

  Future<void> updateStatus(
    String callbackId,
    String status, {
    String? reason,
    String? assignedTo,
    DateTime? scheduledAt,
    String? adminNotes,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_update_callback_status',
      params: {
        'p_callback_id': callbackId,
        'p_status': status,
        'p_reason': reason,
        'p_assigned_to': assignedTo,
        'p_scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'p_admin_notes': adminNotes,
      },
    );
  }

  Future<void> saveSettings(CallbackSettings settings) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client
        .from('callback_settings')
        .update(settings.toJson())
        .eq('id', settings.id);
  }

  Future<void> saveWorkingHour(CallbackWorkingHour hour) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = {
      'weekday': hour.weekday,
      'start_time': hour.startTime,
      'end_time': hour.endTime,
      'is_active': hour.isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final existing = await client
        .from('callback_working_hours')
        .select('id')
        .eq('weekday', hour.weekday)
        .maybeSingle();
    if (existing != null) {
      await client
          .from('callback_working_hours')
          .update(payload)
          .eq('weekday', hour.weekday);
    } else {
      await client.from('callback_working_hours').insert(payload);
    }
  }

  Future<String> upsertDepartment({
    String? id,
    required String name,
    String? description,
    String icon = 'briefcase',
    int responseHours = 24,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'name': name.trim(),
      'slug': slugify(name),
      'description': description?.trim(),
      'icon': icon,
      'response_hours': responseHours,
      'sort_order': sortOrder,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      final row = await client
          .from('callback_departments')
          .insert(payload)
          .select('id')
          .single();
      return '${row['id']}';
    }
    await client.from('callback_departments').update(payload).eq('id', id);
    return id;
  }

  Future<String> upsertPriority({
    String? id,
    required String name,
    String? description,
    int responseHours = 24,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'name': name.trim(),
      'slug': slugify(name),
      'description': description?.trim(),
      'response_hours': responseHours,
      'sort_order': sortOrder,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      final row = await client
          .from('callback_priorities')
          .insert(payload)
          .select('id')
          .single();
      return '${row['id']}';
    }
    await client.from('callback_priorities').update(payload).eq('id', id);
    return id;
  }

  Future<void> reorderDepartments(List<CallbackDepartment> ordered) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    for (var i = 0; i < ordered.length; i++) {
      await client.from('callback_departments').update({
        'sort_order': i,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', ordered[i].id);
    }
  }

  Future<void> reorderPriorities(List<CallbackPriority> ordered) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    for (var i = 0; i < ordered.length; i++) {
      await client.from('callback_priorities').update({
        'sort_order': i,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', ordered[i].id);
    }
  }

  /// Manual admin-created callback (same RPC as public form).
  Future<CallbackSubmitResult> createManualRequest({
    required String fullName,
    required String phone,
    required String reason,
    String? email,
    String? preferredTime,
    String? departmentId,
    String? priorityId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final row = await client.rpc(
      'submit_callback_request',
      params: {
        'p_full_name': fullName.trim(),
        'p_phone': phone.trim(),
        'p_reason': reason.trim(),
        'p_preferred_time': preferredTime,
        'p_department_id': departmentId,
        'p_priority_id': priorityId,
        'p_email': email?.trim(),
        'p_visitor_profile_id': null,
        'p_source': 'admin',
      },
    );
    final map = Map<String, dynamic>.from(row as Map);
    return CallbackSubmitResult(
      reference: '${map['reference'] ?? map['reference_number'] ?? ''}',
      department: map['department'] as String?,
      priority: map['priority'] as String?,
      responseHours: map['response_hours'] as int? ?? 24,
    );
  }
}
