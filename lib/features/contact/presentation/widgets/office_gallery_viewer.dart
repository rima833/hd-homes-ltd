import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fullscreen gallery viewer for office images.
class OfficeGalleryViewer extends StatefulWidget {
  const OfficeGalleryViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  static Future<void> show(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => OfficeGalleryViewer(urls: urls, initialIndex: initialIndex),
    );
  }

  @override
  State<OfficeGalleryViewer> createState() => _OfficeGalleryViewerState();
}

class _OfficeGalleryViewerState extends State<OfficeGalleryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.urls.length}',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
