import 'dart:async';

import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';

/// Audit helper for website market insights CMS actions.
Future<void> logMarketInsightAudit(
  AuditService audit, {
  required String action,
  required String insightId,
  String? title,
  Map<String, dynamic>? metadata,
}) async {
  if (!audit.isConfigured) return;
  unawaited(
    audit.publish(
      AuditPublishRequest(
        action: action,
        module: 'website_cms',
        category: AuditEventCategory.admin,
        entityType: 'website_market_insight',
        entityId: insightId,
        severity: AuditSeverity.notice,
        metadata: {
          if (title != null) 'title': title,
          ...?metadata,
        },
      ),
    ),
  );
}
