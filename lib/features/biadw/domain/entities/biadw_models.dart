// Live operational analytics returned by get_admin_operational_analytics.

class BiadwKpi {
  const BiadwKpi({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String key;
  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'percent' || unit == 'pct') {
      return '${_compact(value)}%';
    }
    if (unit == 'currency') {
      if (value.abs() >= 1000000000) {
        return '₦${_compact(value / 1000000000)}B';
      }
      if (value.abs() >= 1000000) {
        return '₦${_compact(value / 1000000)}M';
      }
      if (value.abs() >= 1000) {
        return '₦${_compact(value / 1000)}K';
      }
      return '₦${_compact(value)}';
    }
    return _compact(value);
  }

  static String _compact(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  factory BiadwKpi.fromJson(Map<String, dynamic> json) => BiadwKpi(
    key: json['key']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    value: _number(json['value']),
    unit: json['unit']?.toString() ?? 'count',
  );
}

class BiadwDailyPoint {
  const BiadwDailyPoint({
    required this.date,
    required this.leads,
    required this.revenue,
    required this.applications,
  });

  final DateTime date;
  final int leads;
  final double revenue;
  final int applications;

  factory BiadwDailyPoint.fromJson(Map<String, dynamic> json) =>
      BiadwDailyPoint(
        date:
            DateTime.tryParse(json['date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        leads: _number(json['leads']).toInt(),
        revenue: _number(json['revenue']),
        applications: _number(json['applications']).toInt(),
      );
}

class BiadwLeadStatus {
  const BiadwLeadStatus({required this.label, required this.value});

  final String label;
  final int value;

  factory BiadwLeadStatus.fromJson(Map<String, dynamic> json) =>
      BiadwLeadStatus(
        label: json['label']?.toString() ?? 'Unknown',
        value: _number(json['value']).toInt(),
      );
}

class BiadwModuleMetric {
  const BiadwModuleMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.detail,
  });

  final String key;
  final String label;
  final double value;
  final String detail;

  factory BiadwModuleMetric.fromJson(Map<String, dynamic> json) =>
      BiadwModuleMetric(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        value: _number(json['value']),
        detail: json['detail']?.toString() ?? '',
      );
}

class BiadwActivity {
  const BiadwActivity({
    required this.type,
    required this.label,
    required this.occurredAt,
  });

  final String type;
  final String label;
  final DateTime occurredAt;

  factory BiadwActivity.fromJson(Map<String, dynamic> json) => BiadwActivity(
    type: json['type']?.toString() ?? 'activity',
    label: json['label']?.toString() ?? 'Operational activity',
    occurredAt:
        DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class BiadwCommandCenterSnapshot {
  const BiadwCommandCenterSnapshot({
    required this.loadedAt,
    required this.periodDays,
    required this.kpis,
    required this.dailySeries,
    required this.leadStatuses,
    required this.modules,
    required this.recentActivity,
  });

  final DateTime loadedAt;
  final int periodDays;
  final List<BiadwKpi> kpis;
  final List<BiadwDailyPoint> dailySeries;
  final List<BiadwLeadStatus> leadStatuses;
  final List<BiadwModuleMetric> modules;
  final List<BiadwActivity> recentActivity;

  bool get isEmpty =>
      kpis.isEmpty &&
      dailySeries.isEmpty &&
      leadStatuses.isEmpty &&
      modules.isEmpty &&
      recentActivity.isEmpty;

  factory BiadwCommandCenterSnapshot.fromJson(Map<String, dynamic> json) {
    return BiadwCommandCenterSnapshot(
      loadedAt:
          DateTime.tryParse(json['loaded_at']?.toString() ?? '') ??
          DateTime.now(),
      periodDays: _number(json['period_days']).toInt(),
      kpis: _maps(json['kpis']).map(BiadwKpi.fromJson).toList(),
      dailySeries: _maps(
        json['daily_series'],
      ).map(BiadwDailyPoint.fromJson).toList(),
      leadStatuses: _maps(
        json['lead_statuses'],
      ).map(BiadwLeadStatus.fromJson).toList(),
      modules: _maps(json['modules']).map(BiadwModuleMetric.fromJson).toList(),
      recentActivity: _maps(
        json['recent_activity'],
      ).map(BiadwActivity.fromJson).toList(),
    );
  }
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
