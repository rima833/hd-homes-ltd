import 'dart:math' as math;

/// EMI / installment math for the public payment plan calculator.
class PaymentPlanMath {
  const PaymentPlanMath._();

  static PaymentPlanEstimate estimate({
    required double propertyPrice,
    required double depositAmount,
    required int durationMonths,
    required double annualInterestPercent,
    String method = 'reducing_balance',
  }) {
    final price = propertyPrice.clamp(0, double.infinity).toDouble();
    final deposit = depositAmount.clamp(0, price).toDouble();
    final months = durationMonths.clamp(1, 600);
    final loan = (price - deposit).clamp(0, double.infinity).toDouble();
    final annual = annualInterestPercent.clamp(0, 100).toDouble();

    late final double monthly;
    if (loan <= 0) {
      monthly = 0;
    } else if (method == 'flat') {
      final totalInterest = loan * (annual / 100) * (months / 12);
      monthly = (loan + totalInterest) / months;
    } else {
      final r = annual / 100 / 12;
      if (r <= 0) {
        monthly = loan / months;
      } else {
        final factor = math.pow(1 + r, months).toDouble();
        monthly = loan * (r * factor) / (factor - 1);
      }
    }

    final installmentTotal = monthly * months;
    final totalInterest =
        (installmentTotal - loan).clamp(0, double.infinity).toDouble();
    final totalRepayment = deposit + installmentTotal;

    return PaymentPlanEstimate(
      propertyPrice: price,
      depositAmount: deposit,
      durationMonths: months,
      interestRate: annual,
      loanAmount: loan,
      monthlyPayment: monthly,
      totalInterest: totalInterest,
      totalRepayment: totalRepayment,
    );
  }
}

class PaymentPlanEstimate {
  const PaymentPlanEstimate({
    required this.propertyPrice,
    required this.depositAmount,
    required this.durationMonths,
    required this.interestRate,
    required this.loanAmount,
    required this.monthlyPayment,
    required this.totalInterest,
    required this.totalRepayment,
  });

  final double propertyPrice;
  final double depositAmount;
  final int durationMonths;
  final double interestRate;
  final double loanAmount;
  final double monthlyPayment;
  final double totalInterest;
  final double totalRepayment;
}
