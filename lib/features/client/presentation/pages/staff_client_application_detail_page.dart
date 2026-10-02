import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/pages/staff_client_applications_page.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

final staffClientApplicationDetailProvider =
    FutureProvider.family<StaffApplicationDetail, String>((ref, applicationId) async {
  ref.watch(staffApplicationsTickProvider);
  ref.watch(staffClientApplicationsRealtimeProvider);
  if (!ref.watch(supabaseConfiguredProvider)) {
    throw StateError('Live data is unavailable right now.');
  }
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('client_property_applications')
      .select('''
        id, status, payment_plan, amount_offered, notes, metadata,
        created_at, updated_at, client_id, property_id,
        properties (
          id, title, bedrooms, bathrooms, category_slug, listing_price,
          inventory_status, marketing_status, description,
          property_locations (address, city, state, country),
          property_pricing (price, currency)
        ),
        clients (
          id, client_code, user_id,
          profiles:user_id (
            first_name, last_name, preferred_name, email, phone,
            occupation, address, city, state
          )
        )
      ''')
      .eq('id', applicationId)
      .eq('is_deleted', false)
      .maybeSingle();
  if (row == null) {
    throw StateError('This application could not be found.');
  }
  final detail = StaffApplicationDetail.fromJson(Map<String, dynamic>.from(row));

  final documents = await _loadSection(
    () => client
        .from('client_documents')
        .select(
          'id, title, file_url, document_type, review_status, file_name, created_at',
        )
        .eq('application_id', applicationId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false),
  );
  final timeline = await _loadSection(
    () => client
        .from('client_timeline')
        .select('id, event_type, title, body, occurred_at')
        .eq('client_id', detail.clientId)
        .eq('is_deleted', false)
        .contains('metadata', {'application_id': applicationId})
        .order('occurred_at', ascending: false)
        .limit(50),
  );
  final payments = await _loadSection(
    () => client
        .from('client_payment_intents')
        .select('id, amount, status, created_at, property_id')
        .eq('client_id', detail.clientId)
        .order('created_at', ascending: false)
        .limit(40),
  );
  final inspections = detail.propertyId.isEmpty
      ? const _SectionResult(rows: [])
      : await _loadSection(
          () => client
              .from('property_inspections')
              .select(
                'id, status, inspection_type, scheduled_at, reference, property_id, visitor_profile_id',
              )
              .eq('property_id', detail.propertyId)
              .order('scheduled_at', ascending: false)
              .limit(30),
        );

  return detail.copyWith(
    documents: [
      for (final row in documents.rows)
        StaffApplicationDocument(
          title: row['title'] as String? ?? row['file_name'] as String? ?? 'Document',
          reviewStatus: row['review_status'] as String? ?? 'uploaded',
          type: row['document_type'] as String?,
          url: row['file_url'] as String?,
          createdAt: DateTime.tryParse('${row['created_at']}'),
        ),
    ],
    timeline: timeline.rows,
    payments: payments.rows
        .where((p) {
          final propertyId = p['property_id'] as String?;
          return propertyId == null || propertyId == detail.propertyId;
        })
        .toList(),
    inspections: [
      for (final row in inspections.rows)
        {
          ...row,
          'for_applicant':
              detail.clientUserId != null &&
              row['visitor_profile_id'] == detail.clientUserId,
        },
    ],
    sectionNotes: [
      if (documents.error != null) 'Documents: ${documents.error}',
      if (timeline.error != null) 'Activity: ${timeline.error}',
      if (payments.error != null) 'Payments: ${payments.error}',
      if (inspections.error != null) 'Inspections: ${inspections.error}',
    ],
  );
});

class StaffClientApplicationDetailPage extends ConsumerWidget {
  const StaffClientApplicationDetailPage({
    super.key,
    required this.applicationId,
  });

  final String applicationId;

  Future<void> _setStatus(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(supabaseClientProvider).from('client_property_applications').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', applicationId);
      ref.invalidate(staffClientApplicationDetailProvider(applicationId));
      ref.invalidate(staffClientApplicationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Status updated to ${ClientPropertyApplication.statusLabel(status)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(e, fallback: 'Could not update status. Please try again.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(staffClientApplicationsRealtimeProvider);
    final asyncDetail = ref.watch(staffClientApplicationDetailProvider(applicationId));
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: asyncDetail.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userFacingError(e, fallback: 'Could not load this application.')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(
                  staffClientApplicationDetailProvider(applicationId),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (detail) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to applications',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(RoutePaths.dashboardClientApplications);
                      }
                    },
                    icon: const Icon(LucideIcons.arrowLeft),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      detail.propertyTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(ClientPropertyApplication.statusLabel(detail.status)),
                    backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${detail.shortId} · changes from the client portal appear here as they happen.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.slate400,
                    ),
              ),
              if (detail.sectionNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...detail.sectionNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(note, style: const TextStyle(color: AppColors.warning)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _Section(
                title: 'Update status',
                rows: const [],
                child: DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: detail.status,
                  decoration: const InputDecoration(labelText: 'Application status'),
                  items: const [
                    'draft',
                    'submitted',
                    'under_review',
                    'documents_required',
                    'approved',
                    'payment_pending',
                    'payment_active',
                    'contract_pending',
                    'completed',
                    'rejected',
                    'cancelled',
                  ]
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(ClientPropertyApplication.statusLabel(status)),
                        ),
                      )
                      .toList(),
                  onChanged: (status) {
                    if (status != null && status != detail.status) {
                      _setStatus(context, ref, status);
                    }
                  },
                ),
              ),
              _Section(
                title: 'Client',
                rows: [
                  _Row('Name', detail.clientName ?? '—'),
                  _Row('Email', detail.clientEmail ?? '—'),
                  _Row('Phone', detail.clientPhone ?? '—'),
                  _Row('Occupation', detail.occupation ?? '—'),
                  _Row('Client code', detail.clientCode ?? '—'),
                  _Row('Address', detail.clientAddress ?? '—'),
                ],
              ),
              _Section(
                title: 'Application',
                rows: [
                  _Row('Application ID', detail.shortId),
                  _Row('Record ID', detail.id),
                  _Row('Status', ClientPropertyApplication.statusLabel(detail.status)),
                  _Row('Payment plan', detail.paymentPlanLabel),
                  _Row(
                    'Amount offered',
                    detail.amountOffered == null ? '—' : fmt.format(detail.amountOffered),
                  ),
                  _Row('Notes', detail.notes?.trim().isNotEmpty == true ? detail.notes! : '—'),
                  _Row('Submitted', _when(detail.createdAt)),
                  _Row('Last updated', _when(detail.updatedAt)),
                  for (final entry in detail.metadata.entries)
                    _Row(_labelize(entry.key), '${entry.value}'),
                ],
              ),
              _Section(
                title: 'Property',
                rows: [
                  _Row('Title', detail.propertyTitle),
                  _Row('Location', detail.location ?? '—'),
                  _Row('Type', detail.propertyType ?? '—'),
                  _Row('Bedrooms', detail.bedrooms?.toString() ?? '—'),
                  _Row('Bathrooms', detail.bathrooms?.toString() ?? '—'),
                  _Row(
                    'Listed price',
                    detail.listingPrice == null ? '—' : fmt.format(detail.listingPrice),
                  ),
                  _Row('Inventory', detail.inventoryStatus ?? '—'),
                  _Row('Marketing', detail.marketingStatus ?? '—'),
                  _Row(
                    'Description',
                    detail.description?.trim().isNotEmpty == true
                        ? detail.description!
                        : '—',
                  ),
                ],
              ),
              _ListSection(
                title: 'Documents',
                empty: 'No documents have been uploaded for this application.',
                children: [
                  for (final doc in detail.documents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.fileText, size: 18),
                      title: Text(doc.title),
                      subtitle: Text(
                        [
                          if (doc.type != null) doc.type!.replaceAll('_', ' '),
                          doc.reviewStatus.replaceAll('_', ' '),
                          if (doc.createdAt != null) _when(doc.createdAt),
                        ].join(' · '),
                      ),
                      trailing: doc.url == null
                          ? null
                          : IconButton(
                              tooltip: 'Open document',
                              onPressed: () => _openUrl(context, ref, doc.url!),
                              icon: const Icon(LucideIcons.externalLink, size: 16),
                            ),
                    ),
                ],
              ),
              _ListSection(
                title: 'Payments',
                empty: 'No payment intents are linked to this client and property yet.',
                children: [
                  for (final payment in detail.payments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(fmt.format((payment['amount'] as num?)?.toDouble() ?? 0)),
                      subtitle: Text(
                        [
                          '${payment['status'] ?? 'pending'}'.replaceAll('_', ' '),
                          _when(
                            payment['created_at'] == null
                                ? null
                                : DateTime.tryParse('${payment['created_at']}'),
                          ),
                        ].join(' · '),
                      ),
                    ),
                ],
              ),
              _ListSection(
                title: 'Inspections',
                empty: 'No inspections are booked on this property.',
                children: [
                  for (final visit in detail.inspections)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${visit['inspection_type'] ?? 'Inspection'}'.toString().replaceAll('_', ' '),
                      ),
                      subtitle: Text(
                        [
                          visit['for_applicant'] == true ? 'This applicant' : 'Other visitor',
                          '${visit['status'] ?? ''}'.replaceAll('_', ' '),
                          if (visit['reference'] != null) '${visit['reference']}',
                          _when(
                            visit['scheduled_at'] == null
                                ? null
                                : DateTime.tryParse('${visit['scheduled_at']}'),
                          ),
                        ].where((part) => part.trim().isNotEmpty).join(' · '),
                      ),
                    ),
                ],
              ),
              _ListSection(
                title: 'Activity',
                empty: 'No activity has been recorded for this application yet.',
                children: [
                  for (final event in detail.timeline)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${event['title'] ?? 'Update'}'),
                      subtitle: Text(
                        [
                          if (event['body'] != null && '${event['body']}'.trim().isNotEmpty)
                            '${event['body']}',
                          _when(
                            event['occurred_at'] == null
                                ? null
                                : DateTime.tryParse('${event['occurred_at']}'),
                          ),
                        ].join('\n'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class StaffApplicationDetail {
  const StaffApplicationDetail({
    required this.id,
    required this.status,
    required this.propertyTitle,
    required this.propertyId,
    required this.clientId,
    this.clientUserId,
    this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.clientCode,
    this.occupation,
    this.clientAddress,
    this.location,
    this.propertyType,
    this.bedrooms,
    this.bathrooms,
    this.listingPrice,
    this.inventoryStatus,
    this.marketingStatus,
    this.description,
    this.paymentPlan,
    this.amountOffered,
    this.notes,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
    this.documents = const [],
    this.timeline = const [],
    this.payments = const [],
    this.inspections = const [],
    this.sectionNotes = const [],
  });

  factory StaffApplicationDetail.fromJson(Map<String, dynamic> json) {
    final property = _map(json['properties']);
    final loc = _firstMap(property['property_locations']);
    final price = _firstMap(property['property_pricing']);
    final client = _map(json['clients']);
    final profile = _map(client['profiles']);
    final preferred = (profile['preferred_name'] as String?)?.trim();
    final composed = [
      profile['first_name'],
      profile['last_name'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    final metaRaw = json['metadata'];
    final metadata = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : const <String, dynamic>{};

    return StaffApplicationDetail(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'submitted',
      clientId: json['client_id'] as String? ?? '',
      clientUserId: client['user_id'] as String?,
      propertyId: json['property_id'] as String? ?? '',
      propertyTitle: property['title'] as String? ?? 'Property',
      clientName: (preferred != null && preferred.isNotEmpty)
          ? preferred
          : (composed.isEmpty ? null : composed),
      clientEmail: profile['email'] as String?,
      clientPhone: profile['phone'] as String?,
      clientCode: client['client_code'] as String?,
      occupation: profile['occupation'] as String?,
      clientAddress: [
        profile['address'],
        profile['city'],
        profile['state'],
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', '),
      location: [
        loc?['address'],
        loc?['city'],
        loc?['state'],
        loc?['country'],
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', '),
      propertyType: property['category_slug'] as String?,
      bedrooms: (property['bedrooms'] as num?)?.toInt(),
      bathrooms: (property['bathrooms'] as num?)?.toInt(),
      listingPrice: (price?['price'] as num?)?.toDouble() ??
          (property['listing_price'] as num?)?.toDouble(),
      inventoryStatus: property['inventory_status'] as String?,
      marketingStatus: property['marketing_status'] as String?,
      description: property['description'] as String?,
      paymentPlan: json['payment_plan'] as String?,
      amountOffered: (json['amount_offered'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      metadata: metadata,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      updatedAt: DateTime.tryParse('${json['updated_at']}'),
    );
  }

  final String id;
  final String status;
  final String propertyTitle;
  final String propertyId;
  final String clientId;
  final String? clientUserId;
  final String? clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? clientCode;
  final String? occupation;
  final String? clientAddress;
  final String? location;
  final String? propertyType;
  final int? bedrooms;
  final int? bathrooms;
  final double? listingPrice;
  final String? inventoryStatus;
  final String? marketingStatus;
  final String? description;
  final String? paymentPlan;
  final double? amountOffered;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<StaffApplicationDocument> documents;
  final List<Map<String, dynamic>> timeline;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> inspections;
  final List<String> sectionNotes;

  String get shortId {
    final raw = id.replaceAll('-', '').toUpperCase();
    return 'APP-${raw.substring(0, 8)}';
  }

  String get paymentPlanLabel =>
      (paymentPlan ?? '—').replaceAll('_', ' ');

  StaffApplicationDetail copyWith({
    List<StaffApplicationDocument>? documents,
    List<Map<String, dynamic>>? timeline,
    List<Map<String, dynamic>>? payments,
    List<Map<String, dynamic>>? inspections,
    List<String>? sectionNotes,
  }) {
    return StaffApplicationDetail(
      id: id,
      status: status,
      propertyTitle: propertyTitle,
      propertyId: propertyId,
      clientId: clientId,
      clientUserId: clientUserId,
      clientName: clientName,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
      clientCode: clientCode,
      occupation: occupation,
      clientAddress: clientAddress,
      location: location,
      propertyType: propertyType,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      listingPrice: listingPrice,
      inventoryStatus: inventoryStatus,
      marketingStatus: marketingStatus,
      description: description,
      paymentPlan: paymentPlan,
      amountOffered: amountOffered,
      notes: notes,
      metadata: metadata,
      createdAt: createdAt,
      updatedAt: updatedAt,
      documents: documents ?? this.documents,
      timeline: timeline ?? this.timeline,
      payments: payments ?? this.payments,
      inspections: inspections ?? this.inspections,
      sectionNotes: sectionNotes ?? this.sectionNotes,
    );
  }
}

class StaffApplicationDocument {
  const StaffApplicationDocument({
    required this.title,
    required this.reviewStatus,
    this.type,
    this.url,
    this.createdAt,
  });

  final String title;
  final String reviewStatus;
  final String? type;
  final String? url;
  final DateTime? createdAt;
}

class _SectionResult {
  const _SectionResult({required this.rows, this.error});
  final List<Map<String, dynamic>> rows;
  final String? error;
}

Future<_SectionResult> _loadSection(Future<dynamic> Function() load) async {
  try {
    final raw = await load();
    if (raw is! List) return const _SectionResult(rows: []);
    return _SectionResult(
      rows: raw.map((row) => Map<String, dynamic>.from(row as Map)).toList(),
    );
  } catch (e) {
    return _SectionResult(rows: const [], error: userFacingError(e));
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

Map<String, dynamic>? _firstMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}

String _when(DateTime? value) {
  if (value == null) return '—';
  return DateFormat.yMMMd().add_jm().format(value.toLocal());
}

String _labelize(String key) => key.replaceAll('_', ' ');

Future<void> _openUrl(BuildContext context, WidgetRef ref, String raw) async {
  try {
    final value = raw.trim();
    final parsed = Uri.tryParse(value);
    final uri = parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')
        ? parsed
        : Uri.parse(
            await _signedUrl(ref, value),
          );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(userFacingError(e, fallback: 'Could not open the document.'))),
    );
  }
}

Future<String> _signedUrl(WidgetRef ref, String value) async {
  final slash = value.indexOf('/');
  if (slash <= 0) throw StateError('Document link is not available.');
  final bucket = value.startsWith('storage://')
      ? value.substring('storage://'.length).split('/').first
      : value.substring(0, slash);
  final path = value.startsWith('storage://')
      ? value.substring('storage://'.length + bucket.length + 1)
      : value.substring(slash + 1);
  return ref.read(supabaseClientProvider).storage.from(bucket).createSignedUrl(path, 120);
}

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.child});

  final String title;
  final List<_Row> rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                    ),
                    Expanded(child: Text(row.value)),
                  ],
                ),
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (children.isEmpty)
              Text(
                empty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate400,
                    ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
