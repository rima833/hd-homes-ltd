import 'dart:convert';
import 'dart:typed_data';

import 'package:hdhomesproject/core/media/media_service.dart';
import 'package:hdhomesproject/features/consultation/domain/entities/consultation_booking_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsultationBookingService {
  ConsultationBookingService({
    SupabaseClient? client,
    MediaService? mediaService,
  }) : _client = client,
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

  Future<List<ConsultationDepartment>> fetchDepartments() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    try {
      final rows = await client
          .from('consultation_departments')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      final list = (rows as List)
          .map(
            (e) => ConsultationDepartment.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      return list;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<List<ConsultationAdvisor>> fetchAdvisors({
    String? departmentId,
  }) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final filter = departmentId != null && departmentId.isNotEmpty
          ? client
                .from('consultation_advisors')
                .select()
                .eq('is_active', true)
                .eq('department_id', departmentId)
          : client.from('consultation_advisors').select().eq('is_active', true);
      final rows = await filter.order('sort_order');
      return (rows as List)
          .map(
            (e) => ConsultationAdvisor.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ConsultationSlot>> fetchSlots({
    String? departmentId,
    int days = 21,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    try {
      final row = await client.rpc(
        'get_consultation_slots',
        params: {
          'p_from': DateTime.now().toIso8601String().split('T').first,
          'p_days': days,
          'p_department_id': departmentId,
        },
      );
      final list = _coerceList(row).map(ConsultationSlot.fromJson).toList();
      return list;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
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
        folder: 'hdhomes/general/website/consultations',
      );
    }

    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        'public-consultations/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await client.storage
        .from('marketing')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from('marketing').getPublicUrl(path);
  }

  Future<ConsultationBookingResult> submit(
    ConsultationBookingDraft draft,
  ) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    final method = switch (draft.meetingMethod) {
      ConsultationMeetingMethod.phone => 'phone',
      ConsultationMeetingMethod.video => 'video',
      ConsultationMeetingMethod.office => 'office',
    };

    final row = await client.rpc(
      'book_public_consultation',
      params: {
        'p_full_name': draft.fullName.trim(),
        'p_phone': draft.phone.trim(),
        'p_email': draft.email.trim(),
        'p_company': draft.company.trim().isEmpty ? null : draft.company.trim(),
        'p_department_slug': draft.departmentSlug,
        'p_meeting_method': method,
        'p_scheduled_at': draft.selectedSlot?.scheduledAt
            .toUtc()
            .toIso8601String(),
        'p_advisor_id': draft.advisorId,
        'p_purpose': draft.purpose,
        'p_budget': draft.budget,
        'p_property_reference': draft.propertyReference,
        'p_preferred_estate': draft.preferredEstate,
        'p_timeline': draft.timeline,
        'p_investment_interest': draft.investmentInterest,
        'p_notes': draft.notes.trim().isEmpty ? null : draft.notes.trim(),
        'p_document_urls': draft.documentUrls,
        'p_timezone': 'Africa/Lagos',
        // Always send so PostgREST can resolve the office-aware overload.
        'p_office_location_id': draft.officeLocationId,
      },
    );

    final map = _coerceMap(row);
    if (map == null || map['reference'] == null) {
      throw StateError('Booking failed — please try again');
    }
    return ConsultationBookingResult(
      reference: '${map['reference']}',
      bookingId: map['booking_id']?.toString(),
      leadId: map['lead_id']?.toString(),
      advisorName: map['advisor_name']?.toString(),
    );
  }
}
