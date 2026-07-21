import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/hcm/domain/entities/hcm_models.dart';
import 'package:hdhomesproject/features/hcm/domain/services/hcm_service.dart';
import 'package:hdhomesproject/features/hcm/presentation/providers/hcm_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 9 — Workforce Command Center™ / HR admin workspace.
class HrCommandCenterPage extends ConsumerWidget {
  const HrCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(hcmSnapshotProvider);
    final ui = ref.watch(hcmControllerProvider);
    final controller = ref.read(hcmControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load HR Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Workforce live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _HcmHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenTalent: () =>
                        controller.setTab(HcmCommandTab.recruitment),
                    onOpenChro: () => controller.setTab(HcmCommandTab.ai),
                  ),
                ),
                if (ui.lastMessage != null)
                  ContainedPadding(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Material(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.cardBorder,
                        child: ListTile(
                          leading: const Icon(
                            LucideIcons.info,
                            color: AppColors.gold,
                          ),
                          title: Text(ui.lastMessage!),
                          dense: true,
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: controller.clearMessage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ContainedPadding(child: _KpiStrip(kpis: snap.kpis)),
                ContainedPadding(
                  child: _SearchAndFilters(
                    ui: ui,
                    onSearch: controller.setSearch,
                    onStatus: controller.setStatusFilter,
                  ),
                ),
                ContainedPadding(
                  child: _TabBar(
                    selected: ui.selectedTab,
                    onSelect: controller.setTab,
                  ),
                ),
                ..._tabSlivers(context, ref, snap, ui, controller),
                const ContainedPadding(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _tabSlivers(
    BuildContext context,
    WidgetRef ref,
    HcmCommandCenterSnapshot snap,
    HcmUiState ui,
    HcmController controller,
  ) {
    switch (ui.selectedTab) {
      case HcmCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Workforce Command Center™',
              icon: LucideIcons.users,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Org Intelligence · Talent pipeline · People operations',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  _ActivityList(activities: snap.activities),
                ],
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'HR Alerts',
              icon: LucideIcons.bell,
              child: _AlertList(alerts: snap.alerts),
            ),
          ),
        ];
      case HcmCommandTab.directory:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Employee Directory',
              icon: LucideIcons.contact,
              child: _EmployeeList(
                employees: controller.filteredEmployees(snap),
              ),
            ),
          ),
        ];
      case HcmCommandTab.recruitment:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Open Vacancies',
              icon: LucideIcons.briefcase,
              child: _VacancyList(vacancies: snap.vacancies),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Applicant Pipeline',
              icon: LucideIcons.userPlus,
              child: _ApplicantList(
                applicants: controller.filteredApplicants(snap),
              ),
            ),
          ),
        ];
      case HcmCommandTab.attendance:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Attendance Today',
              icon: LucideIcons.clock,
              child: _AttendanceList(records: snap.attendance),
            ),
          ),
        ];
      case HcmCommandTab.leave:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Leave Requests',
              icon: LucideIcons.calendarDays,
              child: _LeaveList(requests: controller.filteredLeave(snap)),
            ),
          ),
        ];
      case HcmCommandTab.performance:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Performance Cycles',
              icon: LucideIcons.target,
              child: _PerformanceList(cycles: snap.performanceCycles),
            ),
          ),
        ];
      case HcmCommandTab.training:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Training Enrollments',
              icon: LucideIcons.graduationCap,
              child: _TrainingList(items: snap.trainings),
            ),
          ),
        ];
      case HcmCommandTab.assets:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Assigned Assets',
              icon: LucideIcons.laptop,
              child: _AssetList(assets: snap.assets),
            ),
          ),
        ];
      case HcmCommandTab.announcements:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'HR Announcements',
              icon: LucideIcons.megaphone,
              child: _AnnouncementList(items: snap.announcements),
            ),
          ),
        ];
      case HcmCommandTab.ai:
        final service = ref.read(hcmServiceProvider);
        final briefing = service.generateTalentBriefing(snap);
        final signals = HcmService.detectWorkforceSignals(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Talent Intelligence™',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(briefing),
                  const SizedBox(height: 12),
                  Text(
                    snap.aiDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'CHRO Workspace stubs',
              icon: LucideIcons.briefcase,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...signals.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(LucideIcons.radar, size: 16),
                      title: Text(s),
                    ),
                  ),
                  const Divider(height: 24),
                  ...snap.aiInsights.map(
                    (i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(i.title),
                      subtitle: Text(
                        '${i.body}\n'
                        '${i.editable ? 'Editable / advisory' : 'Factual'}'
                        '${i.confidencePct != null ? ' · ${i.confidencePct!.toStringAsFixed(0)}% conf.' : ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
    }
  }
}

class ContainedPadding extends StatelessWidget {
  const ContainedPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _HcmHeader extends StatelessWidget {
  const _HcmHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenTalent,
    required this.onOpenChro,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenTalent;
  final VoidCallback onOpenChro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.deepBlack.withValues(alpha: 0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final title = Text(
                'Workforce Command Center™',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenTalent,
                    icon: const Icon(LucideIcons.userPlus, size: 16),
                    label: const Text('Talent Intelligence'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenChro,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('CHRO Workspace'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => onRefresh(),
                    icon: const Icon(
                      LucideIcons.rotateCcw,
                      color: AppColors.white,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: AppRadius.cardBorder,
                    ),
                    child: Text(
                      fromRemote ? 'LIVE' : 'DEMO',
                      style: TextStyle(
                        color:
                            fromRemote ? Colors.greenAccent : AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Text(
                      'HCM · directory · leave · attendance · talent',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 4),
                        Text(
                          'Org Intelligence · recruitment · People Ops · AI advisory',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 14, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ticker,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<HcmKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final k = kpis[i];
            return Container(
              width: 148,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.label,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    k.displayValue,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.onSearch,
    required this.onStatus,
  });

  final HcmUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search people, roles, leave…',
                prefixIcon: Icon(LucideIcons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String?>(
            value: ui.statusFilter,
            hint: const Text('Status'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
              DropdownMenuItem(value: 'probation', child: Text('Probation')),
              DropdownMenuItem(value: 'interview', child: Text('Interview')),
              DropdownMenuItem(value: 'open', child: Text('Open')),
            ],
            onChanged: onStatus,
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final HcmCommandTab selected;
  final ValueChanged<HcmCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: HcmCommandTab.values.map((tab) {
            final active = tab == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab.label),
                selected: active,
                onSelected: (_) => onSelect(tab),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({required this.employees});

  final List<HcmEmployee> employees;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) return const Text('No employees.');
    return Column(
      children: employees
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(e.fullName),
              subtitle: Text(
                '${e.directoryLabel} · ${e.jobTitle ?? '—'} · '
                '${e.departmentName ?? '—'} · ${e.status.label}',
              ),
              trailing: Text(e.locationLabel ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _VacancyList extends StatelessWidget {
  const _VacancyList({required this.vacancies});

  final List<HcmVacancy> vacancies;

  @override
  Widget build(BuildContext context) {
    if (vacancies.isEmpty) return const Text('No open vacancies.');
    return Column(
      children: vacancies
          .map(
            (v) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(v.title),
              subtitle: Text(
                '${v.requisitionCode ?? '—'} · ${v.status} · '
                '${v.locationLabel ?? '—'}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ApplicantList extends StatelessWidget {
  const _ApplicantList({required this.applicants});

  final List<HcmApplicant> applicants;

  @override
  Widget build(BuildContext context) {
    if (applicants.isEmpty) return const Text('No applicants.');
    return Column(
      children: applicants
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(a.fullName),
              subtitle: Text(
                '${a.stage.label} · ${a.source ?? '—'}'
                '${a.score != null ? ' · score ${a.score!.toStringAsFixed(0)}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({required this.records});

  final List<HcmAttendance> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const Text('No attendance records.');
    return Column(
      children: records
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(r.employeeName ?? r.employeeId),
              subtitle: Text(
                '${r.status.label} · ${DateFormat.yMMMd().format(r.workDate)}'
                '${r.clockInAt != null ? ' · in ${DateFormat.jm().format(r.clockInAt!)}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LeaveList extends StatelessWidget {
  const _LeaveList({required this.requests});

  final List<HcmLeaveRequest> requests;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const Text('No leave requests.');
    return Column(
      children: requests
          .map(
            (l) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l.employeeName ?? l.employeeId),
              subtitle: Text(
                '${l.leaveType} · ${l.daysCount}d · ${l.status.label} · '
                '${DateFormat.MMMd().format(l.startsOn)}–'
                '${DateFormat.MMMd().format(l.endsOn)}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PerformanceList extends StatelessWidget {
  const _PerformanceList({required this.cycles});

  final List<HcmPerformanceCycle> cycles;

  @override
  Widget build(BuildContext context) {
    if (cycles.isEmpty) return const Text('No performance cycles.');
    return Column(
      children: cycles
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(c.name),
              subtitle: Text(
                '${c.status}'
                '${c.startsOn != null ? ' · ${DateFormat.yMMMd().format(c.startsOn!)}' : ''}'
                '${c.endsOn != null ? ' → ${DateFormat.yMMMd().format(c.endsOn!)}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TrainingList extends StatelessWidget {
  const _TrainingList({required this.items});

  final List<HcmTraining> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No enrollments.');
    return Column(
      children: items
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.courseTitle),
              subtitle: Text(
                '${t.courseCode ?? '—'} · ${t.employeeName ?? '—'} · ${t.status}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AssetList extends StatelessWidget {
  const _AssetList({required this.assets});

  final List<HcmAsset> assets;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const Text('No assets assigned.');
    return Column(
      children: assets
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${a.name} (${a.assetTag})'),
              subtitle: Text(
                '${a.assetType} · ${a.employeeName ?? '—'} · ${a.status}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.items});

  final List<HcmAnnouncement> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No announcements.');
    return Column(
      children: items
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(a.title),
              subtitle: Text(
                '${a.audience} · ${a.authorLabel ?? 'HR'}'
                '${a.publishedAt != null ? ' · ${DateFormat.MMMd().format(a.publishedAt!)}' : ''}\n'
                '${a.body}',
              ),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<HcmActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Text('No activity yet.');
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.history, size: 16),
              title: Text(a.summary),
              subtitle: Text(
                '${a.actorLabel ?? 'System'}'
                '${a.occurredAt != null ? ' · ${DateFormat.MMMd().add_jm().format(a.occurredAt!)}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<HcmAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const Text('No alerts.');
    return Column(
      children: alerts
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                a.severity == 'warning'
                    ? LucideIcons.alertTriangle
                    : LucideIcons.info,
                size: 16,
                color: a.severity == 'warning'
                    ? Colors.orange
                    : AppColors.gold,
              ),
              title: Text(a.title),
              subtitle: a.body == null ? null : Text(a.body!),
            ),
          )
          .toList(),
    );
  }
}
