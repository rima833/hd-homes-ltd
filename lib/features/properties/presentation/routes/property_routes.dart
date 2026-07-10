import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/properties/presentation/pages/marketplace_page.dart';
import 'package:hdhomesproject/features/properties/presentation/pages/property_detail_page.dart';

List<RouteBase> get propertyRoutes => [
      GoRoute(
        path: RoutePaths.properties,
        name: 'properties',
        builder: (context, state) => const MarketplacePage(),
      ),
      GoRoute(
        path: RoutePaths.propertyDetails,
        name: 'property-details',
        builder: (context, state) => PropertyDetailPage(
          propertyId: state.pathParameters['id']!,
        ),
      ),
    ];
