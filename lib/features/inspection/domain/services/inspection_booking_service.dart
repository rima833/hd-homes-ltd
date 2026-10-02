import 'dart:convert';
import 'dart:typed_data';

import 'package:hdhomesproject/core/media/media_service.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_booking_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InspectionBookingLiveStatus {
  const InspectionBookingLiveStatus({
    required this.status,
    this.reference,
    this.meetingUrl,
    this.updatedAt,
  });

  final String status;
  final String? reference;
  final String? meetingUrl;
  final DateTime? updatedAt;
}

class InspectionBookingService {
  InspectionBookingService({SupabaseClient? client, MediaService? mediaService})
    : _client = client,
      _media = mediaService;

  final SupabaseClient? _client;
  final MediaService? _media;

  Map<String, dynamic>? _coerceMap(dynamic row) {
    if (row == null) return null;

    if (row is Map<String, dynamic>) return row;

    if (row is Map) return Map<String, dynamic>.from(row);

    if (row is List && row.isNotEmpty) return _coerceMap(row.first);

    if (row is String) {
      try {
        return _coerceMap(jsonDecode(row));
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _coerceList(dynamic row) {
    if (row == null) return const [];

    if (row is List) {
      return row.map(_coerceMap).whereType<Map<String, dynamic>>().toList();
    }

    if (row is String) {
      try {
        return _coerceList(jsonDecode(row));
      } catch (_) {
        return const [];
      }
    }

    final single = _coerceMap(row);

    return single == null ? const [] : [single];
  }

  Future<Set<String>> fetchDisabledPropertyIds() async {
    final client = _client;

    if (client == null) return {};

    try {
      final rows = await client
          .from('property_inspection_config')
          .select('property_id')
          .eq('inspection_enabled', false);

      return (rows as List).map((e) => '${(e as Map)['property_id']}').toSet();
    } catch (_) {
      return {};
    }
  }

  Future<List<InspectionAdvisor>> fetchAdvisors() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }

    try {
      // Prefer admin-configured inspection agents (respects available/unavailable).
      final allAgents = await client
          .from('inspection_agents')
          .select('advisor_id, is_active, consultation_advisors(*)');

      final agentList = allAgents as List;
      if (agentList.isNotEmpty) {
        final out = <InspectionAdvisor>[];
        for (final row in agentList) {
          final map = Map<String, dynamic>.from(row as Map);
          if (map['is_active'] != true) continue;
          final advisorRaw = map['consultation_advisors'];
          if (advisorRaw is Map) {
            final advisor = InspectionAdvisor.fromJson(
              Map<String, dynamic>.from(advisorRaw),
            );
            if (advisor.name.isNotEmpty) out.add(advisor);
          }
        }
        // If agents are configured, never fall back to every advisor —
        // unavailable agents must stay hidden on public booking.
        return out;
      }

      final rows = await client
          .from('consultation_advisors')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final list = (rows as List)
          .map(
            (e) =>
                InspectionAdvisor.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where((a) => a.name.isNotEmpty)
          .toList();

      return list;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<List<InspectionSlot>> fetchSlots({
    required String propertyId,

    String? estateId,

    String? advisorId,

    DateTime? from,

    int days = 21,
  }) async {
    final client = _client;

    if (client == null) return const [];

    try {
      final row = await client.rpc(
        'get_inspection_slots',

        params: {
          'p_from': (from ?? DateTime.now()).toIso8601String().split('T').first,

          'p_days': days,

          'p_property_id': propertyId,

          'p_estate_id': estateId,

          'p_advisor_id': advisorId,
        },
      );

      return _coerceList(
        row,
      ).map(InspectionSlot.fromJson).where((s) => s.available).toList();
    } catch (e, st) {
      // Surface to the UI instead of silently returning empty slots.

      Error.throwWithStackTrace(e, st);
    }
  }

  Future<String> uploadDocument({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    final isMedia =
        contentType.startsWith('image/') || contentType.startsWith('video/');
    final media = _media;
    if (isMedia && media != null && media.isCloudinaryEnabled) {
      return media.uploadPublicWebsiteMedia(
        bytes: bytes,
        contentType: contentType,
        originalFilename: filename,
        folder: 'hdhomes/inspections/public/evidence',
      );
    }

    // Non-media documents (PDF etc.) remain on private/public Storage.
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        'public-inspections/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await client.storage
        .from('marketing')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from('marketing').getPublicUrl(path);
  }

  Future<InspectionBookingResult> submit(
    InspectionBookingDraft draft, {

    String? visitorProfileId,
  }) async {
    final client = _client;

    if (client == null) throw StateError('Supabase is not configured');

    final scheduled =
        draft.scheduledAt ??
        (draft.preferredDate != null
            ? DateTime(
                draft.preferredDate!.year,

                draft.preferredDate!.month,

                draft.preferredDate!.day,

                draft.preferredTime?.hour ?? 10,

                draft.preferredTime?.minute ?? 0,
              )
            : null);

    if (scheduled == null) {
      throw StateError('Please choose a date and time');
    }

    try {
      final meetupLine = switch (draft.meetingType) {
        InspectionMeetingType.virtual => 'Meetup: Virtual tour',
        InspectionMeetingType.physical => switch (draft.meetupMode) {
          InspectionMeetupMode.meetAtProperty =>
            'Meetup: Meet at property site',
          InspectionMeetupMode.meetAtOffice =>
            'Meetup: Visit office — ${draft.meetupOfficeLabel ?? draft.meetupOfficeId ?? 'HD Homes office'}',
          InspectionMeetupMode.pickup =>
            'Meetup: Pickup at ${draft.pickupAddress.trim()}',
        },
      };
      final locationPayload = switch (draft.meetingType) {
        InspectionMeetingType.virtual => draft.location,
        InspectionMeetingType.physical => switch (draft.meetupMode) {
          InspectionMeetupMode.pickup => draft.pickupAddress.trim(),
          InspectionMeetupMode.meetAtOffice =>
            draft.meetupOfficeLabel ?? draft.location,
          InspectionMeetupMode.meetAtProperty =>
            draft.location ?? 'Property site',
        },
      };
      final notesParts = <String>[
        if (draft.notes.trim().isNotEmpty) draft.notes.trim(),
        meetupLine,
      ];

      final row = await client.rpc(
        'book_public_inspection',

        params: {
          'p_full_name': draft.fullName.trim(),

          'p_phone': draft.phone.trim(),

          'p_email': draft.email.trim(),

          'p_property_id': draft.propertyId,

          'p_estate_id': draft.estateId,

          'p_scheduled_at': scheduled.toUtc().toIso8601String(),

          'p_meeting_type': draft.meetingType == InspectionMeetingType.virtual
              ? 'virtual_tour'
              : 'site_visit',

          'p_advisor_name': null,

          'p_notes': notesParts.join('\n'),

          'p_budget': draft.budget,

          'p_timeline': draft.timeline,

          'p_financing': draft.financing,

          'p_location': locationPayload,

          'p_property_type': draft.propertyType,

          'p_purpose': draft.purpose.name,

          'p_investment_interest':
              draft.investmentInterest ||
              draft.purpose != InspectionPurpose.residence,

          'p_document_urls': draft.documentUrls,

          'p_advisor_id': draft.advisorId,

          'p_preferred_language': draft.preferredLanguage,

          'p_visitor_profile_id': visitorProfileId,
        },
      );

      final map = _coerceMap(row);

      if (map == null || map['reference'] == null) {
        throw StateError('Booking failed — please try again');
      }

      final meetingRaw = '${map['meeting_type'] ?? ''}';

      return InspectionBookingResult(
        reference: '${map['reference']}',

        inspectionId: map['inspection_id']?.toString(),

        leadId: map['lead_id']?.toString(),

        scheduledAt: map['scheduled_at'] != null
            ? DateTime.parse('${map['scheduled_at']}').toLocal()
            : scheduled,

        advisorName: map['advisor_name']?.toString(),

        meetingType: meetingRaw.contains('virtual')
            ? InspectionMeetingType.virtual
            : InspectionMeetingType.physical,
      );
    } on PostgrestException catch (e) {
      final msg = e.message;

      if (msg.contains('slot_unavailable')) {
        throw StateError(
          'This inspection slot was just booked. Please select another available time.',
        );
      }

      throw StateError('We couldn\'t complete your booking. Please try again.');
    }
  }

  Future<Map<String, dynamic>?> fetchBookingStatus(String inspectionId) async {
    final client = _client;
    if (client == null || inspectionId.isEmpty) return null;
    try {
      final row = await client
          .from('property_inspections')
          .select('status, reference, scheduled_at, meeting_url, updated_at')
          .eq('id', inspectionId)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (_) {
      // In public/anon contexts this can be blocked by RLS.
      return null;
    }
  }
}
