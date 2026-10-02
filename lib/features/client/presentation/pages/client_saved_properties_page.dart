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
import 'package:share_plus/share_plus.dart';

class ClientSavedPropertiesPage extends ConsumerStatefulWidget {
  const ClientSavedPropertiesPage({super.key});

  @override
  ConsumerState<ClientSavedPropertiesPage> createState() =>
      _ClientSavedPropertiesPageState();
}

class _ClientSavedPropertiesPageState
    extends ConsumerState<ClientSavedPropertiesPage> {
  final Set<String> _compareIds = {};

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  void _openDetail(ClientProperty property) {
    context.push(RoutePaths.clientPropertyDetail(property.propertyId));
  }

  Future<void> _shareSelected(List<ClientProperty> all) async {
    final selected = all.where((p) => _compareIds.contains(p.propertyId));
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select properties to share')),
      );
      return;
    }
    final text = selected
        .map((p) => '${p.title} — ${p.location ?? ''} — ${p.formattedPrice}')
        .join('\n');
    await Share.share('HD Homes saved properties:\n$text');
  }

  @override
  Widget build(BuildContext context) {
    final savedAsync = ref.watch(clientSavedPropertiesProvider);
    final pad = _padding(context);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return savedAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(showKpis: false),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientSavedPropertiesProvider),
      ),
      data: (properties) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientSavedPropertiesProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: pad,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Saved Properties',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (_compareIds.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _shareSelected(properties),
                              icon: const Icon(LucideIcons.share2, size: 16),
                              label: Text('Share (${_compareIds.length})'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Properties you saved from the marketplace.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                      ),
                      if (_compareIds.length >= 2) ...[
                        const SizedBox(height: 12),
                        ClientPortalCard(
                          child: Text(
                            'Comparing ${_compareIds.length} properties — '
                            'contact sales for a side-by-side review.',
                            style: const TextStyle(color: AppColors.slate400),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (properties.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ClientEmptyState(
                    title: 'No saved properties',
                    message:
                        'Save properties from the marketplace to compare them here.',
                    icon: LucideIcons.heart,
                    action: FilledButton(
                      onPressed: () => context.go(RoutePaths.properties),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.charcoal,
                      ),
                      child: const Text('Browse properties'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: pad.copyWith(top: 0, bottom: 32),
                  sliver: SliverList.separated(
                    itemCount: properties.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final p = properties[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClientPropertyCard(
                            property: p,
                            // List layout avoids grid squeeze; fixed hero height.
                            isGrid: !wide,
                            imageHeight: wide ? null : 180,
                            onViewDetails: () => _openDetail(p),
                            onScheduleInspection: () async {
                              await showClientInspectionBookingSheet(
                                context,
                                ref,
                                initialPropertyId: p.propertyId,
                              );
                              ref.invalidate(clientInspectionsProvider);
                            },
                            compareSelected:
                                _compareIds.contains(p.propertyId),
                            onCompareToggle: (selected) {
                              setState(() {
                                if (selected) {
                                  _compareIds.add(p.propertyId);
                                } else {
                                  _compareIds.remove(p.propertyId);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  context.go(RoutePaths.clientSupport),
                              icon: const Icon(LucideIcons.messageCircle, size: 16),
                              label: const Text('Contact sales'),
                            ),
                          ),
                        ],
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
