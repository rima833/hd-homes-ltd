import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Global intelligent search overlay (CMS-connected in later phases).
class WebsiteSearchOverlay {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SearchSheet(),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet();

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.xxl,
        left: AppSpacing.base,
        right: AppSpacing.base,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.base,
      ),
      child: Material(
        borderRadius: AppRadius.dialogBorder,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  children: [
                    const Icon(LucideIcons.search, color: AppColors.gold),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onSubmitted: (_) => _goProperties(),
                        decoration: InputDecoration(
                          hintText: AppStrings.navSearch,
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.inputBorder,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  children: [
                    Text(
                      'Quick links',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _QuickLink(
                      icon: LucideIcons.building2,
                      label: 'Properties',
                      onTap: () => _go(RoutePaths.properties),
                    ),
                    _QuickLink(
                      icon: LucideIcons.map,
                      label: 'Estates',
                      onTap: () => _go(RoutePaths.estates),
                    ),
                    _QuickLink(
                      icon: LucideIcons.bookOpen,
                      label: 'Blog',
                      onTap: () => _go(RoutePaths.blog),
                    ),
                    _QuickLink(
                      icon: LucideIcons.helpCircle,
                      label: 'FAQs',
                      onTap: () => _go(RoutePaths.contact),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: PrimaryButton(
                  label: 'Search properties',
                  expand: true,
                  icon: LucideIcons.search,
                  onPressed: _goProperties,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(String path) {
    Navigator.pop(context);
    context.go(path);
  }

  void _goProperties() {
    Navigator.pop(context);
    context.go(RoutePaths.properties);
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(label),
      onTap: onTap,
    );
  }
}

/// WhatsApp, live chat, call, and book inspection FABs.
class PublicFloatingActions extends StatelessWidget {
  const PublicFloatingActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: AppSpacing.base,
      bottom: AppSpacing.base,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'live_chat',
            backgroundColor: AppColors.charcoal,
            tooltip: 'Live chat',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open HD Homes AI Concierge™ using the gold chat button')),
              );
            },
            child: const Icon(LucideIcons.messageCircle, color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          FloatingActionButton.small(
            heroTag: 'whatsapp',
            backgroundColor: const Color(0xFF25D366),
            tooltip: 'WhatsApp',
            onPressed: () => launchUrl(Uri.parse('https://wa.me/')),
            child: const Icon(LucideIcons.messageCircle, color: AppColors.white),
          ),
          if (context.isMobile) ...[
            const SizedBox(height: AppSpacing.sm),
            FloatingActionButton.small(
              heroTag: 'call',
              backgroundColor: AppColors.charcoal,
              onPressed: () => launchUrl(Uri.parse('tel:')),
              child: const Icon(LucideIcons.phone, color: AppColors.white),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'Book',
              icon: LucideIcons.calendar,
              onPressed: () => context.go(RoutePaths.bookInspection),
            ),
          ],
        ],
      ),
    );
  }
}
