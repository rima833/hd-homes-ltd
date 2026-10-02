import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ClientConstructionPage extends ConsumerWidget {
  const ClientConstructionPage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clientPortalRealtimeHubProvider);
    final updatesAsync = ref.watch(clientConstructionProvider);

    return updatesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(showKpis: false),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientConstructionProvider),
      ),
      data: (updates) {
        if (updates.isEmpty) {
          return ClientEmptyState(
            title: 'No construction updates',
            message:
                'Progress photos and milestones appear here once a property is allocated to your account.',
            icon: LucideIcons.hardHat,
            action: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => context.go(RoutePaths.clientProperties),
                  icon: const Icon(LucideIcons.building2, size: 16),
                  label: const Text('My properties'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.charcoal,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(RoutePaths.clientApplications),
                  icon: const Icon(LucideIcons.fileCheck, size: 16),
                  label: const Text('Applications'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ],
            ),
          );
        }

        final latestPct = updates
            .map((u) => u.completionPercent ?? 0)
            .fold<double>(0, (a, b) => a > b ? a : b);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientConstructionProvider),
          child: ListView(
            padding: _padding(context),
            children: [
              Text(
                'Construction Updates',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ClientPortalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall progress',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ClientProgressBar(
                      label: 'Latest milestone',
                      percent: latestPct,
                      color: AppColors.info,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...updates.map(
                (u) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UpdateCard(update: u),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update});

  final ClientConstructionUpdate update;

  @override
  Widget build(BuildContext context) {
    return ClientPortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.flag, size: 18, color: AppColors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      update.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (update.projectName != null)
                      Text(
                        update.projectName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                  ],
                ),
              ),
              if (update.updateDate != null)
                Text(
                  DateFormat.yMMMd().format(update.updateDate!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                ),
            ],
          ),
          if (update.completionPercent != null) ...[
            const SizedBox(height: 12),
            ClientProgressBar(
              label: 'Completion',
              percent: update.completionPercent!,
              color: AppColors.info,
            ),
          ],
          if (update.description != null) ...[
            const SizedBox(height: 12),
            Text(update.description!),
          ],
          if (update.photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: update.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: MediaDeliveryImage(
                      url: update.photos[i],
                      fit: BoxFit.cover,
                      thumbnail: true,
                      placeholder: Container(color: AppColors.slate700),
                      errorWidget: Container(
                        color: AppColors.slate700,
                        child: const Icon(LucideIcons.image),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
