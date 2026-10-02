import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/consultation/domain/entities/consultation_booking_models.dart';
import 'package:hdhomesproject/features/consultation/domain/services/consultation_booking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final consultationBookingServiceProvider = Provider<ConsultationBookingService>(
  (ref) {
    final configured = ref.watch(supabaseConfiguredProvider);
    return ConsultationBookingService(
      client: configured ? ref.watch(supabaseClientProvider) : null,
      mediaService: ref.watch(mediaServiceProvider),
    );
  },
);

final consultationDepartmentsProvider =
    FutureProvider<List<ConsultationDepartment>>((ref) {
      return ref.watch(consultationBookingServiceProvider).fetchDepartments();
    });

final consultationAdvisorsProvider =
    FutureProvider.family<List<ConsultationAdvisor>, String?>((ref, deptId) {
      return ref
          .watch(consultationBookingServiceProvider)
          .fetchAdvisors(departmentId: deptId);
    });

final consultationSlotsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('consultation-slots')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'consultation_bookings',
      callback: (_) {
        ref.invalidate(consultationSlotsProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'consultation_bookings',
      callback: (_) {
        ref.invalidate(consultationSlotsProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final consultationSlotsProvider =
    FutureProvider.family<List<ConsultationSlot>, String?>((ref, deptId) {
      return ref
          .read(consultationBookingServiceProvider)
          .fetchSlots(departmentId: deptId);
    });

final consultationBookingControllerProvider =
    NotifierProvider<ConsultationBookingController, ConsultationBookingDraft>(
      ConsultationBookingController.new,
    );

class ConsultationBookingController extends Notifier<ConsultationBookingDraft> {
  @override
  ConsultationBookingDraft build() => const ConsultationBookingDraft();

  void setStep(int step) => state = state.copyWith(step: step.clamp(0, 3));

  /// Returns an error message if the current step is incomplete, else null.
  String? validateStep(int step) {
    switch (step) {
      case 0:
        if (state.fullName.trim().length < 2) {
          return 'Please enter your full name';
        }
        if (state.phone.trim().length < 7) {
          return 'Please enter a valid phone number';
        }
        if (!state.email.contains('@')) {
          return 'Please enter a valid email address';
        }
        return null;
      case 1:
        if (state.departmentSlug.trim().isEmpty) {
          return 'Please choose a consultation department';
        }
        return null;
      case 2:
        if (state.selectedSlot == null) {
          return 'Please select an available date and time slot';
        }
        return null;
      default:
        return null;
    }
  }

  bool goNext() {
    final err = validateStep(state.step);
    if (err != null) {
      state = state.copyWith(error: err);
      return false;
    }
    state = state.copyWith(
      step: (state.step + 1).clamp(0, 3),
      clearError: true,
    );
    return true;
  }

  void goBack() {
    if (state.step <= 0) return;
    state = state.copyWith(step: state.step - 1, clearError: true);
  }

  void patch(ConsultationBookingDraft Function(ConsultationBookingDraft) fn) {
    state = fn(state).copyWith(clearError: true);
  }

  Future<bool> submit() async {
    final draft = state;
    if (draft.fullName.trim().length < 2) {
      state = state.copyWith(error: 'Please enter your full name');
      return false;
    }
    if (draft.phone.trim().length < 7) {
      state = state.copyWith(error: 'Please enter a valid phone number');
      return false;
    }
    if (!draft.email.contains('@')) {
      state = state.copyWith(error: 'Please enter a valid email address');
      return false;
    }
    if (draft.selectedSlot == null) {
      state = state.copyWith(error: 'Please select an available time slot');
      return false;
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final result = await ref
          .read(consultationBookingServiceProvider)
          .submit(draft);
      state = state.copyWith(
        submitting: false,
        submittedReference: result.reference,
        step: 3,
      );
      return true;
    } catch (e) {
      final msg = '$e';
      if (msg.contains('slot_unavailable')) {
        ref.invalidate(consultationSlotsProvider);
        state = state.copyWith(
          submitting: false,
          clearSelectedSlot: true,
          error:
              'This time slot was just booked. Please select another available time.',
        );
        return false;
      }
      state = state.copyWith(
        submitting: false,
        error: userFacingError(
          e,
          fallback: 'We couldn\'t complete your booking. Please try again.',
        ),
      );
      return false;
    }
  }

  void reset() => state = const ConsultationBookingDraft();
}

ConsultationDepartment? selectedConsultationDepartment(WidgetRef ref) {
  final slug = ref.watch(consultationBookingControllerProvider).departmentSlug;
  final list =
      ref.watch(consultationDepartmentsProvider).valueOrNull ??
      const <ConsultationDepartment>[];
  for (final d in list) {
    if (d.slug == slug) return d;
  }
  return list.isEmpty ? null : list.first;
}

ConsultationAdvisor? selectedConsultationAdvisor(WidgetRef ref) {
  final draft = ref.watch(consultationBookingControllerProvider);
  final dept = selectedConsultationDepartment(ref);
  final advisors =
      ref.watch(consultationAdvisorsProvider(dept?.id)).valueOrNull ??
      const <ConsultationAdvisor>[];
  if (draft.advisorId == null) return null;
  for (final a in advisors) {
    if (a.id == draft.advisorId) return a;
  }
  return null;
}
