import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:intl/intl.dart';

/// Lightweight interactive Gantt timeline for construction milestones.
class InvestorGanttChart extends StatelessWidget {
  const InvestorGanttChart({
    super.key,
    required this.milestones,
    this.height = 220,
  });

  final List<InvestorMilestone> milestones;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) {
      return const SizedBox.shrink();
    }

    final dates = milestones
        .map((m) => m.targetDate ?? m.completedAt)
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return const SizedBox.shrink();

    dates.sort();
    final start = dates.first.subtract(const Duration(days: 14));
    final end = dates.last.add(const Duration(days: 30));
    final span = end.difference(start).inDays.clamp(1, 9999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: (span * 3.5).clamp(480, 1400).toDouble(),
            height: height,
            child: CustomPaint(
              painter: _GanttPainter(
                milestones: milestones,
                rangeStart: start,
                rangeEnd: end,
                labelStyle: Theme.of(context).textTheme.labelSmall!,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: const [
            _Legend(color: AppColors.success, label: 'Completed'),
            _Legend(color: AppColors.info, label: 'In progress'),
            _Legend(color: AppColors.slate400, label: 'Planned'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _GanttPainter extends CustomPainter {
  _GanttPainter({
    required this.milestones,
    required this.rangeStart,
    required this.rangeEnd,
    required this.labelStyle,
  });

  final List<InvestorMilestone> milestones;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final labelWidth = 140.0;
    final chartWidth = size.width - labelWidth;
    final rowH = size.height / milestones.length.clamp(1, 20);
    final spanDays = rangeEnd.difference(rangeStart).inDays.clamp(1, 9999);
    final dateFmt = DateFormat.MMMd();

    final gridPaint = Paint()
      ..color = AppColors.slate400.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final x = labelWidth + (chartWidth * i / 4);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      final tick = rangeStart.add(Duration(days: (spanDays * i / 4).round()));
      final tp = TextPainter(
        text: TextSpan(
          text: dateFmt.format(tick),
          style: labelStyle.copyWith(color: AppColors.slate400, fontSize: 10),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 0));
    }

    for (var i = 0; i < milestones.length; i++) {
      final m = milestones[i];
      final y = i * rowH + 18;
      final namePainter = TextPainter(
        text: TextSpan(
          text: m.name,
          style: labelStyle.copyWith(color: AppColors.slate700, fontSize: 11),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: labelWidth - 8);
      namePainter.paint(canvas, Offset(4, y));

      final target = m.targetDate ?? m.completedAt ?? rangeEnd;
      final barStart = m.completedAt != null
          ? target.subtract(const Duration(days: 28))
          : target.subtract(const Duration(days: 21));
      final barEnd = target;

      double xOf(DateTime d) {
        final t = d.difference(rangeStart).inDays / spanDays;
        return labelWidth + (t.clamp(0, 1) * chartWidth);
      }

      final left = xOf(barStart);
      final right = xOf(barEnd);
      final color = switch (m.status) {
        'completed' => AppColors.success,
        'in_progress' => AppColors.info,
        _ => AppColors.slate400,
      };

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, y, right.clamp(left + 8, size.width), y + 14),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(covariant _GanttPainter oldDelegate) =>
      oldDelegate.milestones != milestones;
}
