import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/data/repositories/registration_repository_impl.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/user_profile.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/auth_repository.dart';
import 'package:hdhomesproject/features/authentication/domain/repositories/registration_repository.dart';
import 'package:hdhomesproject/features/authentication/domain/services/captcha_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_validator.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';

final captchaServiceProvider = Provider<CaptchaService>((ref) {
  return const NoOpCaptchaService();
});

// phoneOtpServiceProvider lives in verification_controller.dart (failover-ready).

final registrationRepositoryProvider = Provider<RegistrationRepository>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  if (authRepo == null) {
    return RegistrationRepositoryImpl(
      authRepository: _UnavailableAuthBridge(),
      client: null,
      captcha: ref.watch(captchaServiceProvider),
    );
  }
  final client =
      ref.watch(supabaseConfiguredProvider) ? ref.watch(supabaseClientProvider) : null;
  return RegistrationRepositoryImpl(
    authRepository: authRepo,
    client: client,
    captcha: ref.watch(captchaServiceProvider),
  );
});

class RegistrationFlowState {
  const RegistrationFlowState({
    this.step = RegistrationStep.accountType,
    this.draft = const RegistrationDraft(),
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.fieldErrors = const {},
    this.referralValid,
  });

  final RegistrationStep step;
  final RegistrationDraft draft;
  final bool isSubmitting;
  final RegistrationResult? result;
  final String? errorMessage;
  final Map<String, String?> fieldErrors;
  final bool? referralValid;

  RegistrationFlowState copyWith({
    RegistrationStep? step,
    RegistrationDraft? draft,
    bool? isSubmitting,
    RegistrationResult? result,
    String? errorMessage,
    Map<String, String?>? fieldErrors,
    bool? referralValid,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return RegistrationFlowState(
      step: step ?? this.step,
      draft: draft ?? this.draft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      referralValid: referralValid ?? this.referralValid,
    );
  }
}

class RegistrationController extends Notifier<RegistrationFlowState> {
  @override
  RegistrationFlowState build() {
    final repo = ref.read(registrationRepositoryProvider);
    repo.trackEvent(RegistrationAnalyticsEvent.started);
    return const RegistrationFlowState();
  }

  RegistrationRepository get _repo => ref.read(registrationRepositoryProvider);

  void selectAccountType(RegistrationAccountType type) {
    if (!type.enabled) return;
    state = state.copyWith(
      draft: state.draft.copyWith(accountType: type),
      clearError: true,
    );
    _repo.trackEvent(
      RegistrationAnalyticsEvent.accountTypeSelected,
      accountType: type,
      step: RegistrationStep.accountType,
    );
  }

  void updateDraft(RegistrationDraft Function(RegistrationDraft) updater) {
    state = state.copyWith(draft: updater(state.draft), clearError: true);
  }

  bool nextStep() {
    final step = state.step;
    if (!_validateCurrentStep()) {
      _repo.trackEvent(
        RegistrationAnalyticsEvent.stepAbandoned,
        step: step,
        accountType: state.draft.accountType,
      );
      return false;
    }
    _repo.trackEvent(
      RegistrationAnalyticsEvent.stepCompleted,
      step: step,
      accountType: state.draft.accountType,
    );
    final next = step.next;
    if (next != null) {
      state = state.copyWith(step: next, fieldErrors: {}, clearError: true);
    }
    return true;
  }

  void previousStep() {
    final prev = state.step.previous;
    if (prev != null) {
      state = state.copyWith(step: prev, fieldErrors: {}, clearError: true);
    }
  }

  void goToStep(RegistrationStep step) {
    if (step.index <= state.step.index) {
      state = state.copyWith(step: step, fieldErrors: {}, clearError: true);
    }
  }

  bool _validateCurrentStep() {
    final draft = state.draft;
    switch (state.step) {
      case RegistrationStep.accountType:
        final err = RegistrationValidator.validateAccountType(draft);
        if (err != null) {
          state = state.copyWith(errorMessage: err);
          return false;
        }
        return true;
      case RegistrationStep.personalInfo:
        final errors = RegistrationValidator.validatePersonalInfo(draft);
        final hasError = errors.values.any((e) => e != null);
        if (hasError) {
          state = state.copyWith(fieldErrors: errors);
          return false;
        }
        final referralError =
            RegistrationValidator.validateReferralCode(draft.referralCode);
        if (referralError != null) {
          state = state.copyWith(
            fieldErrors: {...errors, 'referralCode': referralError},
          );
          return false;
        }
        return true;
      case RegistrationStep.credentials:
        final errors = RegistrationValidator.validateCredentials(draft);
        final hasError = errors.values.any((e) => e != null);
        if (hasError) {
          state = state.copyWith(fieldErrors: errors);
          return false;
        }
        return true;
      case RegistrationStep.legal:
        final err = RegistrationValidator.validateLegal(draft);
        if (err != null) {
          state = state.copyWith(errorMessage: err);
          return false;
        }
        return true;
      case RegistrationStep.review:
        return RegistrationValidator.stepIsValid(RegistrationStep.review, draft);
    }
  }

  Future<void> validateReferral() async {
    final code = state.draft.referralCode.trim();
    if (code.isEmpty) {
      state = state.copyWith(referralValid: null);
      return;
    }
    final valid = await _repo.isReferralCodeValid(code);
    state = state.copyWith(referralValid: valid);
    if (valid) {
      _repo.trackEvent(
        RegistrationAnalyticsEvent.referralApplied,
        accountType: state.draft.accountType,
        metadata: {'code': code.toUpperCase()},
      );
    }
  }

  Future<RegistrationResult?> submit() async {
    if (state.step != RegistrationStep.review && !_validateCurrentStep()) {
      return null;
    }
    if (!RegistrationValidator.stepIsValid(RegistrationStep.review, state.draft)) {
      state = state.copyWith(
        errorMessage: 'Please complete all steps before creating your account.',
      );
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await _repo.register(state.draft);
      state = state.copyWith(isSubmitting: false, result: result);
      return result;
    } catch (e) {
      final message = e is AppException
          ? e.message
          : 'Unable to create your account. Please try again.';
      state = state.copyWith(isSubmitting: false, errorMessage: message);
      return null;
    }
  }

  void reset() {
    state = const RegistrationFlowState();
    _repo.trackEvent(RegistrationAnalyticsEvent.started);
  }
}

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RegistrationFlowState>(
  RegistrationController.new,
);

class _UnavailableAuthBridge implements AuthRepository {
  @override
  Stream<UserProfile?> authStateChanges() => const Stream.empty();

  @override
  UserProfile? get currentProfile => null;

  @override
  Set<String> get currentPermissions => {};

  @override
  Future<UserProfile?> fetchCurrentProfile() async => null;

  @override
  Future<Set<String>> refreshPermissions() async => {};

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {
    throw const AuthenticationException('Authentication is not configured.');
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    throw const AuthenticationException('Authentication is not configured.');
  }

  @override
  Future<void> resendSignupEmail(String email) async {
    throw const AuthenticationException('Authentication is not configured.');
  }

  @override
  Future<void> signOut({bool everywhere = false}) async {}

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw const AuthenticationException('Authentication is not configured.');
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    Map<String, dynamic>? metadata,
  }) {
    throw const AuthenticationException(
      'Registration is unavailable until Supabase is configured.',
    );
  }
}
