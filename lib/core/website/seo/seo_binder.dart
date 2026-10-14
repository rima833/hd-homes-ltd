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
    final a = oldWidget.metadata;
    final b = widget.metadata;
    if (a.title != b.title ||
        a.description != b.description ||
        a.canonicalUrl != b.canonicalUrl ||
        a.robots != b.robots ||
        a.ogImageUrl != b.ogImageUrl) {
      SeoHead.apply(widget.metadata);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
