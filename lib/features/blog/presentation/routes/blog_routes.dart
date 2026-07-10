import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/blog/presentation/pages/blog_article_page.dart';
import 'package:hdhomesproject/features/blog/presentation/pages/blog_hub_page.dart';

List<RouteBase> get blogRoutes => [
      GoRoute(
        path: RoutePaths.blog,
        name: 'blog',
        builder: (context, state) => const BlogHubPage(),
      ),
      GoRoute(
        path: RoutePaths.blogPost,
        name: 'blog-post',
        builder: (context, state) => BlogArticlePage(
          slug: state.pathParameters['slug']!,
        ),
      ),
    ];
