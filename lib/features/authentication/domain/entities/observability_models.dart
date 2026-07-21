import 'package:flutter/material.dart';

/// Enterprise Observability — event categories across the HD Homes ecosystem.
enum AuditEventCategory {
  user,
  security,
  authentication,
  property,
  investment,
  payment,
  crm,
  booking,
  support,
  document,
  admin,
  system,
  api,
  ai,
  workflow,
  kyc,
  communication,
  profile;

  String get slug => name;

  String get label => switch (this) {
        AuditEventCategory.user => 'User',
        AuditEventCategory.security => 'Security',
        AuditEventCategory.authentication => 'Authentication',
        AuditEventCategory.property => 'Property',
        AuditEventCategory.investment => 'Investment',
        AuditEventCategory.payment => 'Payment',
        AuditEventCategory.crm => 'CRM',
        AuditEventCategory.booking => 'Booking',
        AuditEventCategory.support => 'Support',
        AuditEventCategory.document => 'Document',
        AuditEventCategory.admin => 'Admin',
        AuditEventCategory.system => 'System',
        AuditEventCategory.api => 'API',
        AuditEventCategory.ai => 'AI',
        AuditEventCategory.workflow => 'Workflow',
        AuditEventCategory.kyc => 'KYC',
        AuditEventCategory.communication => 'Communication',
        AuditEventCategory.profile => 'Profile',
      };

  static AuditEventCategory fromSlug(String? raw) {
    final key = (raw ?? 'system').toLowerCase();
    return AuditEventCategory.values.firstWhere(
      (e) => e.slug == key || e.name == key,
      orElse: () => AuditEventCategory.system,
    );
  }
}

/// Severity drives color, alerting, and retention policy.
enum AuditSeverity {
  info,
  success,
  notice,
  warning,
  error,
  critical,
  emergency;

  String get slug => name;

  int get rank => index;

  bool get shouldAlert =>
      this == AuditSeverity.warning ||
      this == AuditSeverity.error ||
      this == AuditSeverity.critical ||
      this == AuditSeverity.emergency;

  Color get color => switch (this) {
        AuditSeverity.info => const Color(0xFF64748B),
        AuditSeverity.success => const Color(0xFF16A34A),
        AuditSeverity.notice => const Color(0xFF2563EB),
        AuditSeverity.warning => const Color(0xFFD97706),
        AuditSeverity.error => const Color(0xFFDC2626),
        AuditSeverity.critical => const Color(0xFFB91C1C),
        AuditSeverity.emergency => const Color(0xFF7F1D1D),
      };

  IconData get icon => switch (this) {
        AuditSeverity.info => Icons.info_outline,
        AuditSeverity.success => Icons.check_circle_outline,
        AuditSeverity.notice => Icons.notifications_none,
        AuditSeverity.warning => Icons.warning_amber_outlined,
        AuditSeverity.error => Icons.error_outline,
        AuditSeverity.critical => Icons.priority_high,
        AuditSeverity.emergency => Icons.crisis_alert,
      };

  static AuditSeverity fromSlug(String? raw) {
    return switch ((raw ?? 'info').toLowerCase()) {
      'success' => AuditSeverity.success,
      'notice' => AuditSeverity.notice,
      'warning' => AuditSeverity.warning,
      'error' => AuditSeverity.error,
      'critical' => AuditSeverity.critical,
      'emergency' => AuditSeverity.emergency,
      _ => AuditSeverity.info,
    };
  }
}

enum AuditResultStatus {
  success,
  failure,
  partial,
  pending,
  denied;

  String get slug => name;

  static AuditResultStatus fromSlug(String? raw) {
    return switch ((raw ?? 'success').toLowerCase()) {
      'failure' || 'failed' => AuditResultStatus.failure,
      'partial' => AuditResultStatus.partial,
      'pending' => AuditResultStatus.pending,
      'denied' => AuditResultStatus.denied,
      _ => AuditResultStatus.success,
    };
  }
}

enum SystemHealthStatus {
  healthy,
  degraded,
  down,
  unknown;

  String get slug => name;

  Color get color => switch (this) {
        SystemHealthStatus.healthy => const Color(0xFF16A34A),
        SystemHealthStatus.degraded => const Color(0xFFD97706),
        SystemHealthStatus.down => const Color(0xFFDC2626),
        SystemHealthStatus.unknown => const Color(0xFF94A3B8),
      };

  static SystemHealthStatus fromSlug(String? raw) {
    return switch ((raw ?? 'unknown').toLowerCase()) {
      'healthy' || 'green' || 'ok' => SystemHealthStatus.healthy,
      'degraded' || 'yellow' || 'warning' => SystemHealthStatus.degraded,
      'down' || 'red' || 'critical' => SystemHealthStatus.down,
      _ => SystemHealthStatus.unknown,
    };
  }
}

enum AlertLifecycle {
  open,
  acknowledged,
  assigned,
  escalated,
  resolved;

  String get slug => name;

  static AlertLifecycle fromSlug(String? raw) {
    return switch ((raw ?? 'open').toLowerCase()) {
      'acknowledged' => AlertLifecycle.acknowledged,
      'assigned' => AlertLifecycle.assigned,
      'escalated' => AlertLifecycle.escalated,
      'resolved' => AlertLifecycle.resolved,
      _ => AlertLifecycle.open,
    };
  }
}

enum ActivityDatePreset {
  today,
  yesterday,
  last7Days,
  last30Days,
  custom;

  String get label => switch (this) {
        ActivityDatePreset.today => 'Today',
        ActivityDatePreset.yesterday => 'Yesterday',
        ActivityDatePreset.last7Days => 'Last 7 days',
        ActivityDatePreset.last30Days => 'Last 30 days',
        ActivityDatePreset.custom => 'Custom range',
      };

  (DateTime, DateTime) range({DateTime? now}) {
    final n = now ?? DateTime.now().toUtc();
    final startOfToday = DateTime.utc(n.year, n.month, n.day);
    return switch (this) {
      ActivityDatePreset.today => (startOfToday, n),
      ActivityDatePreset.yesterday => (
          startOfToday.subtract(const Duration(days: 1)),
          startOfToday,
        ),
      ActivityDatePreset.last7Days => (
          startOfToday.subtract(const Duration(days: 7)),
          n,
        ),
      ActivityDatePreset.last30Days => (
          startOfToday.subtract(const Duration(days: 30)),
          n,
        ),
      ActivityDatePreset.custom => (startOfToday, n),
    };
  }
}

/// Immutable publish request — modules never write audit tables directly.
class AuditPublishRequest {
  const AuditPublishRequest({
    required this.action,
    required this.module,
    required this.category,
    this.userId,
    this.actorRole,
    this.sessionId,
    this.entityType,
    this.entityId,
    this.oldValues,
    this.newValues,
    this.status = AuditResultStatus.success,
    this.severity = AuditSeverity.info,
    this.reason,
    this.correlationId,
    this.requestId,
    this.device,
    this.browser,
    this.operatingSystem,
    this.ipAddress,
    this.userAgent,
    this.metadata = const {},
    this.immutableVault = false,
    this.visibleToUser = true,
  });

  final String action;
  final String module;
  final AuditEventCategory category;
  final String? userId;
  final String? actorRole;
  final String? sessionId;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final AuditResultStatus status;
  final AuditSeverity severity;
  final String? reason;
  final String? correlationId;
  final String? requestId;
  final String? device;
  final String? browser;
  final String? operatingSystem;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> metadata;
  final bool immutableVault;
  final bool visibleToUser;
}

class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.action,
    required this.module,
    required this.category,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.userId,
    this.actorRole,
    this.sessionId,
    this.entityType,
    this.entityId,
    this.oldValues,
    this.newValues,
    this.reason,
    this.correlationId,
    this.requestId,
    this.device,
    this.browser,
    this.operatingSystem,
    this.ipAddress,
    this.userAgent,
    this.metadata = const {},
  });

  final String id;
  final String action;
  final String module;
  final AuditEventCategory category;
  final AuditSeverity severity;
  final AuditResultStatus status;
  final DateTime createdAt;
  final String? userId;
  final String? actorRole;
  final String? sessionId;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? reason;
  final String? correlationId;
  final String? requestId;
  final String? device;
  final String? browser;
  final String? operatingSystem;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> metadata;

  String get timelineTitle {
    final pretty = action.replaceAll('_', ' ');
    if (pretty.isEmpty) return module;
    return pretty[0].toUpperCase() + pretty.substring(1);
  }

  factory AuditRecord.fromRow(Map<String, dynamic> row) {
    final meta = Map<String, dynamic>.from(
      (row['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    return AuditRecord(
      id: row['id'] as String,
      action: row['action'] as String? ?? 'unknown',
      module: row['module'] as String? ?? 'system',
      category: AuditEventCategory.fromSlug(
        row['event_category'] as String? ?? meta['category'] as String?,
      ),
      severity: AuditSeverity.fromSlug(row['severity'] as String?),
      status: AuditResultStatus.fromSlug(
        row['result_status'] as String? ?? row['status'] as String?,
      ),
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      userId: row['user_id'] as String?,
      actorRole: row['actor_role'] as String?,
      sessionId: row['session_id'] as String?,
      entityType: row['entity_type'] as String?,
      entityId: row['entity_id']?.toString(),
      oldValues: (row['old_values'] as Map?)?.cast<String, dynamic>(),
      newValues: (row['new_values'] as Map?)?.cast<String, dynamic>(),
      reason: row['reason'] as String?,
      correlationId: row['correlation_id'] as String?,
      requestId: row['request_id'] as String?,
      device: row['device'] as String?,
      browser: row['browser'] as String?,
      operatingSystem: row['operating_system'] as String?,
      ipAddress: row['ip_address']?.toString(),
      userAgent: row['user_agent'] as String?,
      metadata: meta,
    );
  }
}

class ChangeHistoryEntry {
  const ChangeHistoryEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    required this.createdAt,
    this.oldValue,
    this.newValue,
    this.changedBy,
    this.reviewer,
    this.auditLogId,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String fieldName;
  final DateTime createdAt;
  final String? oldValue;
  final String? newValue;
  final String? changedBy;
  final String? reviewer;
  final String? auditLogId;

  factory ChangeHistoryEntry.fromRow(Map<String, dynamic> row) {
    return ChangeHistoryEntry(
      id: row['id'] as String,
      entityType: row['entity_type'] as String? ?? '',
      entityId: row['entity_id']?.toString() ?? '',
      fieldName: row['field_name'] as String? ?? '',
      oldValue: row['old_value']?.toString(),
      newValue: row['new_value']?.toString(),
      changedBy: row['changed_by'] as String?,
      reviewer: row['reviewer'] as String?,
      auditLogId: row['audit_log_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }
}

class SystemAlert {
  const SystemAlert({
    required this.id,
    required this.title,
    required this.severity,
    required this.lifecycle,
    required this.createdAt,
    this.description,
    this.sourceModule,
    this.auditLogId,
    this.assignedTo,
  });

  final String id;
  final String title;
  final AuditSeverity severity;
  final AlertLifecycle lifecycle;
  final DateTime createdAt;
  final String? description;
  final String? sourceModule;
  final String? auditLogId;
  final String? assignedTo;

  factory SystemAlert.fromRow(Map<String, dynamic> row) {
    return SystemAlert(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Alert',
      description: row['description'] as String?,
      severity: AuditSeverity.fromSlug(row['severity'] as String?),
      lifecycle: AlertLifecycle.fromSlug(row['lifecycle'] as String?),
      sourceModule: row['source_module'] as String?,
      auditLogId: row['audit_log_id'] as String?,
      assignedTo: row['assigned_to'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }
}

class SystemHealthCheck {
  const SystemHealthCheck({
    required this.serviceKey,
    required this.label,
    required this.status,
    this.latencyMs,
    this.message,
    this.checkedAt,
  });

  final String serviceKey;
  final String label;
  final SystemHealthStatus status;
  final int? latencyMs;
  final String? message;
  final DateTime? checkedAt;

  factory SystemHealthCheck.fromRow(Map<String, dynamic> row) {
    return SystemHealthCheck(
      serviceKey: row['service_key'] as String? ?? 'unknown',
      label: row['label'] as String? ?? row['service_key'] as String? ?? 'Service',
      status: SystemHealthStatus.fromSlug(row['status'] as String?),
      latencyMs: row['latency_ms'] as int?,
      message: row['message'] as String?,
      checkedAt: row['checked_at'] != null
          ? DateTime.parse(row['checked_at'] as String).toUtc()
          : null,
    );
  }
}

class ObservabilityFilter {
  const ObservabilityFilter({
    this.preset = ActivityDatePreset.last7Days,
    this.category,
    this.severity,
    this.query,
    this.userId,
    this.module,
    this.customFrom,
    this.customTo,
  });

  final ActivityDatePreset preset;
  final AuditEventCategory? category;
  final AuditSeverity? severity;
  final String? query;
  final String? userId;
  final String? module;
  final DateTime? customFrom;
  final DateTime? customTo;

  (DateTime, DateTime) get dateRange {
    if (preset == ActivityDatePreset.custom &&
        customFrom != null &&
        customTo != null) {
      return (customFrom!.toUtc(), customTo!.toUtc());
    }
    return preset.range();
  }

  ObservabilityFilter copyWith({
    ActivityDatePreset? preset,
    AuditEventCategory? category,
    AuditSeverity? severity,
    String? query,
    String? userId,
    String? module,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearCategory = false,
    bool clearSeverity = false,
    bool clearQuery = false,
  }) {
    return ObservabilityFilter(
      preset: preset ?? this.preset,
      category: clearCategory ? null : (category ?? this.category),
      severity: clearSeverity ? null : (severity ?? this.severity),
      query: clearQuery ? null : (query ?? this.query),
      userId: userId ?? this.userId,
      module: module ?? this.module,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
    );
  }
}

class CommandCenterSnapshot {
  const CommandCenterSnapshot({
    required this.todayActivity,
    required this.activeUsersEstimate,
    required this.failedLogins,
    required this.openAlerts,
    required this.criticalAlerts,
    required this.recentActivity,
    required this.alerts,
    required this.health,
    required this.securityScore,
  });

  final int todayActivity;
  final int activeUsersEstimate;
  final int failedLogins;
  final int openAlerts;
  final int criticalAlerts;
  final List<AuditRecord> recentActivity;
  final List<SystemAlert> alerts;
  final List<SystemHealthCheck> health;
  final int securityScore;
}

class ActivityTimelineSnapshot {
  const ActivityTimelineSnapshot({
    required this.items,
    required this.filter,
  });

  final List<AuditRecord> items;
  final ObservabilityFilter filter;
}

/// Pure helpers for severity routing and anomaly flags (future-ready).
abstract final class ObservabilityEngine {
  static AuditSeverity inferSeverity({
    required AuditEventCategory category,
    required AuditResultStatus status,
    AuditSeverity? explicit,
  }) {
    if (explicit != null) return explicit;
    if (status == AuditResultStatus.denied ||
        status == AuditResultStatus.failure) {
      if (category == AuditEventCategory.security ||
          category == AuditEventCategory.authentication) {
        return AuditSeverity.warning;
      }
      return AuditSeverity.error;
    }
    if (category == AuditEventCategory.security) return AuditSeverity.notice;
    if (category == AuditEventCategory.payment ||
        category == AuditEventCategory.kyc) {
      return AuditSeverity.success;
    }
    return AuditSeverity.info;
  }

  /// Retention years by severity / category (policy defaults).
  static int retentionYears({
    required AuditEventCategory category,
    required AuditSeverity severity,
  }) {
    if (category == AuditEventCategory.security ||
        severity.rank >= AuditSeverity.critical.rank) {
      return 5;
    }
    if (category == AuditEventCategory.payment ||
        category == AuditEventCategory.kyc ||
        category == AuditEventCategory.admin) {
      return 7;
    }
    if (category == AuditEventCategory.system ||
        category == AuditEventCategory.api) {
      return 1;
    }
    return 2;
  }

  /// Anomaly Detection™ — flag unusual patterns without auto-blocking.
  static List<String> detectAnomalies({
    required int failedLoginsLastHour,
    required int propertyEditsLastHour,
    required int exportCountToday,
    required int paymentFailuresLastHour,
  }) {
    final flags = <String>[];
    if (failedLoginsLastHour >= 8) {
      flags.add('spike_failed_logins');
    }
    if (propertyEditsLastHour >= 40) {
      flags.add('unusual_property_edits');
    }
    if (exportCountToday >= 5) {
      flags.add('unexpected_data_exports');
    }
    if (paymentFailuresLastHour >= 6) {
      flags.add('multiple_failed_payments');
    }
    return flags;
  }

  static int computeSecurityScore({
    required int openCritical,
    required int failedLoginsToday,
    required int openAlerts,
  }) {
    var score = 100;
    score -= openCritical * 15;
    score -= (failedLoginsToday ~/ 3) * 5;
    score -= openAlerts * 2;
    return score.clamp(0, 100);
  }

  static List<AuditRecord> applyFilter(
    List<AuditRecord> source,
    ObservabilityFilter filter,
  ) {
    final (from, to) = filter.dateRange;
    final q = filter.query?.trim().toLowerCase();
    return source.where((r) {
      if (r.createdAt.isBefore(from) || r.createdAt.isAfter(to)) return false;
      if (filter.category != null && r.category != filter.category) return false;
      if (filter.severity != null && r.severity != filter.severity) return false;
      if (filter.userId != null && r.userId != filter.userId) return false;
      if (filter.module != null &&
          r.module.toLowerCase() != filter.module!.toLowerCase()) {
        return false;
      }
      if (q != null && q.isNotEmpty) {
        final hay =
            '${r.action} ${r.module} ${r.entityType} ${r.reason} ${r.correlationId} ${r.metadata}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }
}

/// Fan-out targets for the Enterprise Event Bus™.
enum EventBusSubscriber {
  auditService,
  notificationCenter,
  analyticsEngine,
  aiEngine,
  workflowAutomation,
}

class EventBusEnvelope {
  const EventBusEnvelope({
    required this.eventName,
    required this.request,
    required this.publishedAt,
  });

  final String eventName;
  final AuditPublishRequest request;
  final DateTime publishedAt;
}

typedef EventBusHandler = void Function(EventBusEnvelope envelope);

/// Enterprise Event Bus™ — modules publish; subscribers react.
class EnterpriseEventBus {
  final Map<EventBusSubscriber, List<EventBusHandler>> _handlers = {};

  void subscribe(EventBusSubscriber target, EventBusHandler handler) {
    _handlers.putIfAbsent(target, () => []).add(handler);
  }

  void publish(String eventName, AuditPublishRequest request) {
    final envelope = EventBusEnvelope(
      eventName: eventName,
      request: request,
      publishedAt: DateTime.now().toUtc(),
    );
    for (final list in _handlers.values) {
      for (final handler in list) {
        handler(envelope);
      }
    }
  }

  List<EventBusSubscriber> get activeSubscribers => _handlers.keys.toList();
}
