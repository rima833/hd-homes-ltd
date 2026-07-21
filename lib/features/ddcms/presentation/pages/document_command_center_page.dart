import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/ddcms/domain/entities/ddcms_models.dart';
import 'package:hdhomesproject/features/ddcms/domain/services/ddcms_service.dart';
import 'package:hdhomesproject/features/ddcms/presentation/providers/ddcms_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 12 — Document Command Center (DDCMS).
class DocumentCommandCenterPage extends ConsumerWidget {
  const DocumentCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(ddcmsSnapshotProvider);
    final ui = ref.watch(ddcmsControllerProvider);
    final controller = ref.read(ddcmsControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Document Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Document Command Center live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _DdcmsHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenAi: () => controller.setTab(DdcmsCommandTab.ai),
                    onOpenContracts: () =>
                        controller.setTab(DdcmsCommandTab.contracts),
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
                  child: _EnterpriseFeatureStrip(
                    onSelect: controller.setTab,
                  ),
                ),
                ContainedPadding(
                  child: _SearchAndFilters(
                    ui: ui,
                    onSearch: controller.setSearch,
                    onStatus: controller.setStatusFilter,
                    onCategory: controller.setCategoryFilter,
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
    DdcmsCommandCenterSnapshot snap,
    DdcmsUiState ui,
    DdcmsController controller,
  ) {
    switch (ui.selectedTab) {
      case DdcmsCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Knowledge Vault™',
              icon: LucideIcons.library,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Folders · contracts · OCR · retention in one command surface',
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
              title: 'Secure Collaboration Workspace™',
              icon: LucideIcons.users,
              child: _ShareList(shares: snap.shares.take(3).toList()),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Pending signatures',
              icon: LucideIcons.penTool,
              child: _SignatureList(
                items: snap.signatures
                    .where(
                      (s) =>
                          {'pending', 'sent', 'partially_signed'}
                              .contains(s.status),
                    )
                    .take(3)
                    .toList(),
              ),
            ),
          ),
        ];
      case DdcmsCommandTab.repository:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Document Repository',
              icon: LucideIcons.folderOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FolderChips(folders: snap.folders),
                  const SizedBox(height: 12),
                  _DocumentList(
                    documents: controller.filteredDocuments(snap),
                  ),
                ],
              ),
            ),
          ),
        ];
      case DdcmsCommandTab.contracts:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Intelligent Contract Center™',
              icon: LucideIcons.fileSignature,
              child: _ContractList(
                contracts: controller.filteredContracts(snap),
              ),
            ),
          ),
        ];
      case DdcmsCommandTab.signatures:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Digital Signatures',
              icon: LucideIcons.penTool,
              child: _SignatureList(items: snap.signatures),
            ),
          ),
        ];
      case DdcmsCommandTab.approvals:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Document Approvals',
              icon: LucideIcons.checkCircle,
              child: _ApprovalList(items: snap.approvals),
            ),
          ),
        ];
      case DdcmsCommandTab.dam:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Digital Asset Management',
              icon: LucideIcons.image,
              child: _AssetList(assets: controller.filteredAssets(snap)),
            ),
          ),
        ];
      case DdcmsCommandTab.ocr:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'OCR Processing Queue',
              icon: LucideIcons.scanLine,
              child: _OcrList(jobs: snap.ocrJobs),
            ),
          ),
        ];
      case DdcmsCommandTab.sharing:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Secure Collaboration Workspace™',
              icon: LucideIcons.share2,
              child: _ShareList(shares: snap.shares),
            ),
          ),
        ];
      case DdcmsCommandTab.retention:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Retention Policies',
              icon: LucideIcons.archive,
              child: _RetentionList(policies: snap.retention),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Archival Schedule',
              icon: LucideIcons.clock,
              child: _ArchivalList(records: snap.archival),
            ),
          ),
        ];
      case DdcmsCommandTab.analytics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Document Analytics & Reports',
              icon: LucideIcons.barChart3,
              child: _ReportList(reports: snap.reports),
            ),
          ),
        ];
      case DdcmsCommandTab.ai:
        final service = ref.read(ddcmsServiceProvider);
        final briefing = service.generateIntelligenceBriefing(snap);
        final signals = DdcmsService.detectDocumentSignals(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Smart Document Intelligence™',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(briefing),
                  const SizedBox(height: 8),
                  Text(
                    snap.aiDisclaimer,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const Divider(height: 24),
                  ...signals.map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        LucideIcons.alertTriangle,
                        size: 16,
                        color: AppColors.gold,
                      ),
                      title: Text(s),
                    ),
                  ),
                  const Divider(height: 24),
                  _AiInsightList(insights: snap.aiInsights),
                ],
              ),
            ),
          ),
        ];
      case DdcmsCommandTab.compliance:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Executive Records & Compliance Center™',
              icon: LucideIcons.shieldCheck,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retention alerts · sensitivity · approval trail',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  _ArchivalList(records: snap.archival),
                  const Divider(height: 24),
                  _ApprovalList(
                    items: snap.approvals
                        .where((a) => a.status == 'pending')
                        .toList(),
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

class _DdcmsHeader extends StatelessWidget {
  const _DdcmsHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenAi,
    required this.onOpenContracts,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenContracts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepBlack,
            AppColors.charcoal.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document Command Center',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'DDCMS · Documents · Contracts · DAM',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (fromRemote ? Colors.green : AppColors.gold)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: fromRemote ? Colors.greenAccent : AppColors.gold,
                      ),
                    ),
                    child: Text(
                      fromRemote ? 'Live' : 'Demo',
                      style: TextStyle(
                        color: fromRemote ? Colors.greenAccent : AppColors.gold,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onOpenAi,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('Doc Intelligence'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenContracts,
                    icon: const Icon(LucideIcons.fileSignature, size: 16),
                    label: const Text('Contracts'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      color: AppColors.white,
                    ),
                    tooltip: 'Refresh',
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Document, Digital Asset & Contract Management System',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ticker,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnterpriseFeatureStrip extends StatelessWidget {
  const _EnterpriseFeatureStrip({required this.onSelect});

  final void Function(DdcmsCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (DdcmsCommandTab.repository, 'Knowledge Vault™', LucideIcons.library),
      (DdcmsCommandTab.contracts, 'Contract Center™', LucideIcons.fileSignature),
      (DdcmsCommandTab.ai, 'Doc Intelligence™', LucideIcons.sparkles),
      (DdcmsCommandTab.sharing, 'Collaboration™', LucideIcons.share2),
      (DdcmsCommandTab.compliance, 'Compliance™', LucideIcons.shieldCheck),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (e) => ActionChip(
                avatar: Icon(e.$3, size: 16),
                label: Text(e.$2),
                onPressed: () => onSelect(e.$1),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<DdcmsKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                color: AppColors.white,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.charcoal.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    k.displayValue,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: k.status == 'watch'
                              ? AppColors.gold
                              : AppColors.charcoal,
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
    required this.onCategory,
  });

  final DdcmsUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search documents, contracts, assets…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(borderRadius: AppRadius.cardBorder),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All statuses'),
                selected: ui.statusFilter == null,
                onSelected: (_) => onStatus(null),
              ),
              ...['draft', 'in_review', 'approved', 'published', 'archived']
                  .map(
                (s) => FilterChip(
                  label: Text(s.replaceAll('_', ' ')),
                  selected: ui.statusFilter == s,
                  onSelected: (v) => onStatus(v ? s : null),
                ),
              ),
              FilterChip(
                label: const Text('All categories'),
                selected: ui.categoryFilter == null,
                onSelected: (_) => onCategory(null),
              ),
              ...[
                'property-deed',
                'construction-drawing',
                'marketing-brochure',
                'hr-policy',
                'finance-invoice',
                'contract',
              ].map(
                (c) => FilterChip(
                  label: Text(c.replaceAll('-', ' ')),
                  selected: ui.categoryFilter == c,
                  onSelected: (v) => onCategory(v ? c : null),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final DdcmsCommandTab selected;
  final ValueChanged<DdcmsCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: DdcmsCommandTab.values.map((tab) {
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: AppColors.white,
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
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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

class _FolderChips extends StatelessWidget {
  const _FolderChips({required this.folders});
  final List<DdcmsFolder> folders;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: folders
          .map(
            (f) => Chip(
              avatar: const Icon(LucideIcons.folder, size: 14),
              label: Text(f.name),
            ),
          )
          .toList(),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.documents});
  final List<DdcmsDocument> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const Text('No documents match filters.');
    }
    return Column(
      children: documents
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.fileText,
                color: d.sensitivity == 'confidential'
                    ? Colors.redAccent
                    : AppColors.charcoal,
              ),
              title: Text(d.title),
              subtitle: Text(
                '${d.code ?? d.id} · ${d.status} · ${d.category ?? 'general'}'
                ' · v${d.currentVersion}',
              ),
              trailing: d.ownerLabel != null
                  ? Text(
                      d.ownerLabel!,
                      style: Theme.of(context).textTheme.labelSmall,
                    )
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _ContractList extends StatelessWidget {
  const _ContractList({required this.contracts});
  final List<DdcmsContract> contracts;

  @override
  Widget build(BuildContext context) {
    if (contracts.isEmpty) {
      return const Text('No contracts match filters.');
    }
    return Column(
      children: contracts
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.fileSignature),
              title: Text(c.title),
              subtitle: Text(
                '${c.contractNumber} · ${c.contractType} · ${c.status}'
                '${c.counterpartyName != null ? ' · ${c.counterpartyName}' : ''}',
              ),
              trailing: c.valueAmount != null
                  ? Text(
                      '${c.currency} ${c.valueAmount!.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    )
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _SignatureList extends StatelessWidget {
  const _SignatureList({required this.items});
  final List<DdcmsSignatureRequest> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No signature requests.');
    return Column(
      children: items
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.penTool,
                color: s.status == 'pending' || s.status == 'sent'
                    ? AppColors.gold
                    : AppColors.charcoal,
              ),
              title: Text(s.title),
              subtitle: Text(
                '${s.status}${s.requesterLabel != null ? ' · ${s.requesterLabel}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.items});
  final List<DdcmsApproval> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No approvals.');
    return Column(
      children: items
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                a.status == 'approved'
                    ? LucideIcons.checkCircle2
                    : LucideIcons.clock,
                color: a.status == 'pending' ? AppColors.gold : Colors.green,
              ),
              title: Text(a.title),
              subtitle: Text(
                '${a.status}'
                '${a.requesterLabel != null ? ' · ${a.requesterLabel}' : ''}'
                '${a.approverLabel != null ? ' → ${a.approverLabel}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AssetList extends StatelessWidget {
  const _AssetList({required this.assets});
  final List<DdcmsAsset> assets;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const Text('No digital assets.');
    return Column(
      children: assets
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                a.assetType == 'video'
                    ? LucideIcons.video
                    : a.assetType == 'design'
                        ? LucideIcons.penTool
                        : LucideIcons.image,
              ),
              title: Text(a.title),
              subtitle: Text(
                '${a.assetType} · ${a.status}'
                '${a.usageRights != null ? ' · ${a.usageRights}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _OcrList extends StatelessWidget {
  const _OcrList({required this.jobs});
  final List<DdcmsOcrJob> jobs;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const Text('OCR queue is empty.');
    return Column(
      children: jobs
          .map(
            (j) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.scanLine),
              title: Text('${j.engine} · ${j.pages} page(s)'),
              subtitle: Text('${j.status} · ${j.progressPct}%'),
            ),
          )
          .toList(),
    );
  }
}

class _ShareList extends StatelessWidget {
  const _ShareList({required this.shares});
  final List<DdcmsShare> shares;

  @override
  Widget build(BuildContext context) {
    if (shares.isEmpty) return const Text('No active shares.');
    return Column(
      children: shares
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.share2,
                color: s.isRevoked ? Colors.grey : AppColors.charcoal,
              ),
              title: Text(s.recipientLabel ?? s.recipientEmail ?? 'Share'),
              subtitle: Text(
                '${s.accessLevel}${s.isRevoked ? ' · revoked' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RetentionList extends StatelessWidget {
  const _RetentionList({required this.policies});
  final List<DdcmsRetentionPolicy> policies;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: policies
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.archive),
              title: Text(p.name),
              subtitle: Text(
                '${p.retainMonths} months · on expiry: ${p.actionOnExpiry}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ArchivalList extends StatelessWidget {
  const _ArchivalList({required this.records});
  final List<DdcmsArchivalRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const Text('No archival records.');
    return Column(
      children: records
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.clock, color: AppColors.gold),
              title: Text(r.note ?? 'Archival ${r.status}'),
              subtitle: Text(r.status),
            ),
          )
          .toList(),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.reports});
  final List<DdcmsReport> reports;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: reports
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.barChart3),
              title: Text(r.title),
              subtitle: Text(
                '${r.reportType}${r.periodLabel != null ? ' · ${r.periodLabel}' : ''}'
                '${r.summary != null ? '\n${r.summary}' : ''}',
              ),
              isThreeLine: r.summary != null,
            ),
          )
          .toList(),
    );
  }
}

class _AiInsightList extends StatelessWidget {
  const _AiInsightList({required this.insights});
  final List<DdcmsAiInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: insights
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.sparkles, color: AppColors.gold),
              title: Text(i.title),
              subtitle: Text(
                '${i.body}\n${i.disclaimer}'
                '${i.confidencePct != null ? ' · ${i.confidencePct!.toStringAsFixed(0)}%' : ''}',
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
  final List<DdcmsActivity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.activity, size: 18),
              title: Text(a.summary),
              subtitle: Text(
                '${a.action}${a.actorLabel != null ? ' · ${a.actorLabel}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}
