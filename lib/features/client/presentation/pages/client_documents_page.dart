import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientDocumentsPage extends ConsumerStatefulWidget {
  const ClientDocumentsPage({super.key});

  @override
  ConsumerState<ClientDocumentsPage> createState() =>
      _ClientDocumentsPageState();
}

class _ClientDocumentsPageState extends ConsumerState<ClientDocumentsPage> {
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

  Future<void> _openDocument(ClientDocument doc) async {
    setState(() => _openingId = doc.id);
    try {
      final safeUrl =
          await ref.read(clientServiceProvider).resolveDocumentUrl(doc.fileUrl);
      final uri = Uri.tryParse(safeUrl);
      if (uri == null) {
        throw const NetworkException('This document link is invalid.');
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw const NetworkException('Unable to open this document right now.');
      }
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

  IconData _iconForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'contract':
      case 'purchase_agreement':
        return LucideIcons.fileSignature;
      case 'receipt':
      case 'invoice':
        return LucideIcons.receipt;
      case 'certificate':
      case 'allocation':
        return LucideIcons.award;
      case 'valid_id':
      case 'passport_photo':
      case 'proof_of_address':
        return LucideIcons.badgeCheck;
      default:
        return LucideIcons.fileText;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clientPortalRealtimeHubProvider);
    final docsAsync = ref.watch(clientDocumentsProvider);

    return docsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(showKpis: false),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientDocumentsProvider),
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

        final approved = documents
            .where((d) => d.reviewStatus == 'approved')
            .length;
        final pending = documents
            .where((d) => {'uploaded', 'pending', 'in_review'}
                .contains(d.reviewStatus))
            .length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientDocumentsProvider),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: _padding(context),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your documents',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Contracts, allocation letters, and files shared with you — updates appear live.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _StatPill(
                            label: 'Total',
                            value: '${documents.length}',
                            icon: LucideIcons.files,
                          ),
                          _StatPill(
                            label: 'Approved',
                            value: '$approved',
                            icon: LucideIcons.badgeCheck,
                            accent: const Color(0xFF22C55E),
                          ),
                          _StatPill(
                            label: 'In review',
                            value: '$pending',
                            icon: LucideIcons.clock,
                            accent: AppColors.gold,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search title, type, or file name…',
                          prefixIcon: const Icon(LucideIcons.search, size: 18),
                          filled: true,
                          fillColor: const Color(0xFF16181D),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _typeFilter == null,
                            onTap: () => setState(() => _typeFilter = null),
                          ),
                          for (final t in types)
                            _FilterChip(
                              label: t.replaceAll('_', ' '),
                              selected: _typeFilter == t,
                              onTap: () => setState(() => _typeFilter = t),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ClientEmptyState(
                    title: documents.isEmpty
                        ? 'No documents yet'
                        : 'No matches',
                    message: documents.isEmpty
                        ? 'Staff publish contracts and letters here. Upload application docs from your application, or ask support if something is missing.'
                        : 'Try another search or filter.',
                    icon: LucideIcons.folderOpen,
                    action: documents.isEmpty
                        ? Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => context.go(
                                  RoutePaths.clientApplications,
                                ),
                                icon: const Icon(
                                  LucideIcons.fileCheck,
                                  size: 16,
                                ),
                                label: const Text('Applications'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.charcoal,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go(RoutePaths.clientSupport),
                                icon: const Icon(
                                  LucideIcons.lifeBuoy,
                                  size: 16,
                                ),
                                label: const Text('Support'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.gold,
                                  side: const BorderSide(color: AppColors.gold),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                )
              else
                SliverPadding(
                  padding: _padding(context).copyWith(top: 0),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final doc = filtered[i];
                      final opening = _openingId == doc.id;
                      final date = doc.createdAt == null
                          ? '—'
                          : DateFormat('MMM d, yyyy')
                              .format(doc.createdAt!.toLocal());
                      return Material(
                        color: const Color(0xFF16181D),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: opening ? null : () => _openDocument(doc),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _iconForType(doc.documentType),
                                    color: AppColors.gold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(doc.documentType ?? 'document').replaceAll('_', ' ')} · $date'
                                        '${doc.reviewStatus.isNotEmpty ? ' · ${doc.reviewStatus.replaceAll('_', ' ')}' : ''}',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.55),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (opening)
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  IconButton(
                                    tooltip: 'Open / download',
                                    onPressed: () => _openDocument(doc),
                                    icon: const Icon(
                                      LucideIcons.download,
                                      color: AppColors.gold,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppColors.gold,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.16)
                : const Color(0xFF16181D),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(LucideIcons.check, size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
