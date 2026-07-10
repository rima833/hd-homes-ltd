import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    ref.read(consentGateProvider.notifier).hydrate(accepted);
    setState(() {
      _loaded = true;
      _visible = !accepted;
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.cookieMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              TextButton(
                onPressed: () => _accept(false),
                child: const Text(AppStrings.cookieDecline),
              ),
              FilledButton(
                onPressed: () => _accept(true),
                child: const Text(AppStrings.cookieAccept),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
