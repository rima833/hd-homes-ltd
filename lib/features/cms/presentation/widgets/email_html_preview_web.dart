import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Renders the branded email HTML in a sandboxed frame.
class EmailHtmlPreview extends StatefulWidget {
  const EmailHtmlPreview({super.key, required this.html});

  final String html;

  @override
  State<EmailHtmlPreview> createState() => _EmailHtmlPreviewState();
}

class _EmailHtmlPreviewState extends State<EmailHtmlPreview> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = _register(widget.html);
  }

  @override
  void didUpdateWidget(covariant EmailHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      setState(() => _viewType = _register(widget.html));
    }
  }

  String _register(String html) {
    final viewType =
        'hd-email-preview-${identityHashCode(this)}-${html.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final frame = web.HTMLIFrameElement()..setAttribute('sandbox', '');
      frame.setAttribute('srcdoc', html);
      frame.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%'
        ..backgroundColor = '#f3f4f6';
      return frame;
    });
    return viewType;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFFF3F4F6),
        child: SizedBox(
          height: 640,
          width: double.infinity,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
