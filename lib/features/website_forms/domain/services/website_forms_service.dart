import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebsiteFormsService {
  WebsiteFormsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static const bucket = 'website-private';

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

  StateError _friendly(Object e) {
    if (e is StateError) return e;
    final msg = e is PostgrestException ? e.message : '$e';
    if (msg.contains('support_disabled')) {
      return StateError(
        'Support submissions are temporarily unavailable. Please try again later.',
      );
    }
    if (msg.contains('careers_disabled')) {
      return StateError(
        'Career applications are temporarily closed. Please check back soon.',
      );
    }
    if (msg.contains('partnerships_disabled')) {
      return StateError(
        'Partnership requests are temporarily unavailable. Please try again later.',
      );
    }
    if (msg.contains('Socket') ||
        msg.contains('network') ||
        msg.contains('Failed host')) {
      return StateError(
        'We could not complete your submission because of a network problem. Please try again.',
      );
    }
    return StateError(
      'We couldn\'t complete your submission. Please check your details and try again.',
    );
  }

  Future<WebsiteSupportSettings?> fetchSupportSettings() async {
    final client = _client;
    if (client == null) return const WebsiteSupportSettings(id: 'local');
    final row = await client
        .from('website_support_settings')
        .select()
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return const WebsiteSupportSettings(id: 'local');
    return WebsiteSupportSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<WebsiteFormOption>> fetchSupportTypes({
    bool activeOnly = true,
  }) async {
    final client = _client;
    if (client == null) {
      return const [
        WebsiteFormOption(id: 'complaint', name: 'Complaint', slug: 'complaint'),
        WebsiteFormOption(id: 'feedback', name: 'Feedback', slug: 'feedback'),
        WebsiteFormOption(
          id: 'suggestion',
          name: 'Suggestion',
          slug: 'suggestion',
        ),
        WebsiteFormOption(
          id: 'technical-issue',
          name: 'Technical Issue',
          slug: 'technical-issue',
        ),
        WebsiteFormOption(id: 'other', name: 'Other', slug: 'other'),
      ];
    }
    var query = client.from('website_support_types').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('sort_order');
    return (rows as List)
        .map(
          (e) => WebsiteFormOption.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<CareerApplicationSettings> fetchCareerApplicationSettings() async {
    final client = _client;
    if (client == null) return const CareerApplicationSettings();
    final row = await client
        .from('careers_settings')
        .select()
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return const CareerApplicationSettings();
    return CareerApplicationSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<CmsCareerJob>> fetchOpenJobs() async {
    final client = _client;
    if (client == null) return const [];
    final rows = await client
        .from('career_jobs')
        .select()
        .eq('is_deleted', false)
        .eq('status', 'active')
        .order('sort_order');
    return (rows as List)
        .map((e) => CmsCareerJob.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PartnershipSettings?> fetchPartnershipSettings() async {
    final client = _client;
    if (client == null) {
      return const PartnershipSettings(id: 'local');
    }
    final row = await client
        .from('partnership_settings')
        .select()
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return const PartnershipSettings(id: 'local');
    return PartnershipSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<WebsiteFormOption>> fetchPartnershipTypes({
    bool activeOnly = true,
  }) async {
    final client = _client;
    if (client == null) {
      return const [
        WebsiteFormOption(
          id: 'joint-venture',
          name: 'Joint Venture',
          slug: 'joint-venture',
        ),
        WebsiteFormOption(
          id: 'development',
          name: 'Development Partnership',
          slug: 'development',
        ),
        WebsiteFormOption(id: 'other', name: 'Other', slug: 'other'),
      ];
    }
    var query = client.from('partnership_types').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('sort_order');
    return (rows as List)
        .map(
          (e) => WebsiteFormOption.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  String _inboxId() {
    final n = Random().nextInt(0x7fffffff);
    return '${DateTime.now().microsecondsSinceEpoch}-$n';
  }

  String mimeForExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
  }

  Future<String> uploadPrivateFile({
    required String folder,
    required WebsitePickedFile file,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('File upload is unavailable right now. Please try again.');
    }
    final safeName = file.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$folder/inbox/${_inboxId()}/$safeName';
    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            Uint8List.fromList(file.bytes),
            fileOptions: FileOptions(
              contentType: file.mimeType ?? mimeForExtension(file.extension),
              upsert: false,
            ),
          );
      return path;
    } catch (_) {
      throw StateError(
        'We couldn\'t upload your file. Please try again with a PDF, DOC, or DOCX under the size limit.',
      );
    }
  }

  Future<WebsiteFormSubmitResult> submitSupportTicket({
    required String fullName,
    required String email,
    required String typeId,
    required String details,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError(
        'We could not complete your submission. Please try again shortly.',
      );
    }
    try {
      final row = await client.rpc(
        'submit_website_support_ticket',
        params: {
          'p_full_name': fullName.trim(),
          'p_email': email.trim(),
          'p_type_id': typeId,
          'p_details': details.trim(),
          'p_source': 'public_web',
        },
      );
      final map = _coerceMap(row);
      if (map == null || map['reference'] == null) {
        throw StateError(
          'We couldn\'t complete your submission. Please try again.',
        );
      }
      return WebsiteFormSubmitResult(
        id: map['id']?.toString(),
        reference: '${map['reference']}',
        title: map['confirmation_title']?.toString() ?? 'Ticket submitted',
        message:
            map['confirmation_message']?.toString() ??
            'Thank you. Our support team will get back to you shortly.',
      );
    } catch (e) {
      throw _friendly(e);
    }
  }

  Future<WebsiteFormSubmitResult> submitCareerApplication({
    required String fullName,
    required String email,
    String? phone,
    String? jobId,
    String? preferredLocation,
    String? linkedinUrl,
    String? coverLetter,
    WebsitePickedFile? cv,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError(
        'We could not complete your submission. Please try again shortly.',
      );
    }
    try {
      String? cvPath;
      if (cv != null) {
        cvPath = await uploadPrivateFile(folder: 'careers', file: cv);
      }
      final row = await client.rpc(
        'submit_career_application',
        params: {
          'p_full_name': fullName.trim(),
          'p_email': email.trim(),
          'p_phone': phone?.trim(),
          'p_job_id': jobId,
          'p_preferred_location': preferredLocation?.trim(),
          'p_linkedin_url': linkedinUrl?.trim(),
          'p_cover_letter': coverLetter?.trim(),
          'p_cv_path': cvPath,
          'p_cv_file_name': cv?.fileName,
          'p_cv_mime': cv == null
              ? null
              : (cv.mimeType ?? mimeForExtension(cv.extension)),
          'p_cv_size': cv?.size,
          'p_source': 'public_web',
        },
      );
      final map = _coerceMap(row);
      if (map == null || map['reference'] == null) {
        throw StateError(
          'We couldn\'t complete your application. Please try again.',
        );
      }
      return WebsiteFormSubmitResult(
        id: map['id']?.toString(),
        reference: '${map['reference']}',
        title: map['confirmation_title']?.toString() ?? 'Application received',
        message:
            map['confirmation_message']?.toString() ??
            'Thank you for applying.',
      );
    } catch (e) {
      throw _friendly(e);
    }
  }

  Future<WebsiteFormSubmitResult> submitPartnershipRequest({
    required String companyName,
    required String contactPerson,
    required String email,
    required String phone,
    required String typeId,
    String? proposal,
    List<WebsitePickedFile> documents = const [],
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError(
        'We could not complete your submission. Please try again shortly.',
      );
    }
    try {
      final uploaded = <Map<String, dynamic>>[];
      for (final file in documents) {
        final path = await uploadPrivateFile(
          folder: 'partnerships',
          file: file,
        );
        uploaded.add({
          'path': path,
          'name': file.fileName,
          'mime': file.mimeType ?? mimeForExtension(file.extension),
          'size': file.size,
        });
      }
      final row = await client.rpc(
        'submit_partnership_request',
        params: {
          'p_company_name': companyName.trim(),
          'p_contact_person': contactPerson.trim(),
          'p_email': email.trim(),
          'p_phone': phone.trim(),
          'p_type_id': typeId,
          'p_proposal': proposal?.trim(),
          'p_documents': uploaded,
          'p_source': 'public_web',
        },
      );
      final map = _coerceMap(row);
      if (map == null || map['reference'] == null) {
        throw StateError(
          'We couldn\'t complete your request. Please try again.',
        );
      }
      return WebsiteFormSubmitResult(
        id: map['id']?.toString(),
        reference: '${map['reference']}',
        title:
            map['confirmation_title']?.toString() ??
            'Partnership request received',
        message:
            map['confirmation_message']?.toString() ??
            'Our partnerships team will be in touch.',
      );
    } catch (e) {
      throw _friendly(e);
    }
  }
}
