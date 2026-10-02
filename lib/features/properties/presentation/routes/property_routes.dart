import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/properties/presentation/pages/construction_updates_page.dart';
import 'package:hdhomesproject/features/properties/presentation/pages/marketplace_page.dart';
import 'package:hdhomesproject/features/properties/presentation/pages/payment_calculator_page.dart';
import 'package:hdhomesproject/features/properties/presentation/pages/property_detail_page.dart';

List<RouteBase> get propertyRoutes => [
      GoRoute(
        path: RoutePaths.properties,
        name: 'properties',
        builder: (context, state) => const MarketplacePage(),
      ),
      // Must be registered before `:id` so static segments are not treated as ids.
      GoRoute(
        path: RoutePaths.paymentCalculator,
        name: 'payment-calculator',
        builder: (context, state) => const PaymentCalculatorPage(),
      ),
      GoRoute(
        path: RoutePaths.propertyDetails,
        name: 'property-details',
        builder: (context, state) => PropertyDetailPage(
          propertyId: state.pathParameters['id']!,
        ),
      ),
    ];

/// Public construction hub + detail routes (listed under Properties nav).
List<RouteBase> get constructionRoutes => [
      GoRoute(
        path: RoutePaths.construction,
        name: 'construction-updates',
        builder: (context, state) => const ConstructionUpdatesPage(),
      ),
    ];
