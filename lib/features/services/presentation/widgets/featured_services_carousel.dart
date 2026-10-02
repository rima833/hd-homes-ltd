import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/presentation/widgets/service_card.dart';

/// Infinite auto-scrolling featured services strip.
/// Cards advance one-by-one; direction flips after a full set so motion
/// goes left then right (and so on) forever.
class FeaturedServicesCarousel extends StatefulWidget {
  const FeaturedServicesCarousel({super.key, required this.services});

  final List<ServiceSummary> services;

  @override
  State<FeaturedServicesCarousel> createState() =>
      _FeaturedServicesCarouselState();
}

class _FeaturedServicesCarouselState extends State<FeaturedServicesCarousel> {
  final _controller = ScrollController();
  Timer? _timer;
  bool _paused = false;
  bool _animating = false;

  /// +1 = move left (content scrolls right-to-left), -1 = move right.
  int _direction = 1;
  int _stepsInDirection = 0;

  static const _gap = AppSpacing.base;
  static const _interval = Duration(seconds: 3);
  static const _animDuration = Duration(milliseconds: 650);
  static const _loops = 40;

  double _cardWidth(BuildContext context) => context.isMobile ? 280 : 320;

  double get _stride => _cardWidth(context) + _gap;

  int get _len => widget.services.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _len == 0) return;
      _jumpToMiddle();
      _arm();
    });
  }

  @override
  void didUpdateWidget(covariant FeaturedServicesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services.length != widget.services.length ||
        !_sameSlugs(oldWidget.services, widget.services)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _direction = 1;
        _stepsInDirection = 0;
        _jumpToMiddle();
        _arm();
      });
    }
  }

  bool _sameSlugs(List<ServiceSummary> a, List<ServiceSummary> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].slug != b[i].slug) return false;
    }
    return true;
  }

  void _jumpToMiddle() {
    if (!_controller.hasClients || _len == 0) return;
    final middle = (_loops ~/ 2) * _len;
    _controller.jumpTo(middle * _stride);
  }

  void _arm() {
    _timer?.cancel();
    if (_len <= 1) return;
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (!mounted ||
        _paused ||
        _animating ||
        !_controller.hasClients ||
        _len <= 1) {
      return;
    }
    final stride = _stride;
    final next = _controller.offset + (stride * _direction);
    _animating = true;
    try {
      await _controller.animateTo(
        next,
        duration: _animDuration,
        curve: Curves.easeInOutCubic,
      );
    } catch (_) {
      // Controller disposed mid-animation.
    }
    if (!mounted || !_controller.hasClients) return;
    _animating = false;
    _stepsInDirection++;
    // After one full pass of featured cards, reverse direction.
    if (_stepsInDirection >= _len) {
      _direction = -_direction;
      _stepsInDirection = 0;
    }
    _recenterIfNeeded(stride);
  }

  void _recenterIfNeeded(double stride) {
    if (_len == 0 || !_controller.hasClients) return;
    final total = _loops * _len;
    final index = (_controller.offset / stride).round();
    final low = _len * 4;
    final high = total - _len * 4;
    if (index < low || index > high) {
      final normalized = ((index % _len) + _len) % _len;
      final middle = (_loops ~/ 2) * _len + normalized;
      _controller.jumpTo(middle * stride);
    }
  }

  void _pause() {
    if (_paused) return;
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) return;
    setState(() => _paused = false);
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    if (services.isEmpty) return const SizedBox.shrink();

    final cardW = _cardWidth(context);
    final itemCount = services.length <= 1 ? 1 : services.length * _loops;

    return MouseRegion(
      onEnter: (_) => _pause(),
      onExit: (_) => _resume(),
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          // Pause while user drags; resume when they stop.
          if (notification.direction == ScrollDirection.idle) {
            _resume();
          } else {
            _pause();
          }
          return false;
        },
        child: SizedBox(
          height: 340,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, index) {
              final service = services[index % services.length];
              return SizedBox(
                width: cardW,
                child: ServiceCard(service: service),
              );
            },
          ),
        ),
      ),
    );
  }
}
