import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/kyc_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/kyc_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/profile_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/verification_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final kycServiceProvider = Provider<KycService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return KycService(
    security: ref.watch(securityServiceProvider),
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

void _invalidateKycData(Ref ref) {
  ref.invalidate(kycHubProvider);
  ref.invalidate(kycReviewQueueProvider);
  ref.invalidate(kycReviewCaseProvider);
  ref.invalidate(profileHubProvider);
}

/// Live invalidation for compliance hub + staff review queue.
final kycRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-kyc')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kyc_profiles',
      callback: (_) => _invalidateKycData(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kyc_documents',
      callback: (_) => _invalidateKycData(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'verification_requests',
      callback: (_) => _invalidateKycData(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'document_reviews',
      callback: (_) => _invalidateKycData(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_compliance',
      callback: (_) => _invalidateKycData(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kyc_events',
      callback: (_) => _invalidateKycData(ref),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final kycHubProvider = FutureProvider<KycHubSnapshot?>((ref) async {
  ref.watch(kycRealtimeProvider);
  final session = ref.watch(identitySessionProvider);
  if (!session.isAuthenticated) return null;
  final verification = ref.watch(verificationSnapshotProvider);
  final mfa = await ref.watch(mfaStatusProvider.future);
  return ref.watch(kycServiceProvider).loadHub(
        role: session.primaryRole,
        emailVerified: session.emailConfirmed || verification.emailVerified,
        phoneVerified: verification.phoneVerified,
        mfaEnabled: mfa.enabled,
      );
});

final kycReviewQueueProvider = FutureProvider<List<KycReviewQueueItem>>((ref) async {
  ref.watch(kycRealtimeProvider);
  final session = ref.watch(identitySessionProvider);
  if (!session.isStaff) return const [];
  return ref.read(kycServiceProvider).loadReviewQueue();
});

final kycReviewCaseProvider =
    FutureProvider.autoDispose.family<KycReviewCase, String>((ref, userId) async {
  ref.watch(kycRealtimeProvider);
  final session = ref.watch(identitySessionProvider);
  if (!session.isStaff) {
    throw const AuthenticationException('Staff access is required to review KYC.');
  }
  return ref.read(kycServiceProvider).loadReviewCase(userId);
});

class KycUiState {
  const KycUiState({
    this.isBusy = false,
    this.message,
    this.error,
    this.selectedType = KycDocumentType.passport,
  });

  final bool isBusy;
  final String? message;
  final String? error;
  final KycDocumentType selectedType;

  KycUiState copyWith({
    bool? isBusy,
    String? message,
    String? error,
    KycDocumentType? selectedType,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return KycUiState(
      isBusy: isBusy ?? this.isBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
      selectedType: selectedType ?? this.selectedType,
    );
  }
}

class KycController extends Notifier<KycUiState> {
  @override
  KycUiState build() => const KycUiState();

  KycService get _service => ref.read(kycServiceProvider);

  void selectType(KycDocumentType type) {
    state = state.copyWith(selectedType: type, clearError: true);
  }

  Future<bool> pickAndUpload(String userId) async {
    state = state.copyWith(isBusy: true, clearError: true, clearMessage: true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (file == null) {
        state = state.copyWith(isBusy: false);
        return false;
      }
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      await _service.uploadDocument(
        userId: userId,
        type: state.selectedType,
        bytes: bytes,
        fileName: file.name,
        mimeType: mime,
      );
      ref.invalidate(kycHubProvider);
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Document uploaded.');
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<void> deleteDocument(String userId, String documentId) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.deleteDraftDocument(userId: userId, documentId: documentId);
      ref.invalidate(kycHubProvider);
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Document removed.');
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
    }
  }

  Future<bool> saveCompliance(String userId, InvestorComplianceInfo info) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.saveCompliance(userId, info);
      ref.invalidate(kycHubProvider);
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Compliance details saved.');
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<bool> submit(String userId, KycLevel target) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.submitForReview(userId, target: target);
      ref.invalidate(kycHubProvider);
      ref.invalidate(kycReviewQueueProvider);
      ref.invalidate(profileHubProvider);
      state = state.copyWith(
        isBusy: false,
        message: 'Submitted for compliance review.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }

  Future<bool> review({
    required String userId,
    required KycReviewDecision decision,
    required String notes,
    required int approveLevel,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final reviewerId = ref.read(identitySessionProvider).userId;
      await _service.reviewSubmission(
        userId: userId,
        decision: decision,
        notes: notes,
        approveLevel: approveLevel,
        reviewerId: reviewerId,
      );
      ref.invalidate(kycReviewQueueProvider);
      ref.invalidate(kycReviewCaseProvider);
      ref.invalidate(kycHubProvider);
      ref.invalidate(profileHubProvider);
      state = state.copyWith(isBusy: false, message: 'Review recorded.');
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: userFacingError(e),
      );
      return false;
    }
  }
}

final kycControllerProvider =
    NotifierProvider<KycController, KycUiState>(KycController.new);
