import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/contact/domain/entities/office_directory_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Published office directory with hours + media from Supabase.
final officeDirectoryProvider =
    FutureProvider<List<OfficeDirectoryEntry>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) {
    return _fallbackFromContact(ref.watch(contactHubCmsProvider).offices);
  }

  final service = ref.watch(cmsServiceProvider);
  final locations = await service.listPublishedOfficeLocations(limit: 48);
  if (locations.isEmpty) {
    return _fallbackFromContact(ref.watch(contactHubCmsProvider).offices);
  }

  final allHours = await service.listPublishedOfficeHours();
  final allMedia = await service.listPublishedOfficeMedia();

  return [
    for (final loc in locations)
      OfficeDirectoryEntry(
        location: loc,
        hours: allHours.where((h) => h.officeId == loc.id).toList(),
        media: allMedia.where((m) => m.officeId == loc.id).toList(),
      ),
  ];
});

/// Admin office directory (includes draft).
final adminOfficeDirectoryProvider =
    FutureProvider<List<OfficeDirectoryEntry>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  final service = ref.watch(cmsServiceProvider);
  final locations = await service.listOfficeLocations();
  final entries = <OfficeDirectoryEntry>[];
  for (final loc in locations) {
    final hours = await service.listOfficeHours(loc.id);
    final media = await service.listOfficeMedia(loc.id);
    entries.add(OfficeDirectoryEntry(location: loc, hours: hours, media: media));
  }
  return entries;
});

final officeDirectoryRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;

  void invalidateAll() {
    ref.invalidate(officeDirectoryProvider);
    ref.invalidate(adminOfficeDirectoryProvider);
    ref.invalidate(cmsOfficeLocationsProvider);
    ref.invalidate(publishedOfficeLocationsProvider);
  }

  final channel = client.channel('public:office-directory')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'office_locations',
      callback: (_) => invalidateAll(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'office_hours',
      callback: (_) => invalidateAll(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'office_media',
      callback: (_) => invalidateAll(),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

List<OfficeDirectoryEntry> _fallbackFromContact(List<OfficeLocation> offices) {
  return offices.map((o) {
    final loc = CmsOfficeLocation(
      id: o.id,
      name: o.name,
      slug: o.id,
      officeType: _typeLabel(o.type),
      address: o.address,
      city: o.city,
      phone: o.phone,
      email: o.email,
      hours: o.hours,
      latitude: o.lat,
      longitude: o.lng,
      parkingInfo: o.parkingInfo,
      nearbyLandmarks: o.landmarks,
      isFeatured: o.id == 'hq',
      appointmentPath: '/book-consultation',
    );
    return OfficeDirectoryEntry(location: loc, hours: _defaultHours(o.id));
  }).toList();
}

String _typeLabel(OfficeType type) => switch (type) {
      OfficeType.headOffice => 'Head Office',
      OfficeType.regional => 'Regional Office',
      OfficeType.salesCenter => 'Sales Centre',
      OfficeType.construction => 'Construction Site',
    };

List<OfficeHourEntry> _defaultHours(String officeId) {
  return [
    for (var d = 0; d < 7; d++)
      OfficeHourEntry(
        id: '$officeId-$d',
        officeId: officeId,
        dayOfWeek: d,
        isOpen: d < 6,
        openTime: d == 5 ? '09:00' : '08:00',
        closeTime: d == 5 ? '17:00' : '18:00',
      ),
  ];
}

/// Selected office for booking prefill.
final selectedOfficeForBookingProvider =
    StateProvider<OfficeDirectoryEntry?>((ref) => null);
