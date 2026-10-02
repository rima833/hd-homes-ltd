import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/callback/domain/entities/callback_models.dart';
import 'package:hdhomesproject/features/callback/presentation/providers/callback_providers.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_admin_shared.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class _Cb {
  static const surface = InspectionAdminUi.surface;
  static const elevated = InspectionAdminUi.surfaceElevated;
  static const border = InspectionAdminUi.border;
  static const muted = InspectionAdminUi.muted;
  static const gold = InspectionAdminUi.gold;

  static InputDecoration field(String label, {String? hint, Widget? prefix}) {
    return InspectionAdminUi.fieldDecoration(
      label,
      hint: hint,
      prefix: prefix,
    );
  }

  static Color statusColor(String status) => switch (status) {
        'new' => const Color(0xFF38BDF8),
        'assigned' => gold,
        'contacted' => const Color(0xFFF59E0B),
        'scheduled' => const Color(0xFFA78BFA),
        'completed' => const Color(0xFF22C55E),
        'cancelled' => const Color(0xFFEF4444),
        _ => muted,
      };

  static const weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
}

class CallbackCommandCenterPage extends ConsumerStatefulWidget {
  const CallbackCommandCenterPage({super.key});

  @override
  ConsumerState<CallbackCommandCenterPage> createState() =>
      _CallbackCommandCenterPageState();
}

class _CallbackCommandCenterPageState
    extends ConsumerState<CallbackCommandCenterPage> {
  static const _tabLabels = [
    'Inbox',
    'Form settings',
    'Hours',
    'Departments',
  ];

  int _tabIndex = 0;
  String _statusFilter = 'all';
  String _search = '';
  AdminCallbackRow? _selected;

  Future<void> _refreshAll() async {
    ref.invalidate(adminCallbacksProvider);
    ref.invalidate(adminCallbackStatsProvider);
    ref.invalidate(callbackSettingsProvider);
    ref.invalidate(adminCallbackDepartmentsProvider);
    ref.invalidate(adminCallbackPrioritiesProvider);
    ref.invalidate(adminCallbackWorkingHoursProvider);
    ref.invalidate(adminCallbackStaffProvider);
  }

  Future<void> _updateStatus(
    String id,
    String status, {
    String? reason,
    String? assignedTo,
    DateTime? scheduledAt,
    String? adminNotes,
  }) async {
    try {
      await ref.read(callbackAdminServiceProvider).updateStatus(
            id,
            status,
            reason: reason,
            assignedTo: assignedTo,
            scheduledAt: scheduledAt,
            adminNotes: adminNotes,
          );
      ref.invalidate(adminCallbacksProvider);
      ref.invalidate(adminCallbackStatsProvider);
      ref.invalidate(adminCallbackHistoryProvider(id));
      final list = await ref.read(adminCallbacksProvider.future);
      if (!mounted) return;
      for (final r in list) {
        if (r.id == id) {
          setState(() => _selected = r);
          break;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateCallbackDialog(),
    );
    if (result == true) await _refreshAll();
  }

  Widget _buildActiveTab(AsyncValue<List<AdminCallbackRow>> listAsync) {
    switch (_tabIndex) {
      case 0:
        return _RequestsPane(
          listAsync: listAsync,
          statusFilter: _statusFilter,
          search: _search,
          selectedId: _selected?.id,
          onSearch: (v) => setState(() => _search = v.trim().toLowerCase()),
          onSelect: (r) => setState(() => _selected = r),
          onRefresh: _refreshAll,
          onAddRequest: _openCreateDialog,
          onOpenPublic: () =>
              context.go('${RoutePaths.contact}?section=callback'),
        );
      case 1:
        return const _SettingsPane();
      case 2:
        return const _HoursPane();
      case 3:
        return const _CatalogPane();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminCallbacksRealtimeProvider);
    final statsAsync = ref.watch(adminCallbackStatsProvider);
    final listAsync = ref.watch(adminCallbacksProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      backgroundColor: InspectionAdminUi.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: InspectionAdminUi.gold,
              onRefresh: _refreshAll,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _Header(
                          onOpenPublic: () => context
                              .go('${RoutePaths.contact}?section=callback'),
                          onRefresh: _refreshAll,
                          onAdd: _openCreateDialog,
                        ),
                        const SizedBox(height: 10),
                        statsAsync.when(
                          loading: () => const SizedBox(
                            height: AdminOpsStatStrip.height,
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (s) => AdminOpsStatStrip(
                            selectedKey: _statusFilter,
                            onSelect: (key) {
                              setState(() {
                                _statusFilter = key;
                                _tabIndex = 0;
                              });
                            },
                            items: [
                              AdminOpsStatItem(
                                key: 'all',
                                label: 'All',
                                value: s.total,
                                icon: LucideIcons.layers,
                                accent: Colors.white70,
                              ),
                              AdminOpsStatItem(
                                key: 'new',
                                label: 'New',
                                value: s.neu,
                                icon: LucideIcons.sparkles,
                                accent: _Cb.statusColor('new'),
                              ),
                              AdminOpsStatItem(
                                key: 'assigned',
                                label: 'Assigned',
                                value: s.assigned,
                                icon: LucideIcons.userCheck,
                                accent: _Cb.statusColor('assigned'),
                              ),
                              AdminOpsStatItem(
                                key: 'contacted',
                                label: 'Contacted',
                                value: s.contacted,
                                icon: LucideIcons.phoneCall,
                                accent: _Cb.statusColor('contacted'),
                              ),
                              AdminOpsStatItem(
                                key: 'scheduled',
                                label: 'Scheduled',
                                value: s.scheduled,
                                icon: LucideIcons.calendarClock,
                                accent: _Cb.statusColor('scheduled'),
                              ),
                              AdminOpsStatItem(
                                key: 'completed',
                                label: 'Completed',
                                value: s.completed,
                                icon: LucideIcons.badgeCheck,
                                accent: _Cb.statusColor('completed'),
                              ),
                              AdminOpsStatItem(
                                key: 'cancelled',
                                label: 'Cancelled',
                                value: s.cancelled,
                                icon: LucideIcons.xCircle,
                                accent: _Cb.statusColor('cancelled'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        AdminOpsPageTabs(
                          labels: _tabLabels,
                          index: _tabIndex,
                          onChanged: (i) => setState(() => _tabIndex = i),
                        ),
                        const SizedBox(height: 10),
                        _buildActiveTab(listAsync),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selected != null && wide)
            SizedBox(
              width: 400,
              child: _DetailPanel(
                row: _selected!,
                onClose: () => setState(() => _selected = null),
                onStatus: _updateStatus,
              ),
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
                    child: _DetailPanel(
                      row: _selected!,
                      onClose: () {
                        Navigator.pop(context);
                        setState(() => _selected = null);
                      },
                      onStatus: _updateStatus,
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
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onOpenPublic,
    required this.onRefresh,
    required this.onAdd,
  });

  final VoidCallback onOpenPublic;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;

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
                const Row(
                  children: [
                    Text(
                      'CALLBACKS',
                      style: TextStyle(
                        color: InspectionAdminUi.gold,
                        letterSpacing: 2.4,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 10),
                    InspectionLiveBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Callback command center',
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
            label: const Text('Public form'),
            style: OutlinedButton.styleFrom(
              foregroundColor: InspectionAdminUi.gold,
              side: BorderSide(
                color: InspectionAdminUi.gold.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(width: 6),
          PermissionGate(
            permission: PermissionSlugs.callbacksManage,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('Add request'),
              style: FilledButton.styleFrom(
                backgroundColor: InspectionAdminUi.gold,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = _Cb.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RequestsPane extends StatelessWidget {
  const _RequestsPane({
    required this.listAsync,
    required this.statusFilter,
    required this.search,
    required this.selectedId,
    required this.onSearch,
    required this.onSelect,
    required this.onRefresh,
    required this.onAddRequest,
    required this.onOpenPublic,
  });

  final AsyncValue<List<AdminCallbackRow>> listAsync;
  final String statusFilter;
  final String search;
  final String? selectedId;
  final ValueChanged<String> onSearch;
  final ValueChanged<AdminCallbackRow> onSelect;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddRequest;
  final VoidCallback onOpenPublic;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: onSearch,
          style: const TextStyle(color: Colors.white),
          decoration: InspectionAdminUi.fieldDecoration(
            'Search requests',
            hint: 'Name, phone, reference, department…',
            compact: true,
            prefix: const Icon(
              LucideIcons.search,
              size: 16,
              color: InspectionAdminUi.muted,
            ),
          ),
        ),
        const SizedBox(height: 10),
        listAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userFacingError(e),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                TextButton(onPressed: onRefresh, child: const Text('Retry')),
              ],
            ),
          ),
          data: (rows) {
            final filtered = rows.where((r) {
              if (statusFilter != 'all' && r.status != statusFilter) {
                return false;
              }
              if (search.isEmpty) return true;
              final hay = [
                r.referenceNumber,
                r.fullName,
                r.phone,
                r.email,
                r.departmentName,
                r.priorityName,
                r.assignedToName,
              ].whereType<String>().join(' ').toLowerCase();
              return hay.contains(search);
            }).toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _Cb.elevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _Cb.border),
                        ),
                        child: Icon(
                          LucideIcons.phoneCall,
                          size: 32,
                          color: _Cb.gold.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        statusFilter == 'all'
                            ? 'No callback requests yet'
                            : 'No “$statusFilter” requests',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'When someone submits the public contact callback form, it appears here in realtime. You can also add a request manually.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _Cb.muted, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: onAddRequest,
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Add request'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _Cb.gold,
                              foregroundColor: AppColors.charcoal,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: onOpenPublic,
                            icon: const Icon(LucideIcons.externalLink, size: 16),
                            label: const Text('Public form'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _Cb.gold,
                              side: BorderSide(
                                color: _Cb.gold.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: onRefresh,
                            icon: const Icon(LucideIcons.refreshCw, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final r = filtered[i];
                final selected = r.id == selectedId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected ? _Cb.elevated : _Cb.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelect(r),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? _Cb.gold.withValues(alpha: 0.45)
                                : _Cb.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _Cb.statusColor(r.status)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                LucideIcons.phoneCall,
                                size: 18,
                                color: _Cb.statusColor(r.status),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      r.referenceNumber,
                                      r.departmentName ?? 'General',
                                      r.priorityName ?? 'Normal',
                                      DateFormat('d MMM, HH:mm')
                                          .format(r.createdAt.toLocal()),
                                    ].join(' · '),
                                    style: const TextStyle(
                                      color: _Cb.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (r.assignedToName != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Assigned: ${r.assignedToName}',
                                      style: const TextStyle(
                                        color: _Cb.gold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            _StatusBadge(r.status),
                          ],
                        ),
                      ),
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

class _DetailPanel extends ConsumerStatefulWidget {
  const _DetailPanel({
    required this.row,
    required this.onClose,
    required this.onStatus,
  });

  final AdminCallbackRow row;
  final VoidCallback onClose;
  final Future<void> Function(
    String id,
    String status, {
    String? reason,
    String? assignedTo,
    DateTime? scheduledAt,
    String? adminNotes,
  }) onStatus;

  @override
  ConsumerState<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends ConsumerState<_DetailPanel> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.row.adminNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant _DetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.id != widget.row.id ||
        oldWidget.row.adminNotes != widget.row.adminNotes) {
      _notes.text = widget.row.adminNotes ?? '';
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    final staff = await ref.read(adminCallbackStaffProvider.future);
    if (!mounted) return;
    String? selected = widget.row.assignedTo ??
        (staff.isNotEmpty ? staff.first.id : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _Cb.surface,
          title: const Text('Assign staff', style: TextStyle(color: Colors.white)),
          content: staff.isEmpty
              ? const Text(
                  'No staff profiles with active roles found.',
                  style: TextStyle(color: _Cb.muted),
                )
              : DropdownButtonFormField<String>(
                  value: selected,
                  dropdownColor: _Cb.elevated,
                  decoration: _Cb.field('Assignee'),
                  items: staff
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => selected = v),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _Cb.gold),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && selected != null) {
      await widget.onStatus(
        widget.row.id,
        'assigned',
        reason: 'Assigned by admin',
        assignedTo: selected,
      );
    }
  }

  Future<void> _schedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.row.scheduledAt?.toLocal() ??
          DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        widget.row.scheduledAt?.toLocal() ??
            DateTime.now().add(const Duration(hours: 2)),
      ),
    );
    if (time == null) return;
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await widget.onStatus(
      widget.row.id,
      'scheduled',
      reason: 'Scheduled callback',
      scheduledAt: scheduled,
    );
  }

  Future<void> _saveNotes() async {
    await widget.onStatus(
      widget.row.id,
      widget.row.status,
      reason: 'Admin notes updated',
      adminNotes: _notes.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final historyAsync = ref.watch(adminCallbackHistoryProvider(row.id));

    return Container(
      decoration: BoxDecoration(
        color: _Cb.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Cb.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Request detail',
                      style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(LucideIcons.x, color: _Cb.muted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    _StatusBadge(row.status),
                  ],
                ),
                const SizedBox(height: 8),
                _kv('Reference', row.referenceNumber),
                _kv('Phone', row.phone),
                if (row.email != null) _kv('Email', row.email!),
                _kv('Department', row.departmentName ?? 'General'),
                _kv('Priority', row.priorityName ?? 'Normal'),
                _kv('Preferred time', row.preferredTime ?? '—'),
                if (row.assignedToName != null)
                  _kv('Assignee', row.assignedToName!),
                if (row.scheduledAt != null)
                  _kv(
                    'Scheduled',
                    DateFormat.yMMMd().add_jm().format(row.scheduledAt!.toLocal()),
                  ),
                _kv('Submitted',
                    DateFormat.yMMMd().add_jm().format(row.createdAt.toLocal())),
                const SizedBox(height: 8),
                const Text('Reason',
                    style: TextStyle(color: _Cb.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(row.reason, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: _Cb.field('Admin notes'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saveNotes,
                    child: const Text('Save notes'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Workflow',
                    style: TextStyle(
                    color: _Cb.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                PermissionGate(
                  permission: PermissionSlugs.callbacksManage,
                  child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                      _ActionChip(
                        label: 'Assign',
                        icon: LucideIcons.userPlus,
                        onTap: _assign,
                      ),
                      _ActionChip(
                        label: 'Contacted',
                        icon: LucideIcons.phone,
                        onTap: () => widget.onStatus(
                          row.id,
                          'contacted',
                          reason: 'Customer contacted',
                        ),
                      ),
                      _ActionChip(
                        label: 'Schedule',
                        icon: LucideIcons.calendar,
                        onTap: _schedule,
                      ),
                      _ActionChip(
                        label: 'Complete',
                        icon: LucideIcons.checkCircle2,
                        onTap: () => widget.onStatus(
                          row.id,
                          'completed',
                          reason: 'Completed',
                        ),
                      ),
                      _ActionChip(
                        label: 'Cancel',
                        icon: LucideIcons.xCircle,
                        danger: true,
                        onTap: () => widget.onStatus(
                          row.id,
                          'cancelled',
                          reason: 'Cancelled by admin',
                        ),
                      ),
                      _ActionChip(
                        label: 'Call',
                        icon: LucideIcons.phoneCall,
                        onTap: () => launchUrl(Uri.parse('tel:${row.phone}')),
                    ),
                  ],
                ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Activity',
                  style: TextStyle(
                    color: _Cb.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                historyAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (history) {
                    if (history.isEmpty) {
                      return const Text(
                        'No status history yet.',
                        style: TextStyle(color: _Cb.muted, fontSize: 12),
                      );
                    }
                    return Column(
                    children: [
                      for (final h in history)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: _Cb.statusColor(h.toStatus),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                          child: Text(
                                    [
                                      if (h.changedAt != null)
                                        DateFormat('d MMM HH:mm')
                                            .format(h.changedAt!.toLocal()),
                                      '${h.fromStatus ?? '—'} → ${h.toStatus}',
                                      if (h.reason != null) h.reason!,
                                    ].join(' · '),
                            style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: _Cb.muted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFEF4444) : _Cb.gold;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SettingsPane extends ConsumerStatefulWidget {
  const _SettingsPane();

  @override
  ConsumerState<_SettingsPane> createState() => _SettingsPaneState();
}

class _SettingsPaneState extends ConsumerState<_SettingsPane> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _cta = TextEditingController();
  final _successTitle = TextEditingController();
  final _successMessage = TextEditingController();
  final _trustSecurity = TextEditingController();
  final _trustResponse = TextEditingController();
  final _trustExpert = TextEditingController();
  final _afterHours = TextEditingController();
  final _timezone = TextEditingController();
  final _preferredTimes = TextEditingController();
  final _responseHours = TextEditingController();
  String? _loadedId;
  bool _enabled = true;
  bool _showAvailable = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _cta.dispose();
    _successTitle.dispose();
    _successMessage.dispose();
    _trustSecurity.dispose();
    _trustResponse.dispose();
    _trustExpert.dispose();
    _afterHours.dispose();
    _timezone.dispose();
    _preferredTimes.dispose();
    _responseHours.dispose();
    super.dispose();
  }

  void _hydrate(CallbackSettings s) {
    if (_loadedId == s.id) return;
    _loadedId = s.id;
    _enabled = s.isEnabled;
    _showAvailable = s.showAvailableNow;
    _title.text = s.title;
    _subtitle.text = s.subtitle;
    _cta.text = s.ctaText;
    _successTitle.text = s.successTitle;
    _successMessage.text = s.successMessage;
    _trustSecurity.text = s.trustSecurity;
    _trustResponse.text = s.trustResponse;
    _trustExpert.text = s.trustExpert;
    _afterHours.text = s.afterHoursMessage;
    _timezone.text = s.timezone;
    _preferredTimes.text = s.preferredTimeOptions.join('\n');
    _responseHours.text = '${s.defaultResponseHours}';
  }

  Future<void> _save(CallbackSettings current) async {
    setState(() => _saving = true);
    try {
      final hours = int.tryParse(_responseHours.text.trim()) ?? 24;
      final times = _preferredTimes.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await ref.read(callbackAdminServiceProvider).saveSettings(
            current.copyWith(
              isEnabled: _enabled,
              showAvailableNow: _showAvailable,
              title: _title.text.trim(),
              subtitle: _subtitle.text.trim(),
              ctaText: _cta.text.trim(),
              successTitle: _successTitle.text.trim(),
              successMessage: _successMessage.text.trim(),
              trustSecurity: _trustSecurity.text.trim(),
              trustResponse: _trustResponse.text.trim(),
              trustExpert: _trustExpert.text.trim(),
              afterHoursMessage: _afterHours.text.trim(),
              timezone: _timezone.text.trim().isEmpty
                  ? 'Africa/Lagos'
                  : _timezone.text.trim(),
              defaultResponseHours: hours,
              preferredTimeOptions:
                  times.isEmpty ? current.preferredTimeOptions : times,
            ),
          );
      _loadedId = null;
      ref.invalidate(callbackSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Callback settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(callbackSettingsProvider);
    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userFacingError(e))),
      data: (settings) {
        if (settings == null) {
          return const Center(
            child: Text('No settings found', style: TextStyle(color: _Cb.muted)),
          );
        }
        _hydrate(settings);
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _Cb.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _Cb.border),
              ),
              child: Column(
          children: [
            SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable public callback form',
                  style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'When off, the public form shows unavailable.',
                      style: TextStyle(color: _Cb.muted, fontSize: 12),
                    ),
                    value: _enabled,
                    activeThumbColor: _Cb.gold,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show “available now” cue',
                        style: TextStyle(color: Colors.white)),
                    value: _showAvailable,
                    activeThumbColor: _Cb.gold,
                    onChanged: (v) => setState(() => _showAvailable = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Form copy'),
            TextField(
              controller: _title,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subtitle,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('Subtitle'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cta,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('CTA button text'),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Success state'),
            TextField(
              controller: _successTitle,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('Success title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _successMessage,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('Success message'),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Trust lines'),
            TextField(
              controller: _trustSecurity,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('Security line'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _trustResponse,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('Response line'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _trustExpert,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('Expert line'),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Operations'),
            TextField(
              controller: _afterHours,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field('After-hours message'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _responseHours,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _Cb.field('Default SLA (hours)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _timezone,
                    style: const TextStyle(color: Colors.white),
                    decoration: _Cb.field('Timezone'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _preferredTimes,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: _Cb.field(
                'Preferred time options',
                hint: 'One option per line',
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(settings),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.save, size: 16),
                label: const Text('Save all settings'),
                style: FilledButton.styleFrom(
                  backgroundColor: _Cb.gold,
                  foregroundColor: AppColors.charcoal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t,
          style: const TextStyle(
            color: _Cb.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _HoursPane extends ConsumerWidget {
  const _HoursPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoursAsync = ref.watch(adminCallbackWorkingHoursProvider);
    return hoursAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userFacingError(e))),
      data: (hours) {
        final byDay = {
          for (final h in hours) h.weekday: h,
        };
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
          children: [
            const Text(
              'Working hours control when the public form shows availability. Times are local to the configured timezone (default Africa/Lagos).',
              style: TextStyle(color: _Cb.muted),
            ),
            const SizedBox(height: 16),
            for (var day = 0; day < 7; day++)
              _HourRow(
                weekday: day,
                hour: byDay[day],
            ),
          ],
        );
      },
    );
  }
}

class _HourRow extends ConsumerStatefulWidget {
  const _HourRow({required this.weekday, this.hour});
  final int weekday;
  final CallbackWorkingHour? hour;

  @override
  ConsumerState<_HourRow> createState() => _HourRowState();
}

class _HourRowState extends ConsumerState<_HourRow> {
  late bool _active;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _active = widget.hour?.isActive ?? (widget.weekday >= 1 && widget.weekday <= 5);
    _start = _parse(widget.hour?.startTime ?? '09:00');
    _end = _parse(widget.hour?.endTime ?? '17:00');
  }

  TimeOfDay _parse(String t) {
    final parts = t.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _end);
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _save() async {
    final existing = widget.hour;
    final hour = CallbackWorkingHour(
      id: existing?.id ?? '',
      weekday: widget.weekday,
      startTime: _fmt(_start),
      endTime: _fmt(_end),
      isActive: _active,
    );
    try {
      await ref.read(callbackAdminServiceProvider).saveWorkingHour(hour);
      ref.invalidate(adminCallbackWorkingHoursProvider);
      ref.invalidate(callbackWorkingHoursProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_Cb.weekdays[widget.weekday]} saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Cb.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Cb.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _Cb.weekdays[widget.weekday],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: _active,
            activeThumbColor: _Cb.gold,
            onChanged: (v) => setState(() => _active = v),
          ),
          TextButton(
            onPressed: _active ? _pickStart : null,
            child: Text(_fmt(_start)),
          ),
          const Text('–', style: TextStyle(color: _Cb.muted)),
          TextButton(
            onPressed: _active ? _pickEnd : null,
            child: Text(_fmt(_end)),
          ),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: _Cb.gold,
              foregroundColor: AppColors.charcoal,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _CatalogPane extends ConsumerWidget {
  const _CatalogPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(adminCallbackDepartmentsProvider);
    final prioritiesAsync = ref.watch(adminCallbackPrioritiesProvider);

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
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
                      color: _Cb.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Shown on the public callback form. Toggle off to hide from visitors.',
                    style: TextStyle(color: _Cb.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _editDepartment(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add department'),
              style: FilledButton.styleFrom(
                backgroundColor: _Cb.gold,
                foregroundColor: AppColors.charcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        deptsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(userFacingError(e)),
          data: (depts) {
            final sorted = [...depts]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            return Column(
            children: [
                for (var i = 0; i < sorted.length; i++)
                  _CatalogTile(
                    title: sorted[i].name,
                    subtitle:
                        '${sorted[i].description ?? sorted[i].slug} · SLA ${sorted[i].responseHours}h',
                    active: sorted[i].isActive,
                    onToggle: (v) async {
                      await ref.read(callbackAdminServiceProvider).upsertDepartment(
                            id: sorted[i].id,
                            name: sorted[i].name,
                            description: sorted[i].description,
                            icon: sorted[i].icon,
                            responseHours: sorted[i].responseHours,
                            sortOrder: sorted[i].sortOrder,
                          isActive: v,
                          );
                      ref.invalidate(adminCallbackDepartmentsProvider);
                      ref.invalidate(callbackDepartmentsProvider);
                    },
                    onEdit: () => _editDepartment(context, ref, sorted[i]),
                    onMoveUp: i == 0
                        ? null
                        : () async {
                            final next = [...sorted];
                            final tmp = next[i - 1];
                            next[i - 1] = next[i];
                            next[i] = tmp;
                            await ref
                                .read(callbackAdminServiceProvider)
                                .reorderDepartments(next);
                            ref.invalidate(adminCallbackDepartmentsProvider);
                            ref.invalidate(callbackDepartmentsProvider);
                          },
                    onMoveDown: i == sorted.length - 1
                        ? null
                        : () async {
                            final next = [...sorted];
                            final tmp = next[i + 1];
                            next[i + 1] = next[i];
                            next[i] = tmp;
                            await ref
                                .read(callbackAdminServiceProvider)
                                .reorderDepartments(next);
                    ref.invalidate(adminCallbackDepartmentsProvider);
                    ref.invalidate(callbackDepartmentsProvider);
                  },
                ),
            ],
            );
          },
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Priorities',
                style: TextStyle(
                  color: _Cb.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _editPriority(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add priority'),
              style: FilledButton.styleFrom(
                backgroundColor: _Cb.gold,
                foregroundColor: AppColors.charcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        prioritiesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (priorities) {
            final sorted = [...priorities]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            return Column(
            children: [
                for (var i = 0; i < sorted.length; i++)
                  _CatalogTile(
                    title: sorted[i].name,
                    subtitle:
                        '${sorted[i].description ?? sorted[i].slug} · Response ${sorted[i].responseHours}h',
                    active: sorted[i].isActive,
                    onToggle: (v) async {
                      await ref.read(callbackAdminServiceProvider).upsertPriority(
                            id: sorted[i].id,
                            name: sorted[i].name,
                            description: sorted[i].description,
                            responseHours: sorted[i].responseHours,
                            sortOrder: sorted[i].sortOrder,
                          isActive: v,
                          );
                      ref.invalidate(adminCallbackPrioritiesProvider);
                      ref.invalidate(callbackPrioritiesProvider);
                    },
                    onEdit: () => _editPriority(context, ref, sorted[i]),
                    onMoveUp: i == 0
                        ? null
                        : () async {
                            final next = [...sorted];
                            final tmp = next[i - 1];
                            next[i - 1] = next[i];
                            next[i] = tmp;
                            await ref
                                .read(callbackAdminServiceProvider)
                                .reorderPriorities(next);
                            ref.invalidate(adminCallbackPrioritiesProvider);
                            ref.invalidate(callbackPrioritiesProvider);
                          },
                    onMoveDown: i == sorted.length - 1
                        ? null
                        : () async {
                            final next = [...sorted];
                            final tmp = next[i + 1];
                            next[i + 1] = next[i];
                            next[i] = tmp;
                            await ref
                                .read(callbackAdminServiceProvider)
                                .reorderPriorities(next);
                    ref.invalidate(adminCallbackPrioritiesProvider);
                    ref.invalidate(callbackPrioritiesProvider);
                  },
                ),
            ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _editDepartment(
    BuildContext context,
    WidgetRef ref,
    CallbackDepartment? existing,
  ) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final hours = TextEditingController(
      text: '${existing?.responseHours ?? 24}',
    );
    var active = existing?.isActive ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _Cb.surface,
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
                  decoration: _Cb.field('Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: desc,
                  style: const TextStyle(color: Colors.white),
                  decoration: _Cb.field('Description'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hours,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _Cb.field('Response hours'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active on public form',
                      style: TextStyle(color: Colors.white)),
                  value: active,
                  activeThumbColor: _Cb.gold,
                  onChanged: (v) => setLocal(() => active = v),
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
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _Cb.gold),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await ref.read(callbackAdminServiceProvider).upsertDepartment(
          id: existing?.id,
          name: name.text,
          description: desc.text,
          responseHours: int.tryParse(hours.text.trim()) ?? 24,
          sortOrder: existing?.sortOrder ?? 0,
          isActive: active,
          icon: existing?.icon ?? 'briefcase',
        );
    ref.invalidate(adminCallbackDepartmentsProvider);
    ref.invalidate(callbackDepartmentsProvider);
  }

  Future<void> _editPriority(
    BuildContext context,
    WidgetRef ref,
    CallbackPriority? existing,
  ) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final hours = TextEditingController(
      text: '${existing?.responseHours ?? 24}',
    );
    var active = existing?.isActive ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _Cb.surface,
          title: Text(
            existing == null ? 'Add priority' : 'Edit priority',
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
                  decoration: _Cb.field('Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: desc,
                  style: const TextStyle(color: Colors.white),
                  decoration: _Cb.field('Description'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hours,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _Cb.field('Response hours'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active on public form',
                      style: TextStyle(color: Colors.white)),
                  value: active,
                  activeThumbColor: _Cb.gold,
                  onChanged: (v) => setLocal(() => active = v),
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
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _Cb.gold),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await ref.read(callbackAdminServiceProvider).upsertPriority(
          id: existing?.id,
          name: name.text,
          description: desc.text,
          responseHours: int.tryParse(hours.text.trim()) ?? 24,
          sortOrder: existing?.sortOrder ?? 0,
          isActive: active,
        );
    ref.invalidate(adminCallbackPrioritiesProvider);
    ref.invalidate(callbackPrioritiesProvider);
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onToggle,
    required this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
  });

  final String title;
  final String subtitle;
  final bool active;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _Cb.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Cb.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(color: _Cb.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Move up',
            onPressed: onMoveUp,
            icon: const Icon(LucideIcons.chevronUp, size: 18, color: _Cb.muted),
          ),
          IconButton(
            tooltip: 'Move down',
            onPressed: onMoveDown,
            icon:
                const Icon(LucideIcons.chevronDown, size: 18, color: _Cb.muted),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(LucideIcons.pencil, size: 16, color: _Cb.gold),
          ),
          Switch(
            value: active,
            activeThumbColor: _Cb.gold,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _CreateCallbackDialog extends ConsumerStatefulWidget {
  const _CreateCallbackDialog();

  @override
  ConsumerState<_CreateCallbackDialog> createState() =>
      _CreateCallbackDialogState();
}

class _CreateCallbackDialogState extends ConsumerState<_CreateCallbackDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _reason = TextEditingController();
  String? _departmentId;
  String? _priorityId;
  String? _preferredTime;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _reason.text.trim().isEmpty) {
      setState(() => _error = 'Name, phone, and reason are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(callbackAdminServiceProvider).createManualRequest(
            fullName: _name.text,
            phone: _phone.text,
            reason: _reason.text,
            email: _email.text.trim().isEmpty ? null : _email.text,
            preferredTime: _preferredTime,
            departmentId: _departmentId,
            priorityId: _priorityId,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = userFacingError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(adminCallbackDepartmentsProvider).valueOrNull ?? [];
    final priorities =
        ref.watch(adminCallbackPrioritiesProvider).valueOrNull ?? [];
    final settings = ref.watch(callbackSettingsProvider).valueOrNull;
    final times = settings?.preferredTimeOptions ?? const <String>[];

    return AlertDialog(
      backgroundColor: _Cb.surface,
      title: const Text('Add callback request',
          style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                style: const TextStyle(color: Colors.white),
                decoration: _Cb.field('Full name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                style: const TextStyle(color: Colors.white),
                decoration: _Cb.field('Phone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _email,
                style: const TextStyle(color: Colors.white),
                decoration: _Cb.field('Email (optional)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _departmentId,
                dropdownColor: _Cb.elevated,
                decoration: _Cb.field('Department'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('General')),
                  ...depts
                      .where((d) => d.isActive)
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.name),
                        ),
                      ),
                ],
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _priorityId,
                dropdownColor: _Cb.elevated,
                decoration: _Cb.field('Priority'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Default')),
                  ...priorities
                      .where((p) => p.isActive)
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      ),
                ],
                onChanged: (v) => setState(() => _priorityId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _preferredTime,
                dropdownColor: _Cb.elevated,
                decoration: _Cb.field('Preferred time'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Anytime')),
                  ...times.map(
                    (t) => DropdownMenuItem(value: t, child: Text(t)),
                  ),
                ],
                onChanged: (v) => setState(() => _preferredTime = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _Cb.field('Reason'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _Cb.gold),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
