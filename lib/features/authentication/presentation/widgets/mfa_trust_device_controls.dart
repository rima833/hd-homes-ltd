import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';

/// Shared "Trust this device" switch + 14 / 30 / 90 day chips.
/// Used by MFA challenge (all portals) and trusted-device management sheets.
class MfaTrustDeviceControls extends StatelessWidget {
  const MfaTrustDeviceControls({
    super.key,
    required this.enabled,
    required this.selectedDays,
    required this.onEnabledChanged,
    required this.onDaysChanged,
    this.busy = false,
    this.title = 'Trust this device',
    this.showSwitch = true,
  });

  final bool enabled;
  final int selectedDays;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onDaysChanged;
  final bool busy;
  final String title;

  /// When false, only duration chips are shown (e.g. "Extend trust" sheets).
  final bool showSwitch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSwitch)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text(
              enabled
                  ? 'Skip MFA for ${MfaTrustDurationOptions.label(selectedDays)}'
                  : 'Skip MFA on this device next time you sign in',
            ),
            value: enabled,
            onChanged: busy ? null : onEnabledChanged,
          ),
        if (enabled || !showSwitch) ...[
          if (showSwitch) const SizedBox(height: AppSpacing.sm),
          Text(
            showSwitch ? 'Trust duration' : 'Extend trust',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppColors.slate400),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final days in MfaTrustDurationOptions.all)
                ChoiceChip(
                  label: Text(MfaTrustDurationOptions.label(days)),
                  selected: selectedDays == days,
                  onSelected: busy ? null : (_) => onDaysChanged(days),
                  selectedColor: AppColors.gold.withValues(alpha: 0.28),
                  labelStyle: TextStyle(
                    color: selectedDays == days
                        ? AppColors.gold
                        : AppColors.slate400,
                  ),
                  side: BorderSide(
                    color: selectedDays == days
                        ? AppColors.gold
                        : AppColors.slate700,
                  ),
                  backgroundColor: Colors.transparent,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
