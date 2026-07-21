import 'package:hdhomesproject/core/constants/permissions.dart';

/// Volume 4 Part 1 — Executive Mission Control domain models.

enum BusinessHealthStatus {
  excellent,
  good,
  needsAttention,
  critical;

  String get label => switch (this) {
        BusinessHealthStatus.excellent => 'Excellent',
        BusinessHealthStatus.good => 'Good',
        BusinessHealthStatus.needsAttention => 'Needs Attention',
        BusinessHealthStatus.critical => 'Critical',
      };

  static BusinessHealthStatus fromSlug(String? raw) {
    return switch ((raw ?? 'good').toLowerCase()) {
      'excellent' => BusinessHealthStatus.excellent,
      'needs_attention' || 'needsattention' =>
        BusinessHealthStatus.needsAttention,
      'critical' => BusinessHealthStatus.critical,
      _ => BusinessHealthStatus.good,
    };
  }
}

enum InsightType {
  observation,
  recommendation,
  forecast,
  alert;

  static InsightType fromSlug(String? raw) {
    return InsightType.values.firstWhere(
      (e) => e.name == (raw ?? 'observation').toLowerCase(),
      orElse: () => InsightType.observation,
    );
  }
}

enum NotificationSeverity {
  info,
  warning,
  critical,
  success;

  static NotificationSeverity fromSlug(String? raw) {
    return NotificationSeverity.values.firstWhere(
      (e) => e.name == (raw ?? 'info').toLowerCase(),
      orElse: () => NotificationSeverity.info,
    );
  }
}

class KpiCard {
  const KpiCard({
    required this.metricKey,
    required this.label,
    required this.value,
    this.previousValue,
    this.unit = 'count',
    this.changePct,
    this.series = const [],
    this.capturedAt,
  });

  final String metricKey;
  final String label;
  final double value;
  final double? previousValue;
  final String unit;
  final double? changePct;
  final List<double> series;
  final DateTime? capturedAt;

  bool get isUp => (changePct ?? 0) >= 0;

  String get displayValue {
    if (unit == 'ngn') {
      final n = value;
      if (n >= 1e9) return '₦${(n / 1e9).toStringAsFixed(1)}B';
      if (n >= 1e6) return '₦${(n / 1e6).toStringAsFixed(1)}M';
      if (n >= 1e3) return '₦${(n / 1e3).toStringAsFixed(0)}K';
      return '₦${n.toStringAsFixed(0)}';
    }
    if (value >= 1000) {
      return value >= 10000
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(0);
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  factory KpiCard.fromJson(Map<String, dynamic> json) {
    final seriesRaw = json['series'];
    final series = seriesRaw is List
        ? seriesRaw.map((e) => (e as num).toDouble()).toList()
        : const <double>[];
    return KpiCard(
      metricKey: json['metric_key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      previousValue: (json['previous_value'] as num?)?.toDouble(),
      unit: json['unit'] as String? ?? 'count',
      changePct: (json['change_pct'] as num?)?.toDouble(),
      series: series,
      capturedAt: DateTime.tryParse(json['captured_at'] as String? ?? ''),
    );
  }
}

class HealthFactor {
  const HealthFactor({
    required this.key,
    required this.label,
    required this.score,
    this.weight = 0.1,
  });

  final String key;
  final String label;
  final int score;
  final double weight;

  factory HealthFactor.fromJson(Map<String, dynamic> json) {
    return HealthFactor(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.1,
    );
  }
}

class BusinessHealthScore {
  const BusinessHealthScore({
    required this.overallScore,
    required this.status,
    this.factors = const [],
    this.history = const [],
    this.capturedAt,
  });

  final int overallScore;
  final BusinessHealthStatus status;
  final List<HealthFactor> factors;
  final List<int> history;
  final DateTime? capturedAt;

  factory BusinessHealthScore.fromJson(Map<String, dynamic> json) {
    final factorsRaw = json['factors'];
    final historyRaw = json['history'];
    return BusinessHealthScore(
      overallScore: (json['overall_score'] as num?)?.toInt() ?? 0,
      status: BusinessHealthStatus.fromSlug(json['status'] as String?),
      factors: factorsRaw is List
          ? factorsRaw
              .whereType<Map>()
              .map((e) => HealthFactor.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      history: historyRaw is List
          ? historyRaw.map((e) => (e as num).toInt()).toList()
          : const [],
      capturedAt: DateTime.tryParse(json['captured_at'] as String? ?? ''),
    );
  }
}

class AiExecutiveInsight {
  const AiExecutiveInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.isAiGenerated = true,
    this.confidence,
    this.severity = NotificationSeverity.info,
    this.module,
    this.createdAt,
  });

  final String id;
  final InsightType type;
  final String title;
  final String body;
  final bool isAiGenerated;
  final double? confidence;
  final NotificationSeverity severity;
  final String? module;
  final DateTime? createdAt;

  factory AiExecutiveInsight.fromJson(Map<String, dynamic> json) {
    return AiExecutiveInsight(
      id: json['id']?.toString() ?? '',
      type: InsightType.fromSlug(json['insight_type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isAiGenerated: json['is_ai_generated'] as bool? ?? true,
      confidence: (json['confidence'] as num?)?.toDouble(),
      severity: NotificationSeverity.fromSlug(json['severity'] as String?),
      module: json['module'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ActivityFeedItem {
  const ActivityFeedItem({
    required this.id,
    required this.action,
    required this.module,
    required this.summary,
    this.actorName,
    this.createdAt,
  });

  final String id;
  final String action;
  final String module;
  final String summary;
  final String? actorName;
  final DateTime? createdAt;

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    return ActivityFeedItem(
      id: json['id']?.toString() ?? '',
      action: json['action'] as String? ?? '',
      module: json['module'] as String? ?? 'system',
      summary: json['summary'] as String? ?? '',
      actorName: json['actor_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ExecutiveNotificationItem {
  const ExecutiveNotificationItem({
    required this.id,
    required this.category,
    required this.title,
    this.body,
    this.severity = NotificationSeverity.info,
    this.module,
    this.isRead = false,
    this.isPinned = false,
    this.actionPath,
    this.createdAt,
  });

  final String id;
  final String category;
  final String title;
  final String? body;
  final NotificationSeverity severity;
  final String? module;
  final bool isRead;
  final bool isPinned;
  final String? actionPath;
  final DateTime? createdAt;

  factory ExecutiveNotificationItem.fromJson(Map<String, dynamic> json) {
    return ExecutiveNotificationItem(
      id: json['id']?.toString() ?? '',
      category: json['category'] as String? ?? 'alert',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      severity: NotificationSeverity.fromSlug(json['severity'] as String?),
      module: json['module'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      actionPath: json['action_path'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class QuickActionItem {
  const QuickActionItem({
    required this.id,
    required this.label,
    required this.routeOrKey,
    this.icon,
    this.requiredPermission,
  });

  final String id;
  final String label;
  final String routeOrKey;
  final String? icon;
  final String? requiredPermission;

  bool allowedFor(Set<String> permissions) {
    final p = requiredPermission;
    if (p == null || p.isEmpty) return true;
    return permissions.contains(p);
  }

  factory QuickActionItem.fromJson(Map<String, dynamic> json) {
    return QuickActionItem(
      id: json['id']?.toString() ?? '',
      label: json['label'] as String? ?? '',
      routeOrKey: json['route_or_key'] as String? ?? '',
      icon: json['icon'] as String?,
      requiredPermission: json['required_permission'] as String?,
    );
  }
}

class ScheduleItem {
  const ScheduleItem({
    required this.title,
    required this.when,
    required this.category,
  });

  final String title;
  final DateTime when;
  final String category;
}

class OperationalRisk {
  const OperationalRisk({
    required this.title,
    required this.severity,
    required this.owner,
    required this.nextAction,
    this.module,
  });

  final String title;
  final NotificationSeverity severity;
  final String owner;
  final String nextAction;
  final String? module;
}

class ModuleAnalyticsBlock {
  const ModuleAnalyticsBlock({
    required this.title,
    required this.metrics,
  });

  final String title;
  final Map<String, String> metrics;
}

class ExecutiveReportType {
  const ExecutiveReportType({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class PredictiveForecast {
  const PredictiveForecast({
    required this.label,
    required this.prediction,
    required this.confidence,
    required this.disclaimer,
  });

  final String label;
  final String prediction;
  final double confidence;
  final String disclaimer;
}

class StrategyInitiative {
  const StrategyInitiative({
    required this.title,
    required this.status,
    required this.progressPct,
  });

  final String title;
  final String status;
  final int progressPct;
}

/// Full Mission Control snapshot.
class ExecutiveDashboardSnapshot {
  const ExecutiveDashboardSnapshot({
    required this.kpis,
    required this.health,
    required this.insights,
    required this.activity,
    required this.notifications,
    required this.quickActions,
    required this.schedule,
    required this.risks,
    required this.sales,
    required this.properties,
    required this.investors,
    required this.crm,
    required this.construction,
    required this.finance,
    required this.marketing,
    required this.support,
    required this.reportTypes,
    required this.forecasts,
    required this.initiatives,
    this.briefingSummary,
    this.fromRemote = false,
    this.loadedAt,
  });

  final List<KpiCard> kpis;
  final BusinessHealthScore health;
  final List<AiExecutiveInsight> insights;
  final List<ActivityFeedItem> activity;
  final List<ExecutiveNotificationItem> notifications;
  final List<QuickActionItem> quickActions;
  final List<ScheduleItem> schedule;
  final List<OperationalRisk> risks;
  final ModuleAnalyticsBlock sales;
  final ModuleAnalyticsBlock properties;
  final ModuleAnalyticsBlock investors;
  final ModuleAnalyticsBlock crm;
  final ModuleAnalyticsBlock construction;
  final ModuleAnalyticsBlock finance;
  final ModuleAnalyticsBlock marketing;
  final ModuleAnalyticsBlock support;
  final List<ExecutiveReportType> reportTypes;
  final List<PredictiveForecast> forecasts;
  final List<StrategyInitiative> initiatives;
  final String? briefingSummary;
  final bool fromRemote;
  final DateTime? loadedAt;

  static const requiredPermission = PermissionSlugs.manageReports;
}

/// Default / offline Mission Control dataset when DB is empty or unavailable.
abstract final class ExecutiveDashboardDemo {
  static ExecutiveDashboardSnapshot snapshot() {
    final now = DateTime.now();
    return ExecutiveDashboardSnapshot(
      kpis: const [
        KpiCard(
          metricKey: 'total_properties',
          label: 'Total Properties',
          value: 248,
          previousValue: 240,
          changePct: 3.3,
          series: [210, 218, 225, 232, 240, 244, 248],
        ),
        KpiCard(
          metricKey: 'available_properties',
          label: 'Available Properties',
          value: 96,
          previousValue: 102,
          changePct: -5.9,
          series: [110, 108, 105, 103, 102, 99, 96],
        ),
        KpiCard(
          metricKey: 'sold_properties',
          label: 'Sold Properties',
          value: 112,
          previousValue: 105,
          changePct: 6.7,
          series: [90, 94, 98, 101, 105, 108, 112],
        ),
        KpiCard(
          metricKey: 'reserved_properties',
          label: 'Reserved Properties',
          value: 40,
          previousValue: 33,
          changePct: 21.2,
          series: [28, 30, 31, 32, 33, 36, 40],
        ),
        KpiCard(
          metricKey: 'total_clients',
          label: 'Total Clients',
          value: 1840,
          previousValue: 1792,
          changePct: 2.7,
          series: [1700, 1725, 1750, 1770, 1792, 1815, 1840],
        ),
        KpiCard(
          metricKey: 'active_investors',
          label: 'Active Investors',
          value: 326,
          previousValue: 310,
          changePct: 5.2,
          series: [280, 290, 295, 300, 310, 318, 326],
        ),
        KpiCard(
          metricKey: 'revenue_today',
          label: "Today's Revenue",
          value: 18500000,
          previousValue: 14200000,
          unit: 'ngn',
          changePct: 30.3,
          series: [8, 9, 11, 12, 14, 16, 18.5],
        ),
        KpiCard(
          metricKey: 'revenue_month',
          label: 'Monthly Revenue',
          value: 412000000,
          previousValue: 368000000,
          unit: 'ngn',
          changePct: 12.0,
          series: [280, 300, 320, 340, 360, 368, 412],
        ),
        KpiCard(
          metricKey: 'pending_payments',
          label: 'Pending Payments',
          value: 54000000,
          previousValue: 61000000,
          unit: 'ngn',
          changePct: -11.5,
          series: [70, 68, 65, 62, 61, 58, 54],
        ),
        KpiCard(
          metricKey: 'completed_sales',
          label: 'Completed Sales',
          value: 28,
          previousValue: 22,
          changePct: 27.3,
          series: [15, 17, 18, 19, 22, 24, 28],
        ),
        KpiCard(
          metricKey: 'construction_projects',
          label: 'Construction Projects',
          value: 14,
          previousValue: 13,
          changePct: 7.7,
          series: [10, 11, 11, 12, 13, 13, 14],
        ),
        KpiCard(
          metricKey: 'support_tickets_open',
          label: 'Active Support Tickets',
          value: 19,
          previousValue: 24,
          changePct: -20.8,
          series: [30, 28, 27, 25, 24, 21, 19],
        ),
      ],
      health: BusinessHealthScore(
        overallScore: 82,
        status: BusinessHealthStatus.good,
        factors: const [
          HealthFactor(key: 'sales', label: 'Sales Performance', score: 88, weight: 0.2),
          HealthFactor(key: 'revenue', label: 'Revenue Growth', score: 85, weight: 0.2),
          HealthFactor(key: 'investors', label: 'Investor Activity', score: 80, weight: 0.15),
          HealthFactor(key: 'satisfaction', label: 'Customer Satisfaction', score: 78),
          HealthFactor(key: 'construction', label: 'Construction Progress', score: 72),
          HealthFactor(key: 'cashflow', label: 'Cash Flow', score: 84),
          HealthFactor(key: 'productivity', label: 'Staff Productivity', score: 81),
          HealthFactor(key: 'security', label: 'Security Status', score: 90, weight: 0.05),
        ],
        history: const [74, 76, 78, 79, 80, 81, 82],
        capturedAt: now,
      ),
      insights: const [
        AiExecutiveInsight(
          id: '1',
          type: InsightType.observation,
          title: 'Sales increased 18% this week',
          body:
              'Completed sales rose from 22 to 28 week-over-week. Lekki inventory led closed deals.',
          confidence: 0.86,
          severity: NotificationSeverity.success,
          module: 'sales',
        ),
        AiExecutiveInsight(
          id: '2',
          type: InsightType.alert,
          title: 'Three high-value investors have not completed KYC',
          body:
              'Investors with projected AUM above ₦50M still have incomplete KYC packages.',
          confidence: 0.91,
          severity: NotificationSeverity.warning,
          module: 'compliance',
        ),
        AiExecutiveInsight(
          id: '3',
          type: InsightType.observation,
          title: 'Lekki properties are outperforming other locations',
          body:
              'Engagement and inspections in Lekki lead Abuja and Port Harcourt this period.',
          confidence: 0.79,
          module: 'property',
        ),
        AiExecutiveInsight(
          id: '4',
          type: InsightType.recommendation,
          title: 'Marketing campaign conversion dropped by 9%',
          body:
              'Reallocate spend toward best-performing channels from search analytics.',
          confidence: 0.74,
          severity: NotificationSeverity.warning,
          module: 'marketing',
        ),
        AiExecutiveInsight(
          id: '5',
          type: InsightType.alert,
          title: 'Construction Project Alpha is behind schedule',
          body: 'Milestone slippage detected — update investors and assign PM focus.',
          confidence: 0.88,
          severity: NotificationSeverity.critical,
          module: 'construction',
        ),
      ],
      activity: [
        ActivityFeedItem(
          id: 'a1',
          action: 'property_published',
          module: 'property',
          summary: 'New listing published: Azure Court 3-Bed',
          actorName: 'System',
          createdAt: now.subtract(const Duration(minutes: 4)),
        ),
        ActivityFeedItem(
          id: 'a2',
          action: 'client_registered',
          module: 'crm',
          summary: 'Client registered: Chuka Okonkwo',
          actorName: 'Amina O.',
          createdAt: now.subtract(const Duration(minutes: 18)),
        ),
        ActivityFeedItem(
          id: 'a3',
          action: 'payment_received',
          module: 'finance',
          summary: 'Payment received: ₦12,500,000 — Unit B4',
          actorName: 'Finance',
          createdAt: now.subtract(const Duration(minutes: 42)),
        ),
        ActivityFeedItem(
          id: 'a4',
          action: 'inspection_scheduled',
          module: 'crm',
          summary: 'Inspection scheduled for Palm Estate Block C',
          actorName: 'Field Ops',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        ActivityFeedItem(
          id: 'a5',
          action: 'campaign_launched',
          module: 'marketing',
          summary: 'Campaign launched: Lekki Early Bird July',
          actorName: 'Marketing',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ],
      notifications: const [
        ExecutiveNotificationItem(
          id: 'n1',
          category: 'approval',
          title: 'Pending property approvals',
          body: '4 listings await publishing approval',
          severity: NotificationSeverity.warning,
          module: 'property',
          actionPath: '/dashboard/properties',
        ),
        ExecutiveNotificationItem(
          id: 'n2',
          category: 'security',
          title: 'Security advisory',
          body: 'Review unusual login geography for one staff account',
          severity: NotificationSeverity.critical,
          module: 'security',
          isPinned: true,
        ),
        ExecutiveNotificationItem(
          id: 'n3',
          category: 'meeting',
          title: 'Investor call in 2 hours',
          body: 'Horizon Capital quarterly briefing',
          severity: NotificationSeverity.info,
          module: 'investor',
        ),
      ],
      quickActions: const [
        QuickActionItem(
          id: 'add_property',
          label: 'Add Property',
          routeOrKey: '/dashboard/properties',
          icon: 'building',
          requiredPermission: PermissionSlugs.createProperty,
        ),
        QuickActionItem(
          id: 'register_investor',
          label: 'Register Investor',
          routeOrKey: '/dashboard/investors',
          icon: 'trending-up',
          requiredPermission: PermissionSlugs.manageUsers,
        ),
        QuickActionItem(
          id: 'create_client',
          label: 'Create Client',
          routeOrKey: '/dashboard/clients',
          icon: 'user-plus',
          requiredPermission: PermissionSlugs.manageCrm,
        ),
        QuickActionItem(
          id: 'schedule_inspection',
          label: 'Schedule Inspection',
          routeOrKey: '/book-inspection',
          icon: 'clipboard-check',
          requiredPermission: PermissionSlugs.manageCrm,
        ),
        QuickActionItem(
          id: 'generate_report',
          label: 'Generate Report',
          routeOrKey: '/dashboard/reports',
          icon: 'file-bar-chart',
          requiredPermission: 'generate_executive_reports',
        ),
        QuickActionItem(
          id: 'launch_campaign',
          label: 'Launch Campaign',
          routeOrKey: '/dashboard/marketing',
          icon: 'megaphone',
          requiredPermission: PermissionSlugs.manageMarketing,
        ),
        QuickActionItem(
          id: 'approve_kyc',
          label: 'Approve KYC',
          routeOrKey: '/dashboard/compliance',
          icon: 'shield-check',
          requiredPermission: PermissionSlugs.manageUsers,
        ),
        QuickActionItem(
          id: 'open_crm',
          label: 'Open CRM',
          routeOrKey: '/dashboard/crm',
          icon: 'contact',
          requiredPermission: PermissionSlugs.manageCrm,
        ),
        QuickActionItem(
          id: 'manage_staff',
          label: 'Manage Staff',
          routeOrKey: '/dashboard/organization',
          icon: 'users',
          requiredPermission: PermissionSlugs.manageUsers,
        ),
        QuickActionItem(
          id: 'create_blog',
          label: 'Create Blog Post',
          routeOrKey: '/dashboard/blog',
          icon: 'newspaper',
          requiredPermission: PermissionSlugs.manageBlog,
        ),
      ],
      schedule: [
        ScheduleItem(
          title: 'Palm Estate inspection',
          when: now.add(const Duration(hours: 3)),
          category: 'Inspection',
        ),
        ScheduleItem(
          title: 'Investor call — Horizon Capital',
          when: now.add(const Duration(hours: 5)),
          category: 'Investor',
        ),
        ScheduleItem(
          title: 'Construction milestone review',
          when: now.add(const Duration(days: 1)),
          category: 'Construction',
        ),
        ScheduleItem(
          title: 'Payment deadline — Unit C2',
          when: now.add(const Duration(days: 2)),
          category: 'Finance',
        ),
      ],
      risks: const [
        OperationalRisk(
          title: 'Project Alpha delay',
          severity: NotificationSeverity.critical,
          owner: 'Construction Lead',
          nextAction: 'Rebaseline milestone plan',
          module: 'construction',
        ),
        OperationalRisk(
          title: 'KYC backlog (high-value)',
          severity: NotificationSeverity.warning,
          owner: 'Compliance',
          nextAction: 'Complete 3 pending reviews',
          module: 'compliance',
        ),
        OperationalRisk(
          title: 'Overdue CRM follow-ups',
          severity: NotificationSeverity.warning,
          owner: 'Sales Manager',
          nextAction: 'Clear 12 due tasks today',
          module: 'crm',
        ),
      ],
      sales: const ModuleAnalyticsBlock(
        title: 'Sales Performance',
        metrics: {
          'Daily sales': '₦18.5M',
          'Weekly sales': '₦96M',
          'Monthly sales': '₦412M',
          'Quarterly sales': '₦1.18B',
          'Yearly sales': '₦3.9B',
          'Avg property value': '₦67M',
          'Conversion rate': '4.8%',
          'Pipeline value': '₦780M',
        },
      ),
      properties: const ModuleAnalyticsBlock(
        title: 'Property Performance',
        metrics: {
          'Most viewed': 'Azure Court 3-Bed',
          'Most saved': 'Palm Duplex Lekki',
          'Most booked': 'Harbour View PH',
          'Awaiting approval': '4',
          'Low engagement': '7',
          'By location lead': 'Lekki 42%',
        },
      ),
      investors: const ModuleAnalyticsBlock(
        title: 'Investor Overview',
        metrics: {
          'Total investors': '326',
          'Active investments': '214',
          'Investment value': '₦6.4B',
          'Average ROI': '14.2%',
          'Upcoming returns': '₦180M',
          'Pending KYC': '11',
          'New this week': '8',
        },
      ),
      crm: const ModuleAnalyticsBlock(
        title: 'Client & CRM',
        metrics: {
          'New leads': '64',
          'Qualified leads': '28',
          'Active clients': '410',
          'Closed deals': '28',
          'Conversion rate': '12%',
          'Follow-ups due': '12',
          'Pending meetings': '6',
        },
      ),
      construction: const ModuleAnalyticsBlock(
        title: 'Construction Overview',
        metrics: {
          'Active projects': '14',
          'Completed': '9',
          'Delayed': '2',
          'Upcoming milestones': '5',
          'Budget utilization': '71%',
          'QA status': 'On track',
        },
      ),
      finance: const ModuleAnalyticsBlock(
        title: 'Financial Summary',
        metrics: {
          'Revenue (MTD)': '₦412M',
          'Expenses (MTD)': '₦128M',
          'Profit (MTD)': '₦284M',
          'Cash flow': 'Positive',
          'Outstanding': '₦54M',
          'Refund requests': '3',
          'Investor payouts due': '₦22M',
        },
      ),
      marketing: const ModuleAnalyticsBlock(
        title: 'Marketing Overview',
        metrics: {
          'Website visitors': '48.2K',
          'Top source': 'Search / Organic',
          'Email open rate': '31%',
          'SMS delivery': '97%',
          'WhatsApp reach': '12.4K',
          'Campaign conversion': '2.1%',
        },
      ),
      support: const ModuleAnalyticsBlock(
        title: 'Support Overview',
        metrics: {
          'Open tickets': '19',
          'Pending': '7',
          'Resolved (7d)': '41',
          'Avg resolution': '6.4h',
          'CSAT': '4.6 / 5',
          'Escalated': '2',
        },
      ),
      reportTypes: const [
        ExecutiveReportType(id: 'sales', label: 'Sales Report'),
        ExecutiveReportType(id: 'revenue', label: 'Revenue Report'),
        ExecutiveReportType(id: 'investor', label: 'Investor Report'),
        ExecutiveReportType(id: 'construction', label: 'Construction Report'),
        ExecutiveReportType(id: 'property', label: 'Property Report'),
        ExecutiveReportType(id: 'crm', label: 'CRM Report'),
        ExecutiveReportType(id: 'marketing', label: 'Marketing Report'),
        ExecutiveReportType(id: 'finance', label: 'Finance Report'),
        ExecutiveReportType(id: 'briefing', label: 'Executive Briefing'),
      ],
      forecasts: const [
        PredictiveForecast(
          label: 'Monthly sales forecast',
          prediction: '₦450M – ₦480M next month',
          confidence: 0.72,
          disclaimer: 'Forecast — not a guarantee. Confidence 72%.',
        ),
        PredictiveForecast(
          label: 'Lekki demand',
          prediction: 'Elevated demand through next 6 weeks',
          confidence: 0.68,
          disclaimer: 'Model estimate based on engagement trends.',
        ),
        PredictiveForecast(
          label: 'Cash flow',
          prediction: 'Positive runway with ₦54M receivables risk',
          confidence: 0.7,
          disclaimer: 'Scenario analysis — validate against finance ledger.',
        ),
      ],
      initiatives: const [
        StrategyInitiative(
          title: 'Expand Lekki Phase 3 inventory',
          status: 'On track',
          progressPct: 64,
        ),
        StrategyInitiative(
          title: 'Investor KYC automation',
          status: 'At risk',
          progressPct: 38,
        ),
        StrategyInitiative(
          title: 'Boardroom Mission Control roll-out',
          status: 'Planning',
          progressPct: 20,
        ),
      ],
      briefingSummary:
          'Business health is Good (82). Sales and revenue are up; prioritize KYC backlog and Construction Project Alpha. Lekki remains the growth pocket.',
      fromRemote: false,
      loadedAt: now,
    );
  }
}
