import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/investor/presentation/pages/investor_portal_stub_page.dart';

List<RouteBase> get investorRoutes => [
      GoRoute(
        path: RoutePaths.investor,
        name: 'investor',
        builder: (context, state) => const InvestorPortalStubPage(
          title: 'Investor Dashboard',
          subtitle:
              'Welcome to the Investor Portal shell. Full portfolio, analytics, and reporting '
              'modules ship with Volume 3 after authentication is complete.',
        ),
      ),
    ];
