import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/investment/presentation/pages/investment_hub_page.dart';

List<RouteBase> get investmentRoutes => [
      GoRoute(
        path: RoutePaths.investment,
        name: 'investment',
        builder: (context, state) => const InvestmentHubPage(),
      ),
    ];
