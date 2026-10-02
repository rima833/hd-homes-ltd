import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class InvestorDocumentsPage extends ConsumerStatefulWidget {
  const InvestorDocumentsPage({super.key});

  @override
  ConsumerState<InvestorDocumentsPage> createState() =>
      _InvestorDocumentsPageState();
}

class _InvestorDocumentsPageState extends ConsumerState<InvestorDocumentsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _typeFilter;
  String? _openingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _refresh() async {
    ref.invalidate(investorDocumentsProvider);
    await ref.read(investorDocumentsProvider.future);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw const NetworkException('This document link is invalid.');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw const NetworkException('Unable to open this document right now.');
    }
  }

  Future<void> _openDocument(
    InvestorDocument doc, {
    String? overrideFileUrl,
  }) async {
    if (!doc.hasFile && overrideFileUrl == null) {
      showFriendlyError(
        context,
        null,
        fallback: 'This document has no file attached yet.',
      );
      return;
    }
    if (doc.isExpired && overrideFileUrl == null) {
      showFriendlyError(
        context,
        null,
        fallback: 'This document has expired. Contact HD Homes for a reissue.',
      );
      return;
    }
    setState(() => _openingId = doc.id);
    try {
      final safeUrl = await ref
          .read(investorServiceProvider)
          .resolveInvestorDocumentUrl(doc, overrideFileUrl: overrideFileUrl);
      await _openUrl(safeUrl);
    } catch (e) {
      if (!mounted) return;
      showFriendlyError(
        context,
        e,
        fallback: 'Unable to open this document. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _showVersions(InvestorDocument doc) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final history = doc.versionHistory;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Versions — ${doc.title}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current v${doc.version} · prior copies stay available until Admin replaces them.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.fileCheck, color: AppColors.gold),
                  title: Text(
                    'Current · v${doc.version}',
                    style: const TextStyle(color: AppColors.white),
                  ),
                  subtitle: Text(
                    doc.updatedAt != null
                        ? DateFormat.yMMMd().add_jm().format(doc.updatedAt!)
                        : 'Latest published file',
                    style: const TextStyle(color: AppColors.slate400),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openDocument(doc);
                    },
                    child: const Text('Open'),
                  ),
                ),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No prior versions on file.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                          ),
                    ),
                  )
                else
                  ...history.map(
                    (v) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        LucideIcons.history,
                        color: AppColors.slate400,
                      ),
                      title: Text(
                        'v${v.version}',
                        style: const TextStyle(color: AppColors.white),
                      ),
                      subtitle: Text(
                        v.replacedAt != null
                            ? 'Replaced ${DateFormat.yMMMd().format(v.replacedAt!)}'
                            : 'Prior version',
                        style: const TextStyle(color: AppColors.slate400),
                      ),
                      trailing: TextButton(
                        onPressed: v.fileUrl.isEmpty
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _openDocument(
                                  doc,
                                  overrideFileUrl: v.fileUrl,
                                );
                              },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'contract':
        return LucideIcons.fileSignature;
      case 'statement':
        return LucideIcons.receipt;
      case 'certificate':
        return LucideIcons.award;
      case 'tax':
        return LucideIcons.fileSpreadsheet;
      case 'kyc':
      case 'identity':
        return LucideIcons.shieldCheck;
      case 'agreement':
        return LucideIcons.fileCheck;
      default:
        return LucideIcons.fileText;
    }
  }

  String _prettyType(String? type) =>
      (type ?? 'document').replaceAll('_', ' ');

  String _deliveryLabel(String kind) {
    switch (kind) {
      case 'cloudinary':
        return 'Cloudinary';
      case 'storage':
        return 'Secure storage';
      case 'https':
        return 'Secure link';
      default:
        return 'File';
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(investorDocumentsProvider);
    final connection = ref.watch(investorRealtimeConnectionProvider);
    final live = connection == InvestorRealtimeConnection.live;
    final pad = _padding(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return docsAsync.when(
      loading: () => const InvestorDashboardSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: _refresh,
      ),
      data: (documents) {
        final types = documents
            .map((d) => d.documentType)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

        final filtered = documents.where((d) {
          if (_typeFilter != null && d.documentType != _typeFilter) {
            return false;
          }
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return d.title.toLowerCase().contains(q) ||
              (d.documentType?.toLowerCase().contains(q) ?? false) ||
              (d.fileName?.toLowerCase().contains(q) ?? false);
        }).toList();

        final typeCounts = <String, int>{};
        for (final d in documents) {
          final key = d.documentType ?? 'document';
          typeCounts[key] = (typeCounts[key] ?? 0) + 1;
        }
        final sensitiveCount = documents.where((d) => d.isSensitive).length;
        final versionedCount =
            documents.where((d) => d.version > 1 || d.hasPriorVersions).length;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: pad,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Document vault',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Contracts, statements, and packs published by Admin — versioned and synced live.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.slate400),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _LiveChip(live: live, connection: connection),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: InvestorKpiCard(
                                label: 'Total documents',
                                value: '${documents.length}',
                                icon: LucideIcons.files,
                                subtitle: 'On file',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InvestorKpiCard(
                                label: 'Sensitive',
                                value: '$sensitiveCount',
                                icon: LucideIcons.shield,
                                accent: AppColors.warning,
                                subtitle: 'Restricted',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InvestorKpiCard(
                                label: 'Versioned',
                                value: '$versionedCount',
                                icon: LucideIcons.gitBranch,
                                accent: AppColors.info,
                                subtitle: 'Updated packs',
                              ),
                            ),
                          ],
                        )
                      else
                        InvestorPortalCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  LucideIcons.files,
                                  color: AppColors.gold,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${documents.length} document${documents.length == 1 ? '' : 's'} · $sensitiveCount sensitive',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              Text(
                                '${filtered.length} shown',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: AppColors.slate400),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.white),
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search documents…',
                          hintStyle: TextStyle(
                            color: AppColors.slate400.withValues(alpha: 0.9),
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            color: AppColors.slate400,
                            size: 18,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.darkSurface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  AppColors.neutral700.withValues(alpha: 0.5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  AppColors.neutral700.withValues(alpha: 0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.gold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'All (${documents.length})',
                            selected: _typeFilter == null,
                            onTap: () => setState(() => _typeFilter = null),
                          ),
                          for (final t in types)
                            _FilterChip(
                              label:
                                  '${_prettyType(t)} (${typeCounts[t] ?? 0})',
                              selected: _typeFilter == t,
                              onTap: () => setState(() => _typeFilter = t),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: InvestorEmptyState(
                    title: documents.isEmpty
                        ? 'No documents yet'
                        : 'No matches found',
                    message: documents.isEmpty
                        ? 'When Admin publishes investor packs, contracts, or statements from DDCMS, they appear here live.'
                        : 'Try another search or clear the type filter.',
                    icon: LucideIcons.folderOpen,
                    action: documents.isEmpty
                        ? FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(LucideIcons.rotateCcw, size: 16),
                            label: const Text('Refresh'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.charcoal,
                            ),
                          )
                        : TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _typeFilter = null;
                              });
                            },
                            child: const Text('Clear filters'),
                          ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad.left, 8, pad.right, 32),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final opening = _openingId == doc.id;
                      final date = doc.updatedAt ?? doc.createdAt;
                      return InvestorPortalCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _iconForType(doc.documentType),
                                    color: AppColors.gold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          _prettyType(doc.documentType),
                                          'v${doc.version}',
                                          if (date != null)
                                            DateFormat.yMMMd().format(date),
                                          _deliveryLabel(doc.deliveryKind),
                                        ].join(' · '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.slate400,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (doc.isSensitive)
                                  _MetaChip(
                                    label: 'Sensitive',
                                    color: AppColors.warning,
                                  ),
                                if (doc.isExpired)
                                  _MetaChip(
                                    label: 'Expired',
                                    color: AppColors.error,
                                  ),
                                if (doc.hasPriorVersions)
                                  _MetaChip(
                                    label: '${doc.versionHistory.length} prior',
                                    color: AppColors.info,
                                  ),
                                if (!doc.hasFile)
                                  _MetaChip(
                                    label: 'No file',
                                    color: AppColors.slate500,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: opening || !doc.hasFile || doc.isExpired
                                      ? null
                                      : () => _openDocument(doc),
                                  icon: opening
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.charcoal,
                                          ),
                                        )
                                      : const Icon(
                                          LucideIcons.download,
                                          size: 16,
                                        ),
                                  label: Text(
                                    opening ? 'Opening…' : 'Download / open',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: AppColors.charcoal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (doc.hasPriorVersions || doc.version > 1)
                                  OutlinedButton.icon(
                                    onPressed: () => _showVersions(doc),
                                    icon: const Icon(
                                      LucideIcons.history,
                                      size: 16,
                                    ),
                                    label: const Text('Versions'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live, required this.connection});

  final bool live;
  final InvestorRealtimeConnection connection;

  @override
  Widget build(BuildContext context) {
    if (live || connection == InvestorRealtimeConnection.connecting) {
      return const SizedBox.shrink();
    }
    return const OfflineUpdatesNote();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.15)
              : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.55)
                : AppColors.neutral700.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.gold : AppColors.slate400,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
