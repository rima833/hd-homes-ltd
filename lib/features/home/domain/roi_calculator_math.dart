import 'dart:math' as math;

/// ROI / projected returns math for the public investment calculator.
class RoiCalculatorMath {
  const RoiCalculatorMath._();

  static RoiEstimate estimate({
    required double amount,
    required double annualGrowthPercent,
    required double years,
    String method = 'compound',
  }) {
    final principal = amount.clamp(0, double.infinity).toDouble();
    final rate = annualGrowthPercent.clamp(0, 100).toDouble();
    final period = years.clamp(0.1, 100).toDouble();

    late final double projected;
    if (method == 'simple') {
      projected = principal * (1 + (rate / 100) * period);
    } else {
      projected = principal * math.pow(1 + rate / 100, period).toDouble();
    }

    final profit = (projected - principal).clamp(0, double.infinity).toDouble();
    final totalRoi =
        principal <= 0 ? 0.0 : ((projected - principal) / principal) * 100;
    final annualized = period <= 0 ? 0.0 : totalRoi / period;

    final points = <RoiChartPoint>[
      RoiChartPoint(year: 0, value: principal),
    ];
    final wholeYears = period.ceil().clamp(1, 40);
    for (var y = 1; y <= wholeYears; y++) {
      final t = y > period ? period : y.toDouble();
      late final double value;
      if (method == 'simple') {
        value = principal * (1 + (rate / 100) * t);
      } else {
        value = principal * math.pow(1 + rate / 100, t).toDouble();
      }
      points.add(RoiChartPoint(year: t, value: value));
    }

    return RoiEstimate(
      amount: principal,
      growthRate: rate,
      years: period,
      projectedValue: projected,
      netProfit: profit,
      totalRoiPercent: totalRoi,
      annualizedReturnPercent: annualized,
      chartPoints: points,
    );
  }
}

class RoiChartPoint {
  const RoiChartPoint({required this.year, required this.value});

  final double year;
  final double value;
}

class RoiEstimate {
  const RoiEstimate({
    required this.amount,
    required this.growthRate,
    required this.years,
    required this.projectedValue,
    required this.netProfit,
    required this.totalRoiPercent,
    required this.annualizedReturnPercent,
    required this.chartPoints,
  });

  final double amount;
  final double growthRate;
  final double years;
  final double projectedValue;
  final double netProfit;
  final double totalRoiPercent;
  final double annualizedReturnPercent;
  final List<RoiChartPoint> chartPoints;
}
