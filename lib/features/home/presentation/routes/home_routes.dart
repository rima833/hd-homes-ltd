import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/widgets/placeholder_page.dart';
import 'package:hdhomesproject/features/home/presentation/pages/home_page.dart';

List<RouteBase> get homeRoutes => [
      GoRoute(
        path: RoutePaths.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: RoutePaths.about,
        name: 'about',
        builder: (context, state) => const PlaceholderPage(
          title: 'About HD Homes',
          subtitle: 'Company profile — coming in a future milestone.',
        ),
      ),
      GoRoute(
        path: RoutePaths.contact,
        name: 'contact',
        builder: (context, state) => const PlaceholderPage(
          title: 'Contact Us',
          subtitle: 'Contact form — coming in a future milestone.',
        ),
      ),
      GoRoute(
        path: RoutePaths.careers,
        name: 'careers',
        builder: (context, state) => const PlaceholderPage(
          title: 'Careers',
          subtitle: 'Job listings — coming in a future milestone.',
        ),
      ),
      GoRoute(
        path: RoutePaths.gallery,
        name: 'gallery',
        builder: (context, state) => const PlaceholderPage(
          title: 'Gallery',
          subtitle: 'Project gallery — coming in a future milestone.',
        ),
      ),
    ];
