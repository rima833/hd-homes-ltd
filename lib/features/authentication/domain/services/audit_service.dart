import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Audit Service — sole writer path for enterprise audit records.
///
/// Feature modules must call [publish] (or [EnterpriseEventBus] via this service).
/// Never insert into `audit_logs` / `activity_logs` from business modules.
class AuditService {
  AuditService({
    SupabaseClient? client,
    EnterpriseEventBus? eventBus,
  })  : _client = client,
        eventBus = eventBus ?? EnterpriseEventBus() {
    this.eventBus.subscribe(EventBusSubscriber.auditService, _onBusEvent);
  }

  final SupabaseClient? _client;
  final EnterpriseEventBus eventBus;
  final _random = Random.secure();

  String _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  bool get isConfigured => _client != null;

  /// Primary entry — publish a platform event through the Event Bus + persist.
  Future<AuditRecord> publish(AuditPublishRequest request) async {
    final severity = ObservabilityEngine.inferSeverity(
      category: request.category,
      status: request.status,
      explicit: request.severity,
    );
    final correlationId = request.correlationId ?? _newId();
    final enriched = AuditPublishRequest(
      action: request.action,
      module: request.module,
      category: request.category,
      userId: request.userId,
      actorRole: request.actorRole,
      sessionId: request.sessionId,
      entityType: request.entityType,
      entityId: request.entityId,
      oldValues: request.oldValues,
      newValues: request.newValues,
      status: request.status,
      severity: severity,
      reason: request.reason,
      correlationId: correlationId,
      requestId: request.requestId ?? _newId(),
      device: request.device,
      browser: request.browser,
      operatingSystem: request.operatingSystem,
      ipAddress: request.ipAddress,
      userAgent: request.userAgent ??
          (kIsWeb ? 'web' : defaultTargetPlatform.name),
      metadata: {
        ...request.metadata,
        'category': request.category.slug,
        'retention_years': ObservabilityEngine.retentionYears(
          category: request.category,
          severity: severity,
        ),
      },
      immutableVault: request.immutableVault,
      visibleToUser: request.visibleToUser,
    );

    eventBus.publish(enriched.action, enriched);
    return _persist(enriched);
  }

  /// Convenience for named domain events (User Registered, KYC Approved, …).
  Future<AuditRecord> emitNamed(
    String eventName, {
    required AuditPublishRequest request,
  }) {
    return publish(
      AuditPublishRequest(
        action: eventName,
        module: request.module,
        category: request.category,
        userId: request.userId,
        actorRole: request.actorRole,
        sessionId: request.sessionId,
        entityType: request.entityType,
        entityId: request.entityId,
        oldValues: request.oldValues,
        newValues: request.newValues,
        status: request.status,
        severity: request.severity,
        reason: request.reason,
        correlationId: request.correlationId,
        requestId: request.requestId,
        device: request.device,
        browser: request.browser,
        operatingSystem: request.operatingSystem,
        ipAddress: request.ipAddress,
        userAgent: request.userAgent,
        metadata: {...request.metadata, 'event_name': eventName},
        immutableVault: request.immutableVault,
        visibleToUser: request.visibleToUser,
      ),
    );
  }

  Future<ActivityTimelineSnapshot> loadUserTimeline(
    String userId, {
    ObservabilityFilter filter = const ObservabilityFilter(),
  }) async {
    final rows = await _queryAuditLogs(
      userId: userId,
      filter: filter.copyWith(userId: userId),
      limit: 200,
    );
    final items = ObservabilityEngine.applyFilter(rows, filter);
    return ActivityTimelineSnapshot(items: items, filter: filter);
  }

  Future<List<AuditRecord>> search(ObservabilityFilter filter) async {
    final rows = await _queryAuditLogs(filter: filter, limit: 300);
    return ObservabilityEngine.applyFilter(rows, filter);
  }

  /// Server-aggregated OCC snapshot (no client KPI heuristics).
  Future<CommandCenterSnapshot> loadCommandCenter() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured for Observability.');
    }
    final raw = await client.rpc('observability_command_center');
    if (raw is! Map) {
      throw StateError('observability_command_center returned unexpected payload.');
    }
    return CommandCenterSnapshot.fromRpc(Map<String, dynamic>.from(raw));
  }

  Future<List<SystemAlert>> listAlerts({int limit = 50}) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('system_alerts')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => SystemAlert.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> acknowledgeAlert(String alertId, {String? actorId}) async {
    await _updateAlertLifecycle(
      alertId,
      AlertLifecycle.acknowledged,
      actorId: actorId,
    );
  }

  Future<void> resolveAlert(String alertId, {String? actorId}) async {
    await _updateAlertLifecycle(
      alertId,
      AlertLifecycle.resolved,
      actorId: actorId,
    );
  }

  /// Acknowledge or resolve every open row that shares one alert signature.
  Future<int> updateAlertGroup({
    required String title,
    required String? sourceModule,
    required String severity,
    required AlertLifecycle lifecycle,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Cannot update alert: Supabase is not configured.');
    }
    final raw = await client.rpc(
      'resolve_open_alert_group',
      params: {
        'p_title': title,
        'p_source_module': sourceModule,
        'p_severity': severity,
        'p_lifecycle': lifecycle.slug,
      },
    );
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }

  Future<List<SystemHealthCheck>> listHealth() async {
    final client = _client;
    if (client == null) return const [];
    final rows =
        await client.from('system_health').select().order('service_key');
    return (rows as List)
        .map(
          (e) =>
              SystemHealthCheck.fromRow(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Invokes the deployed Edge health probe and returns refreshed rows.
  Future<List<SystemHealthCheck>> runHealthProbe() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured for Observability.');
    }
    final res = await client.functions.invoke('observability-health-probe');
    if (res.status >= 400) {
      throw StateError(
        'Health probe failed (${res.status}): ${res.data}',
      );
    }
    return listHealth();
  }

  Future<List<ChangeHistoryEntry>> loadChangeHistory({
    required String entityType,
    required String entityId,
  }) async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('change_history')
        .select()
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map(
          (e) => ChangeHistoryEntry.fromRow(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  String exportCsv(List<AuditRecord> records) {
    final buf = StringBuffer(
      'id,created_at_utc,user_id,module,action,category,severity,status,entity_type,entity_id,correlation_id\n',
    );
    for (final r in records) {
      buf.writeln(
        [
          r.id,
          r.createdAt.toIso8601String(),
          r.userId ?? '',
          r.module,
          r.action,
          r.category.slug,
          r.severity.slug,
          r.status.slug,
          r.entityType ?? '',
          r.entityId ?? '',
          r.correlationId ?? '',
        ].map(_csvEscape).join(','),
      );
    }
    return buf.toString();
  }

  RealtimeChannel? subscribeAuditFeed(void Function(AuditRecord) onInsert) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('audit-logs-feed');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audit_logs',
          callback: (payload) {
            try {
              onInsert(
                AuditRecord.fromRow(
                  Map<String, dynamic>.from(payload.newRecord),
                ),
              );
            } catch (_) {}
          },
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel? subscribeAlerts(void Function() onChange) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('system-alerts-feed');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'system_alerts',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel? subscribeHealth(void Function() onChange) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('system-health-feed');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'system_health',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  void _onBusEvent(EventBusEnvelope envelope) {
    AppLogger.info(
      'EventBus: ${envelope.eventName} → ${envelope.request.module}',
    );
  }

  Future<AuditRecord> _persist(AuditPublishRequest request) async {
    final id = _newId();
    final createdAt = DateTime.now().toUtc();
    final record = AuditRecord(
      id: id,
      action: request.action,
      module: request.module,
      category: request.category,
      severity: request.severity,
      status: request.status,
      createdAt: createdAt,
      userId: request.userId,
      actorRole: request.actorRole,
      sessionId: request.sessionId,
      entityType: request.entityType,
      entityId: request.entityId,
      oldValues: request.oldValues,
      newValues: request.newValues,
      reason: request.reason,
      correlationId: request.correlationId,
      requestId: request.requestId,
      device: request.device,
      browser: request.browser,
      operatingSystem: request.operatingSystem,
      ipAddress: request.ipAddress,
      userAgent: request.userAgent,
      metadata: request.metadata,
    );

    AppLogger.info(
      'AuditEvent: ${request.module}/${request.action} [${request.severity.slug}]',
    );

    final client = _client;
    if (client == null) {
      AppLogger.warning(
        'Audit event recorded locally only: Supabase is not configured.',
      );
      return record;
    }

    await client.rpc(
      'publish_audit_event',
      params: {
        'p_id': id,
        'p_user_id': request.userId,
        'p_action': request.action,
        'p_module': request.module,
        'p_event_category': request.category.slug,
        'p_entity_type': request.entityType,
        'p_entity_id': request.entityId,
        'p_old_values': request.oldValues,
        'p_new_values': request.newValues,
        'p_result_status': request.status.slug,
        'p_severity': request.severity.slug,
        'p_reason': request.reason,
        'p_correlation_id': request.correlationId,
        'p_request_id': request.requestId,
        'p_actor_role': request.actorRole,
        'p_session_id': request.sessionId,
        'p_device': request.device,
        'p_browser': request.browser,
        'p_operating_system': request.operatingSystem,
        'p_user_agent': request.userAgent,
        'p_metadata': request.metadata,
        'p_immutable': request.immutableVault,
        'p_visible_to_user': request.visibleToUser,
      },
    );
    return record;
  }

  Future<void> _updateAlertLifecycle(
    String alertId,
    AlertLifecycle lifecycle, {
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Cannot update alert: Supabase is not configured.');
    }
    await client.from('system_alerts').update({
      'lifecycle': lifecycle.slug,
      if (lifecycle == AlertLifecycle.resolved)
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      'resolved_by': ?actorId,
    }).eq('id', alertId);
  }

  Future<List<AuditRecord>> _queryAuditLogs({
    ObservabilityFilter filter = const ObservabilityFilter(),
    String? userId,
    int limit = 100,
  }) async {
    final client = _client;
    if (client == null) return const [];

    final (from, to) = filter.dateRange;
    var query = client.from('audit_logs').select();
    final uid = userId ?? filter.userId;
    if (uid != null) query = query.eq('user_id', uid);
    if (filter.module != null) query = query.eq('module', filter.module!);
    if (filter.category != null) {
      query = query.eq('event_category', filter.category!.slug);
    }
    if (filter.severity != null) {
      query = query.eq('severity', filter.severity!.slug);
    }
    final rows = await query
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => AuditRecord.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
