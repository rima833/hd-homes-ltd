import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Mounts [child] once the section nears the viewport, then keeps it mounted.
///
/// Shows a lightweight placeholder until then. Heavy Contact Hub sections must
/// not all force-mount after a short failsafe — that freezes the public site.
/// Pass a positive [maxWait] only when a section must never stay as a spinner.
class ViewportMount extends StatefulWidget {
  const ViewportMount({
    super.key,
    required this.child,
    this.placeholderHeight = 420,
    this.visibilityFraction = 0.01,
    this.maxWait = Duration.zero,
  });

  final Widget child;
  final double placeholderHeight;

  /// Fraction of the detector that must be visible before mounting.
  final double visibilityFraction;

  /// Optional failsafe mount. [Duration.zero] (default) disables auto-mount.
  final Duration maxWait;

  @override
  State<ViewportMount> createState() => _ViewportMountState();
}

class _ViewportMountState extends State<ViewportMount> {
  var _mountedChild = false;
  Timer? _failsafe;
  late final Key _detectorKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (widget.maxWait > Duration.zero) {
      _failsafe = Timer(widget.maxWait, _mountChild);
    }
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    super.dispose();
  }

  void _mountChild() {
    if (_mountedChild || !mounted) return;
    _failsafe?.cancel();
    _failsafe = null;
    setState(() => _mountedChild = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_mountedChild) return widget.child;

    return VisibilityDetector(
      key: _detectorKey,
      onVisibilityChanged: (info) {
        if (_mountedChild) return;
        if (info.visibleFraction >= widget.visibilityFraction) {
          _mountChild();
        }
      },
      child: SizedBox(
        height: widget.placeholderHeight,
        width: double.infinity,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.gold.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
