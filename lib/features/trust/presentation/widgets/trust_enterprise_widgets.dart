import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/trust/data/models/trust_center_content.dart';
import 'package:hdhomesproject/features/trust/presentation/widgets/trust_info_cards.dart';

/// Reusable trust pillar card.
class TrustPillarCard extends StatefulWidget {
  const TrustPillarCard({super.key, required this.pillar});

  final TrustPillar pillar;

  @override
  State<TrustPillarCard> createState() => _TrustPillarCardState();
}

class _TrustPillarCardState extends State<TrustPillarCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.md : AppShadows.sm,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(TrustIcons.resolve(widget.pillar.iconName), color: AppColors.gold, size: 28),
                const SizedBox(height: AppSpacing.sm),
                Text(widget.pillar.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(widget.pillar.description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Certificate card with verification link.
class TrustCertificateCard extends StatelessWidget {
  const TrustCertificateCard({super.key, required this.cert});

  final TrustCertification cert;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardBorder,
                color: AppColors.charcoal,
              ),
              child: const Center(child: Icon(Icons.verified, color: AppColors.gold, size: 36)),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(cert.title, style: Theme.of(context).textTheme.titleSmall),
            Text('${cert.issuer} · ${cert.certificateNumber}', style: Theme.of(context).textTheme.bodySmall),
            Text('Issued ${cert.issueDate}${cert.expiryDate != null ? ' · Expires ${cert.expiryDate}' : ''}'),
            if (cert.verificationUrl != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: () {}, child: const Text('Verify online')),
            ],
          ],
        ),
      ),
    );
  }
}
