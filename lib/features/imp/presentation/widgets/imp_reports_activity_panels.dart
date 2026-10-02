import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reports desk — list vault reports + publish metadata to an investor.
class ImpReportsDeskPanel extends StatefulWidget {
  const ImpReportsDeskPanel({
    super.key,
    required this.investors,
    required this.selectedInvestorId,
    required this.onSelectInvestor,
    required this.reports,
    required this.loading,
    required this.canPublish,
    required this.onPublish,
    this.error,
  });

  final List<ImpInvestor> investors;
  final String? selectedInvestorId;
  final ValueChanged<String> onSelectInvestor;
  final List<ImpReport> reports;
  final bool loading;
  final String? error;
  final bool canPublish;
  final Future<void> Function({
    required String title,
    required String reportType,
    String? periodLabel,
    String? fileUrl,
  })
  onPublish;

  @override
  State<ImpReportsDeskPanel> createState() => _ImpReportsDeskPanelState();
}

class _ImpReportsDeskPanelState extends State<ImpReportsDeskPanel> {
  final _titleCtrl = TextEditingController();
  final _periodCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  var _reportType = 'portfolio';
  var _publishing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _periodCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report title is required')),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      await widget.onPublish(
        title: title,
        reportType: _reportType,
        periodLabel: _periodCtrl.text.trim().isEmpty
            ? null
            : _periodCtrl.text.trim(),
        fileUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      );
      _titleCtrl.clear();
      _periodCtrl.clear();
      _urlCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report published')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _open(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.investors.isEmpty) {
      return const Text(
        'Add an investor before publishing reports.',
        style: TextStyle(color: AdminDeskColors.muted),
      );
    }

    final fmt = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(widget.selectedInvestorId ?? 'report-investor'),
          initialValue: widget.selectedInvestorId ?? widget.investors.first.id,
          decoration: const InputDecoration(
            labelText: 'Investor',
            isDense: true,
          ),
          items: [
            for (final inv in widget.investors)
              DropdownMenuItem(
                value: inv.id,
                child: Text('${inv.fullName} (${inv.investorCode})'),
              ),
          ],
          onChanged: (id) {
            if (id != null) widget.onSelectInvestor(id);
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Published reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.error != null)
          Text(widget.error!, style: const TextStyle(color: AdminDeskColors.red))
        else if (widget.reports.isEmpty)
          const Text(
            'No reports published for this investor yet.',
            style: TextStyle(color: AdminDeskColors.muted),
          )
        else
          ...widget.reports.map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(
                LucideIcons.fileBarChart,
                size: 16,
                color: AdminDeskColors.gold,
              ),
              title: Text(r.title, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                [
                  r.reportType,
                  if (r.periodLabel != null && r.periodLabel!.isNotEmpty)
                    r.periodLabel!,
                  if (r.generatedAt != null) fmt.format(r.generatedAt!),
                ].join(' · '),
                style: const TextStyle(
                  color: AdminDeskColors.muted,
                  fontSize: 11,
                ),
              ),
              trailing: r.fileUrl == null || r.fileUrl!.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Open report',
                      onPressed: () => _open(r.fileUrl),
                      icon: const Icon(LucideIcons.externalLink, size: 16),
                    ),
            ),
          ),
        if (widget.canPublish) ...[
          const SizedBox(height: 16),
          const Divider(color: AdminDeskColors.border),
          const SizedBox(height: 12),
          const Text(
            'Publish report',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_reportType),
            initialValue: _reportType,
            decoration: const InputDecoration(
              labelText: 'Type',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'portfolio', child: Text('Portfolio')),
              DropdownMenuItem(value: 'distribution', child: Text('Distribution')),
              DropdownMenuItem(value: 'performance', child: Text('Performance')),
              DropdownMenuItem(value: 'tax', child: Text('Tax')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _reportType = v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _periodCtrl,
            decoration: const InputDecoration(
              labelText: 'Period label (optional)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'File URL (optional)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _publishing ? null : _submit,
            icon: const Icon(LucideIcons.upload, size: 16),
            label: Text(_publishing ? 'Publishing…' : 'Publish report'),
          ),
        ],
      ],
    );
  }
}

/// Website CMS ↔ operational capital-raise linker.
class ImpWebsiteLinkPanel extends StatelessWidget {
  const ImpWebsiteLinkPanel({
    super.key,
    required this.opportunities,
    required this.websiteOpportunities,
    required this.canLink,
    required this.onLink,
    this.onSetStatus,
    this.loading = false,
    this.error,
  });

  final List<ImpOpportunity> opportunities;
  final List<ImpWebsiteOpportunity> websiteOpportunities;
  final bool canLink;
  final bool loading;
  final String? error;
  final Future<void> Function({
    required String opportunityId,
    required String websiteOpportunityId,
  })
  onLink;
  final Future<void> Function({
    required String websiteOpportunityId,
    String? status,
    String? opportunityStatus,
    bool? isFeatured,
  })?
  onSetStatus;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Text(error!, style: const TextStyle(color: AdminDeskColors.red));
    }
    if (websiteOpportunities.isEmpty) {
      return const Text(
        'No public website investment cards found to link.',
        style: TextStyle(color: AdminDeskColors.muted),
      );
    }
    if (opportunities.isEmpty) {
      return const Text(
        'Create an operational capital-raise opportunity before linking website cards.',
        style: TextStyle(color: AdminDeskColors.muted, height: 1.4),
      );
    }

    return Column(
      children: [
        for (final site in websiteOpportunities)
          _WebsiteLinkRow(
            site: site,
            opportunities: opportunities,
            canLink: canLink,
            onLink: onLink,
            onSetStatus: onSetStatus,
          ),
      ],
    );
  }
}

class _WebsiteLinkRow extends StatefulWidget {
  const _WebsiteLinkRow({
    required this.site,
    required this.opportunities,
    required this.canLink,
    required this.onLink,
    this.onSetStatus,
  });

  final ImpWebsiteOpportunity site;
  final List<ImpOpportunity> opportunities;
  final bool canLink;
  final Future<void> Function({
    required String opportunityId,
    required String websiteOpportunityId,
  })
  onLink;
  final Future<void> Function({
    required String websiteOpportunityId,
    String? status,
    String? opportunityStatus,
    bool? isFeatured,
  })?
  onSetStatus;

  @override
  State<_WebsiteLinkRow> createState() => _WebsiteLinkRowState();
}

class _WebsiteLinkRowState extends State<_WebsiteLinkRow> {
  String? _opsId;
  late String _opportunityStatus;
  var _linking = false;
  var _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _opsId = widget.site.operationalOpportunityId;
    _opportunityStatus = widget.site.opportunityStatus ?? 'open';
  }

  @override
  void didUpdateWidget(covariant _WebsiteLinkRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.site.operationalOpportunityId !=
        widget.site.operationalOpportunityId) {
      _opsId = widget.site.operationalOpportunityId;
    }
    if (oldWidget.site.opportunityStatus != widget.site.opportunityStatus) {
      _opportunityStatus = widget.site.opportunityStatus ?? 'open';
    }
  }

  Future<void> _save() async {
    final opsId = _opsId;
    if (opsId == null || opsId.isEmpty) return;
    setState(() => _linking = true);
    try {
      await widget.onLink(
        opportunityId: opsId,
        websiteOpportunityId: widget.site.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Linked ${widget.site.projectName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _setStatus({
    String? status,
    String? opportunityStatus,
    bool? isFeatured,
  }) async {
    final handler = widget.onSetStatus;
    if (handler == null) return;
    setState(() => _updatingStatus = true);
    try {
      await handler(
        websiteOpportunityId: widget.site.id,
        status: status,
        opportunityStatus: opportunityStatus,
        isFeatured: isFeatured,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'active'
                  ? 'Published ${widget.site.projectName}'
                  : status == 'draft'
                  ? 'Unpublished ${widget.site.projectName}'
                  : status == 'archived'
                  ? 'Archived ${widget.site.projectName}'
                  : 'Updated ${widget.site.projectName}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? linkedTitle;
    for (final o in widget.opportunities) {
      if (o.id == widget.site.operationalOpportunityId) {
        linkedTitle = o.title;
        break;
      }
    }
    final canPublish = widget.canLink && widget.onSetStatus != null;
    final busy = _linking || _updatingStatus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdminDeskColors.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminDeskColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.site.projectName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    widget.site.isPublished ? 'Published' : widget.site.status,
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: widget.site.isPublished
                      ? AdminDeskColors.gold.withValues(alpha: 0.2)
                      : AdminDeskColors.border,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (widget.site.slug.isNotEmpty) '/${widget.site.slug}',
                if (widget.site.opportunityStatus != null)
                  widget.site.opportunityStatus!,
                if (widget.site.isFeatured) 'Featured',
                if (linkedTitle != null) 'Linked: $linkedTitle',
                if (linkedTitle == null) 'Not linked',
              ].join(' · '),
              style: const TextStyle(
                color: AdminDeskColors.muted,
                fontSize: 12,
              ),
            ),
            if (canPublish) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'opp-status-${widget.site.id}-$_opportunityStatus',
                ),
                initialValue: _opportunityStatus,
                decoration: const InputDecoration(
                  labelText: 'Public opportunity status',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'limited', child: Text('Limited')),
                  DropdownMenuItem(
                    value: 'closing_soon',
                    child: Text('Closing soon'),
                  ),
                  DropdownMenuItem(
                    value: 'coming_soon',
                    child: Text('Coming soon'),
                  ),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  DropdownMenuItem(value: 'sold_out', child: Text('Sold out')),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _opportunityStatus = value);
                        _setStatus(opportunityStatus: value);
                      },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!widget.site.isPublished)
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => _setStatus(status: 'active'),
                      icon: const Icon(LucideIcons.globe, size: 14),
                      label: const Text('Publish'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _setStatus(status: 'draft'),
                      icon: const Icon(LucideIcons.eyeOff, size: 14),
                      label: const Text('Unpublish'),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _setStatus(
                              isFeatured: !widget.site.isFeatured,
                            ),
                    icon: Icon(
                      widget.site.isFeatured
                          ? LucideIcons.starOff
                          : LucideIcons.star,
                      size: 14,
                    ),
                    label: Text(
                      widget.site.isFeatured ? 'Unfeature' : 'Feature',
                    ),
                  ),
                  if (widget.site.status != 'archived')
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => _setStatus(status: 'archived'),
                      child: const Text('Archive'),
                    ),
                ],
              ),
            ],
            if (widget.canLink) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('${widget.site.id}-${_opsId ?? 'none'}'),
                initialValue: _opsId,
                decoration: const InputDecoration(
                  labelText: 'Operational opportunity',
                  isDense: true,
                ),
                items: [
                  for (final opp in widget.opportunities)
                    DropdownMenuItem(
                      value: opp.id,
                      child: Text('${opp.code} — ${opp.title}'),
                    ),
                ],
                onChanged: busy ? null : (id) => setState(() => _opsId = id),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: busy || _opsId == null ? null : _save,
                  icon: const Icon(LucideIcons.link, size: 14),
                  label: Text(_linking ? 'Linking…' : 'Save link'),
                ),
              ),
            ],
            if (_updatingStatus) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class ImpActivityDeskPanel extends StatelessWidget {
  const ImpActivityDeskPanel({
    super.key,
    required this.activities,
    this.onOpenInvestor,
  });

  final List<ImpActivity> activities;
  final ValueChanged<String>? onOpenInvestor;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Text(
        'No investor activity has been recorded.',
        style: TextStyle(color: AdminDeskColors.muted),
      );
    }
    final fmt = DateFormat.MMMd().add_jm();
    return Column(
      children: [
        for (final a in activities)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(
              LucideIcons.activity,
              size: 16,
              color: AdminDeskColors.gold,
            ),
            title: Text(
              a.title,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              [
                a.investorName ?? a.investorId,
                a.eventType,
                if (a.occurredAt != null) fmt.format(a.occurredAt!),
                if (a.description != null && a.description!.isNotEmpty)
                  a.description!,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminDeskColors.muted,
                fontSize: 11,
              ),
            ),
            onTap: onOpenInvestor == null
                ? null
                : () => onOpenInvestor!(a.investorId),
          ),
      ],
    );
  }
}
