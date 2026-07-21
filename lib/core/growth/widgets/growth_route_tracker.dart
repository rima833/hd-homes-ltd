import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/analytics/journey_tracker.dart';
import 'package:hdhomesproject/core/growth/consent/consent_gate.dart';

/// Tracks route changes for analytics and visitor profiling.
class GrowthRouteTracker extends ConsumerStatefulWidget {
  const GrowthRouteTracker({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  ConsumerState<GrowthRouteTracker> createState() => _GrowthRouteTrackerState();
}

class _GrowthRouteTrackerState extends ConsumerState<GrowthRouteTracker> {
  String? _lastLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(consentGateProvider.notifier).load();
      _track(widget.location);
    });
  }

  @override
  void didUpdateWidget(GrowthRouteTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      // Defer provider writes — modifying Riverpod during didUpdateWidget throws.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _track(widget.location);
      });
    }
  }

  void _track(String path) {
    if (_lastLocation == path) return;
    _lastLocation = path;
    trackGrowthPageView(ref, path);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
