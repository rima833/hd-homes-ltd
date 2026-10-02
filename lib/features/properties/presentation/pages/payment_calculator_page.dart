import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_payment_calculator_section.dart';

/// Dedicated public page for the payment plan calculator (under Properties).
class PaymentCalculatorPage extends StatelessWidget {
  const PaymentCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        HomePaymentCalculatorSection(),
      ],
    );
  }
}
