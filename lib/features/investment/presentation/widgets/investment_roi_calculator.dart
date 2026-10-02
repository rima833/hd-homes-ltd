import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_roi_calculator_section.dart';

/// Investment Hub ROI calculator — shares the CMS-backed premium UI.
class InvestmentRoiCalculator extends StatelessWidget {
  const InvestmentRoiCalculator({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeRoiCalculatorSection(wrapInSection: false);
  }
}
