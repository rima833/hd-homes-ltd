import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

Color _hexColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

/// Section 4 + enterprise plot reservation — interactive master plan.
class InteractiveMasterPlan extends HookWidget {
  const InteractiveMasterPlan({super.key, required this.masterPlan});

  final EstateMasterPlan masterPlan;

  @override
  Widget build(BuildContext context) {
    final search = useState('');
    final selectedPlot = useState<MasterPlanPlot?>(null);
    final transformationController = useMemoized(TransformationController.new);

    final filtered = masterPlan.plots.where((p) {
      if (search.value.isEmpty) return true;
      return p.plotNumber.toLowerCase().contains(search.value.toLowerCase()) ||
          p.label.toLowerCase().contains(search.value.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search by plot number…',
            prefixIcon: Icon(LucideIcons.search),
          ),
          onChanged: (v) => search.value = v,
        ),
        const SizedBox(height: AppSpacing.base),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: masterPlan.legend
              .map(
                (l) => Chip(
                  avatar: CircleAvatar(backgroundColor: _hexColor(l.colorHex), radius: 6),
                  label: Text(l.label),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: AppRadius.cardBorder,
          child: SizedBox(
            height: context.isMobile ? 320 : 480,
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: transformationController,
                  minScale: 0.8,
                  maxScale: 4,
                  child: Container(
                    width: 800,
                    height: 500,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.08)],
                      ),
                      border: Border.all(color: AppColors.neutral700),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        return Stack(
                          children: filtered.map((plot) {
                            final color = switch (plot.status.toLowerCase()) {
                              'available' => _hexColor('#4CAF50'),
                              'reserved' => _hexColor('#FF9800'),
                              'sold' => _hexColor('#9E9E9E'),
                              'park' => _hexColor('#2E7D32'),
                              'amenity' => AppColors.gold,
                              'commercial' => _hexColor('#1565C0'),
                              _ => AppColors.neutral500,
                            };
                            return Positioned(
                              left: plot.x * w,
                              top: plot.y * h,
                              width: plot.width * w,
                              height: plot.height * h,
                              child: Material(
                                color: color.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(4),
                                child: InkWell(
                                  onTap: () => selectedPlot.value = plot,
                                  child: Center(
                                    child: Text(
                                      plot.plotNumber,
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.maximize2, color: AppColors.white),
                        onPressed: () => _openFullscreen(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.zoom_in_rounded, color: AppColors.white),
                        onPressed: () {
                          transformationController.value = transformationController.value.scaled(1.2);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selectedPlot.value != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _PlotDetailPanel(
            plot: selectedPlot.value!,
            onClose: () => selectedPlot.value = null,
          ),
        ],
      ],
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            const Center(child: Text('Master Plan — Fullscreen')),
            Positioned(
              top: AppSpacing.base,
              right: AppSpacing.base,
              child: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlotDetailPanel extends StatelessWidget {
  const _PlotDetailPanel({required this.plot, required this.onClose});

  final MasterPlanPlot plot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${plot.plotNumber} — ${plot.label}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClose),
            ],
          ),
          Text('Status: ${plot.status}'),
          if (plot.price != null) Text('Price: ${plot.price}'),
          const SizedBox(height: AppSpacing.base),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (plot.propertyId != null)
                PrimaryButton(
                  label: 'View Property',
                  onPressed: () => context.go('/properties/${plot.propertyId}'),
                ),
              PrimaryButton(
                label: 'Reserve Plot',
                variant: ButtonVariant.secondary,
                onPressed: () => context.go('/contact'),
              ),
              PrimaryButton(
                label: 'Book Inspection',
                variant: ButtonVariant.ghost,
                onPressed: () => context.go('/book-inspection'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
