import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';

List<RouteBase> get trustRoutes => [
      GoRoute(
        path: RoutePaths.trust,
        name: 'trust',
        redirect: (context, state) => RoutePaths.home,
      ),
    ];
