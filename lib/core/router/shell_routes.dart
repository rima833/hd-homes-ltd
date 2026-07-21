import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/layout/portal_shell.dart';
import 'package:hdhomesproject/core/layout/public/public_shell.dart';
import 'package:hdhomesproject/core/navigation/breadcrumbs.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/growth/widgets/growth_route_tracker.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_resolver.dart';
import 'package:hdhomesproject/core/widgets/placeholder_page.dart';
import 'package:hdhomesproject/features/blog/presentation/routes/blog_routes.dart';
import 'package:hdhomesproject/features/contact/presentation/routes/contact_routes.dart';
import 'package:hdhomesproject/features/search/presentation/routes/search_routes.dart';
import 'package:hdhomesproject/features/media/presentation/routes/media_routes.dart';
import 'package:hdhomesproject/features/trust/presentation/routes/trust_routes.dart';
import 'package:hdhomesproject/features/about/presentation/pages/about_page.dart';
import 'package:hdhomesproject/features/home/presentation/pages/home_page.dart';
import 'package:hdhomesproject/features/estates/presentation/routes/estate_routes.dart';
import 'package:hdhomesproject/features/properties/presentation/routes/property_routes.dart';
import 'package:hdhomesproject/features/services/presentation/routes/service_routes.dart';
import 'package:hdhomesproject/features/investment/presentation/routes/investment_routes.dart';
import 'package:hdhomesproject/features/careers/presentation/routes/careers_routes.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/admin_communication_page.dart';
import 'package:hdhomesproject/features/eaih/presentation/pages/ai_command_center_page.dart';
import 'package:hdhomesproject/features/eip/presentation/pages/integration_command_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/kyc_compliance_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/notification_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/observability_command_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/organization_hub_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/personalization_analytics_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/profile_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/rbac_console_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/search_insights_page.dart';
import 'package:hdhomesproject/features/dashboard/presentation/pages/executive_dashboard_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_portal_stub_page.dart';
import 'package:hdhomesproject/features/crm/presentation/pages/crm_command_center_page.dart';
import 'package:hdhomesproject/features/imp/presentation/pages/investor_command_center_page.dart';
import 'package:hdhomesproject/features/pms/presentation/pages/property_command_center_page.dart';
import 'package:hdhomesproject/features/sbms/presentation/pages/sales_command_center_page.dart';
import 'package:hdhomesproject/features/cpms/presentation/pages/construction_command_center_page.dart';
import 'package:hdhomesproject/features/fapms/presentation/pages/finance_command_center_page.dart';
import 'package:hdhomesproject/features/dxp/presentation/pages/marketing_command_center_page.dart';
import 'package:hdhomesproject/features/hcm/presentation/pages/hr_command_center_page.dart';
import 'package:hdhomesproject/features/eoc/presentation/pages/eoc_mission_control_page.dart';
import 'package:hdhomesproject/features/cshop/presentation/pages/support_command_center_page.dart';
import 'package:hdhomesproject/features/ddcms/presentation/pages/document_command_center_page.dart';
import 'package:hdhomesproject/features/eafms/presentation/pages/asset_command_center_page.dart';
import 'package:hdhomesproject/features/grca/presentation/pages/grc_command_center_page.dart';
import 'package:hdhomesproject/features/biadw/presentation/pages/bi_command_center_page.dart';
import 'package:hdhomesproject/features/pviscm/presentation/pages/procurement_command_center_page.dart';

Widget _placeholder(String title, {String? subtitle}) =>
    PlaceholderPage(title: title, subtitle: subtitle);

/// Public website routes wrapped in [PublicShell].
ShellRoute get publicShellRoute => ShellRoute(
      builder: (context, state, child) {
        final location = state.matchedLocation;
        final isFullBleed = location == RoutePaths.home ||
            location == RoutePaths.about ||
            location == RoutePaths.properties ||
            location.startsWith('${RoutePaths.properties}/') ||
            location == RoutePaths.estates ||
            location.startsWith('${RoutePaths.estates}/') ||
            location == RoutePaths.services ||
            location.startsWith('${RoutePaths.services}/') ||
            location == RoutePaths.blog ||
            location.startsWith('${RoutePaths.blog}/') ||
            location == RoutePaths.contact ||
            location == RoutePaths.bookInspection ||
            location == RoutePaths.search ||
            location == RoutePaths.gallery ||
            location.startsWith('${RoutePaths.gallery}/') ||
            location == RoutePaths.trust ||
            location == RoutePaths.investment ||
            location == RoutePaths.careers;
        final page = isFullBleed
            ? child
            : Padding(
                padding: const EdgeInsets.only(top: 88),
                child: child,
              );
        final seo = SeoResolver.resolve(state);
        final bound = seo != null ? SeoBinder(metadata: seo, child: page) : page;
        final content = GrowthRouteTracker(location: location, child: bound);
        return PublicShell(child: content);
      },
      routes: [
        GoRoute(
          path: RoutePaths.home,
          name: 'home',
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: RoutePaths.about,
          name: 'about',
          builder: (_, __) => const AboutPage(),
        ),
        ...investmentRoutes,
        ...contactRoutes,
        ...searchRoutes,
        ...careersRoutes,
        ...mediaRoutes,
        ...trustRoutes,
        ...propertyRoutes,
        ...estateRoutes,
        ...serviceRoutes,
        ...blogRoutes,
      ],
    );

/// Client portal routes wrapped in [PortalShell].
ShellRoute get clientShellRoute => ShellRoute(
      builder: (context, state, child) => PortalShell(
        title: 'Client Portal',
        navItems: NavigationConfig.clientNav,
        bottomNavItems: NavigationConfig.clientBottomNav,
        breadcrumbs: _breadcrumbs(state, 'Client'),
        child: child,
      ),
      routes: _portalRoutes(
        prefix: RoutePaths.client,
        routes: {
          '': 'Dashboard',
          'properties': 'My Properties',
          'saved': 'Saved Properties',
          'payments': 'Payments',
          'documents': 'Documents',
          'construction': 'Construction Updates',
          'inspections': 'Inspection Bookings',
          'messages': 'Messages',
          'notifications': 'Notifications',
          'support': 'Support',
          'referrals': 'Referrals',
          'settings': 'Settings',
        },
      ),
    );

/// Investor portal routes wrapped in [PortalShell].
ShellRoute get investorShellRoute => ShellRoute(
      builder: (context, state, child) => PortalShell(
        title: 'Investor Portal',
        navItems: NavigationConfig.investorNav,
        breadcrumbs: _breadcrumbs(state, 'Investor'),
        child: child,
      ),
      routes: _portalRoutes(
        prefix: RoutePaths.investor,
        routes: {
          '': 'Investor Dashboard',
          'portfolio': 'Portfolio',
          'analytics': 'Investment Analytics',
          'construction': 'Construction Progress',
          'reports': 'Reports',
          'payments': 'Payments',
          'documents': 'Documents',
          'referrals': 'Referrals',
          'messages': 'Messages',
          'notifications': 'Notifications',
          'support': 'Support',
          'settings': 'Settings',
        },
        pageBuilder: (title) => InvestorPortalStubPage(title: title),
      ),
    );

/// Admin dashboard routes wrapped in [PortalShell].
ShellRoute get adminShellRoute => ShellRoute(
      builder: (context, state, child) => PortalShell(
        title: 'Admin Dashboard',
        navItems: NavigationConfig.adminNav,
        breadcrumbs: _breadcrumbs(state, 'Admin'),
        child: child,
      ),
      routes: _portalRoutes(
        prefix: RoutePaths.dashboard,
        routes: {
          '': 'Dashboard',
          'eoc': 'Ops Center',
          'website': 'Website Pages',
          'banners': 'Banners',
          'seo': 'SEO Settings',
          'properties': 'Properties',
          'estates': 'Estates',
          'clients': 'Clients',
          'investors': 'Investors',
          'crm': 'CRM',
          'support': 'Customer Support',
          'documents': 'Documents',
          'procurement': 'Procurement',
          'assets': 'Assets',
          'grc': 'GRC',
          'sales': 'Sales',
          'construction': 'Construction',
          'finance': 'Finance',
          'marketing': 'Marketing',
          'hr': 'Human Resources',
          'blog': 'Blog',
          'media': 'Media Library',
          'reports': 'Reports',
          'analytics': 'Analytics',
          'ai': 'AI Hub',
          'integrations': 'Integrations',
          'notifications': 'Notifications',
          'users': 'Users',
          'organization': 'Organization',
          'roles': 'Roles & Permissions',
          'settings': 'Settings',
          'activity-logs': 'Activity Logs',
          'personalization': 'Personalization Analytics',
          'search': 'Search Insights',
          'profile': 'Profile',
          'compliance': 'Compliance',
          'communications': 'Communications',
        },
      ),
    );

List<RouteBase> _portalRoutes({
  required String prefix,
  required Map<String, String> routes,
  Widget Function(String title)? pageBuilder,
}) {
  return routes.entries.map((entry) {
    final path = entry.key.isEmpty ? prefix : '$prefix/${entry.key}';
    final isProfileSurface =
        entry.key == 'settings' || entry.key == 'profile';
    final isCompliance = entry.key == 'compliance';
    final isNotifications = entry.key == 'notifications';
    final isCommunications = entry.key == 'communications';
    final isActivityLogs = entry.key == 'activity-logs';
    final isOrganization =
        entry.key == 'organization' || entry.key == 'users';
    final isRoles = entry.key == 'roles';
    final isPersonalization = entry.key == 'personalization';
    final isSearchInsights = entry.key == 'search';
    final isAiGovernance = entry.key == 'ai';
    final isIntegrationsAdmin =
        entry.key == 'integrations' && prefix == RoutePaths.dashboard;
    final isExecutiveHome = entry.key.isEmpty && prefix == RoutePaths.dashboard;
    final isPmsProperties =
        entry.key == 'properties' && prefix == RoutePaths.dashboard;
    final isCrm =
        entry.key == 'crm' && prefix == RoutePaths.dashboard;
    final isSupportAdmin =
        entry.key == 'support' && prefix == RoutePaths.dashboard;
    final isDocumentsAdmin =
        entry.key == 'documents' && prefix == RoutePaths.dashboard;
    final isProcurementAdmin =
        entry.key == 'procurement' && prefix == RoutePaths.dashboard;
    final isAssetsAdmin =
        entry.key == 'assets' && prefix == RoutePaths.dashboard;
    final isGrcAdmin =
        entry.key == 'grc' && prefix == RoutePaths.dashboard;
    final isAnalyticsAdmin =
        entry.key == 'analytics' && prefix == RoutePaths.dashboard;
    final isSales =
        entry.key == 'sales' && prefix == RoutePaths.dashboard;
    final isInvestors =
        entry.key == 'investors' && prefix == RoutePaths.dashboard;
    final isConstructionAdmin =
        entry.key == 'construction' && prefix == RoutePaths.dashboard;
    final isFinanceAdmin =
        entry.key == 'finance' && prefix == RoutePaths.dashboard;
    final isMarketingAdmin =
        entry.key == 'marketing' && prefix == RoutePaths.dashboard;
    final isHrAdmin = entry.key == 'hr' && prefix == RoutePaths.dashboard;
    final isEocAdmin = entry.key == 'eoc' && prefix == RoutePaths.dashboard;
    return GoRoute(
      path: path,
      name: path.replaceAll('/', '-').replaceFirst('-', ''),
      builder: (_, _) {
        if (isExecutiveHome) return const ExecutiveDashboardPage();
        if (isEocAdmin) return const EocMissionControlPage();
        if (isPmsProperties) return const PropertyCommandCenterPage();
        if (isCrm) return const CrmCommandCenterPage();
        if (isSupportAdmin) return const SupportCommandCenterPage();
        if (isDocumentsAdmin) return const DocumentCommandCenterPage();
        if (isProcurementAdmin) return const ProcurementCommandCenterPage();
        if (isAssetsAdmin) return const AssetCommandCenterPage();
        if (isGrcAdmin) return const GrcCommandCenterPage();
        if (isAnalyticsAdmin) return const BiCommandCenterPage();
        if (isSales) return const SalesCommandCenterPage();
        if (isInvestors) return const InvestorCommandCenterPage();
        if (isConstructionAdmin) return const ConstructionCommandCenterPage();
        if (isFinanceAdmin) return const FinanceCommandCenterPage();
        if (isMarketingAdmin) return const MarketingCommandCenterPage();
        if (isHrAdmin) return const HrCommandCenterPage();
        if (isCompliance) return const KycCompliancePage();
        if (isCommunications) return const AdminCommunicationPage();
        if (isActivityLogs) return const ObservabilityCommandCenterPage();
        if (isOrganization) return const OrganizationHubPage();
        if (isRoles) return const RbacConsolePage();
        if (isPersonalization) return const PersonalizationAnalyticsPage();
        if (isSearchInsights) return const SearchInsightsPage();
        if (isAiGovernance) return const AiCommandCenterPage();
        if (isIntegrationsAdmin) return const IntegrationCommandCenterPage();
        if (isNotifications) return const NotificationCenterPage();
        if (isProfileSurface) return const ProfileCenterPage();
        return pageBuilder?.call(entry.value) ?? _placeholder(entry.value);
      },
    );
  }).toList();
}

List<BreadcrumbItem> _breadcrumbs(GoRouterState state, String root) {
  final segments = state.uri.pathSegments;
  if (segments.isEmpty) return [BreadcrumbItem(label: root)];

  final items = <BreadcrumbItem>[
    BreadcrumbItem(label: root, path: '/${segments.first}'),
  ];

  var path = '/${segments.first}';
  for (var i = 1; i < segments.length; i++) {
    path += '/${segments[i]}';
    final label = segments[i].replaceAll('-', ' ');
    items.add(BreadcrumbItem(
      label: label[0].toUpperCase() + label.substring(1),
      path: i < segments.length - 1 ? path : null,
    ));
  }
  return items;
}
