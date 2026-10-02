import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bumped when application, document, payment, or inspection rows change.
final staffApplicationsTickProvider = StateProvider<int>((ref) => 0);

/// Live updates for the staff applications desk. Does not wait on the sales
/// command center snapshot.
final staffClientApplicationsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  Timer? debounce;

  void refresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      deferProviderMutation(() {
        try {
          ref.read(staffApplicationsTickProvider.notifier).state++;
        } catch (_) {}
      });
    });
  }

  RealtimeChannel listen(String table) {
    return client.channel('staff-applications-$table')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => refresh(),
      )
      ..subscribe();
  }

  final channels = [
    listen('client_property_applications'),
    listen('client_documents'),
    listen('client_timeline'),
    listen('client_payment_intents'),
    listen('property_inspections'),
  ];

  ref.onDispose(() {
    debounce?.cancel();
    for (final channel in channels) {
      unawaited(client.removeChannel(channel));
    }
  });
});

const _applicationSelect = '''
  id, status, payment_plan, amount_offered, notes, created_at, updated_at,
  client_id, property_id,
  properties (id, title, listing_price, property_locations (city, state)),
  clients (
    id, client_code, user_id,
    profiles:user_id (first_name, last_name, preferred_name, email, phone)
  )
''';

/// Staff workspace for reviewing `client_property_applications`.
/// Shares the same Supabase table as the Client Portal (no duplicate data).
final staffClientApplicationsProvider =
    FutureProvider<List<_StaffApplicationRow>>((ref) async {
  ref.watch(staffApplicationsTickProvider);
  ref.watch(staffClientApplicationsRealtimeProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return const [];
  final client = ref.read(supabaseClientProvider);
  try {
    final rows = await client
        .from('client_property_applications')
        .select(_applicationSelect)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows
        .map((e) => _StaffApplicationRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    final rows = await client
        .from('client_property_applications')
        .select(
          'id, status, payment_plan, amount_offered, notes, created_at, updated_at, client_id, property_id',
        )
        .eq('is_deleted', false)
        .order('created_at', ascending: false);
    return rows
        .map((e) => _StaffApplicationRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
});

const _staffStatuses = [
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
];

class StaffClientApplicationsPage extends ConsumerStatefulWidget {
  const StaffClientApplicationsPage({super.key});

  @override
  ConsumerState<StaffClientApplicationsPage> createState() =>
      _StaffClientApplicationsPageState();
}

class _StaffClientApplicationsPageState
    extends ConsumerState<StaffClientApplicationsPage> {
  String _query = '';
  String _view = 'all';
  String? _updatingId;

  Future<void> _setStatus(_StaffApplicationRow row, String status) async {
    setState(() => _updatingId = row.id);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('client_property_applications').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', row.id);
      ref.invalidate(staffClientApplicationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Updated ${row.shortId} → ${ClientPropertyApplication.statusLabel(status)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e, fallback: 'Could not update status. Please try again.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(staffClientApplicationsProvider);
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: asyncRows.when(
        skipLoadingOnReload: true,
        loading: () => const ClientPageSkeleton(),
        error: (e, _) => ClientErrorView(
          message: e,
          onRetry: () => ref.invalidate(staffClientApplicationsProvider),
        ),
        data: (rows) {
          final needsAction = rows.where(_needsAction).length;
          final active = rows.where(_isActive).length;
          final closed = rows.where(_isClosed).length;
          final presentStatuses = {
            for (final row in rows) row.status,
          }.toList()
            ..sort();
          const builtInViews = {'all', 'action', 'active', 'closed'};
          final view = builtInViews.contains(_view) || presentStatuses.contains(_view)
              ? _view
              : 'all';
          final q = _query.trim().toLowerCase();
          final filtered = rows.where((row) {
            if (!_matchesView(row, view)) return false;
            if (q.isEmpty) return true;
            return [
              row.propertyTitle,
              row.shortId,
              row.clientCode,
              row.clientName,
              row.clientEmail,
              row.clientPhone,
              row.location,
              row.status,
            ].whereType<String>().join(' ').toLowerCase().contains(q);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(staffClientApplicationsProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Client Applications',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Every portal application, with the client, property, and offer. '
                  'New submissions and status changes appear here as they happen.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
                if (asyncRows.isLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _Kpi(label: 'Needs action', value: '$needsAction', accent: AppColors.gold)),
                    const SizedBox(width: 12),
                    Expanded(child: _Kpi(label: 'In progress', value: '$active', accent: AppColors.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _Kpi(label: 'Closed', value: '$closed', accent: AppColors.slate400)),
                    const SizedBox(width: 12),
                    Expanded(child: _Kpi(label: 'All applications', value: '${rows.length}')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Search client, property, phone, or APP-ID',
                          prefixIcon: Icon(LucideIcons.search, size: 18),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: view,
                        isDense: true,
                        decoration: const InputDecoration(labelText: 'View'),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All')),
                          const DropdownMenuItem(value: 'action', child: Text('Needs action')),
                          const DropdownMenuItem(value: 'active', child: Text('In progress')),
                          const DropdownMenuItem(value: 'closed', child: Text('Closed')),
                          for (final status in presentStatuses)
                            DropdownMenuItem(
                              value: status,
                              child: Text(ClientPropertyApplication.statusLabel(status)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _view = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No applications match this view.')),
                  )
                else
                  ...filtered.map((row) {
                    final busy = _updatingId == row.id;
                    return _ApplicationCard(
                      row: row,
                      busy: busy,
                      amount: row.amountOffered == null ? null : fmt.format(row.amountOffered),
                      listed: row.listingPrice == null ? null : fmt.format(row.listingPrice),
                      onOpen: () => context.push(
                        '${RoutePaths.dashboardClientApplications}/${row.id}',
                      ),
                      onStatus: (status) => _setStatus(row, status),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _matchesView(_StaffApplicationRow row, String view) {
    return switch (view) {
      'action' => _needsAction(row),
      'active' => _isActive(row),
      'closed' => _isClosed(row),
      'all' => true,
      _ => row.status == _view,
    };
  }
}

bool _needsAction(_StaffApplicationRow row) {
  return row.status == 'submitted' ||
      row.status == 'under_review' ||
      row.status == 'documents_required';
}

bool _isActive(_StaffApplicationRow row) {
  return row.status == 'approved' ||
      row.status == 'payment_pending' ||
      row.status == 'payment_active' ||
      row.status == 'contract_pending';
}

bool _isClosed(_StaffApplicationRow row) {
  return row.status == 'completed' ||
      row.status == 'rejected' ||
      row.status == 'cancelled';
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.accent = AppColors.goldLight});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        color: accent.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.row,
    required this.busy,
    required this.onOpen,
    required this.onStatus,
    this.amount,
    this.listed,
  });

  final _StaffApplicationRow row;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<String> onStatus;
  final String? amount;
  final String? listed;

  @override
  Widget build(BuildContext context) {
    final tone = _statusColor(row.status);
    final submitted = row.createdAt == null
        ? null
        : DateFormat.yMMMd().add_jm().format(row.createdAt!.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: AppRadius.cardBorder,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.slate400.withValues(alpha: 0.18)),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusPill(label: ClientPropertyApplication.statusLabel(row.status), color: tone),
                    const Spacer(),
                    Text(
                      row.shortId,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.slate400,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  row.propertyTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                if ([
                  row.clientName,
                  row.clientEmail,
                  row.clientPhone,
                ].whereType<String>().any((part) => part.trim().isNotEmpty)) ...[
                  Text(
                    [
                      row.clientName,
                      row.clientEmail,
                      row.clientPhone,
                    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · '),
                    style: const TextStyle(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  [
                    if ((row.clientCode ?? '').isNotEmpty) row.clientCode!,
                    if ((row.location ?? '').isNotEmpty) row.location!,
                    if ((row.paymentPlan ?? '').isNotEmpty)
                      row.paymentPlan!.replaceAll('_', ' '),
                    if (amount != null) 'Offer $amount',
                    if (listed != null) 'Listed $listed',
                    if (submitted != null) submitted,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
                if ((row.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(row.notes!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(LucideIcons.eye, size: 16),
                      label: const Text('Open record'),
                    ),
                    const Spacer(),
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      PopupMenuButton<String>(
                        tooltip: 'Change status',
                        onSelected: onStatus,
                        itemBuilder: (_) => [
                          for (final status in _staffStatuses)
                            PopupMenuItem(
                              value: status,
                              child: Text(ClientPropertyApplication.statusLabel(status)),
                            ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.gitBranch, size: 16),
                              SizedBox(width: 6),
                              Text('Update status'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'approved' || 'payment_active' || 'completed' => AppColors.success,
    'rejected' || 'cancelled' => AppColors.error,
    'documents_required' || 'payment_pending' || 'contract_pending' => AppColors.warning,
    _ => AppColors.gold,
  };
}

class _StaffApplicationRow {
  const _StaffApplicationRow({
    required this.id,
    required this.status,
    required this.propertyTitle,
    this.location,
    this.clientCode,
    this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.paymentPlan,
    this.amountOffered,
    this.listingPrice,
    this.notes,
    this.createdAt,
  });

  factory _StaffApplicationRow.fromJson(Map<String, dynamic> json) {
    final property = json['properties'];
    Map<String, dynamic> propMap = {};
    if (property is Map) propMap = Map<String, dynamic>.from(property);
    final locRaw = propMap['property_locations'];
    Map<String, dynamic>? loc;
    if (locRaw is List && locRaw.isNotEmpty && locRaw.first is Map) {
      loc = Map<String, dynamic>.from(locRaw.first as Map);
    } else if (locRaw is Map) {
      loc = Map<String, dynamic>.from(locRaw);
    }
    final clients = json['clients'];
    Map<String, dynamic> clientMap = {};
    if (clients is Map) clientMap = Map<String, dynamic>.from(clients);
    final profRaw = clientMap['profiles'];
    Map<String, dynamic>? prof;
    if (profRaw is Map) prof = Map<String, dynamic>.from(profRaw);
    final preferred = (prof?['preferred_name'] as String?)?.trim();
    final first = prof?['first_name'] as String? ?? '';
    final last = prof?['last_name'] as String? ?? '';
    final composed = '$first $last'.trim();
    final clientName = (preferred != null && preferred.isNotEmpty)
        ? preferred
        : (composed.isEmpty ? null : composed);

    return _StaffApplicationRow(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'submitted',
      propertyTitle: propMap['title'] as String? ?? 'Property',
      location: [loc?['city'], loc?['state']]
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .join(', '),
      clientCode: clientMap['client_code'] as String?,
      clientName: clientName,
      clientEmail: prof?['email'] as String?,
      clientPhone: prof?['phone'] as String?,
      paymentPlan: json['payment_plan'] as String?,
      amountOffered: (json['amount_offered'] as num?)?.toDouble(),
      listingPrice: (propMap['listing_price'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String status;
  final String propertyTitle;
  final String? location;
  final String? clientCode;
  final String? clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? paymentPlan;
  final double? amountOffered;
  final double? listingPrice;
  final String? notes;
  final DateTime? createdAt;

  String get shortId {
    final raw = id.replaceAll('-', '').toUpperCase();
    return 'APP-${raw.substring(0, 8)}';
  }
}
