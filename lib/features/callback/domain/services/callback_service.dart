import 'dart:convert';

import 'package:hdhomesproject/features/callback/domain/entities/callback_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallbackService {
  CallbackService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

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

  Future<CallbackSettings?> fetchSettings() async {
    final client = _client;
    if (client == null) return null;
    final row = await client
        .from('callback_settings')
        .select()
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return CallbackSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<CallbackDepartment>> fetchDepartments({bool activeOnly = true}) async {
    final client = _client;
    if (client == null) return const [];
    final rows = activeOnly
        ? await client
            .from('callback_departments')
            .select()
            .eq('is_active', true)
            .order('sort_order')
        : await client.from('callback_departments').select().order('sort_order');
    return (rows as List)
        .map((e) => CallbackDepartment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<CallbackPriority>> fetchPriorities({bool activeOnly = true}) async {
    final client = _client;
    if (client == null) return const [];
    final rows = activeOnly
        ? await client
            .from('callback_priorities')
            .select()
            .eq('is_active', true)
            .order('sort_order')
        : await client.from('callback_priorities').select().order('sort_order');
    return (rows as List)
        .map((e) => CallbackPriority.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<CallbackWorkingHour>> fetchWorkingHours() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client.from('callback_working_hours').select().order('weekday');
    return (rows as List)
        .map((e) => CallbackWorkingHour.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Africa/Lagos weekday: Mon=0 .. Sun=6
  bool isWithinBusinessHours(
    List<CallbackWorkingHour> hours, {
    DateTime? now,
  }) {
    final lagos = now ?? DateTime.now().toUtc().add(const Duration(hours: 1));
    final weekday = (lagos.weekday + 6) % 7; // DateTime Mon=1 → 0
    CallbackWorkingHour? today;
    for (final h in hours) {
      if (h.weekday == weekday) today = h;
    }
    if (today == null || !today.isActive) return false;
    final partsStart = today.startTime.split(':');
    final partsEnd = today.endTime.split(':');
    final start = int.parse(partsStart[0]) * 60 + int.parse(partsStart[1]);
    final end = int.parse(partsEnd[0]) * 60 + int.parse(partsEnd[1]);
    if (start >= end) return false;
    final mins = lagos.hour * 60 + lagos.minute;
    return mins >= start && mins < end;
  }

  Future<CallbackSubmitResult> submit({
    required String fullName,
    required String phone,
    required String reason,
    String? preferredTime,
    String? departmentId,
    String? priorityId,
    String? email,
    String? visitorProfileId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    try {
      final row = await client.rpc(
        'submit_callback_request',
        params: {
          'p_full_name': fullName.trim(),
          'p_phone': phone.trim(),
          'p_reason': reason.trim(),
          'p_preferred_time': preferredTime,
          'p_department_id': departmentId,
          'p_priority_id': priorityId,
          'p_email': email,
          'p_visitor_profile_id': visitorProfileId,
          'p_source': 'public_web',
        },
      );

      final map = _coerceMap(row);
      if (map == null || map['reference'] == null) {
        throw StateError('We couldn\'t submit your request. Please try again.');
      }

      return CallbackSubmitResult(
        reference: '${map['reference']}',
        department: map['department']?.toString(),
        priority: map['priority']?.toString(),
        responseHours: map['response_hours'] as int? ?? 24,
      );
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains('callback_disabled')) {
        throw StateError('Callback requests are temporarily unavailable.');
      }
      if (msg.contains('phone')) {
        throw StateError('Please enter a valid phone number.');
      }
      throw StateError('We couldn\'t submit your request. Please try again.');
    }
  }
}
