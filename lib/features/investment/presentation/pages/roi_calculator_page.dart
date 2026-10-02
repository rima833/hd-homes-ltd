import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/home/presentation/sections/home_roi_calculator_section.dart';

/// Dedicated public page for the ROI calculator (under Investment).
class RoiCalculatorPage extends StatelessWidget {
  const RoiCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        HomeRoiCalculatorSection(),
      ],
    );
  }
}
