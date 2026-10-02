import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/auth/policies/role_nav_policy.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/layout/portal_shell.dart';
import 'package:hdhomesproject/core/layout/public/public_shell.dart';
import 'package:hdhomesproject/core/navigation/app_sidebar.dart';
import 'package:hdhomesproject/core/navigation/breadcrumbs.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/growth/widgets/growth_route_tracker.dart';
import 'package:hdhomesproject/core/website/seo/cms_seo_binder.dart';
import 'package:hdhomesproject/core/widgets/placeholder_page.dart';
import 'package:hdhomesproject/features/admin/presentation/providers/admin_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_portal_chrome.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/admin_reports_hub_page.dart';
import 'package:hdhomesproject/features/settings/presentation/pages/platform_control_center_page.dart';
import 'package:hdhomesproject/features/settings/presentation/widgets/platform_control_nav.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_website_hub_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_banners_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_blog_admin_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_faq_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_featured_estates_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_featured_properties_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_footer_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_hero_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_homepage_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_media_library_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_menus_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_pages_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_seo_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_team_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_testimonials_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_awards_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_partners_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_company_stats_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_client_journey_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_journey_benefits_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_offices_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_digital_profile_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_investment_opportunities_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_market_insights_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_construction_updates_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_careers_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_website_forms_pages.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_services_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_browse_categories_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_payment_calculator_page.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_roi_calculator_page.dart';
import 'package:hdhomesproject/features/blog/presentation/routes/blog_routes.dart';
import 'package:hdhomesproject/features/cms/presentation/pages/cms_public_page.dart';
import 'package:hdhomesproject/features/contact/presentation/routes/contact_routes.dart';
import 'package:hdhomesproject/features/search/presentation/routes/search_routes.dart';
import 'package:hdhomesproject/features/media/presentation/routes/media_routes.dart';
import 'package:hdhomesproject/features/trust/presentation/routes/trust_routes.dart';
import 'package:hdhomesproject/features/about/presentation/pages/about_page.dart';
import 'package:hdhomesproject/features/home/presentation/pages/construction_progress_detail_page.dart';
import 'package:hdhomesproject/features/home/presentation/pages/home_page.dart';
import 'package:hdhomesproject/features/estates/presentation/routes/estate_routes.dart';
import 'package:hdhomesproject/features/properties/presentation/routes/property_routes.dart';
import 'package:hdhomesproject/features/services/presentation/routes/service_routes.dart';
import 'package:hdhomesproject/features/investment/presentation/routes/investment_routes.dart';
import 'package:hdhomesproject/features/careers/presentation/routes/careers_routes.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/admin_communication_page.dart';
import 'package:hdhomesproject/features/eaih/presentation/pages/ai_command_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/kyc_compliance_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/observability_command_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/organization_hub_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/personalization_analytics_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/platform_users_tab.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/profile_center_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/rbac_console_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/search_insights_page.dart';
import 'package:hdhomesproject/features/dashboard/presentation/pages/role_aware_dashboard_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_analytics_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_construction_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_dashboard_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_documents_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_messages_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_more_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_notifications_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_payments_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_portfolio_detail_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_portfolio_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_referrals_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_reports_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_settings_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_support_page.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_tools_page.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_chrome.dart';
import 'package:hdhomesproject/features/inspection/presentation/pages/inspection_command_center_page.dart';
import 'package:hdhomesproject/features/callback/presentation/pages/callback_command_center_page.dart';
import 'package:hdhomesproject/features/consultation/presentation/pages/client_consultations_page.dart';
import 'package:hdhomesproject/features/consultation/presentation/pages/consultation_command_center_page.dart';
import 'package:hdhomesproject/features/crm/presentation/pages/crm_command_center_page.dart';
import 'package:hdhomesproject/features/client_ops/presentation/pages/client_command_center_page.dart';
import 'package:hdhomesproject/features/imp/presentation/pages/investor_command_center_page.dart';
import 'package:hdhomesproject/features/cpms/presentation/pages/construction_command_center_page.dart';
import 'package:hdhomesproject/features/fapms/presentation/pages/finance_command_center_page.dart';
import 'package:hdhomesproject/features/dxp/presentation/pages/marketing_command_center_page.dart';
import 'package:hdhomesproject/features/dxp/presentation/pages/public_landing_page.dart';
import 'package:hdhomesproject/features/cshop/presentation/pages/support_command_center_page.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/features/ddcms/presentation/pages/document_command_center_page.dart';
import 'package:hdhomesproject/features/biadw/presentation/pages/bi_command_center_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_construction_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_dashboard_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_documents_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_inspections_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_applications_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_application_detail_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/staff_client_application_detail_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/staff_client_applications_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_messages_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_more_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_notifications_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_payments_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_properties_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_property_detail_page.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/marketplace_favorites_bridge.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_chrome.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_referrals_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_saved_properties_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_settings_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_support_page.dart';
import 'package:hdhomesproject/features/client/presentation/pages/client_tools_page.dart';

Widget _placeholder(String title, {String? subtitle}) =>
    PlaceholderPage(title: title, subtitle: subtitle);

/// Public website routes wrapped in [PublicShell].
ShellRoute get publicShellRoute => ShellRoute(
  builder: (context, state, child) {
    final location = state.matchedLocation;
    final isFullBleed =
        location == RoutePaths.home ||
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
        location == RoutePaths.bookConsultation ||
        location == RoutePaths.search ||
        location == RoutePaths.gallery ||
        location.startsWith('${RoutePaths.gallery}/') ||
        location == RoutePaths.construction ||
        location.startsWith('${RoutePaths.construction}/') ||
        location == RoutePaths.trust ||
        location == RoutePaths.investment ||
        location.startsWith('${RoutePaths.investment}/') ||
        location == RoutePaths.careers ||
        location.startsWith('/pages/');
    final page = isFullBleed
        ? child
        : Padding(padding: const EdgeInsets.only(top: 88), child: child);
    final bound = CmsSeoBinder(path: state.uri.path, child: page);
    final content = GrowthRouteTracker(location: location, child: bound);
    return PublicShell(child: content);
  },
  routes: [
    GoRoute(
      path: RoutePaths.home,
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: RoutePaths.about,
      name: 'about',
      builder: (context, state) => const AboutPage(),
    ),
    // List route must come before /construction/:slug.
    ...constructionRoutes,
    GoRoute(
      path: '${RoutePaths.construction}/:slug',
      name: 'construction-progress',
      builder: (context, state) {
        final slug = state.pathParameters['slug'] ?? '';
        return ConstructionProgressDetailPage(slug: slug);
      },
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
    GoRoute(
      path: RoutePaths.cmsPage,
      name: 'cms-page',
      builder: (context, state) =>
          CmsPublicPage(slug: state.pathParameters['slug']!),
    ),
    GoRoute(
      path: RoutePaths.landingPage,
      name: 'landing-page',
      builder: (context, state) =>
          PublicLandingPage(slug: state.pathParameters['slug']!),
    ),
  ],
);

/// Client portal routes wrapped in [PortalShell].
ShellRoute get clientShellRoute => ShellRoute(
  builder: (context, state, child) => Consumer(
    builder: (context, ref, _) {
      ref.watch(clientPortalRealtimeHubProvider);
      ref.watch(marketplaceFavoritesBootstrapProvider);
      final routedChild = KeyedSubtree(
        key: ValueKey('client-shell:${state.uri}'),
        child: child,
      );
      final isDashboard = state.uri.path == RoutePaths.client;
      final isMessages = state.uri.path == RoutePaths.clientMessages;
      final isSupport = state.uri.path == RoutePaths.clientSupport;
      return PortalShell(
        title: '',
        navItems: ref.watch(clientPortalNavItemsProvider),
        bottomNavItems: ref.watch(clientPortalBottomNavItemsProvider),
        breadcrumbs: isDashboard ? const [] : _clientBreadcrumbs(state),
        contentPadding:
            (isDashboard || isMessages || isSupport) ? EdgeInsets.zero : null,
        actions: const [ClientPortalGlobalHeaderActions()],
        showBrandLogo: false,
        showSearch: false,
        forceDrawerChrome: false,
        permanentSidebarMinWidth: 768,
        sidebarCollapsed: ref.watch(clientSidebarCollapsedProvider),
        onSidebarCollapsedChanged: (collapsed) {
          ref.read(clientSidebarCollapsedProvider.notifier).state = collapsed;
        },
        onNavSelect: (item) {
          if (item.path != NavItem.actionLogout) return false;
          Future.microtask(() async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) context.go(RoutePaths.login);
          });
          return true;
        },
        sidebarHeader: const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
          child: ClientPortalSidebarBrand(),
        ),
        // Need Help card removed — Support / Messages already cover tickets & chat.
        sidebarFooter: null,
        collapsedSidebarFooter: null,
        child: routedChild,
      );
    },
  ),
  routes: [
    ..._portalRoutes(
      prefix: RoutePaths.client,
      routes: {
        '': 'Dashboard',
        'properties': 'My Properties',
        'applications': 'Applications',
        'saved': 'Saved Properties',
        'payments': 'Payments',
        'documents': 'Documents',
        'construction': 'Construction Updates',
        'inspections': 'Inspection Bookings',
        'consultations': 'My Consultations',
        'messages': 'Messages',
        'notifications': 'Notifications',
        'support': 'Support',
        'referrals': 'Referrals',
        'settings': 'Settings',
        'tools': 'Buying Tools',
        'more': 'More',
      },
    ),
    GoRoute(
      path: '${RoutePaths.clientApplications}/:applicationId',
      name: 'client-application-detail',
      builder: (context, state) => ClientApplicationDetailPage(
        applicationId: state.pathParameters['applicationId']!,
      ),
    ),
    GoRoute(
      path: '${RoutePaths.clientProperties}/:propertyId',
      name: 'client-property-detail',
      builder: (context, state) => ClientPropertyDetailLoader(
        propertyId: state.pathParameters['propertyId']!,
      ),
    ),
  ],
);

/// Investor portal routes wrapped in [PortalShell].
ShellRoute get investorShellRoute => ShellRoute(
  builder: (context, state, child) => Consumer(
    builder: (context, ref, _) {
      ref.watch(investorPortalRealtimeHubProvider);
      final routedChild = KeyedSubtree(
        key: ValueKey('investor-shell:${state.uri}'),
        child: child,
      );
      final isDashboard = state.uri.path == RoutePaths.investor;
      final isMessages = state.uri.path == RoutePaths.investorMessages;
      final isSupport = state.uri.path == RoutePaths.investorSupport;
      return PortalShell(
        title: '',
        navItems: ref.watch(investorPortalNavItemsProvider),
        bottomNavItems: ref.watch(investorPortalBottomNavItemsProvider),
        breadcrumbs: isDashboard ? const [] : _investorBreadcrumbs(state),
        contentPadding:
            (isDashboard || isMessages || isSupport) ? EdgeInsets.zero : null,
        actions: const [InvestorPortalGlobalHeaderActions()],
        showBrandLogo: false,
        showSearch: false,
        forceDrawerChrome: false,
        permanentSidebarMinWidth: 768,
        sidebarCollapsed: ref.watch(investorSidebarCollapsedProvider),
        onSidebarCollapsedChanged: (collapsed) {
          ref.read(investorSidebarCollapsedProvider.notifier).state = collapsed;
        },
        onNavSelect: (item) {
          if (item.path != NavItem.actionLogout) return false;
          Future.microtask(() async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) context.go(RoutePaths.login);
          });
          return true;
        },
        sidebarHeader: const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
          child: InvestorPortalSidebarBrand(),
        ),
        // Need Help card removed — Support / Messages already cover tickets & chat.
        sidebarFooter: null,
        collapsedSidebarFooter: null,
        child: routedChild,
      );
    },
  ),
  routes: [
    ..._portalRoutes(
      prefix: RoutePaths.investor,
      routes: {
        '': 'Investor Dashboard',
        'portfolio': 'Portfolio',
        'analytics': 'Investment Analytics',
        'tools': 'Investment Tools',
        'construction': 'Construction Progress',
        'reports': 'Reports',
        'payments': 'Payments',
        'documents': 'Documents',
        'referrals': 'Referrals',
        'messages': 'Messages',
        'notifications': 'Notifications',
        'support': 'Support',
        'settings': 'Settings',
        'more': 'More',
      },
    ),
    GoRoute(
      path: '${RoutePaths.investorPortfolio}/:holdingId',
      name: 'investor-holding-detail',
      builder: (context, state) => InvestorPortfolioDetailLoader(
        holdingId: state.pathParameters['holdingId']!,
      ),
    ),
  ],
);

/// Admin dashboard routes wrapped in [PortalShell].
ShellRoute get adminShellRoute => ShellRoute(
  builder: (context, state, child) => Consumer(
    builder: (context, ref, _) {
      ref.watch(adminPortalRealtimeHubProvider);
      final session = ref.watch(identitySessionProvider);
      final navItems = ref.watch(adminPortalNavItemsProvider);
      final routedChild = KeyedSubtree(
        key: ValueKey('admin-shell:${state.uri}'),
        child: child,
      );
      final portalTitle = RoleNavPolicy.portalTitleFor(session);
      final breadcrumbRoot = RoleNavPolicy.portalBreadcrumbRoot(session);
      final isMarketing = state.uri.path == RoutePaths.dashboardMarketing;
      final isLiveChat = state.uri.path == RoutePaths.dashboardLiveChat;
      final isSupportDesk = state.uri.path == RoutePaths.dashboardSupport ||
          isLiveChat;
      return PortalShell(
        title: (isMarketing || isSupportDesk) ? '' : portalTitle,
        navItems: navItems,
        breadcrumbs: (isMarketing || isSupportDesk)
            ? const []
            : _breadcrumbs(state, breadcrumbRoot),
        actions: const [AdminPortalHeaderActions()],
        showSearch: false,
        // Support owns insets — shell padding was crushing the chat viewport.
        contentPadding: (isMarketing || isSupportDesk)
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(8, 4, 8, 8),
        reserveHeaderTitleSpace: !isMarketing && !isSupportDesk,
        showHeader: !isSupportDesk,
        backgroundColor: isLiveChat
            ? const Color(0xFFF3F5F8)
            : const Color(0xFF0E1014),
        headerBackgroundColor: const Color(0xFF16131A),
        headerBorderColor: const Color(0x44E8B84A),
        sidebarTheme: SidebarVisualTheme.adminCinematic,
        permanentSidebarMinWidth: 768,
        sidebarCollapsed: ref.watch(adminSidebarCollapsedProvider),
        onSidebarCollapsedChanged: (collapsed) {
          ref.read(adminSidebarCollapsedProvider.notifier).state = collapsed;
        },
        sidebarHeader: const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
          child: AdminPortalSidebarBrand(),
        ),
        sidebarFooter: null,
        collapsedSidebarFooter: null,
        child: routedChild,
      );
    },
  ),
  routes: [
    ..._portalRoutes(
    prefix: RoutePaths.dashboard,
    routes: {
      '': 'Dashboard',
      // Website CMS (all public-site controls live under /dashboard/website)
      'website': 'Website',
      'website/homepage': 'Homepage Sections',
      'website/hero': 'Hero Manager',
      'website/pages': 'Pages & Hubs',
      'website/featured-estates': 'Estates',
      'website/featured-properties': 'Listings',
      'website/testimonials': 'Testimonials',
      'website/awards': 'Awards',
      'website/partners': 'Partners',
      'website/statistics': 'Statistics',
      'website/client-journey': 'Client Journey',
      'website/journey-benefits': 'Journey Benefits',
      'website/offices': 'Offices',
      'website/investments': 'Investments',
      'website/market-insights': 'Market Insights',
      'website/construction': 'Construction',
      'website/digital-profile': 'Digital Profile',
      'website/careers': 'Careers',
      'website/support': 'Support inbox',
      'website/partnerships': 'Partnerships',
      'website/services': 'Services',
      'website/browse-categories': 'Browse Categories',
      'website/payment-calculator': 'Payment Calculator',
      'website/roi-calculator': 'ROI Calculator',
      'website/team': 'Team',
      'website/faq': 'FAQ',
      'website/blog': 'Blog',
      'website/banners': 'Banners',
      'website/menus': 'Menus',
      'website/footer': 'Footer',
      'website/media': 'Media Library',
      'website/seo': 'SEO Settings',
      'website/company': 'Company Profile',
      // Legacy aliases
      'banners': 'Banners',
      'seo': 'SEO Settings',
      'blog': 'Blog',
      'media': 'Media Library',
      // Properties catalog (create → upload → publish)
      'estates': 'Estates',
      'properties': 'Listings',
      'properties/units': 'Units',
      'properties/types': 'Property Types',
      'properties/categories': 'Categories',
      'properties/amenities': 'Amenities',
      'properties/pricing': 'Pricing',
      'properties/availability': 'Availability',
      'inspections': 'Inspections',
      'consultations': 'Consultations',
      'callbacks': 'Callbacks',
      // Core ops
      'clients': 'Clients',
      'investors': 'Investors',
      'crm': 'Sales',
      'client-applications': 'Client Applications',
      'construction': 'Construction',
      'finance': 'Finance',
      'documents': 'Documents',
      'marketing': 'Marketing',
      'reports': 'Reports',
      'analytics': 'Analytics',
      'support': 'Support',
      'live-chat': 'Live Chat',
      // People & system
      'users': 'Staff',
      'roles': 'Roles & Permissions',
      'platform-users': 'Platform Users',
      'settings': 'Settings',
      'activity-logs': 'Activity Logs',
      if (kAiFeaturesEnabled) 'ai': 'AI Hub',
      // Soft-kept utility routes (not in sidebar)
      'organization': 'Organization',
      'profile': 'Profile',
      'compliance': 'Compliance',
      'communications': 'Communications',
      'personalization': 'Personalization Analytics',
      'search': 'Search Insights',
    },
  ),
    GoRoute(
      path: '${RoutePaths.dashboardClientApplications}/:applicationId',
      name: 'dashboard-client-application-detail',
      builder: (context, state) => StaffClientApplicationDetailPage(
        applicationId: state.pathParameters['applicationId']!,
      ),
    ),
  ],
);

List<RouteBase> _portalRoutes({
  required String prefix,
  required Map<String, String> routes,
  Widget Function(String title)? pageBuilder,
}) {
  return routes.entries.map((entry) {
    final path = entry.key.isEmpty ? prefix : '$prefix/${entry.key}';
    return GoRoute(
      path: path,
      name: path.replaceAll('/', '-').replaceFirst('-', ''),
      builder: (context, state) {
        if (prefix == RoutePaths.client) {
          return switch (entry.key) {
            '' => const ClientDashboardPage(),
            'properties' => const ClientPropertiesPage(),
            'applications' => const ClientApplicationsPage(),
            'saved' => const ClientSavedPropertiesPage(),
            'payments' => const ClientPaymentsPage(),
            'documents' => const ClientDocumentsPage(),
            'construction' => const ClientConstructionPage(),
            'inspections' => const ClientInspectionsPage(),
            'consultations' => const ClientConsultationsPage(),
            'messages' => ClientMessagesPage(
              openLiveChat: state.uri.queryParameters['live'] == '1',
            ),
            'notifications' => const ClientNotificationsPage(),
            'support' => const ClientSupportPage(),
            'referrals' => const ClientReferralsPage(),
            'settings' => const ClientSettingsPage(),
            'tools' => const ClientToolsPage(),
            'more' => const ClientMorePage(),
            _ => _placeholder(entry.value),
          };
        }
        if (prefix == RoutePaths.investor) {
          return switch (entry.key) {
            '' => const InvestorDashboardPage(),
            'portfolio' => const InvestorPortfolioPage(),
            'analytics' => const InvestorAnalyticsPage(),
            'tools' => InvestorToolsPage(
              initialAmount: double.tryParse(
                state.uri.queryParameters['amount'] ?? '',
              ),
            ),
            'construction' => const InvestorConstructionPage(),
            'reports' => const InvestorReportsPage(),
            'payments' => const InvestorPaymentsPage(),
            'documents' => const InvestorDocumentsPage(),
            'referrals' => const InvestorReferralsPage(),
            'messages' => InvestorMessagesPage(
              openLiveChat: state.uri.queryParameters['live'] == '1',
            ),
            'notifications' => const InvestorNotificationsPage(),
            'support' => const InvestorSupportPage(),
            'settings' => const InvestorSettingsPage(),
            'more' => const InvestorMorePage(),
            _ => _placeholder(entry.value),
          };
        }
        if (prefix == RoutePaths.dashboard) {
          return switch (entry.key) {
            '' => const RoleAwareDashboardPage(),
            // Website CMS
            'website' => const CmsWebsiteHubPage(),
            'website/homepage' => const CmsHomepagePage(),
            'website/hero' => const CmsHeroPage(),
            'website/pages' => const CmsPagesPage(),
            'website/featured-estates' ||
            'estates' => const CmsFeaturedEstatesPage(),
            // Listings is the only public create/publish path for properties.
            // Legacy nav labels (types, units, …) all open the same Listings CMS.
            'website/featured-properties' ||
            'properties' ||
            'properties/units' ||
            'properties/types' ||
            'properties/categories' ||
            'properties/amenities' ||
            'properties/pricing' ||
            'properties/availability' => const CmsFeaturedPropertiesPage(),
            'inspections' => const InspectionCommandCenterPage(),
            'consultations' => const ConsultationCommandCenterPage(),
            'callbacks' => const CallbackCommandCenterPage(),
            'website/testimonials' => const CmsTestimonialsPage(),
            'website/awards' => const CmsAwardsPage(),
            'website/partners' => const CmsPartnersPage(),
            'website/statistics' => const CmsCompanyStatsPage(),
            'website/client-journey' => const CmsClientJourneyPage(),
            'website/journey-benefits' => const CmsJourneyBenefitsPage(),
            'website/offices' => const CmsOfficesPage(),
            'website/investments' => const CmsInvestmentOpportunitiesPage(),
            'website/market-insights' => const CmsMarketInsightsPage(),
            'website/construction' => const CmsConstructionUpdatesPage(),
            'website/digital-profile' => const CmsDigitalProfilePage(),
            'website/careers' => const CmsCareersPage(),
            'website/support' => const CmsWebsiteSupportPage(),
            'website/partnerships' => const CmsPartnershipsPage(),
            'website/services' => const CmsServicesPage(),
            'website/browse-categories' => const CmsBrowseCategoriesPage(),
            'website/payment-calculator' => const CmsPaymentCalculatorPage(),
            'website/roi-calculator' => const CmsRoiCalculatorPage(),
            'website/team' => const CmsTeamPage(),
            'website/faq' => const CmsFaqPage(),
            'website/blog' || 'blog' => const CmsBlogAdminPage(),
            'website/banners' || 'banners' => const CmsBannersPage(),
            'website/menus' => const CmsMenusPage(),
            'website/footer' => const CmsFooterPage(),
            'website/media' || 'media' => const CmsMediaLibraryPage(),
            'website/seo' || 'seo' => const CmsSeoPage(),
            'website/company' => const PlatformControlCenterPage(
              initialSection: PlatformControlSection.business,
            ),
            // Core business
            'clients' => const ClientCommandCenterPage(),
            'crm' => const CrmCommandCenterPage(),
            'client-applications' => const StaffClientApplicationsPage(),
            'investors' => const InvestorCommandCenterPage(),
            'construction' => const ConstructionCommandCenterPage(),
            'finance' => const FinanceCommandCenterPage(),
            'documents' => const DocumentCommandCenterPage(),
            'marketing' => const MarketingCommandCenterPage(),
            'reports' => const AdminReportsHubPage(),
            'analytics' => const BiCommandCenterPage(),
            'support' => SupportCommandCenterPage(
              initialTab: _supportTabFromQuery(state.uri.queryParameters),
              initialPortalConversationKey:
                  _portalConversationKeyFromQuery(state.uri.queryParameters),
              initialChannelFilter:
                  state.uri.queryParameters['channel']?.trim(),
            ),
            'live-chat' => const SupportCommandCenterPage(
              desk: SupportDesk.liveChat,
              initialTab: CshopCommandTab.liveChat,
            ),
            // People & system
            'users' || 'organization' => const OrganizationHubPage(),
            'roles' => const RbacConsolePage(),
            'platform-users' => const PlatformUsersTab(),
            'settings' => PlatformControlCenterPage(
              initialSection: _settingsSectionFromQuery(state.uri.queryParameters),
            ),
            'activity-logs' => const ObservabilityCommandCenterPage(),
            'profile' => const ProfileCenterPage(),
            'compliance' => const KycCompliancePage(),
            'communications' => const AdminCommunicationPage(),
            'personalization' => const PersonalizationAnalyticsPage(),
            'search' => const SearchInsightsPage(),
            'ai' => const AiCommandCenterPage(),
            _ => pageBuilder?.call(entry.value) ?? _placeholder(entry.value),
          };
        }
        return pageBuilder?.call(entry.value) ?? _placeholder(entry.value);
      },
    );
  }).toList();
}

CshopCommandTab? _supportTabFromQuery(Map<String, String> query) {
  final raw = query['tab']?.trim();
  if (raw == null || raw.isEmpty) return null;
  for (final tab in CshopCommandTab.values) {
    if (tab.name == raw) return tab;
  }
  return null;
}

PlatformControlSection? _settingsSectionFromQuery(Map<String, String> query) {
  final raw = (query['section'] ?? query['tab'] ?? '').trim().toLowerCase();
  if (raw.isEmpty) return null;
  for (final section in PlatformControlSection.values) {
    if (section.name.toLowerCase() == raw) return section;
  }
  // Friendly aliases
  return switch (raw) {
    'company' || 'business' => PlatformControlSection.business,
    'brand' || 'social' || 'brandsocial' => PlatformControlSection.brandSocial,
    'website' || 'public' => PlatformControlSection.publicWebsite,
    'portal' || 'client' => PlatformControlSection.clientPortal,
    'investor' => PlatformControlSection.investorPortal,
    'mail' => PlatformControlSection.email,
    _ => null,
  };
}

/// Deep-link: `/dashboard/support?tab=clientMessages&conversation=<id>&kind=investor`
String? _portalConversationKeyFromQuery(Map<String, String> query) {
  final conversation = query['conversation']?.trim();
  if (conversation == null || conversation.isEmpty) return null;
  if (conversation.contains(':')) return conversation;
  final kind = (query['kind']?.trim().toLowerCase() == 'investor')
      ? 'investor'
      : 'client';
  return '$kind:$conversation';
}

List<BreadcrumbItem> _investorBreadcrumbs(GoRouterState state) {
  const labels = <String, String>{
    'portfolio': 'Portfolio',
    'analytics': 'Analytics',
    'tools': 'Investment Tools',
    'construction': 'Construction',
    'reports': 'Reports',
    'payments': 'Payments',
    'documents': 'Documents',
    'referrals': 'Referrals',
    'messages': 'Messages',
    'notifications': 'Notifications',
    'support': 'Support',
    'settings': 'Settings',
    'more': 'More',
  };

  final segments = state.uri.pathSegments;
  final items = <BreadcrumbItem>[
    const BreadcrumbItem(label: 'Home', path: RoutePaths.investor),
  ];
  if (segments.length <= 1) return items;

  var path = '/${segments.first}';
  for (var i = 1; i < segments.length; i++) {
    path += '/${segments[i]}';
    final seg = segments[i];
    final looksLikeId = seg.contains('-') && seg.length > 20;
    final label = looksLikeId
        ? 'Details'
        : (labels[seg] ??
              seg.replaceAll('-', ' ')[0].toUpperCase() +
                  seg.replaceAll('-', ' ').substring(1));
    items.add(
      BreadcrumbItem(label: label, path: i < segments.length - 1 ? path : null),
    );
  }
  return items;
}

List<BreadcrumbItem> _clientBreadcrumbs(GoRouterState state) {
  const labels = <String, String>{
    'properties': 'Properties',
    'applications': 'Applications',
    'saved': 'Saved',
    'payments': 'Payments',
    'documents': 'Documents',
    'construction': 'Construction',
    'inspections': 'Inspections',
    'consultations': 'Consultations',
    'messages': 'Messages',
    'notifications': 'Notifications',
    'support': 'Support',
    'referrals': 'Referrals',
    'settings': 'Settings',
    'tools': 'Buying Tools',
    'more': 'More',
  };

  final segments = state.uri.pathSegments;
  final items = <BreadcrumbItem>[
    const BreadcrumbItem(label: 'Home', path: RoutePaths.client),
  ];
  if (segments.length <= 1) return items;

  var path = '/${segments.first}';
  for (var i = 1; i < segments.length; i++) {
    path += '/${segments[i]}';
    final seg = segments[i];
    final looksLikeId = seg.contains('-') && seg.length > 20;
    final label = looksLikeId
        ? 'Details'
        : (labels[seg] ??
              (seg.isEmpty
                  ? seg
                  : '${seg[0].toUpperCase()}${seg.substring(1).replaceAll('-', ' ')}'));
    items.add(
      BreadcrumbItem(label: label, path: i < segments.length - 1 ? path : null),
    );
  }
  return items;
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
    final previous = i > 0 ? segments[i - 1] : '';
    final looksLikeId = segments[i].length > 20 && segments[i].contains('-');
    final label = previous == 'client-applications' && looksLikeId
        ? 'Application'
        : segments[i].replaceAll('-', ' ');
    items.add(
      BreadcrumbItem(
        label: label[0].toUpperCase() + label.substring(1),
        path: i < segments.length - 1 ? path : null,
      ),
    );
  }
  return items;
}
