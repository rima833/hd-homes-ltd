import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/consultation/domain/entities/consultation_admin_models.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/consultation_admin_providers.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_admin_shared.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ConsultationCommandCenterPage extends ConsumerStatefulWidget {
  const ConsultationCommandCenterPage({super.key});

  @override
  ConsumerState<ConsultationCommandCenterPage> createState() =>
      _ConsultationCommandCenterPageState();
}

class _ConsultationCommandCenterPageState
    extends ConsumerState<ConsultationCommandCenterPage> {
  static const _tabLabels = [
    'Bookings',
    'Departments',
    'Advisors',
    'Types',
    'Availability',
    'Settings',
  ];

  int _tabIndex = 0;
  String _statusFilter = 'all';
  String _search = '';
  AdminConsultationRow? _selected;

  void _invalidateAll() {
    ref.invalidate(adminConsultationsProvider);
    ref.invalidate(adminConsultationStatsProvider);
    ref.invalidate(adminConsultationDepartmentsProvider);
    ref.invalidate(adminConsultationAdvisorsProvider);
    ref.invalidate(adminConsultationTypesProvider);
    ref.invalidate(adminConsultationWorkingHoursProvider);
    ref.invalidate(adminConsultationHolidaysProvider);
    ref.invalidate(adminConsultationSettingsProvider);
    ref.read(adminConsultationsLiveTickProvider.notifier).state++;
  }

  void _syncSelected(List<AdminConsultationRow> rows) {
    final id = _selected?.id;
    if (id == null) return;
    AdminConsultationRow? updated;
    for (final r in rows) {
      if (r.id == id) {
        updated = r;
        break;
      }
    }
    if (updated != _selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selected = updated);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminConsultationsRealtimeProvider);
    final liveTick = ref.watch(adminConsultationsLiveTickProvider);
    final bookingsAsync = ref.watch(adminConsultationsProvider);
    final statsAsync = ref.watch(adminConsultationStatsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    bookingsAsync.whenData(_syncSelected);

    return Scaffold(
      backgroundColor: InspectionAdminUi.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: InspectionAdminUi.gold,
              onRefresh: () async => _invalidateAll(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _Header(
                          liveTick: liveTick,
                          onOpenPublic: () =>
                              context.go(RoutePaths.bookConsultation),
                          onRefresh: _invalidateAll,
                        ),
                        const SizedBox(height: 10),
                        statsAsync.when(
                          loading: () => const SizedBox(
                            height: AdminOpsStatStrip.height,
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (stats) => _StatsRow(
                            stats: stats,
                            selected: _statusFilter,
                            onSelect: (v) {
                              setState(() {
                                _statusFilter = v;
                                _tabIndex = 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        AdminOpsPageTabs(
                          labels: _tabLabels,
                          index: _tabIndex,
                          onChanged: (i) => setState(() => _tabIndex = i),
                        ),
                        const SizedBox(height: 10),
                        _buildActiveTab(bookingsAsync),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selected != null && wide)
            _BookingDetailPanel(
              row: _selected!,
              onClose: () => setState(() => _selected = null),
              onUpdated: () {
                ref.invalidate(adminConsultationsProvider);
                ref.invalidate(adminConsultationStatsProvider);
              },
            ),
        ],
      ),
      floatingActionButton: !wide && _selected != null
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: InspectionAdminUi.surface,
                  isScrollControlled: true,
                  builder: (_) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.85,
                    child: _BookingDetailPanel(
                      row: _selected!,
                      onClose: () {
                        Navigator.pop(context);
                        setState(() => _selected = null);
                      },
                      onUpdated: () {
                        ref.invalidate(adminConsultationsProvider);
                        ref.invalidate(adminConsultationStatsProvider);
                      },
                    ),
                  ),
                );
              },
              backgroundColor: InspectionAdminUi.gold,
              foregroundColor: Colors.black,
              icon: const Icon(LucideIcons.panelRight),
              label: const Text('Details'),
            )
          : null,
    );
  }

  Widget _buildActiveTab(AsyncValue<List<AdminConsultationRow>> bookingsAsync) {
    switch (_tabIndex) {
      case 0:
        return _BookingsTab(
          bookingsAsync: bookingsAsync,
          statusFilter: _statusFilter,
          search: _search,
          selectedId: _selected?.id,
          onStatusFilter: (v) => setState(() => _statusFilter = v),
          onSearch: (v) => setState(() => _search = v.trim().toLowerCase()),
          onSelect: (row) => setState(() => _selected = row),
        );
      case 1:
        return const _DepartmentsTab();
      case 2:
        return const _AdvisorsTab();
      case 3:
        return const _TypesTab();
      case 4:
        return const _AvailabilityTab();
      case 5:
        return const _SettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.liveTick,
    required this.onOpenPublic,
    required this.onRefresh,
  });

  final int liveTick;
  final VoidCallback onOpenPublic;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            InspectionAdminUi.surfaceElevated,
            InspectionAdminUi.surface,
            InspectionAdminUi.gold.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InspectionAdminUi.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'CONSULTATIONS',
                      style: TextStyle(
                        color: InspectionAdminUi.gold,
                        letterSpacing: 2.4,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    InspectionLiveBadge(tick: liveTick),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Consultation command center',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            style: IconButton.styleFrom(
              foregroundColor: Colors.white70,
              backgroundColor: InspectionAdminUi.bg,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: onOpenPublic,
            icon: const Icon(LucideIcons.externalLink, size: 15),
            label: const Text('Public page'),
            style: OutlinedButton.styleFrom(
              foregroundColor: InspectionAdminUi.gold,
              side: BorderSide(
                color: InspectionAdminUi.gold.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.stats,
    required this.selected,
    required this.onSelect,
  });

  final AdminConsultationStats stats;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return AdminOpsStatStrip(
      selectedKey: selected,
      onSelect: onSelect,
      items: [
        AdminOpsStatItem(
          key: 'all',
          label: 'Total',
          value: stats.total,
          icon: LucideIcons.layers,
          accent: Colors.white70,
        ),
        AdminOpsStatItem(
          key: 'today',
          label: 'Today',
          value: stats.today,
          icon: LucideIcons.sun,
          accent: const Color(0xFFFBBF24),
        ),
        AdminOpsStatItem(
          key: 'upcoming',
          label: 'Upcoming',
          value: stats.upcoming,
          icon: LucideIcons.calendarClock,
          accent: const Color(0xFF60A5FA),
        ),
        AdminOpsStatItem(
          key: 'pending',
          label: 'Pending',
          value: stats.pending,
          icon: LucideIcons.clock,
          accent: InspectionAdminUi.gold,
        ),
        AdminOpsStatItem(
          key: 'confirmed',
          label: 'Confirmed',
          value: stats.confirmed,
          icon: LucideIcons.checkCircle2,
          accent: const Color(0xFF22C55E),
        ),
        AdminOpsStatItem(
          key: 'completed',
          label: 'Completed',
          value: stats.completed,
          icon: LucideIcons.badgeCheck,
          accent: const Color(0xFF3B82F6),
        ),
        AdminOpsStatItem(
          key: 'cancelled',
          label: 'Cancelled',
          value: stats.cancelled,
          icon: LucideIcons.xCircle,
          accent: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _BookingsTab extends StatelessWidget {
  const _BookingsTab({
    required this.bookingsAsync,
    required this.statusFilter,
    required this.search,
    required this.selectedId,
    required this.onStatusFilter,
    required this.onSearch,
    required this.onSelect,
  });

  final AsyncValue<List<AdminConsultationRow>> bookingsAsync;
  final String statusFilter;
  final String search;
  final String? selectedId;
  final ValueChanged<String> onStatusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<AdminConsultationRow> onSelect;

  bool _matchesFilter(AdminConsultationRow r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final at = r.scheduledAt.toLocal();
    final day = DateTime(at.year, at.month, at.day);

    switch (statusFilter) {
      case 'all':
        return true;
      case 'today':
        return day == today;
      case 'upcoming':
        return at.isAfter(now) &&
            !{'cancelled', 'rejected', 'completed', 'no_show'}
                .contains(r.status);
      case 'pending':
        return {'scheduled', 'pending', 'assigned'}.contains(r.status);
      default:
        return r.status == statusFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InspectionAdminUi.fieldDecoration(
                  'Search',
                  hint: 'Search customer, reference, department…',
                  compact: true,
                  prefix: const Icon(
                    LucideIcons.search,
                    size: 16,
                    color: InspectionAdminUi.muted,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: onSearch,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: InspectionAdminUi.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: InspectionAdminUi.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: statusFilter,
                  dropdownColor: InspectionAdminUi.surfaceElevated,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'confirmed',
                      child: Text('Confirmed'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                    DropdownMenuItem(value: 'no_show', child: Text('No-show')),
                  ],
                  onChanged: (v) => onStatusFilter(v ?? 'all'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        bookingsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Unable to load bookings.',
            style: TextStyle(color: Colors.red.shade300),
          ),
          data: (rows) {
            final filtered = rows.where((r) {
              if (!_matchesFilter(r)) return false;
              if (search.isEmpty) return true;
              final hay = [
                r.reference,
                r.fullName,
                r.email,
                r.phone,
                r.departmentName,
                r.advisorName,
              ].whereType<String>().join(' ').toLowerCase();
              return hay.contains(search);
            }).toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.calendarOff,
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No consultations match your filters.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final row = filtered[i];
                return _BookingTile(
                  row: row,
                  selected: row.id == selectedId,
                  onTap: () => onSelect(row),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final AdminConsultationRow row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? InspectionAdminUi.surfaceElevated
              : InspectionAdminUi.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? InspectionAdminUi.gold.withValues(alpha: 0.55)
                : InspectionAdminUi.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.fullName ?? 'Guest',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.departmentName ?? 'Consultation'} • ${fmt.format(row.scheduledAt.toLocal())}',
                    style: const TextStyle(
                      color: InspectionAdminUi.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    row.reference,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            InspectionStatusBadge(status: row.status),
          ],
        ),
      ),
    );
  }
}

class _BookingDetailPanel extends ConsumerWidget {
  const _BookingDetailPanel({
    required this.row,
    required this.onClose,
    required this.onUpdated,
  });

  final AdminConsultationRow row;
  final VoidCallback onClose;
  final VoidCallback onUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');
    final eventsAsync = ref.watch(consultationBookingEventsProvider(row.id));
    final advisorsAsync = ref.watch(adminConsultationAdvisorsProvider);

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: InspectionAdminUi.surface,
        border: Border(left: BorderSide(color: InspectionAdminUi.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.reference,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow('Customer', row.fullName ?? '—'),
                  _DetailRow('Email', row.email ?? '—'),
                  _DetailRow('Phone', row.phone ?? '—'),
                  _DetailRow('Department', row.departmentName ?? '—'),
                  _DetailRow('Advisor', row.advisorName ?? 'Unassigned'),
                  _DetailRow('When', fmt.format(row.scheduledAt.toLocal())),
                  _DetailRow('Method', row.meetingMethod),
                  _DetailRow('Status', row.status),
                  if (row.notes?.isNotEmpty == true)
                    _DetailRow('Notes', row.notes!),
                  if (row.adminNotes?.isNotEmpty == true)
                    _DetailRow('Admin notes', row.adminNotes!),
                  const SizedBox(height: 16),
                  _AdminNoteField(bookingId: row.id, onUpdated: onUpdated),
                  const SizedBox(height: 16),
                  const Text(
                    'Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PermissionGate(
                    permission: PermissionSlugs.consultationsManage,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (row.status == 'scheduled' || row.status == 'assigned')
                          _ActionChip(
                            label: 'Confirm',
                            onTap: () => _updateStatus(ref, 'confirmed'),
                          ),
                        if (row.status != 'completed' &&
                            row.status != 'cancelled')
                          _ActionChip(
                            label: 'Reschedule',
                            onTap: () => _reschedule(context, ref),
                          ),
                        if (row.status != 'completed' &&
                            row.status != 'cancelled')
                          _ActionChip(
                            label: 'Complete',
                            onTap: () => _updateStatus(ref, 'completed'),
                          ),
                        if (row.status != 'cancelled' &&
                            row.status != 'completed')
                          _ActionChip(
                            label: 'Cancel',
                            onTap: () => _updateStatus(ref, 'cancelled'),
                          ),
                        if (row.status == 'confirmed')
                          _ActionChip(
                            label: 'No-show',
                            onTap: () => _updateStatus(ref, 'no_show'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  advisorsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (advisors) {
                      final active =
                          advisors.where((a) => a.isActive).toList();
                      if (active.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assign advisor',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey('advisor-${row.id}-${row.advisorId}'),
                            initialValue: row.advisorId,
                            dropdownColor: InspectionAdminUi.surfaceElevated,
                            decoration: InspectionAdminUi.fieldDecoration(
                              'Advisor',
                            ),
                            items: active
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      a.fullName,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (id) async {
                              if (id == null) return;
                              await ref
                                  .read(consultationAdminServiceProvider)
                                  .assignAdvisor(row.id, id);
                              onUpdated();
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Timeline',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  eventsAsync.when(
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, _) => const Text(
                      'Unable to load timeline.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                    ),
                    data: (events) {
                      if (events.isEmpty) {
                        return const Text(
                          'No events yet.',
                          style: TextStyle(color: InspectionAdminUi.muted),
                        );
                      }
                      return Column(
                        children: events
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '${DateFormat('d MMM, HH:mm').format(e.createdAt.toLocal())} — ${e.eventType.replaceAll('_', ' ')}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(WidgetRef ref, String status) async {
    await ref.read(consultationAdminServiceProvider).updateStatus(
          row.id,
          status,
        );
    onUpdated();
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      initialDate: row.scheduledAt.toLocal(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(row.scheduledAt.toLocal()),
    );
    if (time == null || !context.mounted) return;

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    try {
      await ref.read(consultationAdminServiceProvider).rescheduleBooking(
            bookingId: row.id,
            scheduledAt: scheduled,
            advisorId: row.advisorId,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultation rescheduled')),
        );
      }
      onUpdated();
    } catch (e) {
      if (!context.mounted) return;
      final msg = '$e'.contains('slot_unavailable')
          ? 'That slot is no longer available.'
          : 'Unable to reschedule consultation.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

// ─── Departments ─────────────────────────────────────────────────────────────

class _DepartmentsTab extends ConsumerWidget {
  const _DepartmentsTab();

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    AdminConsultationDepartment? existing,
  }) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final response = TextEditingController(
      text: existing?.responseTimeLabel ?? '',
    );
    final description = TextEditingController(text: existing?.description ?? '');
    final duration = TextEditingController(
      text: '${existing?.durationMinutes ?? 45}',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: InspectionAdminUi.surfaceElevated,
        title: Text(
          existing == null ? 'Add department' : 'Edit department',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                style: const TextStyle(color: Colors.white),
                decoration: InspectionAdminUi.fieldDecoration('Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: response,
                style: const TextStyle(color: Colors.white),
                decoration: InspectionAdminUi.fieldDecoration(
                  'Response time label',
                  hint: 'e.g. < 1 day',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: duration,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InspectionAdminUi.fieldDecoration(
                  'Duration (minutes)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InspectionAdminUi.fieldDecoration('Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: InspectionAdminUi.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    if (name.text.trim().isEmpty) return;

    try {
      await ref.read(consultationAdminServiceProvider).upsertDepartment(
            id: existing?.id,
            name: name.text,
            responseTimeLabel: response.text,
            description: description.text,
            durationMinutes: int.tryParse(duration.text) ?? 45,
            isActive: existing?.isActive ?? true,
            sortOrder: existing?.sortOrder ?? 0,
          );
      ref.invalidate(adminConsultationDepartmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null ? 'Department created' : 'Department updated',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(adminConsultationDepartmentsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Departments',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Organize consultation queues and response SLAs.',
                    style: TextStyle(
                      color: InspectionAdminUi.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add department'),
              style: FilledButton.styleFrom(
                backgroundColor: InspectionAdminUi.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        deptsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Text(
            'Unable to load departments.',
            style: TextStyle(color: InspectionAdminUi.muted),
          ),
          data: (depts) {
            if (depts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.building2,
                      color: Colors.white24,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No departments yet.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(context, ref),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add department'),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: depts.length,
              itemBuilder: (_, i) {
                final d = depts[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: InspectionAdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: InspectionAdminUi.border),
                  ),
                  child: ListTile(
                    onTap: () => _openEditor(context, ref, existing: d),
                    title: Text(
                      d.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (d.responseTimeLabel?.isNotEmpty == true)
                          d.responseTimeLabel!,
                        if (d.durationMinutes != null)
                          '${d.durationMinutes} min',
                      ].join(' • '),
                      style: const TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Switch(
                      value: d.isActive,
                      activeThumbColor: InspectionAdminUi.gold,
                      onChanged: (v) async {
                        await ref
                            .read(consultationAdminServiceProvider)
                            .toggleDepartmentActive(d.id, v);
                        ref.invalidate(adminConsultationDepartmentsProvider);
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─── Advisors ────────────────────────────────────────────────────────────────

class _AdvisorsTab extends ConsumerWidget {
  const _AdvisorsTab();

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    AdminConsultationAdvisor? existing,
  }) async {
    final depts =
        await ref.read(adminConsultationDepartmentsProvider.future);
    if (!context.mounted) return;

    final name = TextEditingController(text: existing?.fullName ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final whatsapp = TextEditingController(text: existing?.whatsapp ?? '');
    String? departmentId = existing?.departmentId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: InspectionAdminUi.surfaceElevated,
            title: Text(
              existing == null ? 'Add advisor' : 'Edit advisor',
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      style: const TextStyle(color: Colors.white),
                      decoration: InspectionAdminUi.fieldDecoration('Full name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: title,
                      style: const TextStyle(color: Colors.white),
                      decoration: InspectionAdminUi.fieldDecoration(
                        'Title / role',
                        hint: 'Senior Property Consultant',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: departmentId,
                      dropdownColor: InspectionAdminUi.surfaceElevated,
                      decoration:
                          InspectionAdminUi.fieldDecoration('Department'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No department'),
                        ),
                        ...depts.map(
                          (d) => DropdownMenuItem<String?>(
                            value: d.id,
                            child: Text(d.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => departmentId = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: email,
                      style: const TextStyle(color: Colors.white),
                      decoration: InspectionAdminUi.fieldDecoration('Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InspectionAdminUi.fieldDecoration('Phone'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: whatsapp,
                      style: const TextStyle(color: Colors.white),
                      decoration: InspectionAdminUi.fieldDecoration('WhatsApp'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: InspectionAdminUi.gold,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    if (name.text.trim().isEmpty) return;

    try {
      await ref.read(consultationAdminServiceProvider).upsertAdvisor(
            id: existing?.id,
            fullName: name.text,
            title: title.text,
            departmentId: departmentId,
            email: email.text,
            phone: phone.text,
            whatsapp: whatsapp.text,
            isActive: existing?.isActive ?? true,
            sortOrder: existing?.sortOrder ?? 0,
          );
      ref.invalidate(adminConsultationAdvisorsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null ? 'Advisor created' : 'Advisor updated',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisorsAsync = ref.watch(adminConsultationAdvisorsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Advisors & agents',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Add specialists who can be assigned to consultations.',
                    style: TextStyle(
                      color: InspectionAdminUi.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: const Text('Add advisor'),
              style: FilledButton.styleFrom(
                backgroundColor: InspectionAdminUi.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        advisorsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Text(
            'Unable to load advisors.',
            style: TextStyle(color: InspectionAdminUi.muted),
          ),
          data: (advisors) {
            if (advisors.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.users,
                      color: Colors.white24,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No advisors yet.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(context, ref),
                      icon: const Icon(LucideIcons.userPlus, size: 16),
                      label: const Text('Add advisor'),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: advisors.length,
              itemBuilder: (_, i) {
                final a = advisors[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: InspectionAdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: InspectionAdminUi.border),
                  ),
                  child: ListTile(
                    onTap: () => _openEditor(context, ref, existing: a),
                    leading: CircleAvatar(
                      backgroundColor:
                          InspectionAdminUi.gold.withValues(alpha: 0.18),
                      foregroundColor: InspectionAdminUi.gold,
                      child: Text(
                        a.fullName.isNotEmpty
                            ? a.fullName[0].toUpperCase()
                            : 'A',
                      ),
                    ),
                    title: Text(
                      a.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${a.title ?? 'Advisor'} • ${a.departmentName ?? 'Unassigned'}',
                      style: const TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Switch(
                      value: a.isActive,
                      activeThumbColor: InspectionAdminUi.gold,
                      onChanged: (v) async {
                        await ref
                            .read(consultationAdminServiceProvider)
                            .toggleAdvisorActive(a.id, v);
                        ref.invalidate(adminConsultationAdvisorsProvider);
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─── Types ───────────────────────────────────────────────────────────────────

class _TypesTab extends ConsumerWidget {
  const _TypesTab();

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? existing,
  }) async {
    final depts =
        await ref.read(adminConsultationDepartmentsProvider.future);
    if (!context.mounted) return;

    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final description =
        TextEditingController(text: '${existing?['description'] ?? ''}');
    final duration = TextEditingController(
      text: '${existing?['duration_minutes'] ?? 45}',
    );
    final price = TextEditingController(
      text: (existing?['price_amount'] as num?)?.toStringAsFixed(0) ?? '0',
    );
    String? departmentId = existing?['department_id']?.toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: InspectionAdminUi.surfaceElevated,
            title: Text(
              existing == null ? 'Add consultation type' : 'Edit type',
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    style: const TextStyle(color: Colors.white),
                    decoration: InspectionAdminUi.fieldDecoration('Name'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: departmentId,
                    dropdownColor: InspectionAdminUi.surfaceElevated,
                    decoration: InspectionAdminUi.fieldDecoration('Department'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All departments'),
                      ),
                      ...depts.map(
                        (d) => DropdownMenuItem<String?>(
                          value: d.id,
                          child: Text(d.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => departmentId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        InspectionAdminUi.fieldDecoration('Duration (minutes)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InspectionAdminUi.fieldDecoration(
                      'Price (NGN)',
                      hint: '0 = Free',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InspectionAdminUi.fieldDecoration('Description'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: InspectionAdminUi.gold,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    if (name.text.trim().isEmpty) return;

    try {
      await ref.read(consultationAdminServiceProvider).upsertConsultationType(
            id: existing?['id']?.toString(),
            name: name.text,
            departmentId: departmentId,
            description: description.text,
            durationMinutes: int.tryParse(duration.text) ?? 45,
            priceAmount: double.tryParse(price.text) ?? 0,
            isActive: existing?['is_active'] as bool? ?? true,
            sortOrder: (existing?['sort_order'] as num?)?.toInt() ?? 0,
          );
      ref.invalidate(adminConsultationTypesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? 'Type created' : 'Type updated'),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(adminConsultationTypesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consultation types',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Define products customers can book on the public page.',
                    style: TextStyle(
                      color: InspectionAdminUi.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add type'),
              style: FilledButton.styleFrom(
                backgroundColor: InspectionAdminUi.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        typesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Text(
            'Unable to load consultation types.',
            style: TextStyle(color: InspectionAdminUi.muted),
          ),
          data: (types) {
            if (types.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.tags,
                      color: Colors.white24,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No consultation types yet.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openEditor(context, ref),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add type'),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: types.length,
              itemBuilder: (_, i) {
                final t = types[i];
                final dept = t['consultation_departments'];
                final deptName = dept is Map ? '${dept['name'] ?? ''}' : '';
                final active = t['is_active'] == true;
                final duration = t['duration_minutes'] ?? 45;
                final price = (t['price_amount'] as num?)?.toDouble() ?? 0;
                final priceLabel =
                    price <= 0 ? 'Free' : '₦${price.toStringAsFixed(0)}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: InspectionAdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: InspectionAdminUi.border),
                  ),
                  child: ListTile(
                    onTap: () => _openEditor(context, ref, existing: t),
                    title: Text(
                      '${t['name'] ?? 'Type'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${deptName.isEmpty ? 'All departments' : deptName}'
                      ' • $duration min • $priceLabel',
                      style: const TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Switch(
                      value: active,
                      activeThumbColor: InspectionAdminUi.gold,
                      onChanged: (v) async {
                        await ref
                            .read(consultationAdminServiceProvider)
                            .toggleConsultationTypeActive('${t['id']}', v);
                        ref.invalidate(adminConsultationTypesProvider);
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─── Availability ────────────────────────────────────────────────────────────

class _AvailabilityTab extends ConsumerStatefulWidget {
  const _AvailabilityTab();

  @override
  ConsumerState<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends ConsumerState<_AvailabilityTab> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> _withFeedback(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  String _hhmm(String? raw, String fallback) {
    final s = (raw ?? fallback).toString();
    return s.length >= 5 ? s.substring(0, 5) : fallback;
  }

  Future<void> _pickTime({
    required int weekday,
    required bool start,
    required String startTime,
    required String endTime,
    required bool isActive,
    required int slotMinutes,
  }) async {
    final current = start ? startTime : endTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
    await _withFeedback(() async {
      await ref.read(consultationAdminServiceProvider).upsertWorkingHours(
            weekday: weekday,
            startTime: start ? formatted : startTime,
            endTime: start ? endTime : formatted,
            isActive: true,
            slotMinutes: slotMinutes,
          );
      ref.invalidate(adminConsultationWorkingHoursProvider);
    });
  }

  Future<void> _addHoliday() async {
    final name = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: InspectionAdminUi.surfaceElevated,
            title: const Text(
              'Add holiday',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  style: const TextStyle(color: Colors.white),
                  decoration: InspectionAdminUi.fieldDecoration('Name'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat('EEE, d MMM yyyy').format(date),
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(
                    LucideIcons.calendar,
                    color: InspectionAdminUi.gold,
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setLocal(() => date = picked);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: InspectionAdminUi.gold,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await _withFeedback(() async {
      await ref.read(consultationAdminServiceProvider).addHoliday(
            date: date,
            name: name.text,
          );
      ref.invalidate(adminConsultationHolidaysProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hoursAsync = ref.watch(adminConsultationWorkingHoursProvider);
    final holidaysAsync = ref.watch(adminConsultationHolidaysProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hoursAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, _) => const Text(
            'Working hours unavailable.',
            style: TextStyle(color: InspectionAdminUi.muted),
          ),
          data: (hours) {
            final byWeekday = <int, Map<String, dynamic>>{};
            for (final h in hours) {
              final day = (h['weekday'] as num?)?.toInt();
              if (day != null) byWeekday[day] = h;
            }
            return InspectionAdminCard(
              title: 'Working hours',
              subtitle: 'Open days and editable start / end times for bookings',
              child: Column(
                children: [
                  for (var i = 0; i < 7; i++)
                    Builder(
                      builder: (_) {
                        final row = byWeekday[i];
                        final active = row?['is_active'] == true;
                        final start = _hhmm(
                          row?['start_time']?.toString(),
                          '09:00',
                        );
                        final end = _hhmm(
                          row?['end_time']?.toString(),
                          '17:00',
                        );
                        final slot =
                            (row?['slot_minutes'] as num?)?.toInt() ?? 45;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                          decoration: BoxDecoration(
                            color: InspectionAdminUi.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: InspectionAdminUi.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _days[i],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (active)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          _TimeChip(
                                            label: start,
                                            onTap: () => _pickTime(
                                              weekday: i,
                                              start: true,
                                              startTime: '$start:00',
                                              endTime: '$end:00',
                                              isActive: active,
                                              slotMinutes: slot,
                                            ),
                                          ),
                                          const Text(
                                            '→',
                                            style: TextStyle(
                                              color: InspectionAdminUi.muted,
                                            ),
                                          ),
                                          _TimeChip(
                                            label: end,
                                            onTap: () => _pickTime(
                                              weekday: i,
                                              start: false,
                                              startTime: '$start:00',
                                              endTime: '$end:00',
                                              isActive: active,
                                              slotMinutes: slot,
                                            ),
                                          ),
                                          Text(
                                            '• $slot min slots',
                                            style: const TextStyle(
                                              color: InspectionAdminUi.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const Text(
                                        'Closed',
                                        style: TextStyle(
                                          color: InspectionAdminUi.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: active,
                                activeThumbColor: InspectionAdminUi.gold,
                                onChanged: (v) => _withFeedback(() async {
                                  await ref
                                      .read(consultationAdminServiceProvider)
                                      .upsertWorkingHours(
                                        weekday: i,
                                        startTime: '$start:00',
                                        endTime: '$end:00',
                                        isActive: v,
                                        slotMinutes: slot,
                                      );
                                  ref.invalidate(
                                    adminConsultationWorkingHoursProvider,
                                  );
                                }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        holidaysAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (holidays) => InspectionAdminCard(
            title: 'Holidays',
            subtitle: 'Closed dates override working hours',
            trailing: IconButton(
              tooltip: 'Add holiday',
              onPressed: _addHoliday,
              icon: const Icon(
                LucideIcons.plus,
                size: 18,
                color: InspectionAdminUi.gold,
              ),
            ),
            child: holidays.isEmpty
                ? const Text(
                    'No holidays configured.',
                    style: TextStyle(color: InspectionAdminUi.muted),
                  )
                : Column(
                    children: [
                      for (final h in holidays)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${h['name'] ?? 'Holiday'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '${h['holiday_date'] ?? ''}',
                            style: const TextStyle(
                              color: InspectionAdminUi.muted,
                              fontSize: 12,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              LucideIcons.trash2,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _withFeedback(() async {
                              await ref
                                  .read(consultationAdminServiceProvider)
                                  .deleteHoliday('${h['id']}');
                              ref.invalidate(adminConsultationHolidaysProvider);
                            }),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: InspectionAdminUi.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: InspectionAdminUi.gold.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Settings ────────────────────────────────────────────────────────────────

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  final _duration = TextEditingController();
  final _notice = TextEditingController();
  final _window = TextEditingController();
  final _cancel = TextEditingController();
  final _reschedule = TextEditingController();
  final _reminder = TextEditingController();
  final _timezone = TextEditingController();
  final _message = TextEditingController();
  var _emailConfirm = false;
  var _hydrated = false;
  var _saving = false;

  @override
  void dispose() {
    _duration.dispose();
    _notice.dispose();
    _window.dispose();
    _cancel.dispose();
    _reschedule.dispose();
    _reminder.dispose();
    _timezone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> settings) {
    if (_hydrated) return;
    _duration.text = '${settings['default_duration_minutes'] ?? 45}';
    _notice.text = '${settings['booking_notice_hours'] ?? 2}';
    _window.text = '${settings['max_booking_window_days'] ?? 60}';
    _cancel.text = '${settings['cancellation_notice_hours'] ?? 12}';
    _reschedule.text = '${settings['reschedule_notice_hours'] ?? 12}';
    _reminder.text = '${settings['reminder_hours_before'] ?? 24}';
    _timezone.text = '${settings['timezone'] ?? 'Africa/Lagos'}';
    _message.text =
        '${settings['confirmation_message'] ?? 'Your private consultation has been successfully booked.'}';
    _emailConfirm = settings['email_confirmation_enabled'] == true;
    _hydrated = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(consultationAdminServiceProvider).updateSettings({
        'default_duration_minutes': int.tryParse(_duration.text) ?? 45,
        'booking_notice_hours': int.tryParse(_notice.text) ?? 2,
        'max_booking_window_days': int.tryParse(_window.text) ?? 60,
        'cancellation_notice_hours': int.tryParse(_cancel.text) ?? 12,
        'reschedule_notice_hours': int.tryParse(_reschedule.text) ?? 12,
        'reminder_hours_before': int.tryParse(_reminder.text) ?? 24,
        'timezone': _timezone.text.trim().isEmpty
            ? 'Africa/Lagos'
            : _timezone.text.trim(),
        'confirmation_message': _message.text.trim(),
        'email_confirmation_enabled': _emailConfirm,
      });
      _hydrated = false;
      ref.invalidate(adminConsultationSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminConsultationSettingsProvider);
    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Text(
          'Unable to load settings.',
          style: TextStyle(color: InspectionAdminUi.muted),
        ),
      ),
      data: (settings) {
        if (settings != null) _hydrate(settings);
        return InspectionAdminCard(
          title: 'Booking rules',
          subtitle: 'Controls public slot generation and notice windows',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                  _settingsField('Default duration (minutes)', _duration),
                  _settingsField('Booking notice (hours)', _notice),
                  _settingsField('Max booking window (days)', _window),
                  _settingsField('Cancellation notice (hours)', _cancel),
                  _settingsField('Reschedule notice (hours)', _reschedule),
                  _settingsField('Reminder hours before', _reminder),
                  TextField(
                    controller: _timezone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InspectionAdminUi.fieldDecoration('Timezone'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Email confirmation',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Send confirmation emails when enabled in your stack',
                      style: TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                    value: _emailConfirm,
                    activeThumbColor: InspectionAdminUi.gold,
                    onChanged: (v) => setState(() => _emailConfirm = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _message,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InspectionAdminUi.fieldDecoration(
                      'Confirmation message',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(LucideIcons.save, size: 16),
                      label: Text(_saving ? 'Saving…' : 'Save settings'),
                      style: FilledButton.styleFrom(
                        backgroundColor: InspectionAdminUi.gold,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
        );
      },
    );
  }

  Widget _settingsField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InspectionAdminUi.fieldDecoration(label),
      ),
    );
  }
}

class _AdminNoteField extends ConsumerStatefulWidget {
  const _AdminNoteField({
    required this.bookingId,
    required this.onUpdated,
  });

  final String bookingId;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_AdminNoteField> createState() => _AdminNoteFieldState();
}

class _AdminNoteFieldState extends ConsumerState<_AdminNoteField> {
  final _controller = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _controller.text.trim();
    if (note.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(consultationAdminServiceProvider)
          .addAdminNote(widget.bookingId, note);
      _controller.clear();
      widget.onUpdated();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Add internal note',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: 2,
          style: const TextStyle(color: Colors.white),
          decoration: InspectionAdminUi.fieldDecoration(
            'Note',
            hint: 'Visible to staff only',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Add note'),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: InspectionAdminUi.muted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: InspectionAdminUi.gold,
        side: BorderSide(
          color: InspectionAdminUi.gold.withValues(alpha: 0.5),
        ),
      ),
      child: Text(label),
    );
  }
}
