import 'package:hdhomesproject/features/consultation/domain/entities/consultation_admin_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsultationAdminService {
  ConsultationAdminService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<List<AdminConsultationRow>> listBookings({int limit = 200}) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('consultation_bookings')
        .select(
          '*, consultation_departments(name, slug), '
          'consultation_advisors(full_name), '
          'office_locations(name)',
        )
        .order('scheduled_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map(
          (e) => AdminConsultationRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<AdminConsultationStats> fetchStats() async {
    final client = _client;
    if (client == null) return const AdminConsultationStats();

    final rows = await client
        .from('consultation_bookings')
        .select('status, scheduled_at');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var total = 0;
    var todayCount = 0;
    var upcoming = 0;
    var pending = 0;
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
      if (at.isAfter(now) &&
          !{'cancelled', 'rejected', 'completed', 'no_show'}.contains(status)) {
        upcoming++;
      }

      switch (status) {
        case 'scheduled':
        case 'pending':
        case 'assigned':
          pending++;
        case 'confirmed':
        case 'in_progress':
          confirmed++;
        case 'completed':
          completed++;
        case 'cancelled':
        case 'rejected':
          cancelled++;
        case 'no_show':
          noShow++;
      }
    }

    return AdminConsultationStats(
      total: total,
      today: todayCount,
      upcoming: upcoming,
      pending: pending,
      confirmed: confirmed,
      completed: completed,
      cancelled: cancelled,
      noShow: noShow,
    );
  }

  Future<List<ConsultationBookingEvent>> fetchEvents(String bookingId) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('consultation_booking_events')
        .select()
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map(
          (e) => ConsultationBookingEvent.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<AdminConsultationAdvisor>> listAdvisors() async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('consultation_advisors')
        .select('*, consultation_departments(name)')
        .order('sort_order');

    return (rows as List)
        .map(
          (e) => AdminConsultationAdvisor.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<AdminConsultationDepartment>> listDepartments() async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('consultation_departments')
        .select()
        .order('sort_order');

    return (rows as List)
        .map(
          (e) => AdminConsultationDepartment.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> updateStatus(
    String bookingId,
    String status, {
    String? reason,
    String? meetingUrl,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_update_consultation_status',
      params: {
        'p_booking_id': bookingId,
        'p_status': status,
        'p_reason': reason,
        'p_meeting_url': meetingUrl,
      },
    );
  }

  Future<void> assignAdvisor(String bookingId, String advisorId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_assign_consultation_advisor',
      params: {
        'p_booking_id': bookingId,
        'p_advisor_id': advisorId,
      },
    );
  }

  Future<void> rescheduleBooking({
    required String bookingId,
    required DateTime scheduledAt,
    String? advisorId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_reschedule_consultation',
      params: {
        'p_booking_id': bookingId,
        'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'p_advisor_id': ?advisorId,
      },
    );
  }

  Future<void> addAdminNote(String bookingId, String note) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.rpc(
      'admin_add_consultation_note',
      params: {
        'p_booking_id': bookingId,
        'p_note': note,
      },
    );
  }

  Future<List<Map<String, dynamic>>> listWorkingHours() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('consultation_working_hours')
        .select()
        .order('weekday');
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listHolidays() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('consultation_holidays')
        .select()
        .order('holiday_date');
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchSettings() async {
    final client = _client;
    if (client == null) return null;
    final row = await client
        .from('consultation_settings')
        .select()
        .eq('id', 1)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('consultation_settings').update({
      ...patch,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', 1);
  }

  String _normalizeTime(String raw) {
    final parts = raw.trim().split(':');
    final h = (parts.isNotEmpty ? parts[0] : '09').padLeft(2, '0');
    final m = (parts.length > 1 ? parts[1] : '00').padLeft(2, '0');
    final s = (parts.length > 2 ? parts[2] : '00').padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> upsertWorkingHours({
    required int weekday,
    required String startTime,
    required String endTime,
    required bool isActive,
    int slotMinutes = 45,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('consultation_working_hours').upsert({
      'weekday': weekday,
      'start_time': _normalizeTime(startTime),
      'end_time': _normalizeTime(endTime),
      'slot_minutes': slotMinutes,
      'is_active': isActive,
    }, onConflict: 'weekday');
  }

  Future<List<Map<String, dynamic>>> listConsultationTypes() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('consultation_types')
        .select('*, consultation_departments(name)')
        .order('sort_order');
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> toggleConsultationTypeActive(String id, bool active) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('consultation_types').update({
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> toggleDepartmentActive(String id, bool active) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('consultation_departments').update({
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> toggleAdvisorActive(String id, bool active) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('consultation_advisors').update({
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  String _slugify(String input) {
    final slug = input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'item-${DateTime.now().millisecondsSinceEpoch}' : slug;
  }

  Future<String> upsertAdvisor({
    String? id,
    required String fullName,
    required String title,
    String? departmentId,
    String? email,
    String? phone,
    String? whatsapp,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'full_name': fullName.trim(),
      'title': title.trim().isEmpty ? 'Advisor' : title.trim(),
      'department_id': departmentId,
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'whatsapp': whatsapp?.trim().isEmpty == true ? null : whatsapp?.trim(),
      'is_active': isActive,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      final row = await client
          .from('consultation_advisors')
          .insert(payload)
          .select('id')
          .single();
      return row['id'] as String;
    }
    await client.from('consultation_advisors').update(payload).eq('id', id);
    return id;
  }

  Future<void> deleteAdvisor(String id) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('consultation_advisors').update({
      'is_active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<String> upsertDepartment({
    String? id,
    required String name,
    String? description,
    String? responseTimeLabel,
    int durationMinutes = 45,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'name': name.trim(),
      'slug': _slugify(name),
      'description': description?.trim() ?? '',
      'response_time_label': responseTimeLabel?.trim() ?? '',
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'sort_order': sortOrder,
      'icon_name': 'briefcase',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      final row = await client
          .from('consultation_departments')
          .insert(payload)
          .select('id')
          .single();
      return row['id'] as String;
    }
    await client.from('consultation_departments').update({
      ...payload,
      // Keep existing slug on edit unless name drives a new unique need —
      // still update slug for consistency with rename.
    }).eq('id', id);
    return id;
  }

  Future<String> upsertConsultationType({
    String? id,
    required String name,
    String? departmentId,
    String? description,
    int durationMinutes = 45,
    double priceAmount = 0,
    String currency = 'NGN',
    List<String> meetingMethods = const ['video', 'in_person'],
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'name': name.trim(),
      'slug': _slugify(name),
      'department_id': departmentId,
      'description': description?.trim() ?? '',
      'duration_minutes': durationMinutes,
      'price_amount': priceAmount,
      'currency': currency,
      'meeting_methods': meetingMethods,
      'is_active': isActive,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      final row = await client
          .from('consultation_types')
          .insert(payload)
          .select('id')
          .single();
      return row['id'] as String;
    }
    await client.from('consultation_types').update(payload).eq('id', id);
    return id;
  }

  Future<void> addHoliday({
    required DateTime date,
    required String name,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final day = DateTime(date.year, date.month, date.day);
    await client.from('consultation_holidays').insert({
      'holiday_date':
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      'name': name.trim(),
    });
  }

  Future<void> deleteHoliday(String id) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('consultation_holidays').delete().eq('id', id);
  }
}
