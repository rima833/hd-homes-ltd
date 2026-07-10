import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/login_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/register_page.dart';

List<RouteBase> get authRoutes => [
      GoRoute(
        path: RoutePaths.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RoutePaths.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
    ];
