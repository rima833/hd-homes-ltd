import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
        ],
      ),
    );
  }
}

class CmsWebsiteSupportPage extends ConsumerStatefulWidget {
  const CmsWebsiteSupportPage({super.key});

  @override
  ConsumerState<CmsWebsiteSupportPage> createState() =>
      _CmsWebsiteSupportPageState();
}

class _CmsWebsiteSupportPageState extends ConsumerState<CmsWebsiteSupportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _status = 'all';
  String _search = '';
  WebsiteSupportTicketRow? _selected;

  static const statuses = [
    'new',
    'open',
    'in_progress',
    'waiting_for_customer',
    'resolved',
    'closed',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _label(String slug) => slug.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    ref.watch(websiteFormsAdminRealtimeProvider);
    final stats = ref.watch(adminWebsiteTicketStatsProvider);
    final list = ref.watch(adminWebsiteTicketsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(LucideIcons.headphones, color: AppColors.gold, size: 22),
                const SizedBox(
                  width: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support desk is the primary inbox',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Website tickets are managed in Support → Tickets (channel: website). This CMS list remains for quick review.',
                        style: TextStyle(color: AppColors.slate500, fontSize: 12.5, height: 1.35),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go(
                    '${RoutePaths.dashboardSupport}?tab=tickets&channel=website',
                  ),
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  label: const Text('Open in Support Tickets'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WEBSITE SUPPORT', style: TextStyle(color: AppColors.gold, letterSpacing: 2, fontSize: 12)),
                    SizedBox(height: 6),
                    Text('Support tickets', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go(RoutePaths.contact),
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: const Text('Public form'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (s) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(label: 'Total', value: '${s.total}'),
                _StatChip(label: 'New', value: '${s.neu}'),
                _StatChip(label: 'Open', value: '${s.open}'),
                _StatChip(label: 'In Progress', value: '${s.inProgress}'),
                _StatChip(label: 'Resolved', value: '${s.resolved}'),
                _StatChip(label: 'Urgent', value: '${s.urgent}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.slate500,
            indicatorColor: AppColors.gold,
            tabs: const [
              Tab(text: 'Tickets'),
              Tab(text: 'Settings'),
              Tab(text: 'Types'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TicketsTab(
                  listAsync: list,
                  status: _status,
                  search: _search,
                  selected: _selected,
                  onStatus: (v) => setState(() => _status = v),
                  onSearch: (v) => setState(() => _search = v.trim().toLowerCase()),
                  onSelect: (r) => setState(() => _selected = r),
                  onUpdate: (id, {status, priority, notes}) async {
                    await ref.read(websiteFormsAdminServiceProvider).updateTicket(
                          id: id,
                          status: status,
                          priority: priority,
                          adminNotes: notes,
                        );
                    ref.invalidate(adminWebsiteTicketsProvider);
                    ref.invalidate(adminWebsiteTicketStatsProvider);
                  },
                  onNote: (id, body) async {
                    await ref.read(websiteFormsAdminServiceProvider).addTicketNote(id, body);
                  },
                  statusLabel: _label,
                  statuses: statuses,
                ),
                const _SupportSettingsTab(),
                const _SupportTypesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketsTab extends StatelessWidget {
  const _TicketsTab({
    required this.listAsync,
    required this.status,
    required this.search,
    required this.selected,
    required this.onStatus,
    required this.onSearch,
    required this.onSelect,
    required this.onUpdate,
    required this.onNote,
    required this.statusLabel,
    required this.statuses,
  });

  final AsyncValue<List<WebsiteSupportTicketRow>> listAsync;
  final String status;
  final String search;
  final WebsiteSupportTicketRow? selected;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onSearch;
  final ValueChanged<WebsiteSupportTicketRow> onSelect;
  final Future<void> Function(String id, {String? status, String? priority, String? notes}) onUpdate;
  final Future<void> Function(String id, String body) onNote;
  final String Function(String) statusLabel;
  final List<String> statuses;

  @override
  Widget build(BuildContext context) {
    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load tickets: $e')),
      data: (rows) {
        final filtered = rows.where((r) {
          final statusOk = status == 'all' || r.status == status;
          final q = search;
          final searchOk = q.isEmpty ||
              r.name.toLowerCase().contains(q) ||
              r.email.toLowerCase().contains(q) ||
              r.reference.toLowerCase().contains(q) ||
              r.subject.toLowerCase().contains(q);
          return statusOk && searchOk;
        }).toList();
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(hintText: 'Search name, email, reference…'),
                          onChanged: onSearch,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: status,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All statuses')),
                          ...statuses.map((s) => DropdownMenuItem(value: s, child: Text(statusLabel(s)))),
                        ],
                        onChanged: (v) => onStatus(v ?? 'all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No tickets yet.', style: TextStyle(color: AppColors.slate500)))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final r = filtered[i];
                              final active = selected?.id == r.id;
                              return ListTile(
                                selected: active,
                                title: Text('${r.reference} · ${r.subject}'),
                                subtitle: Text('${r.name} · ${r.email} · ${statusLabel(r.status)}'),
                                trailing: Text(r.priority),
                                onTap: () => onSelect(r),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 24),
            Expanded(
              flex: 2,
              child: selected == null
                  ? const Center(child: Text('Select a ticket', style: TextStyle(color: AppColors.slate500)))
                  : _TicketDetail(
                      ticket: selected!,
                      statuses: statuses,
                      statusLabel: statusLabel,
                      onUpdate: onUpdate,
                      onNote: onNote,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TicketDetail extends StatefulWidget {
  const _TicketDetail({
    required this.ticket,
    required this.statuses,
    required this.statusLabel,
    required this.onUpdate,
    required this.onNote,
  });

  final WebsiteSupportTicketRow ticket;
  final List<String> statuses;
  final String Function(String) statusLabel;
  final Future<void> Function(String id, {String? status, String? priority, String? notes}) onUpdate;
  final Future<void> Function(String id, String body) onNote;

  @override
  State<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends State<_TicketDetail> {
  late final TextEditingController _notes;
  late final TextEditingController _internal;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.ticket.adminNotes ?? '');
    _internal = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _TicketDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket.id != widget.ticket.id) {
      _notes.text = widget.ticket.adminNotes ?? '';
      _internal.clear();
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _internal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final created = t.createdAt == null ? '' : DateFormat.yMMMd().add_jm().format(t.createdAt!.toLocal());
    return ListView(
      children: [
        Text(t.reference, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
        Text(t.subject, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('${t.name} · ${t.email}'),
        Text(created, style: const TextStyle(color: AppColors.slate500)),
        const SizedBox(height: 12),
        Text(t.details),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: widget.statuses.contains(t.status) ? t.status : 'new',
          decoration: const InputDecoration(labelText: 'Status'),
          items: widget.statuses
              .map((s) => DropdownMenuItem(value: s, child: Text(widget.statusLabel(s))))
              .toList(),
          onChanged: _saving
              ? null
              : (v) async {
                  if (v == null) return;
                  setState(() => _saving = true);
                  await widget.onUpdate(t.id, status: v);
                  if (mounted) setState(() => _saving = false);
                },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: const ['low', 'normal', 'high', 'urgent'].contains(t.priority) ? t.priority : 'normal',
          decoration: const InputDecoration(labelText: 'Priority'),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
          ],
          onChanged: _saving
              ? null
              : (v) async {
                  if (v == null) return;
                  setState(() => _saving = true);
                  await widget.onUpdate(t.id, priority: v);
                  if (mounted) setState(() => _saving = false);
                },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Admin notes'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onUpdate(t.id, notes: _notes.text);
                    if (mounted) setState(() => _saving = false);
                  },
            child: const Text('Save notes'),
          ),
        ),
        TextField(
          controller: _internal,
          decoration: const InputDecoration(labelText: 'Add internal note'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _internal.text.trim().isEmpty
                ? null
                : () async {
                    await widget.onNote(t.id, _internal.text);
                    _internal.clear();
                  },
            child: const Text('Add note'),
          ),
        ),
      ],
    );
  }
}

class _SupportSettingsTab extends ConsumerStatefulWidget {
  const _SupportSettingsTab();

  @override
  ConsumerState<_SupportSettingsTab> createState() => _SupportSettingsTabState();
}

class _SupportSettingsTabState extends ConsumerState<_SupportSettingsTab> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(websiteSupportSettingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(userFacingError(e)),
      data: (s) {
        if (s == null) return const Text('No settings row.');
        return _SupportSettingsForm(settings: s);
      },
    );
  }
}

class _SupportSettingsForm extends ConsumerStatefulWidget {
  const _SupportSettingsForm({required this.settings});
  final WebsiteSupportSettings settings;

  @override
  ConsumerState<_SupportSettingsForm> createState() => _SupportSettingsFormState();
}

class _SupportSettingsFormState extends ConsumerState<_SupportSettingsForm> {
  late bool _enabled;
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _disabled;
  late String _priority;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _enabled = s.isEnabled;
    _title = TextEditingController(text: s.confirmationTitle);
    _message = TextEditingController(text: s.confirmationMessage);
    _disabled = TextEditingController(text: s.disabledMessage);
    _priority = s.defaultPriority;
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _disabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SwitchListTile(
          title: const Text('Form enabled'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Confirmation title')),
        const SizedBox(height: 8),
        TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Confirmation message')),
        const SizedBox(height: 8),
        TextField(controller: _disabled, maxLines: 2, decoration: const InputDecoration(labelText: 'Disabled message')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _priority,
          decoration: const InputDecoration(labelText: 'Default priority'),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
          ],
          onChanged: (v) => setState(() => _priority = v ?? 'normal'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await ref.read(websiteFormsAdminServiceProvider).saveSupportSettings(
                        WebsiteSupportSettings(
                          id: widget.settings.id,
                          isEnabled: _enabled,
                          confirmationTitle: _title.text,
                          confirmationMessage: _message.text,
                          disabledMessage: _disabled.text,
                          defaultPriority: _priority,
                        ),
                      );
                  ref.invalidate(websiteSupportSettingsProvider);
                  if (mounted) setState(() => _saving = false);
                },
          child: Text(_saving ? 'Saving…' : 'Save settings'),
        ),
      ],
    );
  }
}

class _SupportTypesTab extends ConsumerWidget {
  const _SupportTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminSupportTypesAllProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(userFacingError(e)),
      data: (items) => ListView(
        children: [
          for (final t in items)
            SwitchListTile(
              title: Text(t.name),
              subtitle: Text(t.slug),
              value: t.isActive,
              onChanged: (v) async {
                await ref.read(websiteFormsAdminServiceProvider).saveSupportType(id: t.id, isActive: v);
                ref.invalidate(adminSupportTypesAllProvider);
                ref.invalidate(websiteSupportTypesProvider);
              },
            ),
        ],
      ),
    );
  }
}

class CmsPartnershipsPage extends ConsumerStatefulWidget {
  const CmsPartnershipsPage({super.key});

  @override
  ConsumerState<CmsPartnershipsPage> createState() => _CmsPartnershipsPageState();
}

class _CmsPartnershipsPageState extends ConsumerState<CmsPartnershipsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _status = 'all';
  String _search = '';
  PartnershipRequestRow? _selected;

  static const statuses = [
    'new',
    'under_review',
    'contacted',
    'negotiation',
    'approved',
    'declined',
    'closed',
    'archived',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _label(String slug) => slug.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    ref.watch(websiteFormsAdminRealtimeProvider);
    final stats = ref.watch(adminPartnershipStatsProvider);
    final list = ref.watch(adminPartnershipRequestsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PARTNERSHIPS', style: TextStyle(color: AppColors.gold, letterSpacing: 2, fontSize: 12)),
                    SizedBox(height: 6),
                    Text('Partnership requests', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go(RoutePaths.contact),
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: const Text('Public form'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (s) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(label: 'Total', value: '${s.total}'),
                _StatChip(label: 'New', value: '${s.neu}'),
                _StatChip(label: 'Under Review', value: '${s.underReview}'),
                _StatChip(label: 'Negotiation', value: '${s.negotiation}'),
                _StatChip(label: 'Approved', value: '${s.approved}'),
                _StatChip(label: 'Closed', value: '${s.closed}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.slate500,
            indicatorColor: AppColors.gold,
            tabs: const [
              Tab(text: 'Requests'),
              Tab(text: 'Settings'),
              Tab(text: 'Types'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                list.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(userFacingError(e))),
                  data: (rows) {
                    final filtered = rows.where((r) {
                      final statusOk = _status == 'all' || r.status == _status;
                      final q = _search;
                      final searchOk = q.isEmpty ||
                          r.companyName.toLowerCase().contains(q) ||
                          r.contactPerson.toLowerCase().contains(q) ||
                          r.email.toLowerCase().contains(q) ||
                          r.reference.toLowerCase().contains(q);
                      return statusOk && searchOk;
                    }).toList();
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(hintText: 'Search company, contact, email…'),
                                      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  DropdownButton<String>(
                                    value: _status,
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All statuses')),
                                      ...statuses.map((s) => DropdownMenuItem(value: s, child: Text(_label(s)))),
                                    ],
                                    onChanged: (v) => setState(() => _status = v ?? 'all'),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: filtered.isEmpty
                                    ? const Center(child: Text('No partnership requests yet.'))
                                    : ListView.builder(
                                        itemCount: filtered.length,
                                        itemBuilder: (context, i) {
                                          final r = filtered[i];
                                          return ListTile(
                                            selected: _selected?.id == r.id,
                                            title: Text('${r.reference} · ${r.companyName}'),
                                            subtitle: Text('${r.contactPerson} · ${r.typeName ?? ''} · ${_label(r.status)}'),
                                            onTap: () => setState(() => _selected = r),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 24),
                        Expanded(
                          flex: 2,
                          child: _selected == null
                              ? const Center(child: Text('Select a request'))
                              : _PartnershipDetail(row: _selected!),
                        ),
                      ],
                    );
                  },
                ),
                const _PartnershipSettingsTab(),
                const _PartnershipTypesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnershipDetail extends ConsumerStatefulWidget {
  const _PartnershipDetail({required this.row});
  final PartnershipRequestRow row;

  @override
  ConsumerState<_PartnershipDetail> createState() => _PartnershipDetailState();
}

class _PartnershipDetailState extends ConsumerState<_PartnershipDetail> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.row.adminNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant _PartnershipDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.id != widget.row.id) {
      _notes.text = widget.row.adminNotes ?? '';
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return ListView(
      children: [
        Text(r.reference, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
        Text(r.companyName, style: Theme.of(context).textTheme.titleLarge),
        Text('${r.contactPerson} · ${r.email} · ${r.phone}'),
        Text(r.typeName ?? ''),
        const SizedBox(height: 12),
        Text(r.proposalSummary ?? ''),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: r.status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: _CmsPartnershipsPageState.statuses
              .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '))))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            await ref.read(websiteFormsAdminServiceProvider).updatePartnership(id: r.id, status: v);
            ref.invalidate(adminPartnershipRequestsProvider);
            ref.invalidate(adminPartnershipStatsProvider);
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: r.priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
          ],
          onChanged: (v) async {
            if (v == null) return;
            await ref.read(websiteFormsAdminServiceProvider).updatePartnership(id: r.id, priority: v);
            ref.invalidate(adminPartnershipRequestsProvider);
          },
        ),
        const SizedBox(height: 8),
        TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Admin notes')),
        TextButton(
          onPressed: () async {
            await ref.read(websiteFormsAdminServiceProvider).updatePartnership(id: r.id, adminNotes: _notes.text);
          },
          child: const Text('Save notes'),
        ),
        const SizedBox(height: 8),
        const Text('Documents', style: TextStyle(fontWeight: FontWeight.w600)),
        for (final doc in r.documents)
          ListTile(
            dense: true,
            leading: const Icon(LucideIcons.file),
            title: Text('${doc['name'] ?? 'Document'}'),
            trailing: IconButton(
              icon: const Icon(LucideIcons.download),
              onPressed: () async {
                final path = '${doc['path'] ?? ''}';
                if (path.isEmpty) return;
                final url = await ref.read(websiteFormsAdminServiceProvider).signedUrl(path);
                if (url != null) await launchUrl(Uri.parse(url));
              },
            ),
          ),
      ],
    );
  }
}

class _PartnershipSettingsTab extends ConsumerWidget {
  const _PartnershipSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(partnershipSettingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(userFacingError(e)),
      data: (s) {
        if (s == null) return const Text('No settings.');
        return _PartnershipSettingsForm(settings: s);
      },
    );
  }
}

class _PartnershipSettingsForm extends ConsumerStatefulWidget {
  const _PartnershipSettingsForm({required this.settings});
  final PartnershipSettings settings;

  @override
  ConsumerState<_PartnershipSettingsForm> createState() =>
      _PartnershipSettingsFormState();
}

class _PartnershipSettingsFormState extends ConsumerState<_PartnershipSettingsForm> {
  late bool _enabled;
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _disabled;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.isEnabled;
    _title = TextEditingController(text: widget.settings.confirmationTitle);
    _message = TextEditingController(text: widget.settings.confirmationMessage);
    _disabled = TextEditingController(text: widget.settings.disabledMessage);
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _disabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SwitchListTile(
          title: const Text('Form enabled'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Confirmation title')),
        const SizedBox(height: 8),
        TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Confirmation message')),
        const SizedBox(height: 8),
        TextField(controller: _disabled, maxLines: 2, decoration: const InputDecoration(labelText: 'Disabled message')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await ref.read(websiteFormsAdminServiceProvider).savePartnershipSettings(
                        PartnershipSettings(
                          id: widget.settings.id,
                          isEnabled: _enabled,
                          confirmationTitle: _title.text,
                          confirmationMessage: _message.text,
                          disabledMessage: _disabled.text,
                          allowedDocExtensions: widget.settings.allowedDocExtensions,
                          maxDocBytes: widget.settings.maxDocBytes,
                        ),
                      );
                  ref.invalidate(partnershipSettingsProvider);
                  if (mounted) setState(() => _saving = false);
                },
          child: Text(_saving ? 'Saving…' : 'Save settings'),
        ),
      ],
    );
  }
}

class _PartnershipTypesTab extends ConsumerWidget {
  const _PartnershipTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminPartnershipTypesAllProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(userFacingError(e)),
      data: (items) => ListView(
        children: [
          for (final t in items)
            SwitchListTile(
              title: Text(t.name),
              value: t.isActive,
              onChanged: (v) async {
                await ref.read(websiteFormsAdminServiceProvider).savePartnershipType(id: t.id, isActive: v);
                ref.invalidate(adminPartnershipTypesAllProvider);
                ref.invalidate(partnershipTypesProvider);
              },
            ),
        ],
      ),
    );
  }
}
