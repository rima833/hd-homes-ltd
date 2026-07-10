import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/website/seo/seo_head.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';

/// Binds [SeoMetadata] to the document `<head>` when this widget mounts or updates.
class SeoBinder extends StatefulWidget {
  const SeoBinder({super.key, required this.metadata, required this.child});

  final SeoMetadata metadata;
  final Widget child;

  @override
  State<SeoBinder> createState() => _SeoBinderState();
}

class _SeoBinderState extends State<SeoBinder> {
  @override
  void initState() {
    super.initState();
    SeoHead.apply(widget.metadata);
  }

  @override
  void didUpdateWidget(SeoBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.title != widget.metadata.title ||
        oldWidget.metadata.description != widget.metadata.description ||
        oldWidget.metadata.canonicalUrl != widget.metadata.canonicalUrl ||
        oldWidget.metadata.robots != widget.metadata.robots) {
      SeoHead.apply(widget.metadata);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
