import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_health.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PccPanel extends StatelessWidget {
  const PccPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminDeskColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminDeskColors.border),
      ),
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
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AdminDeskColors.muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class PccField extends StatelessWidget {
  const PccField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.seed,
    this.hint,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final Object seed;
  final String? hint;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AdminDeskColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('$label-$seed'),
          initialValue: value,
          enabled: enabled,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AdminDeskColors.muted.withValues(alpha: 0.55),
            ),
            filled: true,
            fillColor: AdminDeskColors.elevated,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminDeskColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminDeskColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminDeskColors.gold),
            ),
          ),
        ),
      ],
    );
  }
}

class PccToggle extends StatelessWidget {
  const PccToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminDeskColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AdminDeskColors.muted, fontSize: 12),
        ),
        value: value,
        activeThumbColor: AdminDeskColors.gold,
        onChanged: onChanged,
      ),
    );
  }
}

class PccDeepLinkCard extends StatelessWidget {
  const PccDeepLinkCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.actionLabel,
    required this.onOpen,
  });

  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminDeskColors.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AdminDeskColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AdminDeskColors.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AdminDeskColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(LucideIcons.arrowUpRight, size: 14),
            label: Text(actionLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminDeskColors.gold,
              side: BorderSide(
                color: AdminDeskColors.gold.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color pccStatusColor(PlatformHealthStatus status) => switch (status) {
      PlatformHealthStatus.connected => AdminDeskColors.green,
      PlatformHealthStatus.warning => AdminDeskColors.amber,
      PlatformHealthStatus.error => AdminDeskColors.red,
      PlatformHealthStatus.notConfigured => AdminDeskColors.muted,
      PlatformHealthStatus.unknown => AdminDeskColors.muted,
    };
