import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/widgets/placeholder_page.dart';

List<RouteBase> get clientRoutes => [
      GoRoute(
        path: RoutePaths.client,
        name: 'client',
        builder: (context, state) => const PlaceholderPage(
          title: 'Client Portal',
          subtitle: 'Buyer dashboard — coming after auth (Part 3).',
        ),
      ),
    ];
