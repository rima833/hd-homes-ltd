import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_property_card.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_public_flow_sheets.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum _PropertySort { titleAsc, titleDesc, priceAsc, priceDesc, progressDesc }

class ClientPropertiesPage extends ConsumerStatefulWidget {
  const ClientPropertiesPage({super.key});

  @override
  ConsumerState<ClientPropertiesPage> createState() =>
      _ClientPropertiesPageState();
}

class _ClientPropertiesPageState extends ConsumerState<ClientPropertiesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  _PropertySort _sort = _PropertySort.titleAsc;
  bool _isGrid = false; // mockup uses list/horizontal cards by default
  int _page = 0;
  static const _pageSize = 6;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  List<ClientProperty> _enrich(List<ClientProperty> items) {
    final paymentsBundle = ref.watch(clientPaymentsProvider).valueOrNull;
    final installments = paymentsBundle?.installments ?? const [];
    final applications =
        ref.watch(clientApplicationsProvider).valueOrNull ?? const [];

    final nextByPropertyId = <String, DateTime>{};
    final installmentCounts = <String, int>{};
    for (final inst in installments) {
      final pid = inst.propertyId;
      if (pid == null) continue;
      installmentCounts[pid] = (installmentCounts[pid] ?? 0) + 1;
      if (inst.status == 'paid' || inst.status == 'completed') continue;
      final existing = nextByPropertyId[pid];
      if (existing == null || inst.dueDate.isBefore(existing)) {
        nextByPropertyId[pid] = inst.dueDate;
      }
    }

    final planByPropertyId = <String, String?>{};
    for (final app in applications) {
      if (app.paymentPlan != null && app.paymentPlan!.isNotEmpty) {
        planByPropertyId[app.propertyId] = app.paymentPlan;
      }
    }

    return items
        .map(
          (p) => p.copyWith(
            nextDueDate: nextByPropertyId[p.propertyId],
            installmentCount: installmentCounts[p.propertyId] ?? 0,
            paymentPlanCode: planByPropertyId[p.propertyId],
          ),
        )
        .toList();
  }

  List<ClientProperty> _filterAndSort(List<ClientProperty> items) {
    var result = items.where((p) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          (p.location?.toLowerCase().contains(q) ?? false) ||
          (p.propertyCode?.toLowerCase().contains(q) ?? false);
    }).toList();

    switch (_sort) {
      case _PropertySort.titleAsc:
        result.sort((a, b) => a.title.compareTo(b.title));
      case _PropertySort.titleDesc:
        result.sort((a, b) => b.title.compareTo(a.title));
      case _PropertySort.priceAsc:
        result.sort(
          (a, b) => (a.purchasePrice ?? 0).compareTo(b.purchasePrice ?? 0),
        );
      case _PropertySort.priceDesc:
        result.sort(
          (a, b) => (b.purchasePrice ?? 0).compareTo(a.purchasePrice ?? 0),
        );
      case _PropertySort.progressDesc:
        result.sort(
          (a, b) =>
              b.constructionProgressPct.compareTo(a.constructionProgressPct),
        );
    }
    return result;
  }

  void _openDetail(ClientProperty property) {
    context.push(RoutePaths.clientPropertyDetail(property.propertyId));
  }

  Future<void> _bookInspection(ClientProperty property) async {
    await showClientInspectionBookingSheet(
      context,
      ref,
      initialPropertyId: property.propertyId,
    );
    ref.invalidate(clientInspectionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Keep realtime hub warm via parent shell; also watch payments for due dates.
    ref.watch(clientPaymentsProvider);
    final propertiesAsync = ref.watch(clientPropertiesProvider);
    final applicationsAsync = ref.watch(clientApplicationsProvider);

    return propertiesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientPropertiesProvider),
      ),
      data: (properties) {
        final enriched = _enrich(properties);
        final filtered = _filterAndSort(enriched);
        final pageCount = filtered.isEmpty
            ? 1
            : ((filtered.length - 1) / _pageSize).floor() + 1;
        final safePage = _page.clamp(0, pageCount - 1);
        final start = safePage * _pageSize;
        final pageItems = filtered.skip(start).take(_pageSize).toList();
        final pendingApps = applicationsAsync.valueOrNull
                ?.where(
                  (a) => ![
                    'completed',
                    'rejected',
                    'cancelled',
                  ].contains(a.status),
                )
                .length ??
            0;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(clientPropertiesProvider);
            ref.invalidate(clientPaymentsProvider);
            ref.invalidate(clientApplicationsProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: _padding(context),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Properties',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track payment and construction progress for properties allocated to you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                      if (pendingApps > 0) ...[
                        const SizedBox(height: 14),
                        Material(
                          color: AppColors.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () =>
                                context.go(RoutePaths.clientApplications),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.fileText,
                                    color: AppColors.gold,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'You have $pendingApps application${pendingApps == 1 ? '' : 's'} in progress. Open Applications to continue.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.white),
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    color: AppColors.gold,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by title or location...',
                          hintStyle: TextStyle(
                            color: AppColors.slate400.withValues(alpha: 0.9),
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            color: AppColors.slate400,
                          ),
                          filled: true,
                          fillColor: AppColors.darkSurface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  AppColors.neutral700.withValues(alpha: 0.5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color:
                                  AppColors.neutral700.withValues(alpha: 0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(color: AppColors.gold),
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    LucideIcons.x,
                                    color: AppColors.slate400,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _query = '';
                                      _page = 0;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() {
                          _query = v;
                          _page = 0;
                        }),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<_PropertySort>(
                              initialValue: _sort,
                              dropdownColor: AppColors.charcoal,
                              decoration: InputDecoration(
                                labelText: 'Sort by',
                                labelStyle: const TextStyle(
                                  color: AppColors.slate400,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.darkSurface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: _PropertySort.titleAsc,
                                  child: Text('Title A–Z'),
                                ),
                                DropdownMenuItem(
                                  value: _PropertySort.titleDesc,
                                  child: Text('Title Z–A'),
                                ),
                                DropdownMenuItem(
                                  value: _PropertySort.priceAsc,
                                  child: Text('Price low–high'),
                                ),
                                DropdownMenuItem(
                                  value: _PropertySort.priceDesc,
                                  child: Text('Price high–low'),
                                ),
                                DropdownMenuItem(
                                  value: _PropertySort.progressDesc,
                                  child: Text('Construction progress'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _sort = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.darkSurface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.neutral700
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ViewToggle(
                                  icon: LucideIcons.layoutGrid,
                                  selected: _isGrid,
                                  onTap: () => setState(() => _isGrid = true),
                                ),
                                _ViewToggle(
                                  icon: LucideIcons.list,
                                  selected: !_isGrid,
                                  onTap: () => setState(() => _isGrid = false),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (pageItems.isEmpty)
                SliverFillRemaining(
                  child: ClientEmptyState(
                    title: properties.isEmpty
                        ? 'No properties allocated yet'
                        : 'No matches found',
                    message: properties.isEmpty
                        ? 'Apply for a property, then HD Homes allocates it after approval. Model payment plans in Buying tools while you wait.'
                        : 'Try a different search term.',
                    icon: LucideIcons.building2,
                    action: properties.isEmpty
                        ? Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () =>
                                    context.go(RoutePaths.clientApplications),
                                icon: const Icon(
                                  LucideIcons.filePlus2,
                                  size: 16,
                                ),
                                label: const Text('Start application'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.charcoal,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go(RoutePaths.clientTools),
                                icon: const Icon(
                                  LucideIcons.calculator,
                                  size: 16,
                                ),
                                label: const Text('Buying tools'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.gold,
                                  side: const BorderSide(color: AppColors.gold),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go(RoutePaths.properties),
                                icon: const Icon(
                                  LucideIcons.building2,
                                  size: 16,
                                ),
                                label: const Text('Browse listings'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.gold,
                                  side: BorderSide(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                )
              else if (_isGrid)
                SliverPadding(
                  padding: _padding(context).copyWith(top: 0),
                  sliver: MediaQuery.sizeOf(context).width >=
                          AppBreakpoints.desktop
                      ? SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final p = pageItems[index];
                              return ClientPropertyCard(
                                property: p,
                                isGrid: true,
                                onViewDetails: () => _openDetail(p),
                                onScheduleInspection: () => _bookInspection(p),
                                onMore: () => _openDetail(p),
                              );
                            },
                            childCount: pageItems.length,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final p = pageItems[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: ClientPropertyCard(
                                  property: p,
                                  isGrid: true,
                                  onViewDetails: () => _openDetail(p),
                                  onScheduleInspection: () =>
                                      _bookInspection(p),
                                  onMore: () => _openDetail(p),
                                ),
                              );
                            },
                            childCount: pageItems.length,
                          ),
                        ),
                )
              else
                SliverPadding(
                  padding: _padding(context).copyWith(top: 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final p = pageItems[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClientPropertyCard(
                            property: p,
                            isGrid: false,
                            onViewDetails: () => _openDetail(p),
                            onScheduleInspection: () => _bookInspection(p),
                            onMore: () => _openDetail(p),
                          ),
                        );
                      },
                      childCount: pageItems.length,
                    ),
                  ),
                ),
              if (filtered.isNotEmpty)
                SliverPadding(
                  padding: _padding(context),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          'Showing ${start + 1}–${start + pageItems.length} of ${filtered.length} ${filtered.length == 1 ? 'property' : 'properties'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.slate400,
                                  ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: safePage > 0
                              ? () => setState(() => _page = safePage - 1)
                              : null,
                          icon: const Icon(LucideIcons.chevronLeft),
                          color: AppColors.gold,
                        ),
                        ...List.generate(pageCount.clamp(0, 5), (i) {
                          final pageIndex = i;
                          final selected = pageIndex == safePage;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => setState(() => _page = pageIndex),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.gold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.gold
                                        : AppColors.neutral700,
                                  ),
                                ),
                                child: Text(
                                  '${pageIndex + 1}',
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.charcoal
                                        : AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        IconButton(
                          onPressed: safePage < pageCount - 1
                              ? () => setState(() => _page = safePage + 1)
                              : null,
                          icon: const Icon(LucideIcons.chevronRight),
                          color: AppColors.gold,
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(
            icon,
            size: 18,
            color: selected ? AppColors.gold : AppColors.slate400,
          ),
        ),
      ),
    );
  }
}
