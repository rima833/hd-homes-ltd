import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Draft vs baseline edit model for Platform Control Center (Phase 4 UI).
class PlatformSettingsEditState {
  const PlatformSettingsEditState({
    required this.baseline,
    required this.draft,
    this.saving = false,
    this.error,
    this.savedNotice,
  });

  final PlatformSettingsBundle baseline;
  final PlatformSettingsBundle draft;
  final bool saving;
  final String? error;
  final String? savedNotice;

  bool get isDirty => _encode(baseline) != _encode(draft);

  PlatformSettingsEditState copyWith({
    PlatformSettingsBundle? baseline,
    PlatformSettingsBundle? draft,
    bool? saving,
    String? error,
    String? savedNotice,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return PlatformSettingsEditState(
      baseline: baseline ?? this.baseline,
      draft: draft ?? this.draft,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      savedNotice: clearNotice ? null : (savedNotice ?? this.savedNotice),
    );
  }

  static String _encode(PlatformSettingsBundle bundle) => jsonEncode({
        'company': bundle.company,
        'contact': bundle.contact,
        'theme': bundle.theme,
        'seo': bundle.seo,
        'social': bundle.social,
        'website_features': bundle.websiteFeatures,
        'maintenance': bundle.maintenance,
        'portal_features': bundle.portalFeatures,
        'integrations': bundle.integrations,
      });
}

/// Mutable draft holder. Hydrated from [adminPlatformSettingsProvider].
class PlatformSettingsEditController
    extends Notifier<PlatformSettingsEditState> {
  @override
  PlatformSettingsEditState build() {
    // Do not watch the FutureProvider here — that would reset dirty drafts
    // on every Realtime tick. Sync via listen only.
    ref.listen<AsyncValue<PlatformSettingsBundle>>(
      adminPlatformSettingsProvider,
      (previous, next) {
        final bundle = next.valueOrNull;
        if (bundle == null) return;
        final current = state;
        if (current.isDirty && !current.saving) {
          state = current.copyWith(baseline: bundle);
          return;
        }
        if (!current.saving) {
          state = PlatformSettingsEditState(baseline: bundle, draft: bundle);
        }
      },
      fireImmediately: true,
    );

    final loaded = ref.read(adminPlatformSettingsProvider).valueOrNull ??
        const PlatformSettingsBundle();
    return PlatformSettingsEditState(baseline: loaded, draft: loaded);
  }

  void replaceDraft(PlatformSettingsBundle draft) {
    state = state.copyWith(
      draft: draft,
      clearError: true,
      clearNotice: true,
    );
  }

  void patchDraft({
    Map<String, dynamic>? company,
    Map<String, dynamic>? contact,
    Map<String, dynamic>? theme,
    Map<String, dynamic>? seo,
    Map<String, dynamic>? social,
    Map<String, dynamic>? websiteFeatures,
    Map<String, dynamic>? maintenance,
    Map<String, dynamic>? portalFeatures,
    Map<String, dynamic>? integrations,
  }) {
    replaceDraft(
      state.draft.copyWith(
        company: company,
        contact: contact,
        theme: theme,
        seo: seo,
        social: social,
        websiteFeatures: websiteFeatures,
        maintenance: maintenance,
        portalFeatures: portalFeatures,
        integrations: integrations,
      ),
    );
  }

  void reset() {
    state = PlatformSettingsEditState(
      baseline: state.baseline,
      draft: state.baseline,
    );
  }

  Future<bool> save() async {
    if (!state.isDirty) return false;
    final draft = state.draft;
    state = state.copyWith(saving: true, clearError: true, clearNotice: true);
    try {
      await ref.read(platformSettingsServiceProvider).saveBundle(draft);
      ref.invalidate(adminPlatformSettingsProvider);
      ref.invalidate(publishedPlatformSettingsProvider);
      ref.invalidate(publishedCompanySettingsCompatProvider);
      ref.invalidate(publishedCompanySettingsProvider);
      ref.invalidate(portalFeatureFlagsProvider);
      state = PlatformSettingsEditState(
        baseline: draft,
        draft: draft,
        savedNotice: 'Settings saved.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(saving: false, error: userFacingError(e));
      return false;
    }
  }
}

final platformSettingsEditControllerProvider =
    NotifierProvider<PlatformSettingsEditController, PlatformSettingsEditState>(
  PlatformSettingsEditController.new,
);
