import 'dart:async';
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
  final List<AuditRecord> _localBuffer = [];

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

  List<AuditRecord> get recentLocal => List.unmodifiable(_localBuffer);

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

  Future<CommandCenterSnapshot> loadCommandCenter() async {
    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final recent = await _queryAuditLogs(
      filter: const ObservabilityFilter(preset: ActivityDatePreset.last7Days),
      limit: 80,
    );
    final today = recent
        .where((r) => !r.createdAt.isBefore(startOfToday))
        .toList();
    final failedLogins = today
        .where(
          (r) =>
              r.action.contains('login') &&
              (r.status == AuditResultStatus.failure ||
                  r.action.contains('fail')),
        )
        .length;
    final alerts = await listAlerts(limit: 40);
    final open = alerts
        .where((a) => a.lifecycle != AlertLifecycle.resolved)
        .toList();
    final critical = open
        .where(
          (a) =>
              a.severity == AuditSeverity.critical ||
              a.severity == AuditSeverity.emergency,
        )
        .length;
    final health = await listHealth();
    final activeUsers = today.map((e) => e.userId).whereType<String>().toSet();

    return CommandCenterSnapshot(
      todayActivity: today.length,
      activeUsersEstimate: activeUsers.length,
      failedLogins: failedLogins,
      openAlerts: open.length,
      criticalAlerts: critical,
      recentActivity: recent.take(25).toList(),
      alerts: open.take(15).toList(),
      health: health,
      securityScore: ObservabilityEngine.computeSecurityScore(
        openCritical: critical,
        failedLoginsToday: failedLogins,
        openAlerts: open.length,
      ),
    );
  }

  Future<List<SystemAlert>> listAlerts({int limit = 50}) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('system_alerts')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((e) => SystemAlert.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
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

  Future<List<SystemHealthCheck>> listHealth() async {
    final client = _client;
    if (client == null) {
      return _defaultHealth(supabase: false);
    }
    try {
      final rows = await client
          .from('system_health')
          .select()
          .order('service_key');
      final list = (rows as List)
          .map(
            (e) =>
                SystemHealthCheck.fromRow(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      if (list.isEmpty) return _defaultHealth(supabase: true);
      return list;
    } catch (_) {
      return _defaultHealth(supabase: true);
    }
  }

  Future<List<ChangeHistoryEntry>> loadChangeHistory({
    required String entityType,
    required String entityId,
  }) async {
    final client = _client;
    if (client == null) return const [];
    try {
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
    } catch (_) {
      return const [];
    }
  }

  /// CSV export stub (permission-gated in UI).
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

    _localBuffer.insert(0, record);
    if (_localBuffer.length > 200) {
      _localBuffer.removeRange(200, _localBuffer.length);
    }

    AppLogger.info(
      'AuditEvent: ${request.module}/${request.action} [${request.severity.slug}]',
    );

    final client = _client;
    if (client == null) return record;

    try {
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
    } catch (_) {
      // Fall through to direct inserts when RPC not yet applied.
    }

    try {
      await client.from('audit_logs').insert({
        'id': id,
        'user_id': request.userId,
        'action': request.action,
        'module': request.module,
        'entity_type': request.entityType,
        'entity_id': request.entityId,
        'user_agent': request.userAgent,
        'metadata': request.metadata,
        'event_category': request.category.slug,
        'severity': request.severity.slug,
        'result_status': request.status.slug,
        'reason': request.reason,
        'correlation_id': request.correlationId,
        'request_id': request.requestId,
        'actor_role': request.actorRole,
        'session_id': request.sessionId,
        'device': request.device,
        'browser': request.browser,
        'operating_system': request.operatingSystem,
        'old_values': request.oldValues,
        'new_values': request.newValues,
      });
    } catch (e) {
      AppLogger.info('Audit persist soft-fail: $e');
    }

    if (request.visibleToUser && request.userId != null) {
      try {
        await client.from('activity_logs').insert({
          'user_id': request.userId,
          'activity_type': request.action,
          'module': request.module,
          'entity_type': request.entityType,
          'entity_id': request.entityId,
          'severity': request.severity.slug,
          'audit_log_id': id,
          'metadata': request.metadata,
        });
      } catch (_) {
        try {
          await client.from('user_activity').insert({
            'user_id': request.userId,
            'activity_type': request.action,
            'entity_type': request.entityType,
            'entity_id': request.entityId,
            'metadata': {
              ...request.metadata,
              'module': request.module,
              'audit_log_id': id,
            },
          });
        } catch (_) {}
      }
    }

    if (request.oldValues != null || request.newValues != null) {
      unawaited(_writeChangeHistory(id, request));
    }

    if (request.severity.shouldAlert) {
      unawaited(_raiseAlert(id, request));
    }

    if (request.immutableVault) {
      unawaited(_vaultSnapshot(id, request));
    }

    return record;
  }

  Future<void> _writeChangeHistory(
    String auditId,
    AuditPublishRequest request,
  ) async {
    final client = _client;
    if (client == null || request.entityType == null || request.entityId == null) {
      return;
    }
    final oldMap = request.oldValues ?? const {};
    final newMap = request.newValues ?? const {};
    final keys = {...oldMap.keys, ...newMap.keys};
    for (final key in keys) {
      final ov = oldMap[key];
      final nv = newMap[key];
      if (ov == nv) continue;
      try {
        await client.from('change_history').insert({
          'entity_type': request.entityType,
          'entity_id': request.entityId,
          'field_name': key,
          'old_value': ov?.toString(),
          'new_value': nv?.toString(),
          'changed_by': request.userId,
          'audit_log_id': auditId,
        });
      } catch (_) {}
    }
  }

  Future<void> _raiseAlert(String auditId, AuditPublishRequest request) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('system_alerts').insert({
        'title': '${request.module}: ${request.action}',
        'description': request.reason ?? request.action,
        'severity': request.severity.slug,
        'lifecycle': AlertLifecycle.open.slug,
        'source_module': request.module,
        'audit_log_id': auditId,
        'metadata': request.metadata,
      });
    } catch (_) {}
  }

  Future<void> _vaultSnapshot(
    String auditId,
    AuditPublishRequest request,
  ) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('compliance_vault').insert({
        'audit_log_id': auditId,
        'event_category': request.category.slug,
        'action': request.action,
        'entity_type': request.entityType,
        'entity_id': request.entityId,
        'snapshot': {
          'old_values': request.oldValues,
          'new_values': request.newValues,
          'metadata': request.metadata,
          'user_id': request.userId,
          'correlation_id': request.correlationId,
        },
      });
    } catch (_) {}
  }

  Future<void> _updateAlertLifecycle(
    String alertId,
    AlertLifecycle lifecycle, {
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('system_alerts').update({
        'lifecycle': lifecycle.slug,
        if (lifecycle == AlertLifecycle.resolved)
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        if (actorId != null) 'resolved_by': actorId,
      }).eq('id', alertId);
    } catch (_) {}
  }

  Future<List<AuditRecord>> _queryAuditLogs({
    ObservabilityFilter filter = const ObservabilityFilter(),
    String? userId,
    int limit = 100,
  }) async {
    final client = _client;
    if (client == null) {
      return ObservabilityEngine.applyFilter(
        _localBuffer,
        filter.copyWith(userId: userId ?? filter.userId),
      );
    }

    final (from, to) = filter.dateRange;
    try {
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
    } catch (_) {
      // Fallback when extended columns not yet migrated.
      try {
        var query = client.from('audit_logs').select();
        final uid = userId ?? filter.userId;
        if (uid != null) query = query.eq('user_id', uid);
        final rows = await query
            .order('created_at', ascending: false)
            .limit(limit);
        return (rows as List)
            .map(
              (e) => AuditRecord.fromRow(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {
        return ObservabilityEngine.applyFilter(_localBuffer, filter);
      }
    }
  }

  List<SystemHealthCheck> _defaultHealth({required bool supabase}) {
    final now = DateTime.now().toUtc();
    return [
      SystemHealthCheck(
        serviceKey: 'database',
        label: 'Database',
        status: supabase
            ? SystemHealthStatus.healthy
            : SystemHealthStatus.unknown,
        checkedAt: now,
        message: supabase ? 'Reachable' : 'Client not configured',
      ),
      SystemHealthCheck(
        serviceKey: 'realtime',
        label: 'Realtime',
        status: supabase
            ? SystemHealthStatus.healthy
            : SystemHealthStatus.unknown,
        checkedAt: now,
      ),
      SystemHealthCheck(
        serviceKey: 'auth',
        label: 'Authentication',
        status: supabase
            ? SystemHealthStatus.healthy
            : SystemHealthStatus.unknown,
        checkedAt: now,
      ),
      const SystemHealthCheck(
        serviceKey: 'email',
        label: 'Email provider',
        status: SystemHealthStatus.degraded,
        message: 'Queued delivery (Phase 1)',
      ),
      const SystemHealthCheck(
        serviceKey: 'sms',
        label: 'SMS provider',
        status: SystemHealthStatus.degraded,
        message: 'Queued delivery (Phase 1)',
      ),
      SystemHealthCheck(
        serviceKey: 'storage',
        label: 'Storage',
        status: supabase
            ? SystemHealthStatus.healthy
            : SystemHealthStatus.unknown,
        checkedAt: now,
      ),
      const SystemHealthCheck(
        serviceKey: 'edge_functions',
        label: 'Edge Functions',
        status: SystemHealthStatus.unknown,
        message: 'Not probed in Phase 1',
      ),
    ];
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
