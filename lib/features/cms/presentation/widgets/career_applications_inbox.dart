import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class CareerApplicationsInbox extends ConsumerStatefulWidget {
  const CareerApplicationsInbox({super.key});

  @override
  ConsumerState<CareerApplicationsInbox> createState() =>
      _CareerApplicationsInboxState();
}

class _CareerApplicationsInboxState extends ConsumerState<CareerApplicationsInbox> {
  String _status = 'all';
  String _search = '';
  String _job = 'all';
  CareerApplicationRow? _selected;

  static const statuses = [
    'new',
    'reviewing',
    'shortlisted',
    'interview',
    'assessment',
    'offer',
    'hired',
    'rejected',
    'withdrawn',
    'archived',
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(websiteFormsAdminRealtimeProvider);
    final stats = ref.watch(adminCareerApplicationStatsProvider);
    final list = ref.watch(adminCareerApplicationsProvider);
    final jobs = ref.watch(openCareerJobsProvider).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stats.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (s) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _chip('Open positions', '${s.openPositions}'),
              _chip('Total', '${s.total}'),
              _chip('New', '${s.neu}'),
              _chip('Shortlisted', '${s.shortlisted}'),
              _chip('Interviews', '${s.interviews}'),
              _chip('Hired', '${s.hired}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: list.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(userFacingError(e))),
            data: (rows) {
              final filtered = rows.where((r) {
                final statusOk = _status == 'all' || r.status == _status;
                final jobOk = _job == 'all' || r.jobId == _job;
                final q = _search;
                final searchOk = q.isEmpty ||
                    r.fullName.toLowerCase().contains(q) ||
                    r.email.toLowerCase().contains(q) ||
                    r.reference.toLowerCase().contains(q) ||
                    r.positionTitle.toLowerCase().contains(q);
                return statusOk && jobOk && searchOk;
              }).toList();
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: 240,
                              child: TextField(
                                decoration: const InputDecoration(hintText: 'Search applicants…'),
                                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                              ),
                            ),
                            DropdownButton<String>(
                              value: _status,
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('All statuses')),
                                ...statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? 'all'),
                            ),
                            DropdownButton<String>(
                              value: _job,
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('All positions')),
                                ...jobs.map((j) => DropdownMenuItem(value: j.id, child: Text(j.title))),
                              ],
                              onChanged: (v) => setState(() => _job = v ?? 'all'),
                            ),
                          ],
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(child: Text('No applications yet.'))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, i) {
                                    final r = filtered[i];
                                    return ListTile(
                                      selected: _selected?.id == r.id,
                                      title: Text('${r.reference} · ${r.fullName}'),
                                      subtitle: Text('${r.positionTitle} · ${r.email} · ${r.status}'),
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
                        ? const Center(child: Text('Select an application'))
                        : _ApplicationDetail(row: _selected!),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ApplicationDetail extends ConsumerStatefulWidget {
  const _ApplicationDetail({required this.row});
  final CareerApplicationRow row;

  @override
  ConsumerState<_ApplicationDetail> createState() => _ApplicationDetailState();
}

class _ApplicationDetailState extends ConsumerState<_ApplicationDetail> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.row.adminNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant _ApplicationDetail oldWidget) {
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
        Text(r.fullName, style: Theme.of(context).textTheme.titleLarge),
        Text('${r.email}${r.phone == null ? '' : ' · ${r.phone}'}'),
        Text(r.positionTitle),
        if (r.preferredLocation != null) Text('Location: ${r.preferredLocation}'),
        if (r.linkedinUrl != null) Text(r.linkedinUrl!),
        const SizedBox(height: 12),
        Text(r.coverLetter ?? ''),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: r.status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: _CareerApplicationsInboxState.statuses
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            await ref.read(websiteFormsAdminServiceProvider).updateApplication(id: r.id, status: v);
            ref.invalidate(adminCareerApplicationsProvider);
            ref.invalidate(adminCareerApplicationStatsProvider);
          },
        ),
        const SizedBox(height: 8),
        TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Internal notes')),
        TextButton(
          onPressed: () async {
            await ref.read(websiteFormsAdminServiceProvider).updateApplication(
                  id: r.id,
                  adminNotes: _notes.text,
                );
          },
          child: const Text('Save notes'),
        ),
        if (r.cvPath != null)
          ListTile(
            leading: const Icon(LucideIcons.file),
            title: Text(r.cvFileName ?? 'CV'),
            trailing: IconButton(
              icon: const Icon(LucideIcons.download),
              onPressed: () async {
                final url = await ref.read(websiteFormsAdminServiceProvider).signedUrl(r.cvPath!);
                if (url != null) await launchUrl(Uri.parse(url));
              },
            ),
          ),
      ],
    );
  }
}
