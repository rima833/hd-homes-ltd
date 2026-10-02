import 'package:hdhomesproject/features/cshop/domain/entities/support_foundation_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository boundary for Support Phase 2 foundation records.
///
/// Supabase RLS remains the authority; this layer never uses elevated keys.
abstract interface class SupportRepository {
  Future<SupportConfigurationSnapshot> loadConfiguration();
  Future<List<SupportTicketEvent>> listTicketEvents(String ticketId);
  Future<List<SupportTicketLink>> listTicketLinks(String ticketId);
  Future<SupportSettings> updateSettings(SupportSettings settings);
  Future<SupportOperatingHour> upsertOperatingHour(SupportOperatingHour hour);
  Future<SupportHoliday> saveHoliday({
    String? id,
    required DateTime date,
    required String name,
    bool isClosed,
    String? opensAt,
    String? closesAt,
  });
  Future<void> deleteHoliday(String id);
  Future<SupportQuickReply> saveQuickReply({
    String? id,
    required String title,
    required String shortcut,
    required String body,
    String? categoryId,
    String? teamId,
    bool isActive,
    int sortOrder,
  });
  Future<void> deleteQuickReply(String id);
  Future<SupportAssignmentRule> saveAssignmentRule({
    String? id,
    required String name,
    int rank,
    bool isEnabled,
    String? categoryId,
    String? customerType,
    String? channel,
    String? priority,
    String? teamId,
    String? queueId,
    Map<String, dynamic> conditions,
  });
  Future<void> deleteAssignmentRule(String id);
  Future<SupportTicketLink> linkTicketContext({
    required String ticketId,
    required String entityType,
    required String entityId,
    String? label,
    String? resourceUrl,
    Map<String, dynamic> metadata,
  });
  Future<void> unlinkTicketContext(String linkId);
  Future<SupportTicketEvent> appendTicketEvent({
    required String ticketId,
    required String action,
    String? actorLabel,
    String? fromStatus,
    String? toStatus,
    String? fromPriority,
    String? toPriority,
    bool isInternal,
    Map<String, dynamic> metadata,
  });
}

final class SupabaseSupportRepository implements SupportRepository {
  SupabaseSupportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SupportConfigurationSnapshot> loadConfiguration() async {
    final settingsRow = await _client
        .from('support_settings')
        .select()
        .limit(1)
        .maybeSingle();
    if (settingsRow == null) {
      throw StateError('Support settings are not configured');
    }

    final results = await Future.wait<dynamic>([
      _client.from('support_operating_hours').select().order('day_of_week'),
      _client.from('support_holidays').select().order('holiday_date'),
      _client
          .from('support_quick_replies')
          .select()
          .order('sort_order')
          .order('title'),
      _client
          .from('support_assignment_rules')
          .select()
          .order('rank')
          .order('name'),
    ]);

    return SupportConfigurationSnapshot(
      settings: SupportSettings.fromJson(
        Map<String, dynamic>.from(settingsRow),
      ),
      hours: _models(results[0], SupportOperatingHour.fromJson),
      holidays: _models(results[1], SupportHoliday.fromJson),
      quickReplies: _models(results[2], SupportQuickReply.fromJson),
      assignmentRules: _models(results[3], SupportAssignmentRule.fromJson),
    );
  }

  @override
  Future<List<SupportTicketEvent>> listTicketEvents(String ticketId) async {
    final rows = await _client
        .from('support_ticket_events')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at');
    return _models(rows, SupportTicketEvent.fromJson);
  }

  @override
  Future<List<SupportTicketLink>> listTicketLinks(String ticketId) async {
    final rows = await _client
        .from('support_ticket_links')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at');
    return _models(rows, SupportTicketLink.fromJson);
  }

  @override
  Future<SupportSettings> updateSettings(SupportSettings settings) async {
    _requiredText(settings.timezone, 'Timezone');
    _requiredText(settings.welcomeMessage, 'Welcome message');
    _requiredText(settings.offlineMessage, 'Offline message');
    final row = await _client
        .from('support_settings')
        .update(settings.toUpdateJson())
        .eq('id', settings.id)
        .select()
        .single();
    return SupportSettings.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<SupportOperatingHour> upsertOperatingHour(
    SupportOperatingHour hour,
  ) async {
    if (hour.dayOfWeek < 0 || hour.dayOfWeek > 6) {
      throw ArgumentError.value(hour.dayOfWeek, 'dayOfWeek');
    }
    if (hour.isOpen &&
        ((hour.opensAt ?? '').isEmpty || (hour.closesAt ?? '').isEmpty)) {
      throw ArgumentError('Open days require opening and closing times');
    }
    final row = await _client
        .from('support_operating_hours')
        .upsert(hour.toUpsertJson(), onConflict: 'day_of_week')
        .select()
        .single();
    return SupportOperatingHour.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<SupportHoliday> saveHoliday({
    String? id,
    required DateTime date,
    required String name,
    bool isClosed = true,
    String? opensAt,
    String? closesAt,
  }) async {
    _requiredText(name, 'Holiday name');
    if (!isClosed && ((opensAt ?? '').isEmpty || (closesAt ?? '').isEmpty)) {
      throw ArgumentError('Partial holiday hours require opening and closing');
    }
    final payload = <String, dynamic>{
      'holiday_date': _dateOnly(date),
      'name': name.trim(),
      'is_closed': isClosed,
      'opens_at': isClosed ? null : opensAt,
      'closes_at': isClosed ? null : closesAt,
    };
    final dynamic row;
    if (id == null) {
      row = await _client
          .from('support_holidays')
          .insert(payload)
          .select()
          .single();
    } else {
      row = await _client
          .from('support_holidays')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
    }
    return SupportHoliday.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> deleteHoliday(String id) async {
    await _client.from('support_holidays').delete().eq('id', id);
  }

  @override
  Future<SupportQuickReply> saveQuickReply({
    String? id,
    required String title,
    required String shortcut,
    required String body,
    String? categoryId,
    String? teamId,
    bool isActive = true,
    int sortOrder = 100,
  }) async {
    _requiredText(title, 'Quick reply title');
    _requiredText(body, 'Quick reply body');
    final normalizedShortcut = _shortcut(shortcut);
    final payload = <String, dynamic>{
      'title': title.trim(),
      'shortcut': normalizedShortcut,
      'body': body.trim(),
      'category_id': categoryId,
      'team_id': teamId,
      'is_active': isActive,
      'sort_order': sortOrder,
      'created_by': id == null ? _client.auth.currentUser?.id : null,
    }..removeWhere((key, value) => key == 'created_by' && value == null);

    final dynamic row;
    if (id == null) {
      row = await _client
          .from('support_quick_replies')
          .insert(payload)
          .select()
          .single();
    } else {
      row = await _client
          .from('support_quick_replies')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
    }
    return SupportQuickReply.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> deleteQuickReply(String id) async {
    await _client.from('support_quick_replies').delete().eq('id', id);
  }

  @override
  Future<SupportAssignmentRule> saveAssignmentRule({
    String? id,
    required String name,
    int rank = 100,
    bool isEnabled = false,
    String? categoryId,
    String? customerType,
    String? channel,
    String? priority,
    String? teamId,
    String? queueId,
    Map<String, dynamic> conditions = const {},
  }) async {
    _requiredText(name, 'Assignment rule name');
    if (isEnabled && teamId == null && queueId == null) {
      throw ArgumentError('Enabled rules require a target team or queue');
    }
    final payload = <String, dynamic>{
      'name': name.trim(),
      'rank': rank,
      'is_enabled': isEnabled,
      'category_id': categoryId,
      'customer_type': customerType,
      'channel': channel,
      'priority': priority,
      'team_id': teamId,
      'queue_id': queueId,
      'conditions': conditions,
    };
    final dynamic row;
    if (id == null) {
      row = await _client
          .from('support_assignment_rules')
          .insert(payload)
          .select()
          .single();
    } else {
      row = await _client
          .from('support_assignment_rules')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
    }
    return SupportAssignmentRule.fromJson(
      Map<String, dynamic>.from(row as Map),
    );
  }

  @override
  Future<void> deleteAssignmentRule(String id) async {
    await _client.from('support_assignment_rules').delete().eq('id', id);
  }

  @override
  Future<SupportTicketLink> linkTicketContext({
    required String ticketId,
    required String entityType,
    required String entityId,
    String? label,
    String? resourceUrl,
    Map<String, dynamic> metadata = const {},
  }) async {
    _requiredText(ticketId, 'Ticket ID');
    _requiredText(entityType, 'Entity type');
    _requiredText(entityId, 'Entity ID');
    final row = await _client
        .from('support_ticket_links')
        .upsert({
          'ticket_id': ticketId,
          'entity_type': entityType,
          'entity_id': entityId,
          'label': label?.trim(),
          'resource_url': resourceUrl?.trim(),
          'metadata': metadata,
        }, onConflict: 'ticket_id,entity_type,entity_id')
        .select()
        .single();
    return SupportTicketLink.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> unlinkTicketContext(String linkId) async {
    await _client.from('support_ticket_links').delete().eq('id', linkId);
  }

  @override
  Future<SupportTicketEvent> appendTicketEvent({
    required String ticketId,
    required String action,
    String? actorLabel,
    String? fromStatus,
    String? toStatus,
    String? fromPriority,
    String? toPriority,
    bool isInternal = false,
    Map<String, dynamic> metadata = const {},
  }) async {
    final row = await _client
        .from('support_ticket_events')
        .insert({
          'ticket_id': ticketId,
          'actor_id': _client.auth.currentUser?.id,
          'actor_label': actorLabel ?? _client.auth.currentUser?.email,
          'action': action,
          'from_status': fromStatus,
          'to_status': toStatus,
          'from_priority': fromPriority,
          'to_priority': toPriority,
          'is_internal': isInternal,
          'metadata': metadata,
        })
        .select()
        .single();
    return SupportTicketEvent.fromJson(Map<String, dynamic>.from(row));
  }

  static List<T> _models<T>(
    dynamic rows,
    T Function(Map<String, dynamic>) factory,
  ) {
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => factory(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  static void _requiredText(String value, String label) {
    if (value.trim().isEmpty) throw ArgumentError('$label is required');
  }

  static String _shortcut(String input) {
    final normalized = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    _requiredText(normalized, 'Quick reply shortcut');
    return normalized;
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
