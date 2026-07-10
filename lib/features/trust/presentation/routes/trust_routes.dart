import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/trust/presentation/pages/trust_center_page.dart';

List<RouteBase> get trustRoutes => [
      GoRoute(
        path: RoutePaths.trust,
        name: 'trust',
        builder: (context, state) => const TrustCenterPage(),
      ),
    ];
