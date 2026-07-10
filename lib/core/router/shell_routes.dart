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
import 'package:hdhomesproject/features/investor/presentation/pages/investor_portal_stub_page.dart';

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
          'website': 'Website Pages',
          'banners': 'Banners',
          'seo': 'SEO Settings',
          'properties': 'Properties',
          'estates': 'Estates',
          'clients': 'Clients',
          'investors': 'Investors',
          'crm': 'CRM',
          'construction': 'Construction',
          'finance': 'Finance',
          'marketing': 'Marketing',
          'blog': 'Blog',
          'media': 'Media Library',
          'reports': 'Reports',
          'analytics': 'Analytics',
          'notifications': 'Notifications',
          'users': 'Users',
          'roles': 'Roles & Permissions',
          'settings': 'Settings',
          'activity-logs': 'Activity Logs',
          'profile': 'Profile',
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
    return GoRoute(
      path: path,
      name: path.replaceAll('/', '-').replaceFirst('-', ''),
      builder: (_, __) => pageBuilder?.call(entry.value) ?? _placeholder(entry.value),
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
