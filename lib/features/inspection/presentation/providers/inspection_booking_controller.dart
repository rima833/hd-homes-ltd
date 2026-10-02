import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_booking_models.dart';
import 'package:hdhomesproject/features/inspection/domain/services/inspection_booking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final inspectionBookingServiceProvider = Provider<InspectionBookingService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return InspectionBookingService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
    mediaService: ref.watch(mediaServiceProvider),
  );
});

final inspectionAdvisorsProvider =
    FutureProvider<List<InspectionAdvisor>>((ref) async {
  ref.watch(inspectionAvailabilityTickProvider);
  return ref.watch(inspectionBookingServiceProvider).fetchAdvisors();
});

final inspectionDisabledPropertyIdsProvider =
    FutureProvider<Set<String>>((ref) async {
  ref.watch(inspectionAvailabilityTickProvider);
  return ref.watch(inspectionBookingServiceProvider).fetchDisabledPropertyIds();
});

/// Published properties eligible for inspection booking.
final inspectionBookablePropertiesProvider =
    FutureProvider<List<CmsPropertyFeatured>>((ref) async {
  ref.watch(publishedPropertiesRealtimeProvider);
  ref.watch(inspectionAvailabilityTickProvider);
  final properties =
      await ref.watch(publishedPropertiesCatalogProvider.future);
  final disabled =
      await ref.watch(inspectionDisabledPropertyIdsProvider.future);
  return properties.where((p) {
    if (!p.isPublished) return false;
    if (disabled.contains(p.id)) return false;
    final ms = (p.marketingStatus ?? '').toLowerCase();
    if (ms.contains('sold') ||
        ms.contains('unavailable') ||
        ms.contains('archived')) {
      return false;
    }
    return true;
  }).toList();
});

class InspectionSlotQuery {
  const InspectionSlotQuery({
    required this.propertyId,
    this.estateId,
    this.advisorId,
    this.from,
  });

  final String propertyId;
  final String? estateId;
  final String? advisorId;
  final DateTime? from;

  @override
  bool operator ==(Object other) =>
      other is InspectionSlotQuery &&
      other.propertyId == propertyId &&
      other.estateId == estateId &&
      other.advisorId == advisorId &&
      other.from?.toIso8601String().split('T').first ==
          from?.toIso8601String().split('T').first;

  @override
  int get hashCode => Object.hash(
        propertyId,
        estateId,
        advisorId,
        from?.toIso8601String().split('T').first,
      );
}

/// Bumped by inspectionBookingRealtimeProvider so availability providers refresh
/// without forming a watch/invalidate cycle.
final inspectionAvailabilityTickProvider = StateProvider<int>((ref) => 0);

/// Live invalidation for properties, estates, advisors, and inspection slots.
final inspectionBookingRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  void refreshAvailability() {
    ref.read(inspectionAvailabilityTickProvider.notifier).state++;
    ref.invalidate(publishedEstatesCatalogProvider);
  }

  final channel = client.channel('inspection-booking-live')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_inspections',
      callback: (_) => refreshAvailability(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_inspection_config',
      callback: (_) => refreshAvailability(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_blocked_slots',
      callback: (_) => refreshAvailability(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_holidays',
      callback: (_) => refreshAvailability(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_working_hours',
      callback: (_) => refreshAvailability(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_settings',
      callback: (_) => refreshAvailability(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'inspection_agents',
      callback: (_) => refreshAvailability(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'estates',
      callback: (_) {
        ref.read(inspectionAvailabilityTickProvider.notifier).state++;
        ref.invalidate(publishedEstatesCatalogProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final inspectionSlotsRealtimeProvider =
    Provider.family<void, String>((ref, propertyId) {
  if (propertyId.isEmpty) return;
  ref.watch(inspectionBookingRealtimeProvider);
});

final inspectionSlotsProvider =
    FutureProvider.family<List<InspectionSlot>, InspectionSlotQuery>(
  (ref, query) async {
    ref.watch(inspectionAvailabilityTickProvider);
    bool isUuid(String? v) =>
        v != null &&
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(v);

    return ref.read(inspectionBookingServiceProvider).fetchSlots(
          propertyId: query.propertyId,
          estateId: isUuid(query.estateId) ? query.estateId : null,
          advisorId: isUuid(query.advisorId) ? query.advisorId : null,
          from: query.from,
        );
  },
);

final inspectionBookingStatusProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, inspectionId) async {
  ref.watch(inspectionAvailabilityTickProvider);
  return ref
      .read(inspectionBookingServiceProvider)
      .fetchBookingStatus(inspectionId);
});

final inspectionBookingControllerProvider =
    NotifierProvider<InspectionBookingController, InspectionBookingDraft>(
  InspectionBookingController.new,
);

class InspectionBookingController extends Notifier<InspectionBookingDraft> {
  @override
  InspectionBookingDraft build() => const InspectionBookingDraft();

  void setStep(int step) {
    final next = step.clamp(0, 4);
    if (next > state.maxStepReached) return;
    state = state.copyWith(step: next, clearError: true);
  }

  void goBack() {
    if (state.step <= 0) return;
    state = state.copyWith(step: state.step - 1, clearError: true);
  }

  String? validateStep(int step) {
    switch (step) {
      case 0:
        if (state.fullName.trim().length < 2) {
          return 'Please enter your full name';
        }
        final digits = state.phone.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 10) {
          return 'Please enter a valid phone number';
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(state.email.trim())) {
          return 'Please enter a valid email address';
        }
        return null;
      case 1:
        if (state.propertyId == null || state.propertyId!.isEmpty) {
          return 'Please select a property';
        }
        return null;
      case 2:
        if (state.preferredDate == null) {
          return 'Please choose a preferred date';
        }
        if (state.preferredTime == null && state.scheduledAt == null) {
          return 'Please choose a live time slot';
        }
        return null;
      case 3:
        if (state.meetingType == InspectionMeetingType.physical) {
          switch (state.meetupMode) {
            case InspectionMeetupMode.pickup:
              if (state.pickupAddress.trim().length < 5) {
                return 'Enter your pickup address so we can collect you';
              }
            case InspectionMeetupMode.meetAtOffice:
              if (state.meetupOfficeId == null ||
                  state.meetupOfficeId!.isEmpty) {
                return 'Select the HD Homes office you will visit';
              }
            case InspectionMeetupMode.meetAtProperty:
              break;
          }
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
    final next = (state.step + 1).clamp(0, 4);
    final reached =
        next > state.maxStepReached ? next : state.maxStepReached;
    DateTime? scheduled = state.scheduledAt;
    if (scheduled == null &&
        state.preferredDate != null &&
        state.preferredTime != null) {
      final d = state.preferredDate!;
      final t = state.preferredTime!;
      scheduled = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }
    state = state.copyWith(
      step: next,
      maxStepReached: reached,
      scheduledAt: scheduled,
      clearError: true,
    );
    return true;
  }

  void patch(InspectionBookingDraft Function(InspectionBookingDraft) fn) {
    state = fn(state).copyWith(clearError: true);
  }

  void selectProperty(CmsPropertyFeatured? property, {String? estateId}) {
    state = state.copyWith(
      propertyId: property?.id,
      clearPropertyId: property == null,
      estateId: estateId ?? state.estateId,
      clearEstateId: estateId == null && property == null,
      clearPreferredDate: true,
      clearPreferredTime: true,
      clearScheduledAt: true,
    );
  }

  /// Change estate filter. Clears property only when the estate actually changes.
  void selectEstate(String? estateId) {
    final changed = estateId != state.estateId;
    state = state.copyWith(
      estateId: estateId,
      clearEstateId: estateId == null,
      clearPropertyId: changed,
      clearPreferredDate: changed,
      clearPreferredTime: changed,
      clearScheduledAt: changed,
    );
  }

  void preselectProperty(String propertyId, {String? estateId}) {
    state = state.copyWith(
      propertyId: propertyId,
      estateId: estateId,
    );
  }

  void clearUnavailableSlot() {
    if (state.scheduledAt == null && state.preferredTime == null) return;
    state = state.copyWith(
      clearPreferredTime: true,
      clearScheduledAt: true,
      error: 'That time was just booked. Please pick another live slot.',
    );
  }

  Future<bool> submit() async {
    for (final step in const [0, 1, 2]) {
      final err = validateStep(step);
      if (err != null) {
        state = state.copyWith(error: err, step: step);
        return false;
      }
    }

    DateTime? scheduled = state.scheduledAt;
    if (scheduled == null &&
        state.preferredDate != null &&
        state.preferredTime != null) {
      final d = state.preferredDate!;
      final t = state.preferredTime!;
      scheduled = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      state = state.copyWith(scheduledAt: scheduled);
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final userId = ref.read(identitySessionProvider).userId;
      final result = await ref.read(inspectionBookingServiceProvider).submit(
            state,
            visitorProfileId: userId,
          );
      state = state.copyWith(
        submitting: false,
        submittedReference: result.reference,
        submittedInspectionId: result.inspectionId,
        submittedScheduledAt: result.scheduledAt,
        submittedAdvisorName: result.advisorName,
        submittedMeetingType: result.meetingType ?? state.meetingType,
        step: 4,
        maxStepReached: 4,
      );
      return true;
    } catch (e) {
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

  void reset() {
    final session = ref.read(identitySessionProvider);
    final profile = session.profile;
    state = InspectionBookingDraft(
      fullName: profile?.displayName ?? '',
      email: profile?.email ?? '',
      phone: profile?.phone ?? '',
    );
  }
}

CmsPropertyFeatured? selectedInspectionProperty(WidgetRef ref) {
  final id = ref.watch(inspectionBookingControllerProvider).propertyId;
  if (id == null) return null;
  final list =
      ref.watch(inspectionBookablePropertiesProvider).valueOrNull ?? const [];
  for (final p in list) {
    if (p.id == id) return p;
  }
  final catalog =
      ref.watch(publishedPropertiesCatalogProvider).valueOrNull ?? const [];
  for (final p in catalog) {
    if (p.id == id) return p;
  }
  return null;
}

CmsEstateSummary? selectedInspectionEstate(WidgetRef ref) {
  final id = ref.watch(inspectionBookingControllerProvider).estateId;
  final list =
      ref.watch(publishedEstatesCatalogProvider).valueOrNull ?? const [];
  if (id != null) {
    for (final e in list) {
      if (e.id == id) return e;
    }
  }
  final property = selectedInspectionProperty(ref);
  if (property?.estateName == null) return null;
  for (final e in list) {
    if (e.name == property!.estateName) return e;
  }
  return null;
}

InspectionAdvisor? selectedInspectionAdvisor(WidgetRef ref) {
  final id = ref.watch(inspectionBookingControllerProvider).advisorId;
  if (id == null) return null;
  final advisors =
      ref.watch(inspectionAdvisorsProvider).valueOrNull ?? const [];
  for (final a in advisors) {
    if (a.id == id) return a;
  }
  return null;
}
