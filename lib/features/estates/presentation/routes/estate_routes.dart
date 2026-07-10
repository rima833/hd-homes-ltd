import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/estates/presentation/pages/estate_detail_page.dart';
import 'package:hdhomesproject/features/estates/presentation/pages/estates_listing_page.dart';

List<RouteBase> get estateRoutes => [
      GoRoute(
        path: RoutePaths.estates,
        name: 'estates',
        builder: (context, state) => const EstatesListingPage(),
      ),
      GoRoute(
        path: RoutePaths.estateDetails,
        name: 'estate-details',
        builder: (context, state) => EstateDetailPage(
          estateSlug: state.pathParameters['slug']!,
        ),
      ),
    ];
