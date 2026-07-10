import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Animated counter for homepage statistics.
class AnimatedStatistic extends StatefulWidget {
  const AnimatedStatistic({
    super.key,
    required this.value,
    required this.label,
    this.suffix,
    this.valueColor,
    this.textColor,
  });

  final int value;
  final String label;
  final String? suffix;
  final Color? valueColor;
  final Color? textColor;

  @override
  State<AnimatedStatistic> createState() => _AnimatedStatisticState();
}

class _AnimatedStatisticState extends State<AnimatedStatistic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final display = _animation.value.round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$display${widget.suffix ?? ''}',
              style: theme.headlineMedium?.copyWith(
                color: widget.valueColor ?? AppColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: theme.bodySmall?.copyWith(color: widget.textColor),
            ),
          ],
        );
      },
    );
  }
}
