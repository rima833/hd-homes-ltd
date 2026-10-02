import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';

/// Module visibility for Client / Investor portals from `portal_features`.
class PortalFeatureFlags {
  const PortalFeatureFlags({
    required this.portal,
    required this.flags,
  });

  final String portal;
  final Map<String, dynamic> flags;

  factory PortalFeatureFlags.fromRpc(Map<String, dynamic> json) {
    final rawFlags = json['flags'];
    return PortalFeatureFlags(
      portal: '${json['portal'] ?? ''}',
      flags: rawFlags is Map
          ? Map<String, dynamic>.from(rawFlags)
          : const <String, dynamic>{},
    );
  }

  bool get enabled => _bool('enabled', true);

  String get welcomeMessage {
    final value = '${flags['welcome_message'] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
    return portal == 'investor'
        ? 'Welcome to your HD Homes investor portal.'
        : 'Welcome to your HD Homes client portal.';
  }

  bool moduleEnabled(String key, {bool fallback = true}) =>
      _bool(key, fallback);

  /// Whether a portal nav path should remain visible.
  bool allowsPath(String path) {
    if (path == NavItem.actionLogout) return true;
    if (path.isEmpty || path.startsWith('section:')) return true;

    final key = _moduleKeyForPath(path);
    if (key == null) return true;
    return moduleEnabled(key);
  }

  List<NavItem> filterNav(List<NavItem> items) {
    if (!enabled) {
      return [
        for (final item in items)
          if (item.path == RoutePaths.client ||
              item.path == RoutePaths.investor ||
              item.path == NavItem.actionLogout ||
              item.isSectionHeader)
            item,
      ];
    }

    final filtered = <NavItem>[
      for (final item in items)
        if (item.isSectionHeader || allowsPath(item.path)) item,
    ];

    // Drop orphan section headers with no following items.
    final cleaned = <NavItem>[];
    for (var i = 0; i < filtered.length; i++) {
      final item = filtered[i];
      if (!item.isSectionHeader) {
        cleaned.add(item);
        continue;
      }
      final hasChild =
          filtered.skip(i + 1).any((next) => !next.isSectionHeader);
      if (hasChild) cleaned.add(item);
    }
    return cleaned;
  }

  String? _moduleKeyForPath(String path) {
    if (portal == 'investor') {
      if (path == RoutePaths.investor) return 'show_dashboard';
      if (path == RoutePaths.investorPortfolio ||
          path.startsWith('${RoutePaths.investorPortfolio}/')) {
        return 'show_portfolio';
      }
      if (path == RoutePaths.investorAnalytics) return 'show_analytics';
      if (path == RoutePaths.investorConstruction) return 'show_construction';
      if (path == RoutePaths.investorReports) return 'show_reports';
      if (path == RoutePaths.investorPayments) return 'show_payments';
      if (path == RoutePaths.investorDocuments) return 'show_documents';
      if (path == RoutePaths.investorMessages) return 'show_messages';
      if (path == RoutePaths.investorSupport) return 'show_support';
      if (path == RoutePaths.investorReferrals) return 'show_referrals';
      if (path == RoutePaths.investorNotifications) {
        return 'show_notifications';
      }
      // Tools / settings / more stay available as account essentials.
      return null;
    }

    // Client portal
    if (path == RoutePaths.client) return 'show_dashboard';
    if (path == RoutePaths.clientProperties ||
        path.startsWith('${RoutePaths.clientProperties}/') ||
        path == RoutePaths.clientSaved) {
      return 'show_properties';
    }
    if (path == RoutePaths.clientPayments) return 'show_payments';
    if (path == RoutePaths.clientDocuments) return 'show_documents';
    if (path == RoutePaths.clientInspections ||
        path == RoutePaths.clientConsultations) {
      return 'show_inspections';
    }
    if (path == RoutePaths.clientConstruction) return 'show_construction';
    if (path == RoutePaths.clientMessages) return 'show_messages';
    if (path == RoutePaths.clientSupport) return 'show_support';
    if (path == RoutePaths.clientReferrals) return 'show_referrals';
    if (path == RoutePaths.clientNotifications) return 'show_notifications';
    return null;
  }

  bool _bool(String key, bool fallback) {
    final value = flags[key];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }
}
