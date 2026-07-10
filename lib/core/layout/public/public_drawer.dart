import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/navigation_config.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';

class PublicDrawer extends StatelessWidget {
  const PublicDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('HD Homes Ltd', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final item in NavigationConfig.publicNav)
                    ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      selected: location == item.path,
                      selectedColor: AppColors.gold,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(item.path);
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Book Inspection',
                    expand: true,
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go(RoutePaths.bookInspection);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go(RoutePaths.login);
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
