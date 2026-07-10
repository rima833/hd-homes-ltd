import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/contact/presentation/pages/contact_page.dart';

List<RouteBase> get contactRoutes => [
      GoRoute(
        path: RoutePaths.contact,
        name: 'contact',
        builder: (context, state) => const ContactPage(),
      ),
      GoRoute(
        path: RoutePaths.bookInspection,
        name: 'book-inspection',
        builder: (context, state) => const ContactPage(initialTarget: ContactScrollTarget.inspection),
      ),
    ];
