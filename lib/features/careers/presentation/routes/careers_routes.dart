import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/careers/presentation/pages/careers_page.dart';

List<RouteBase> get careersRoutes => [
      GoRoute(
        path: RoutePaths.careers,
        name: 'careers',
        builder: (context, state) => const CareersPage(),
      ),
    ];
