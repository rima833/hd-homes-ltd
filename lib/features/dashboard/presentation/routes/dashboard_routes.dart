import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/widgets/placeholder_page.dart';

List<RouteBase> get dashboardRoutes => [
      GoRoute(
        path: RoutePaths.dashboard,
        name: 'dashboard',
        builder: (context, state) => const PlaceholderPage(
          title: 'Admin Dashboard',
          subtitle: 'Enterprise admin — coming after auth & roles (Part 3).',
        ),
        routes: [
          GoRoute(
            path: 'properties',
            name: 'dashboard-properties',
            builder: (context, state) => const PlaceholderPage(
              title: 'Manage Properties',
            ),
          ),
          GoRoute(
            path: 'users',
            name: 'dashboard-users',
            builder: (context, state) => const PlaceholderPage(
              title: 'Manage Users',
            ),
          ),
          GoRoute(
            path: 'settings',
            name: 'dashboard-settings',
            builder: (context, state) => const PlaceholderPage(
              title: 'Dashboard Settings',
            ),
          ),
        ],
      ),
    ];
