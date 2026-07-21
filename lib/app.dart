import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/config/app_config.dart';
import 'package:hdhomesproject/core/navigation/command_palette.dart';
import 'package:hdhomesproject/core/router/app_router.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/theme_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/app_breakpoints.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Root application widget with global UI framework.
class HdHomesApp extends ConsumerWidget {
  const HdHomesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode.valueOrNull ?? ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) => CommandPalette(
        child: ResponsiveBreakpoints.builder(
          child: child ?? const SizedBox.shrink(),
          breakpoints: const [
            Breakpoint(start: 0, end: AppBreakpoints.mobileMax, name: MOBILE),
            Breakpoint(
              start: AppBreakpoints.mobile,
              end: AppBreakpoints.tabletMax,
              name: TABLET,
            ),
            Breakpoint(
              start: AppBreakpoints.tablet,
              end: AppBreakpoints.laptopMax,
              name: 'LAPTOP',
            ),
            Breakpoint(
              start: AppBreakpoints.laptop,
              end: AppBreakpoints.desktopMax,
              name: DESKTOP,
            ),
            Breakpoint(
              start: AppBreakpoints.desktop,
              end: double.infinity,
              name: '4K',
            ),
          ],
        ),
      ),
    );
  }
}
