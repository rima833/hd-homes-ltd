import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Defers building heavy Contact Hub sections until they are near the viewport
/// (and optionally after a short delay) so navigation stays responsive.
class DeferredSection extends StatefulWidget {
  const DeferredSection({
    super.key,
    required this.builder,
    this.placeholderHeight = 220,
    this.delay = Duration.zero,
    this.waitUntilVisible = true,
  });

  final WidgetBuilder builder;
  final double placeholderHeight;
  final Duration delay;

  /// When true, only mounts once this section is within ~1.25× screen height.
  final bool waitUntilVisible;

  @override
  State<DeferredSection> createState() => _DeferredSectionState();
}

class _DeferredSectionState extends State<DeferredSection> {
  var _ready = false;
  ScrollPosition? _position;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.delay > Duration.zero) {
      _delayTimer = Timer(widget.delay, _scheduleCheck);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleCheck());
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _detachScroll();
    super.dispose();
  }

  void _scheduleCheck() {
    if (!mounted || _ready) return;
    if (!widget.waitUntilVisible) {
      setState(() => _ready = true);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
  }

  void _detachScroll() {
    _position?.removeListener(_checkVisible);
    _position = null;
  }

  void _attachScroll() {
    final scrollable = Scrollable.maybeOf(context);
    final next = scrollable?.position;
    if (identical(next, _position)) return;
    _detachScroll();
    _position = next;
    _position?.addListener(_checkVisible);
  }

  void _checkVisible() {
    if (!mounted || _ready) return;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisible());
      return;
    }

    _attachScroll();

    final top = ro.localToGlobal(Offset.zero).dy;
    final bottom = top + ro.size.height;
    final viewH = MediaQuery.sizeOf(context).height;
    // Mount a bit before it enters the viewport.
    final near = top < viewH * 1.35 && bottom > -viewH * 0.2;
    if (near) {
      _detachScroll();
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return SizedBox(
        height: widget.placeholderHeight,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.gold,
            ),
          ),
        ),
      );
    }
    return widget.builder(context);
  }
}
