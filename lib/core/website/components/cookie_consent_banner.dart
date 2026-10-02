import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/growth/consent/consent_gate.dart';
import 'package:hdhomesproject/core/storage/storage_service.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';

/// GDPR-style cookie consent (persisted via [StorageService]).
class CookieConsentBanner extends ConsumerStatefulWidget {
  const CookieConsentBanner({super.key});

  @override
  ConsumerState<CookieConsentBanner> createState() =>
      _CookieConsentBannerState();
}

class _CookieConsentBannerState extends ConsumerState<CookieConsentBanner> {
  bool _loaded = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final storage = await ref.read(storageServiceProvider.future);
    if (!mounted) return;
    final accepted = storage.cookieConsentAccepted;
    if (accepted && storage.cookieConsentChoice == null) {
      await storage.setCookieConsentChoice('accepted');
    }
    ref.read(consentGateProvider.notifier).hydrate(accepted);
    setState(() {
      _loaded = true;
      _visible = !storage.cookieConsentAnswered && !accepted;
    });
  }

  Future<void> _accept(bool accepted) async {
    await ref.read(consentGateProvider.notifier).setConsent(accepted);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_visible) return const SizedBox.shrink();

    return Positioned(
      left: AppSpacing.base,
      right: AppSpacing.base,
      bottom: AppSpacing.base,
      child: Material(
        elevation: 8,
        borderRadius: AppRadius.cardBorder,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 480;
              final message = Text(
                AppStrings.cookieMessage,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: stacked ? 4 : 3,
                overflow: TextOverflow.ellipsis,
              );
              final actions = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: stacked ? WrapAlignment.end : WrapAlignment.start,
                children: [
                  TextButton(
                    onPressed: () =>
                        context.go(RoutePaths.cmsPagePath('cookies')),
                    child: const Text('Cookie policy'),
                  ),
                  TextButton(
                    onPressed: () => _accept(false),
                    child: const Text(AppStrings.cookieDecline),
                  ),
                  FilledButton(
                    onPressed: () => _accept(true),
                    child: const Text(AppStrings.cookieAccept),
                  ),
                ],
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    message,
                    const SizedBox(height: AppSpacing.sm),
                    actions,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: message),
                  const SizedBox(width: AppSpacing.base),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
