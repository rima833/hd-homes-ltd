import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/services/presentation/pages/services_page.dart';

List<RouteBase> get serviceRoutes => [
      GoRoute(
        path: RoutePaths.services,
        name: 'services',
        builder: (context, state) => const ServicesPage(),
      ),
      GoRoute(
        path: RoutePaths.serviceDetails,
        redirect: (context, state) => RoutePaths.services,
      ),
    ];
