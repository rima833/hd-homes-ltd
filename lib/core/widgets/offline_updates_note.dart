import 'package:flutter/material.dart';

/// Quiet line shown only when a portal cannot reach live data.
class OfflineUpdatesNote extends StatelessWidget {
  const OfflineUpdatesNote({super.key, this.color});

  final Color? color;

  static const message = "Updates will refresh when you're back online.";

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: color ?? const Color(0xFF8B929E),
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
