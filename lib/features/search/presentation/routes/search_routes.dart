import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/search/presentation/pages/search_intelligence_page.dart';

List<RouteBase> get searchRoutes => [
      GoRoute(
        path: RoutePaths.search,
        name: 'search',
        builder: (context, state) => const SearchIntelligencePage(),
      ),
    ];
