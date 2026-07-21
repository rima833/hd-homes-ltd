import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';

class RegistrationStepperHeader extends StatelessWidget {
  const RegistrationStepperHeader({
    super.key,
    required this.current,
    this.onStepTap,
  });

  final RegistrationStep current;
  final ValueChanged<RegistrationStep>? onStepTap;

  @override
  Widget build(BuildContext context) {
    final steps = RegistrationStep.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create your HD Homes account',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Step ${current.index + 1} of ${steps.length} — ${current.title}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= current.index
                        ? AppColors.gold
                        : AppColors.gray.withValues(alpha: 0.35),
                  ),
                ),
              InkWell(
                onTap: i <= current.index ? () => onStepTap?.call(steps[i]) : null,
                borderRadius: BorderRadius.circular(20),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= current.index
                      ? AppColors.gold
                      : AppColors.gray.withValues(alpha: 0.25),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i <= current.index ? AppColors.deepBlack : AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
