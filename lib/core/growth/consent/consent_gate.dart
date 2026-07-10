import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/storage/storage_service.dart';

/// Consent gate for analytics and marketing tracking (NDPR/GDPR).
class ConsentNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> load() async {
    final storage = await ref.read(storageServiceProvider.future);
    state = storage.cookieConsentAccepted;
  }

  Future<void> setConsent(bool accepted) async {
    final storage = await ref.read(storageServiceProvider.future);
    await storage.setCookieConsentAccepted(accepted);
    state = accepted;
  }

  void hydrate(bool accepted) => state = accepted;
}

final consentGateProvider = NotifierProvider<ConsentNotifier, bool>(ConsentNotifier.new);

/// Whether analytics and personalization are allowed.
final analyticsConsentProvider = Provider<bool>((ref) => ref.watch(consentGateProvider));
