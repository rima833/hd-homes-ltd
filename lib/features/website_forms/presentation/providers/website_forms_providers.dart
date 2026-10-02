import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/domain/services/website_forms_admin_service.dart';
import 'package:hdhomesproject/features/website_forms/domain/services/website_forms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final websiteFormsServiceProvider = Provider<WebsiteFormsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return WebsiteFormsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final websiteFormsAdminServiceProvider = Provider<WebsiteFormsAdminService>((
  ref,
) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return WebsiteFormsAdminService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

void _invalidatePublicForms(Ref ref) {
  ref.invalidate(websiteSupportSettingsProvider);
  ref.invalidate(websiteSupportTypesProvider);
  ref.invalidate(careerApplicationSettingsProvider);
  ref.invalidate(openCareerJobsProvider);
  ref.invalidate(partnershipSettingsProvider);
  ref.invalidate(partnershipTypesProvider);
}

void _invalidateAdminInbox(Ref ref) {
  ref.invalidate(adminWebsiteTicketsProvider);
  ref.invalidate(adminWebsiteTicketStatsProvider);
  ref.invalidate(adminCareerApplicationsProvider);
  ref.invalidate(adminCareerApplicationStatsProvider);
  ref.invalidate(adminPartnershipRequestsProvider);
  ref.invalidate(adminPartnershipStatsProvider);
}

final websiteFormsPublicRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('public-website-forms')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_support_settings',
      callback: (_) => _invalidatePublicForms(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_support_types',
      callback: (_) => _invalidatePublicForms(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'careers_settings',
      callback: (_) => _invalidatePublicForms(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'career_jobs',
      callback: (_) => _invalidatePublicForms(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'partnership_settings',
      callback: (_) => _invalidatePublicForms(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'partnership_types',
      callback: (_) => _invalidatePublicForms(ref),
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final websiteFormsAdminRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-website-forms')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tickets',
      callback: (_) => _invalidateAdminInbox(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'career_applications',
      callback: (_) => _invalidateAdminInbox(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'partnership_requests',
      callback: (_) => _invalidateAdminInbox(ref),
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final websiteSupportSettingsProvider =
    FutureProvider<WebsiteSupportSettings?>((ref) {
  ref.watch(websiteFormsPublicRealtimeProvider);
  return ref.read(websiteFormsServiceProvider).fetchSupportSettings();
});

final websiteSupportTypesProvider =
    FutureProvider<List<WebsiteFormOption>>((ref) {
  ref.watch(websiteFormsPublicRealtimeProvider);
  return ref.read(websiteFormsServiceProvider).fetchSupportTypes();
});

final careerApplicationSettingsProvider =
    FutureProvider<CareerApplicationSettings>((ref) {
  ref.watch(websiteFormsPublicRealtimeProvider);
  return ref.read(websiteFormsServiceProvider).fetchCareerApplicationSettings();
});

final openCareerJobsProvider = FutureProvider<List<CmsCareerJob>>((ref) {
  ref.watch(websiteFormsPublicRealtimeProvider);
  return ref.read(websiteFormsServiceProvider).fetchOpenJobs();
});

final partnershipSettingsProvider = FutureProvider<PartnershipSettings?>((ref) {
  ref.watch(websiteFormsPublicRealtimeProvider);
  return ref.read(websiteFormsServiceProvider).fetchPartnershipSettings();
});

final partnershipTypesProvider = FutureProvider<List<WebsiteFormOption>>((ref) {
  ref.watch(websiteFormsPublicRealtimeProvider);
  return ref.read(websiteFormsServiceProvider).fetchPartnershipTypes();
});

final adminWebsiteTicketsProvider =
    FutureProvider<List<WebsiteSupportTicketRow>>((ref) {
  ref.watch(websiteFormsAdminRealtimeProvider);
  return ref.read(websiteFormsAdminServiceProvider).listSupportTickets();
});

final adminWebsiteTicketStatsProvider =
    FutureProvider<WebsiteSupportStats>((ref) {
  ref.watch(websiteFormsAdminRealtimeProvider);
  return ref.read(websiteFormsAdminServiceProvider).fetchSupportStats();
});

final adminCareerApplicationsProvider =
    FutureProvider<List<CareerApplicationRow>>((ref) {
  ref.watch(websiteFormsAdminRealtimeProvider);
  return ref.read(websiteFormsAdminServiceProvider).listApplications();
});

final adminCareerApplicationStatsProvider =
    FutureProvider<CareerApplicationStats>((ref) async {
  ref.watch(websiteFormsAdminRealtimeProvider);
  final jobs = await ref.read(websiteFormsServiceProvider).fetchOpenJobs();
  return ref
      .read(websiteFormsAdminServiceProvider)
      .fetchApplicationStats(openPositions: jobs.length);
});

final adminPartnershipRequestsProvider =
    FutureProvider<List<PartnershipRequestRow>>((ref) {
  ref.watch(websiteFormsAdminRealtimeProvider);
  return ref.read(websiteFormsAdminServiceProvider).listPartnerships();
});

final adminPartnershipStatsProvider =
    FutureProvider<PartnershipRequestStats>((ref) {
  ref.watch(websiteFormsAdminRealtimeProvider);
  return ref.read(websiteFormsAdminServiceProvider).fetchPartnershipStats();
});

final adminSupportTypesAllProvider =
    FutureProvider<List<WebsiteFormOption>>((ref) {
  return ref
      .read(websiteFormsServiceProvider)
      .fetchSupportTypes(activeOnly: false);
});

final adminPartnershipTypesAllProvider =
    FutureProvider<List<WebsiteFormOption>>((ref) {
  return ref
      .read(websiteFormsServiceProvider)
      .fetchPartnershipTypes(activeOnly: false);
});
