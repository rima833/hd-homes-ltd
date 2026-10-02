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
    final progress = (current.index + 1) / steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create your HD Homes account',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${current.index + 1} of ${steps.length} — ${current.title}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
              ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: AppColors.gold,
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    height: 2,
                    color: i <= current.index
                        ? AppColors.gold
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              Tooltip(
                message: steps[i].title,
                child: InkWell(
                  onTap:
                      i <= current.index ? () => onStepTap?.call(steps[i]) : null,
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: i <= current.index
                          ? LinearGradient(
                              colors: [
                                AppColors.gold,
                                AppColors.gold.withValues(alpha: 0.75),
                              ],
                            )
                          : null,
                      color: i <= current.index
                          ? null
                          : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: i == current.index
                            ? Colors.white.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                      boxShadow: i == current.index
                          ? [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.45),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i <= current.index
                            ? AppColors.deepBlack
                            : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
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
