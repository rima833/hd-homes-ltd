import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/investment/presentation/pages/investment_hub_page.dart';
import 'package:hdhomesproject/features/investment/presentation/pages/investment_opportunity_detail_page.dart';
import 'package:hdhomesproject/features/investment/presentation/pages/roi_calculator_page.dart';

List<RouteBase> get investmentRoutes => [
      GoRoute(
        path: RoutePaths.investment,
        name: 'investment',
        builder: (context, state) => const InvestmentHubPage(),
        routes: [
          // Must be before `:slug` so "roi-calculator" is not treated as a slug.
          GoRoute(
            path: 'roi-calculator',
            name: 'roi-calculator',
            builder: (context, state) => const RoiCalculatorPage(),
          ),
          GoRoute(
            path: ':slug',
            name: 'investment-opportunity',
            builder: (context, state) {
              final slug = state.pathParameters['slug'] ?? '';
              return InvestmentOpportunityDetailPage(slug: slug);
            },
          ),
        ],
      ),
    ];
