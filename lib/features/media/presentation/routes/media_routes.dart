import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/media/presentation/pages/media_center_hub_page.dart';
import 'package:hdhomesproject/features/media/presentation/pages/media_experience_page.dart';

List<RouteBase> get mediaRoutes => [
      GoRoute(
        path: RoutePaths.gallery,
        name: 'gallery',
        builder: (context, state) => const MediaCenterHubPage(),
        routes: [
          GoRoute(
            path: ':slug',
            name: 'gallery-experience',
            builder: (context, state) => MediaExperiencePage(
              slug: state.pathParameters['slug']!,
            ),
          ),
        ],
      ),
    ];
