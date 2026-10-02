import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AccountTypeCards extends StatelessWidget {
  const AccountTypeCards({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final RegistrationAccountType? selected;
  final ValueChanged<RegistrationAccountType> onSelected;

  IconData _icon(RegistrationAccountType type) => switch (type) {
        RegistrationAccountType.client => LucideIcons.home,
        RegistrationAccountType.investor => LucideIcons.trendingUp,
        RegistrationAccountType.propertyOwner => LucideIcons.building2,
        RegistrationAccountType.businessPartner => LucideIcons.users,
        RegistrationAccountType.contractor => LucideIcons.hardHat,
        RegistrationAccountType.vendor => LucideIcons.package,
        RegistrationAccountType.estateManager => LucideIcons.mapPin,
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final selectable = RegistrationAccountType.selectable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How will you use HD Homes?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Client and investor accounts are open.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
        ),
        const SizedBox(height: 18),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < selectable.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _TypeCard(
                    type: selectable[i],
                    icon: _icon(selectable[i]),
                    selected: selected == selectable[i],
                    onTap: () => onSelected(selectable[i]),
                  ),
                ),
              ],
            ],
          )
        else
          Column(
            children: [
              for (final type in selectable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TypeCard(
                    type: type,
                    icon: _icon(type),
                    selected: selected == type,
                    onTap: () => onSelected(type),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _TypeCard extends StatefulWidget {
  const _TypeCard({
    required this.type,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final RegistrationAccountType type;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover || selected ? 1.01 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.gold.withValues(alpha: 0.18),
                          const Color(0xFF1A1D26),
                        ],
                      )
                    : null,
                color: selected
                    ? null
                    : Colors.white.withValues(alpha: _hover ? 0.06 : 0.03),
                border: Border.all(
                  color: selected
                      ? AppColors.gold
                      : Colors.white.withValues(alpha: 0.1),
                  width: selected ? 1.6 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.icon, color: AppColors.gold, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.type.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          LucideIcons.checkCircle2,
                          color: AppColors.gold,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.type.description,
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  for (final b in widget.type.benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              LucideIcons.check,
                              size: 14,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white60),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
