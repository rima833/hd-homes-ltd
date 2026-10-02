import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/navigation/deferred_navigation.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/validators/phone_validator.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/public_live_chat_panel.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
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
    goDeferred(context, path);
  }

  void _goProperties() {
    Navigator.pop(context);
    goDeferred(context, RoutePaths.properties);
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

/// WhatsApp, live chat, call, and book inspection FABs (bottom-right).
class PublicFloatingActions extends ConsumerWidget {
  const PublicFloatingActions({super.key});

  Future<void> _openWhatsApp(String? rawNumber) async {
    final uri = PhoneValidator.whatsappUri(
      rawNumber,
      prefillText: 'Hello HD Homes',
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String? rawPhone) async {
    final digits = PhoneValidator.whatsappDigits(rawPhone);
    if (digits == null || digits.isEmpty) return;
    await launchUrl(Uri.parse('tel:+$digits'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(publishedPlatformSettingsProvider).valueOrNull;
    final whatsapp = settings?.supportWhatsapp.trim() ?? '';
    final phone = settings?.supportPhone.trim() ?? '';
    final path = GoRouterState.of(context).uri.path;
    final onContactHub = path == RoutePaths.contact;

    final chatOpen = ref.watch(liveChatPanelOpenProvider);
    // Contact Hub already has QuickRail + Live Chat section — never show the
    // yellow/charcoal FAB stack there (it freezes taps over embedded wizards).
    // Still allow the floating panel when an in-page CTA opens chat.
    final showLiveChatFab =
        (settings?.showLiveChatFab ?? true) && !onContactHub;
    final showWhatsapp = !onContactHub &&
        (settings?.showWhatsappFab ?? true) &&
        whatsapp.isNotEmpty;
    final showCall = !onContactHub &&
        (settings?.showCallFabMobile ?? true) &&
        phone.isNotEmpty;
    final showBook = !onContactHub && (settings?.showBookFabMobile ?? true);

    if (onContactHub && !(chatOpen && (settings?.showLiveChatFab ?? true))) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: AppSpacing.base,
      bottom: AppSpacing.base,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chatOpen && (settings?.showLiveChatFab ?? true)) ...[
            const PublicLiveChatPanel(),
            if (showLiveChatFab) const SizedBox(height: AppSpacing.sm),
          ],
          if (showLiveChatFab) ...[
            FloatingActionButton.small(
              heroTag: 'live_chat',
              backgroundColor: chatOpen ? AppColors.gold : AppColors.charcoal,
              tooltip: chatOpen ? 'Close live chat' : 'Live chat',
              onPressed: () {
                // Defer so we don't rebuild mid-gesture over a heavy page.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(liveChatPanelOpenProvider.notifier).state = !chatOpen;
                });
              },
              child: Icon(
                chatOpen ? LucideIcons.x : LucideIcons.messageCircle,
                color: chatOpen ? AppColors.deepBlack : AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (showWhatsapp) ...[
            FloatingActionButton.small(
              heroTag: 'whatsapp',
              backgroundColor: const Color(0xFF25D366),
              tooltip: 'WhatsApp',
              onPressed: () => _openWhatsApp(whatsapp),
              child: const Icon(
                LucideIcons.messageCircle,
                color: AppColors.white,
              ),
            ),
          ],
          if (context.isMobile) ...[
            if (showCall) ...[
              const SizedBox(height: AppSpacing.sm),
              FloatingActionButton.small(
                heroTag: 'call',
                backgroundColor: AppColors.charcoal,
                onPressed: () => _call(phone),
                child: const Icon(LucideIcons.phone, color: AppColors.white),
              ),
            ],
            if (showBook) ...[
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: 'Book',
                icon: LucideIcons.calendar,
                onPressed: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      goDeferred(context, RoutePaths.bookInspection);
                    }
                  });
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
