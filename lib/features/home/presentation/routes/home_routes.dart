import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/widgets/placeholder_page.dart';
import 'package:hdhomesproject/features/about/presentation/pages/about_page.dart';
import 'package:hdhomesproject/features/careers/presentation/pages/careers_page.dart';
import 'package:hdhomesproject/features/contact/presentation/pages/contact_page.dart';
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
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: RoutePaths.contact,
        name: 'contact',
        builder: (context, state) => const ContactPage(),
      ),
      GoRoute(
        path: RoutePaths.careers,
        name: 'careers',
        builder: (context, state) => const CareersPage(),
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
