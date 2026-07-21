import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';

void main() {
  group('ObservabilityEngine.inferSeverity', () {
    test('failed auth becomes warning', () {
      final s = ObservabilityEngine.inferSeverity(
        category: AuditEventCategory.authentication,
        status: AuditResultStatus.failure,
      );
      expect(s, AuditSeverity.warning);
    });

    test('explicit severity wins', () {
      final s = ObservabilityEngine.inferSeverity(
        category: AuditEventCategory.system,
        status: AuditResultStatus.success,
        explicit: AuditSeverity.emergency,
      );
      expect(s, AuditSeverity.emergency);
    });
  });

  group('ObservabilityEngine.retentionYears', () {
    test('security retains 5 years', () {
      expect(
        ObservabilityEngine.retentionYears(
          category: AuditEventCategory.security,
          severity: AuditSeverity.info,
        ),
        5,
      );
    });

    test('payment / kyc retain 7 years', () {
      expect(
        ObservabilityEngine.retentionYears(
          category: AuditEventCategory.payment,
          severity: AuditSeverity.success,
        ),
        7,
      );
    });

    test('default activity retains 2 years', () {
      expect(
        ObservabilityEngine.retentionYears(
          category: AuditEventCategory.user,
          severity: AuditSeverity.info,
        ),
        2,
      );
    });
  });

  group('ObservabilityEngine.detectAnomalies', () {
    test('flags login spikes without blocking', () {
      final flags = ObservabilityEngine.detectAnomalies(
        failedLoginsLastHour: 10,
        propertyEditsLastHour: 1,
        exportCountToday: 0,
        paymentFailuresLastHour: 0,
      );
      expect(flags, contains('spike_failed_logins'));
    });
  });

  group('ObservabilityEngine.applyFilter', () {
    final now = DateTime.utc(2026, 7, 13, 12);
    final records = [
      AuditRecord(
        id: '1',
        action: 'login',
        module: 'auth',
        category: AuditEventCategory.authentication,
        severity: AuditSeverity.info,
        status: AuditResultStatus.success,
        createdAt: now,
        correlationId: 'corr-abc',
      ),
      AuditRecord(
        id: '2',
        action: 'property_updated',
        module: 'properties',
        category: AuditEventCategory.property,
        severity: AuditSeverity.notice,
        status: AuditResultStatus.success,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ];

    test('filters by preset and query', () {
      final filtered = ObservabilityEngine.applyFilter(
        records,
        ObservabilityFilter(
          preset: ActivityDatePreset.custom,
          customFrom: now.subtract(const Duration(days: 1)),
          customTo: now.add(const Duration(hours: 1)),
          query: 'corr-abc',
        ),
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, '1');
    });
  });

  group('ObservabilityEngine.computeSecurityScore', () {
    test('penalizes critical alerts', () {
      final score = ObservabilityEngine.computeSecurityScore(
        openCritical: 2,
        failedLoginsToday: 0,
        openAlerts: 0,
      );
      expect(score, 70);
    });
  });

  group('EnterpriseEventBus', () {
    test('fans out to subscribers', () {
      final bus = EnterpriseEventBus();
      var hit = 0;
      bus.subscribe(EventBusSubscriber.auditService, (_) => hit++);
      bus.subscribe(EventBusSubscriber.analyticsEngine, (_) => hit++);
      bus.publish(
        'User Registered',
        const AuditPublishRequest(
          action: 'user_registered',
          module: 'auth',
          category: AuditEventCategory.user,
        ),
      );
      expect(hit, 2);
      expect(bus.activeSubscribers.length, 2);
    });
  });

  group('AuditSeverity', () {
    test('alert thresholds', () {
      expect(AuditSeverity.info.shouldAlert, isFalse);
      expect(AuditSeverity.warning.shouldAlert, isTrue);
      expect(AuditSeverity.critical.shouldAlert, isTrue);
    });
  });
}
