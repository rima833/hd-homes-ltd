import 'package:flutter/material.dart';

/// Non-web fallback. The admin Settings app is used in the browser.
class EmailHtmlPreview extends StatelessWidget {
  const EmailHtmlPreview({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Open Settings in the browser to see the rendered email.',
      style: TextStyle(color: Color(0xFF8B929E)),
    );
  }
}
