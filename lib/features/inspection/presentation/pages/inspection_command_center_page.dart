import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_admin_models.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_admin_providers.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_admin_shared.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_booking_editor_sheet.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/property_inspection_config_panel.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class InspectionCommandCenterPage extends ConsumerStatefulWidget {
  const InspectionCommandCenterPage({super.key});

  @override
  ConsumerState<InspectionCommandCenterPage> createState() =>
      _InspectionCommandCenterPageState();
}

class _InspectionCommandCenterPageState
    extends ConsumerState<InspectionCommandCenterPage> {
  static const _tabLabels = [
    'Bookings',
    'Calendar',
    'Availability',
    'Agents',
    'Properties',
  ];

  int _tabIndex = 0;
  String _statusFilter = 'all';
  String _search = '';
  AdminInspectionRow? _selected;
  DateTime _calendarDay = DateTime.now();

  void _invalidateAll() {
    ref.invalidate(adminInspectionsProvider);
    ref.invalidate(adminInspectionStatsProvider);
    ref.invalidate(adminInspectionSettingsProvider);
    ref.invalidate(adminInspectionWorkingHoursProvider);
    ref.invalidate(adminInspectionHolidaysProvider);
    ref.invalidate(adminInspectionBlockedSlotsProvider);
    ref.invalidate(adminInspectionAgentsProvider);
  }

  void _syncSelected(List<AdminInspectionRow> rows) {
    final id = _selected?.id;
    if (id == null) return;
    AdminInspectionRow? updated;
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

  Future<void> _refreshSelected(String id) async {
    final list = await ref.read(adminInspectionsProvider.future);
    AdminInspectionRow? updated;
    for (final r in list) {
      if (r.id == id) {
        updated = r;
        break;
      }
    }
    if (mounted) setState(() => _selected = updated);
  }

  Future<void> _updateStatus(
    String id,
    String status, {
    String? reason,
    String? meetingUrl,
  }) async {
    await ref.read(inspectionAdminServiceProvider).updateStatus(
          id,
          status,
          reason: reason,
          meetingUrl: meetingUrl,
        );
    _invalidateAll();
    if (_selected?.id == id) await _refreshSelected(id);
  }

  Future<void> _openEditor({AdminInspectionRow? row, DateTime? day}) async {
    final saved = await showInspectionBookingEditor(
      context: context,
      ref: ref,
      existing: row,
      initialDay: day,
    );
    if (!saved) return;
    _invalidateAll();
    if (row != null) await _refreshSelected(row.id);
  }

  Future<void> _deleteInspection(AdminInspectionRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: InspectionAdminUi.surfaceElevated,
        title: const Text(
          'Delete inspection?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Permanently remove ${row.reference ?? row.visitorName ?? 'this booking'}?',
          style: const TextStyle(color: InspectionAdminUi.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(inspectionAdminServiceProvider).deleteInspection(row.id);
    if (_selected?.id == row.id) setState(() => _selected = null);
    _invalidateAll();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminInspectionsRealtimeProvider);
    final liveTick = ref.watch(adminInspectionsLiveTickProvider);
    final statsAsync = ref.watch(adminInspectionStatsProvider);
    final inspectionsAsync = ref.watch(adminInspectionsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    inspectionsAsync.whenData(_syncSelected);

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
                              context.go(RoutePaths.bookInspection),
                          onNewBooking: () => _openEditor(),
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
                        _buildActiveTab(inspectionsAsync),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selected != null && wide)
            _DetailPanel(
              row: _selected!,
              onClose: () => setState(() => _selected = null),
              onStatus: _updateStatus,
              onEdit: () => _openEditor(row: _selected),
              onDelete: () => _deleteInspection(_selected!),
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
                      onEdit: () async {
                        Navigator.pop(context);
                        await _openEditor(row: _selected);
                      },
                      onDelete: () async {
                        Navigator.pop(context);
                        await _deleteInspection(_selected!);
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

  Widget _buildActiveTab(AsyncValue<List<AdminInspectionRow>> inspectionsAsync) {
    switch (_tabIndex) {
      case 0:
        return _BookingsTab(
          inspectionsAsync: inspectionsAsync,
          statusFilter: _statusFilter,
          search: _search,
          selectedId: _selected?.id,
          onStatusFilter: (v) => setState(() => _statusFilter = v),
          onSearch: (v) => setState(() => _search = v.trim().toLowerCase()),
          onSelect: (row) => setState(() => _selected = row),
          onEdit: (row) => _openEditor(row: row),
          onDelete: _deleteInspection,
          onStatus: _updateStatus,
          onNew: () => _openEditor(),
        );
      case 1:
        return _CalendarTab(
          inspectionsAsync: inspectionsAsync,
          day: _calendarDay,
          onDayChanged: (d) => setState(() => _calendarDay = d),
          onSelect: (row) => setState(() => _selected = row),
          onAddForDay: () => _openEditor(day: _calendarDay),
          onEdit: (row) => _openEditor(row: row),
          onDelete: _deleteInspection,
          onStatus: _updateStatus,
        );
      case 2:
        return const _AvailabilityTab();
      case 3:
        return const _AgentsTab();
      case 4:
        return const _PropertiesTab();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.liveTick,
    required this.onOpenPublic,
    required this.onNewBooking,
    required this.onRefresh,
  });

  final int liveTick;
  final VoidCallback onOpenPublic;
  final VoidCallback onNewBooking;
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
                      'INSPECTIONS',
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
                  'Inspection command center',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
          const SizedBox(width: 6),
          PermissionGateAny(
            permissions: const [
              PermissionSlugs.propertiesInspections,
              PermissionSlugs.propertiesWrite,
            ],
            child: FilledButton.icon(
              onPressed: onNewBooking,
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('New booking'),
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.stats,
    required this.selected,
    required this.onSelect,
  });

  final AdminInspectionStats stats;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return AdminOpsStatStrip(
      selectedKey: selected,
      onSelect: (key) {
        if (key == 'today' || key == 'upcoming') {
          onSelect('all');
        } else {
          onSelect(key);
        }
      },
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
          key: 'scheduled',
          label: 'Pending',
          value: stats.scheduled,
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
        AdminOpsStatItem(
          key: 'no_show',
          label: 'No-show',
          value: stats.noShow,
          icon: LucideIcons.userX,
          accent: const Color(0xFFF59E0B),
        ),
      ],
    );
  }
}

class _BookingsTab extends StatelessWidget {
  const _BookingsTab({
    required this.inspectionsAsync,
    required this.statusFilter,
    required this.search,
    required this.selectedId,
    required this.onStatusFilter,
    required this.onSearch,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
    required this.onNew,
  });

  final AsyncValue<List<AdminInspectionRow>> inspectionsAsync;
  final String statusFilter;
  final String search;
  final String? selectedId;
  final ValueChanged<String> onStatusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<AdminInspectionRow> onSelect;
  final ValueChanged<AdminInspectionRow> onEdit;
  final Future<void> Function(AdminInspectionRow) onDelete;
  final Future<void> Function(String id, String status,
      {String? reason, String? meetingUrl}) onStatus;
  final VoidCallback onNew;

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
                  'Search customer, property, reference…',
                  prefix: const Icon(LucideIcons.search, size: 16),
                  compact: true,
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: onSearch,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onNew,
              style: FilledButton.styleFrom(
                backgroundColor: InspectionAdminUi.gold,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final item in [
                ('all', 'All'),
                ('scheduled', 'Pending'),
                ('confirmed', 'Confirmed'),
                ('completed', 'Completed'),
                ('cancelled', 'Cancelled'),
                ('no_show', 'No-show'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InspectionFilterChip(
                    label: item.$2,
                    selected: statusFilter == item.$1,
                    onTap: () => onStatusFilter(item.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        inspectionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Error: $e',
            style: const TextStyle(color: Colors.redAccent),
          ),
          data: (rows) {
            final filtered = rows.where((r) {
              if (statusFilter != 'all' && r.status != statusFilter) {
                return false;
              }
              if (search.isEmpty) return true;
              final hay = [
                r.reference,
                r.visitorName,
                r.visitorEmail,
                r.visitorPhone,
                r.propertyTitle,
              ].whereType<String>().join(' ').toLowerCase();
              return hay.contains(search);
            }).toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.calendarOff,
                      color: Colors.white24,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No inspections match your filters.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onNew,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Create first booking'),
                      style: FilledButton.styleFrom(
                        backgroundColor: InspectionAdminUi.gold,
                        foregroundColor: Colors.black,
                      ),
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
                return _InspectionListTile(
                  row: row,
                  selected: row.id == selectedId,
                  onTap: () => onSelect(row),
                  onEdit: () => onEdit(row),
                  onDelete: () => onDelete(row),
                  onConfirm: row.status == 'scheduled'
                      ? () => onStatus(row.id, 'confirmed')
                      : null,
                  onCancel: row.status != 'cancelled' &&
                          row.status != 'completed'
                      ? () => onStatus(
                            row.id,
                            'cancelled',
                            reason: 'Cancelled by admin',
                          )
                      : null,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({
    required this.inspectionsAsync,
    required this.day,
    required this.onDayChanged,
    required this.onSelect,
    required this.onAddForDay,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });

  final AsyncValue<List<AdminInspectionRow>> inspectionsAsync;
  final DateTime day;
  final ValueChanged<DateTime> onDayChanged;
  final ValueChanged<AdminInspectionRow> onSelect;
  final VoidCallback onAddForDay;
  final ValueChanged<AdminInspectionRow> onEdit;
  final Future<void> Function(AdminInspectionRow) onDelete;
  final Future<void> Function(String id, String status,
      {String? reason, String? meetingUrl}) onStatus;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM yyyy');
    final weekStart = day.subtract(Duration(days: day.weekday % 7));
    final rows = inspectionsAsync.valueOrNull ?? const <AdminInspectionRow>[];

    int countFor(DateTime d) {
      final start = DateTime(d.year, d.month, d.day);
      final end = start.add(const Duration(days: 1));
      return rows
          .where((r) =>
              !r.scheduledAt.toLocal().isBefore(start) &&
              r.scheduledAt.toLocal().isBefore(end))
          .length;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () =>
                  onDayChanged(day.subtract(const Duration(days: 1))),
              icon: const Icon(LucideIcons.chevronLeft, color: Colors.white70),
            ),
            Text(
              fmt.format(day),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            IconButton(
              onPressed: () => onDayChanged(day.add(const Duration(days: 1))),
              icon: const Icon(LucideIcons.chevronRight, color: Colors.white70),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => onDayChanged(DateTime.now()),
              child: const Text('Today'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAddForDay,
              icon: const Icon(LucideIcons.plus, size: 14),
              label: const Text('Schedule'),
              style: FilledButton.styleFrom(
                backgroundColor: InspectionAdminUi.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = weekStart.add(Duration(days: i));
              final selected = d.year == day.year &&
                  d.month == day.month &&
                  d.day == day.day;
              final count = countFor(d);
              return InkWell(
                onTap: () => onDayChanged(d),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? InspectionAdminUi.gold.withValues(alpha: 0.18)
                        : InspectionAdminUi.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? InspectionAdminUi.gold
                          : InspectionAdminUi.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E').format(d),
                        style: TextStyle(
                          color: selected
                              ? InspectionAdminUi.gold
                              : InspectionAdminUi.muted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: InspectionAdminUi.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: InspectionAdminUi.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        inspectionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(userFacingError(e)),
          data: (allRows) {
            final dayStart = DateTime(day.year, day.month, day.day);
            final dayEnd = dayStart.add(const Duration(days: 1));
            final dayRows = allRows
                .where((r) =>
                    !r.scheduledAt.toLocal().isBefore(dayStart) &&
                    r.scheduledAt.toLocal().isBefore(dayEnd))
                .toList()
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

            if (dayRows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.calendarDays,
                      color: Colors.white24,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No inspections scheduled for this day.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onAddForDay,
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: const Text('Schedule one'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InspectionAdminUi.gold,
                        side: BorderSide(
                          color: InspectionAdminUi.gold.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayRows.length,
                itemBuilder: (_, i) {
                  final row = dayRows[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: InspectionAdminUi.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: InspectionAdminUi.border),
                    ),
                    child: ListTile(
                      onTap: () => onSelect(row),
                      leading: Container(
                        width: 64,
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat('h:mm a')
                              .format(row.scheduledAt.toLocal()),
                          style: const TextStyle(
                            color: InspectionAdminUi.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        row.propertyTitle ?? 'Inspection',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${row.visitorName ?? 'Guest'} · ${row.inspectionType.replaceAll('_', ' ')}',
                        style: const TextStyle(
                          color: InspectionAdminUi.muted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InspectionStatusBadge(status: row.status),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => onEdit(row),
                            icon: const Icon(
                              LucideIcons.pencil,
                              size: 16,
                              color: Colors.white54,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => onDelete(row),
                            icon: const Icon(
                              LucideIcons.trash2,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
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

class _AvailabilityTab extends ConsumerStatefulWidget {
  const _AvailabilityTab();

  @override
  ConsumerState<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends ConsumerState<_AvailabilityTab> {
  String? _toast;

  Future<void> _withFeedback(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      setState(() => _toast = 'Saved');
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _toast = null);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminInspectionSettingsProvider);
    final hoursAsync = ref.watch(adminInspectionWorkingHoursProvider);
    final holidaysAsync = ref.watch(adminInspectionHolidaysProvider);
    final blockedAsync = ref.watch(adminInspectionBlockedSlotsProvider);
    final propertiesAsync = ref.watch(adminInspectionPropertyOptionsProvider);

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            settingsAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => InspectionAdminCard(
                title: 'Global settings',
                subtitle: 'Using defaults — remote load failed',
                child: _SettingsEditor(
                  settings: const InspectionSettingsRow(
                    id: 'inspection-settings-default',
                  ),
                  onSave: (s) => _withFeedback(() async {
                    await ref
                        .read(inspectionAdminServiceProvider)
                        .saveSettings(s);
                    ref.invalidate(adminInspectionSettingsProvider);
                  }),
                ),
              ),
              data: (settings) {
                final resolved = settings ??
                    const InspectionSettingsRow(
                      id: 'inspection-settings-default',
                    );
                return InspectionAdminCard(
                  title: 'Global settings',
                  subtitle:
                      'Controls public booking slots, notice windows, and timezone',
                  child: _SettingsEditor(
                    settings: resolved,
                    onSave: (s) => _withFeedback(() async {
                      await ref
                          .read(inspectionAdminServiceProvider)
                          .saveSettings(s);
                      ref.invalidate(adminInspectionSettingsProvider);
                    }),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final dual = c.maxWidth > 900;
                final hours = hoursAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const Text(
                    'Working hours unavailable.',
                    style: TextStyle(color: InspectionAdminUi.muted),
                  ),
                  data: (h) => InspectionAdminCard(
                    title: 'Working hours',
                    subtitle: 'Open days and editable start / end times',
                    child: _WorkingHoursEditor(
                      hours: h,
                      onSave: (hour) => _withFeedback(() async {
                        await ref
                            .read(inspectionAdminServiceProvider)
                            .saveWorkingHour(hour);
                        ref.invalidate(adminInspectionWorkingHoursProvider);
                      }),
                    ),
                  ),
                );
                final holidays = holidaysAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (list) => InspectionAdminCard(
                    title: 'Holidays',
                    subtitle: 'Closed dates override working hours',
                    child: _HolidaysEditor(
                      holidays: list,
                      onAdd: (d, n) => _withFeedback(() async {
                        await ref
                            .read(inspectionAdminServiceProvider)
                            .addHoliday(d, n);
                        ref.invalidate(adminInspectionHolidaysProvider);
                      }),
                      onUpdate: (id, d, n) => _withFeedback(() async {
                        await ref
                            .read(inspectionAdminServiceProvider)
                            .updateHoliday(id: id, date: d, name: n);
                        ref.invalidate(adminInspectionHolidaysProvider);
                      }),
                      onDelete: (id) => _withFeedback(() async {
                        await ref
                            .read(inspectionAdminServiceProvider)
                            .deleteHoliday(id);
                        ref.invalidate(adminInspectionHolidaysProvider);
                      }),
                    ),
                  ),
                );
                final blocked = blockedAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (list) => InspectionAdminCard(
                    title: 'Blocked slots',
                    subtitle: 'One-off times unavailable for booking',
                    child: _BlockedEditor(
                      slots: list,
                      properties: propertiesAsync.valueOrNull ?? const [],
                      onAdd: (at, reason, propertyId) =>
                          _withFeedback(() async {
                        await ref
                            .read(inspectionAdminServiceProvider)
                            .addBlockedSlot(
                              blockedAt: at,
                              reason: reason,
                              propertyId: propertyId,
                            );
                        ref.invalidate(adminInspectionBlockedSlotsProvider);
                      }),
                      onUpdate: (id, at, reason, propertyId) =>
                          _withFeedback(() async {
                        await ref
                            .read(inspectionAdminServiceProvider)
                            .updateBlockedSlot(
                              id: id,
                              blockedAt: at,
                              reason: reason,
                              propertyId: propertyId,
                            );
                        ref.invalidate(adminInspectionBlockedSlotsProvider);
                      }),
                      onDelete: (id) => _withFeedback(() async {
                        await ref
                            .read(inspectionAdminServiceProvider)
                            .deleteBlockedSlot(id);
                        ref.invalidate(adminInspectionBlockedSlotsProvider);
                      }),
                    ),
                  ),
                );

                if (!dual) {
                  return Column(
                    children: [
                      hours,
                      const SizedBox(height: 12),
                      holidays,
                      const SizedBox(height: 12),
                      blocked,
                    ],
                  );
                }
                return Column(
                  children: [
                    hours,
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: holidays),
                        const SizedBox(width: 12),
                        Expanded(child: blocked),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
        if (_toast != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: Material(
              color: InspectionAdminUi.gold,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  _toast!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsEditor extends StatefulWidget {
  const _SettingsEditor({required this.settings, required this.onSave});
  final InspectionSettingsRow settings;
  final Future<void> Function(InspectionSettingsRow) onSave;

  @override
  State<_SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends State<_SettingsEditor> {
  late int _slotDuration;
  late int _buffer;
  late int _minNotice;
  late int _maxDays;
  late int _maxDaily;
  late int _maxAgentDaily;
  late bool _allowAgentSelection;
  late String _timezone;
  bool _saving = false;

  static const _timezones = [
    'Africa/Lagos',
    'Africa/Accra',
    'Africa/Nairobi',
    'UTC',
    'Europe/London',
    'America/New_York',
  ];

  @override
  void initState() {
    super.initState();
    _sync(widget.settings);
  }

  @override
  void didUpdateWidget(covariant _SettingsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.id != widget.settings.id ||
        oldWidget.settings.updatedFingerprint !=
            widget.settings.updatedFingerprint) {
      _sync(widget.settings);
    }
  }

  void _sync(InspectionSettingsRow s) {
    _slotDuration = s.slotDurationMinutes;
    _buffer = s.bufferMinutes;
    _minNotice = s.minNoticeHours;
    _maxDays = s.maxBookingDays;
    _maxDaily = s.maxDailyInspections;
    _maxAgentDaily = s.maxAgentDailyInspections;
    _allowAgentSelection = s.allowAgentSelection;
    _timezone = s.timezone;
  }

  @override
  Widget build(BuildContext context) {
    final tzItems = {
      ..._timezones,
      if (!_timezones.contains(_timezone)) _timezone,
    }.toList();

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 700 ? 3 : (c.maxWidth > 420 ? 2 : 1);
            final width = (c.maxWidth - (12 * (cols - 1))) / cols;
            final fields = [
              InspectionNumberField(
                label: 'Slot duration (mins)',
                value: _slotDuration,
                onChanged: (v) => setState(() => _slotDuration = v),
              ),
              InspectionNumberField(
                label: 'Buffer (mins)',
                value: _buffer,
                onChanged: (v) => setState(() => _buffer = v),
              ),
              InspectionNumberField(
                label: 'Min notice (hours)',
                value: _minNotice,
                onChanged: (v) => setState(() => _minNotice = v),
              ),
              InspectionNumberField(
                label: 'Max booking window (days)',
                value: _maxDays,
                onChanged: (v) => setState(() => _maxDays = v),
              ),
              InspectionNumberField(
                label: 'Max daily inspections',
                value: _maxDaily,
                onChanged: (v) => setState(() => _maxDaily = v),
              ),
              InspectionNumberField(
                label: 'Max per agent / day',
                value: _maxAgentDaily,
                onChanged: (v) => setState(() => _maxAgentDaily = v),
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final f in fields) SizedBox(width: width, child: f),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    initialValue: _timezone,
                    dropdownColor: InspectionAdminUi.surfaceElevated,
                    decoration: InspectionAdminUi.fieldDecoration('Timezone'),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      for (final tz in tzItems)
                        DropdownMenuItem(value: tz, child: Text(tz)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _timezone = v);
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Allow agent selection on public booking',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          value: _allowAgentSelection,
          activeThumbColor: InspectionAdminUi.gold,
          onChanged: (v) => setState(() => _allowAgentSelection = v),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(
                      widget.settings.copyWith(
                        slotDurationMinutes: _slotDuration,
                        bufferMinutes: _buffer,
                        minNoticeHours: _minNotice,
                        maxBookingDays: _maxDays,
                        maxDailyInspections: _maxDaily,
                        maxAgentDailyInspections: _maxAgentDaily,
                        allowAgentSelection: _allowAgentSelection,
                        timezone: _timezone,
                      ),
                    );
                    if (mounted) setState(() => _saving = false);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: InspectionAdminUi.gold,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(LucideIcons.save, size: 16),
            label: Text(_saving ? 'Saving…' : 'Save settings'),
          ),
        ),
      ],
    );
  }
}

extension on InspectionSettingsRow {
  String get updatedFingerprint =>
      '$slotDurationMinutes-$bufferMinutes-$minNoticeHours-$maxBookingDays-$maxDailyInspections-$maxAgentDailyInspections-$allowAgentSelection-$timezone';
}

class _WorkingHoursEditor extends StatelessWidget {
  const _WorkingHoursEditor({required this.hours, required this.onSave});
  final List<InspectionWorkingHourRow> hours;
  final Future<void> Function(InspectionWorkingHourRow) onSave;

  Future<void> _pickTime(
    BuildContext context, {
    required InspectionWorkingHourRow hour,
    required bool start,
  }) async {
    final parts = (start ? hour.startTime : hour.endTime).split(':');
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
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await onSave(
      hour.copyWith(
        startTime: start ? formatted : null,
        endTime: start ? null : formatted,
        isActive: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final h in hours)
          Container(
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
                        InspectionWorkingHourRow.weekdayLabels[h.weekday],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (h.isActive)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _TimeChip(
                              label: h.startTime,
                              onTap: () =>
                                  _pickTime(context, hour: h, start: true),
                            ),
                            const Text(
                              '→',
                              style: TextStyle(color: InspectionAdminUi.muted),
                            ),
                            _TimeChip(
                              label: h.endTime,
                              onTap: () =>
                                  _pickTime(context, hour: h, start: false),
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
                  value: h.isActive,
                  activeThumbColor: InspectionAdminUi.gold,
                  onChanged: (v) => onSave(h.copyWith(isActive: v)),
                ),
              ],
            ),
          ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.clock, size: 12, color: InspectionAdminUi.gold),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HolidaysEditor extends StatelessWidget {
  const _HolidaysEditor({
    required this.holidays,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  final List<InspectionHolidayRow> holidays;
  final Future<void> Function(DateTime, String) onAdd;
  final Future<void> Function(String, DateTime, String) onUpdate;
  final Future<void> Function(String) onDelete;

  Future<void> _prompt(
    BuildContext context, {
    InspectionHolidayRow? existing,
  }) async {
    var date = existing?.holidayDate ??
        DateTime.now().add(const Duration(days: 30));
    final controller = TextEditingController(text: existing?.name ?? 'Holiday');

    final result = await showDialog<(DateTime, String)>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: InspectionAdminUi.surfaceElevated,
              title: Text(
                existing == null ? 'Add holiday' : 'Edit holiday',
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      DateFormat.yMMMd().format(date),
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      LucideIcons.calendar,
                      color: InspectionAdminUi.gold,
                      size: 18,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 30)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)),
                        initialDate: date,
                      );
                      if (picked != null) setLocal(() => date = picked);
                    },
                  ),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InspectionAdminUi.fieldDecoration('Name'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx, (date, name));
                  },
                  child: Text(existing == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    if (existing == null) {
      await onAdd(result.$1, result.$2);
    } else {
      await onUpdate(existing.id, result.$1, result.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final h in holidays)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(h.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              DateFormat.yMMMd().format(h.holidayDate),
              style: const TextStyle(color: InspectionAdminUi.muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    LucideIcons.pencil,
                    size: 16,
                    color: Colors.white54,
                  ),
                  onPressed: () => _prompt(context, existing: h),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => onDelete(h.id),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _prompt(context),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add holiday'),
          ),
        ),
      ],
    );
  }
}

class _BlockedEditor extends StatelessWidget {
  const _BlockedEditor({
    required this.slots,
    required this.properties,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  final List<InspectionBlockedSlotRow> slots;
  final List<InspectionPropertyOption> properties;
  final Future<void> Function(DateTime, String, String?) onAdd;
  final Future<void> Function(String, DateTime, String, String?) onUpdate;
  final Future<void> Function(String) onDelete;

  Future<void> _prompt(
    BuildContext context, {
    InspectionBlockedSlotRow? existing,
  }) async {
    var at = existing?.blockedAt.toLocal() ??
        DateTime.now().add(const Duration(days: 7, hours: 14));
    final reasonController =
        TextEditingController(text: existing?.reason ?? 'Admin blocked');
    String? propertyId = existing?.propertyId;

    final result = await showDialog<(DateTime, String, String?)>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: InspectionAdminUi.surfaceElevated,
              title: Text(
                existing == null ? 'Block slot' : 'Edit blocked slot',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        DateFormat('EEE, d MMM yyyy • h:mm a').format(at),
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        LucideIcons.calendarClock,
                        color: InspectionAdminUi.gold,
                        size: 18,
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 1)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          initialDate: at,
                        );
                        if (date == null || !ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(at),
                        );
                        if (time == null) return;
                        setLocal(() {
                          at = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InspectionAdminUi.fieldDecoration('Reason'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: propertyId,
                      dropdownColor: InspectionAdminUi.surfaceElevated,
                      decoration: InspectionAdminUi.fieldDecoration(
                        'Scope (optional property)',
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All properties'),
                        ),
                        for (final p in properties)
                          DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.title),
                          ),
                      ],
                      onChanged: (v) => setLocal(() => propertyId = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) return;
                    Navigator.pop(ctx, (at, reason, propertyId));
                  },
                  child: Text(existing == null ? 'Block' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    if (existing == null) {
      await onAdd(result.$1, result.$2, result.$3);
    } else {
      await onUpdate(existing.id, result.$1, result.$2, result.$3);
    }
  }

  String _propertyLabel(String? id) {
    if (id == null) return 'All properties';
    for (final p in properties) {
      if (p.id == id) return p.title;
    }
    return 'Property';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final s in slots)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              DateFormat('EEE, d MMM yyyy • h:mm a')
                  .format(s.blockedAt.toLocal()),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              '${s.reason} · ${_propertyLabel(s.propertyId)}',
              style: const TextStyle(color: InspectionAdminUi.muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    LucideIcons.pencil,
                    size: 16,
                    color: Colors.white54,
                  ),
                  onPressed: () => _prompt(context, existing: s),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => onDelete(s.id),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _prompt(context),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Block slot'),
          ),
        ),
      ],
    );
  }
}

class _AgentsTab extends ConsumerWidget {
  const _AgentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(adminInspectionAgentsProvider);
    final advisorsAsync = ref.watch(adminInspectionAdvisorOptionsProvider);
    final estatesAsync = ref.watch(adminInspectionEstateOptionsProvider);

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
                    'Inspection agents',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Assign advisors, set daily caps, and map estates.',
                    style: TextStyle(
                      color: InspectionAdminUi.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showAddAgentMenu(context, ref, advisorsAsync),
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: const Text('Add agent'),
              style: FilledButton.styleFrom(
                backgroundColor: InspectionAdminUi.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        agentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(userFacingError(e)),
          data: (agents) {
            if (agents.isEmpty) {
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
                      'No inspection agents yet.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showAddAgentMenu(context, ref, advisorsAsync),
                      icon: const Icon(LucideIcons.userPlus, size: 16),
                      label: const Text('Add agent'),
                    ),
                  ],
                ),
              );
            }

            final estates = estatesAsync.valueOrNull ?? const [];
            return LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 1100
                    ? 3
                    : constraints.maxWidth > 700
                        ? 2
                        : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: cols == 1 ? 2.4 : 1.55,
                  ),
                  itemCount: agents.length,
                    itemBuilder: (_, i) {
                      final agent = agents[i];
                      return _AgentCard(
                        agent: agent,
                        estates: estates,
                        onSave: ({
                          required int maxDaily,
                          required bool isActive,
                          List<String>? estateIds,
                        }) async {
                          await ref
                              .read(inspectionAdminServiceProvider)
                              .saveAgent(
                                advisorId: agent.advisorId,
                                maxDailyInspections: maxDaily,
                                isActive: isActive,
                                estateIds: estateIds,
                              );
                          ref.invalidate(adminInspectionAgentsProvider);
                        },
                        onRemove: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor:
                                  InspectionAdminUi.surfaceElevated,
                              title: const Text(
                                'Remove agent?',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                'Remove ${agent.advisorName} from inspection duty?',
                                style: const TextStyle(
                                  color: InspectionAdminUi.muted,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          await ref
                              .read(inspectionAdminServiceProvider)
                              .removeAgent(agent.advisorId);
                          ref.invalidate(adminInspectionAgentsProvider);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Future<void> _showAddAgentMenu(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<InspectionAdvisorOption>> advisorsAsync,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: InspectionAdminUi.surfaceElevated,
        title: const Text(
          'Add inspection agent',
          style: TextStyle(color: Colors.white),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'create'),
            child: const ListTile(
              leading: Icon(LucideIcons.userPlus, color: InspectionAdminUi.gold),
              title: Text(
                'Create new agent',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Add a person and assign them as an inspection agent',
                style: TextStyle(color: InspectionAdminUi.muted, fontSize: 12),
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'existing'),
            child: const ListTile(
              leading: Icon(LucideIcons.users, color: Colors.white70),
              title: Text(
                'Add from advisors',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Assign an existing consultation advisor',
                style: TextStyle(color: InspectionAdminUi.muted, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'create') {
      await _showCreateAgent(context, ref);
    } else {
      await _showAddFromAdvisors(context, ref, advisorsAsync);
    }
  }

  Future<void> _showCreateAgent(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final title = TextEditingController(text: 'Inspection Agent');
    final email = TextEditingController();
    final phone = TextEditingController();
    var maxDaily = 4;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            backgroundColor: InspectionAdminUi.surfaceElevated,
            title: const Text(
              'Create new agent',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 420,
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
                    decoration: InspectionAdminUi.fieldDecoration('Title / role'),
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Max daily inspections',
                          style: TextStyle(color: InspectionAdminUi.muted),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setLocal(() {
                          if (maxDaily > 1) maxDaily--;
                        }),
                        icon: const Icon(LucideIcons.minus, size: 16),
                      ),
                      Text(
                        '$maxDaily',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setLocal(() => maxDaily++),
                        icon: const Icon(LucideIcons.plus, size: 16),
                      ),
                    ],
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
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await ref.read(inspectionAdminServiceProvider).createAdvisorAndAssignAgent(
            fullName: name.text,
            title: title.text,
            email: email.text,
            phone: phone.text,
            maxDailyInspections: maxDaily,
            isActive: true,
            estateIds: const [],
          );
      ref.invalidate(adminInspectionAgentsProvider);
      ref.invalidate(adminInspectionAdvisorOptionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent created')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    }
  }

  Future<void> _showAddFromAdvisors(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<InspectionAdvisorOption>> advisorsAsync,
  ) async {
    final agents = await ref.read(adminInspectionAgentsProvider.future);
    final existing = agents.map((a) => a.advisorId).toSet();
    final advisors = advisorsAsync.valueOrNull
            ?.where((a) => !existing.contains(a.id))
            .toList() ??
        [];
    if (!context.mounted) return;
    if (advisors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All advisors are already agents. Create a new agent instead.',
          ),
        ),
      );
      return;
    }
    final picked = await showDialog<InspectionAdvisorOption>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: InspectionAdminUi.surfaceElevated,
        title: const Text(
          'Add from advisors',
          style: TextStyle(color: Colors.white),
        ),
        children: [
          for (final a in advisors)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, a),
              child: ListTile(
                title: Text(
                  a.fullName,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  a.title ?? 'Advisor',
                  style: const TextStyle(color: InspectionAdminUi.muted),
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await ref.read(inspectionAdminServiceProvider).saveAgent(
          advisorId: picked.id,
          maxDailyInspections: 4,
          isActive: true,
          estateIds: const [],
        );
    ref.invalidate(adminInspectionAgentsProvider);
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.estates,
    required this.onSave,
    required this.onRemove,
  });

  final InspectionAgentRow agent;
  final List<InspectionEstateOption> estates;
  final Future<void> Function({
    required int maxDaily,
    required bool isActive,
    List<String>? estateIds,
  }) onSave;
  final VoidCallback onRemove;

  String get _initials {
    final parts = agent.advisorName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _editEstates(BuildContext context) async {
    final selected = agent.estateIds.toSet();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: InspectionAdminUi.surfaceElevated,
              title: Text(
                'Estates for ${agent.advisorName}',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 420,
                height: 320,
                child: estates.isEmpty
                    ? const Center(
                        child: Text(
                          'No estates found.',
                          style: TextStyle(color: InspectionAdminUi.muted),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final e in estates)
                            CheckboxListTile(
                              value: selected.contains(e.id),
                              activeColor: InspectionAdminUi.gold,
                              title: Text(
                                e.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onChanged: (v) {
                                setLocal(() {
                                  if (v == true) {
                                    selected.add(e.id);
                                  } else {
                                    selected.remove(e.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected.toList()),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    await onSave(
      maxDaily: agent.maxDailyInspections,
      isActive: agent.isActive,
      estateIds: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectionAdminUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: agent.isActive
              ? InspectionAdminUi.gold.withValues(alpha: 0.28)
              : InspectionAdminUi.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      InspectionAdminUi.gold.withValues(alpha: 0.35),
                      InspectionAdminUi.gold.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: InspectionAdminUi.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.advisorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      agent.advisorTitle ?? 'Property advisor',
                      style: const TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: agent.isActive,
                activeThumbColor: InspectionAdminUi.gold,
                onChanged: (v) => onSave(
                  maxDaily: agent.maxDailyInspections,
                  isActive: v,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                onPressed: agent.maxDailyInspections <= 1
                    ? null
                    : () => onSave(
                          maxDaily: agent.maxDailyInspections - 1,
                          isActive: agent.isActive,
                        ),
                icon: const Icon(
                  LucideIcons.minusCircle,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
              Text(
                'Max ${agent.maxDailyInspections}/day',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => onSave(
                  maxDaily: agent.maxDailyInspections + 1,
                  isActive: agent.isActive,
                ),
                icon: const Icon(
                  LucideIcons.plusCircle,
                  size: 18,
                  color: InspectionAdminUi.gold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editEstates(context),
                icon: const Icon(LucideIcons.mapPin, size: 14),
                label: Text(
                  agent.estateIds.isEmpty
                      ? 'Estates'
                      : '${agent.estateIds.length} estates',
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PropertiesTab extends ConsumerStatefulWidget {
  const _PropertiesTab();

  @override
  ConsumerState<_PropertiesTab> createState() => _PropertiesTabState();
}

class _PropertiesTabState extends ConsumerState<_PropertiesTab> {
  String _search = '';
  InspectionPropertyOption? _selected;

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(adminInspectionPropertyOptionsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Property inspection setup',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Enable or disable bookings per property and override global rules.',
          style: TextStyle(
            color: InspectionAdminUi.muted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InspectionAdminUi.fieldDecoration(
            'Search properties…',
            prefix: const Icon(LucideIcons.search, size: 16),
            compact: true,
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 12),
        propertiesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            '$e',
            style: const TextStyle(color: Colors.redAccent),
          ),
          data: (props) {
            final filtered = props
                .where((p) =>
                    _search.isEmpty || p.title.toLowerCase().contains(_search))
                .toList();
            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No properties found.',
                    style: TextStyle(color: InspectionAdminUi.muted),
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                final selected = _selected?.id == p.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? InspectionAdminUi.surfaceElevated
                        : InspectionAdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? InspectionAdminUi.gold.withValues(alpha: 0.45)
                          : InspectionAdminUi.border,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => setState(
                      () => _selected = selected ? null : p,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: InspectionAdminUi.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.building2,
                        size: 18,
                        color: InspectionAdminUi.gold,
                      ),
                    ),
                    title: Text(
                      p.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      selected
                          ? 'Tap again to collapse config'
                          : 'Tap to configure inspection options',
                      style: const TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Icon(
                      selected
                          ? LucideIcons.chevronDown
                          : LucideIcons.settings2,
                      size: 16,
                      color: selected
                          ? InspectionAdminUi.gold
                          : Colors.white38,
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (_selected != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: InspectionAdminUi.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: InspectionAdminUi.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Property config',
                            style: TextStyle(
                              color: InspectionAdminUi.gold,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selected!.title,
                            style: const TextStyle(
                              color: InspectionAdminUi.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => setState(() => _selected = null),
                      icon: const Icon(
                        LucideIcons.x,
                        size: 16,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PropertyInspectionConfigPanel(
                  key: ValueKey(_selected!.id),
                  propertyId: _selected!.id,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({
    required this.row,
    required this.onClose,
    required this.onStatus,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminInspectionRow row;
  final VoidCallback onClose;
  final Future<void> Function(String id, String status,
      {String? reason, String? meetingUrl}) onStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync =
        ref.watch(adminInspectionStatusHistoryProvider(row.id));
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');
    final payload = row.reportPayload;
    final qualification = payload?['qualification'];
    final docs = payload?['document_urls'];

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
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Inspection detail',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(
                    LucideIcons.pencil,
                    size: 18,
                    color: InspectionAdminUi.gold,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(LucideIcons.x, color: Colors.white54),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                InspectionStatusBadge(status: row.status),
                const Spacer(),
                if (row.reference != null)
                  Text(
                    row.reference!,
                    style: const TextStyle(
                      color: InspectionAdminUi.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _DetailSection('Customer', [
                  _DetailLine('Name', row.visitorName),
                  _DetailLine('Email', row.visitorEmail),
                  _DetailLine('Phone', row.visitorPhone),
                ]),
                _DetailSection('Schedule', [
                  _DetailLine('When', fmt.format(row.scheduledAt.toLocal())),
                  _DetailLine('Type', row.inspectionType.replaceAll('_', ' ')),
                  _DetailLine('Language', row.preferredLanguage),
                  if (row.meetingUrl != null)
                    _DetailLine('Meeting URL', row.meetingUrl),
                ]),
                _DetailSection('Property', [
                  _DetailLine('Property', row.propertyTitle),
                ]),
                if (qualification is Map)
                  _DetailSection('Lead qualification', [
                    for (final e in qualification.entries)
                      _DetailLine(e.key, '${e.value}'),
                  ]),
                if (docs is List && docs.isNotEmpty)
                  _DetailSection('Documents', [
                    for (final d in docs) _DetailLine('File', '$d'),
                  ]),
                historyAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (history) => _DetailSection(
                    'Audit history',
                    [
                      for (final h in history)
                        _DetailLine(
                          h.changedAt != null
                              ? DateFormat('d MMM HH:mm')
                                  .format(h.changedAt!.toLocal())
                              : '—',
                          '${h.fromStatus ?? '—'} → ${h.toStatus}'
                              '${h.reason != null ? ' · ${h.reason}' : ''}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(LucideIcons.pencil, size: 14),
                      label: const Text('Edit booking'),
                      style: FilledButton.styleFrom(
                        backgroundColor: InspectionAdminUi.gold,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    if (row.status == 'scheduled')
                      OutlinedButton(
                        onPressed: () => onStatus(row.id, 'confirmed'),
                        child: const Text('Confirm'),
                      ),
                    if (row.status == 'scheduled' || row.status == 'confirmed')
                      OutlinedButton(
                        onPressed: () async {
                          final controller =
                              TextEditingController(text: row.meetingUrl ?? '');
                          final link = await showDialog<String>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                backgroundColor:
                                    InspectionAdminUi.surfaceElevated,
                                title: const Text(
                                  'Send meeting link',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: TextField(
                                  controller: controller,
                                  decoration: InspectionAdminUi.fieldDecoration(
                                    'Meeting URL',
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      final value = controller.text.trim();
                                      if (value.isEmpty) return;
                                      Navigator.of(dialogContext).pop(value);
                                    },
                                    child: const Text('Send'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (link == null || link.isEmpty) return;
                          await onStatus(
                            row.id,
                            'confirmed',
                            meetingUrl: link,
                            reason: 'Meeting link shared with client',
                          );
                        },
                        child: const Text('Send meeting link'),
                      ),
                    if (row.status == 'scheduled' || row.status == 'confirmed')
                      OutlinedButton(
                        onPressed: () => onStatus(row.id, 'completed'),
                        child: const Text('Complete'),
                      ),
                    if (row.status != 'cancelled' && row.status != 'completed')
                      OutlinedButton(
                        onPressed: () => onStatus(
                          row.id,
                          'cancelled',
                          reason: 'Cancelled by admin',
                        ),
                        child: const Text('Cancel'),
                      ),
                    if (row.status == 'confirmed')
                      OutlinedButton(
                        onPressed: () => onStatus(row.id, 'no_show'),
                        child: const Text('No-show'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection(this.title, this.lines);
  final String title;
  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: InspectionAdminUi.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...lines,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: InspectionAdminUi.muted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionListTile extends StatelessWidget {
  const _InspectionListTile({
    required this.row,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onConfirm,
    this.onCancel,
  });

  final AdminInspectionRow row;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? InspectionAdminUi.surfaceElevated
            : InspectionAdminUi.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? InspectionAdminUi.gold.withValues(alpha: 0.45)
              : InspectionAdminUi.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          row.propertyTitle ?? 'Property inspection',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${row.visitorName ?? 'Guest'} · ${fmt.format(row.scheduledAt.toLocal())}',
          style: const TextStyle(color: InspectionAdminUi.muted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InspectionStatusBadge(status: row.status),
            if (onConfirm != null)
              IconButton(
                tooltip: 'Confirm',
                onPressed: onConfirm,
                icon: const Icon(
                  LucideIcons.checkCircle2,
                  size: 16,
                  color: Color(0xFF22C55E),
                ),
              ),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(
                LucideIcons.pencil,
                size: 16,
                color: Colors.white54,
              ),
            ),
            if (onCancel != null)
              IconButton(
                tooltip: 'Cancel',
                onPressed: onCancel,
                icon: const Icon(
                  LucideIcons.xCircle,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(
                LucideIcons.trash2,
                size: 16,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
