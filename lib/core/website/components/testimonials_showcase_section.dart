import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared testimonial model for Home, About, Investment, Services, etc.
class TestimonialShowcaseItem {
  const TestimonialShowcaseItem({
    required this.name,
    required this.role,
    required this.quote,
    this.rating = 5,
    this.verified = true,
    this.avatarUrl,
  });

  final String name;
  final String role;
  final String quote;
  final double rating;
  final bool verified;
  final String? avatarUrl;
}

/// Styled testimonials with profiles, typing quotes, centered layout when
/// ≤3 cards, and auto left/right carousel when there are more than 3.
class TestimonialsShowcaseSection extends StatefulWidget {
  const TestimonialsShowcaseSection({
    super.key,
    required this.items,
    this.overline = 'TESTIMONIALS',
    this.title = 'What our clients say',
    this.subtitle =
        'Verified experiences from homeowners, investors, and partners.',
    this.backgroundColor = AppColors.deepBlack,
  });

  final List<TestimonialShowcaseItem> items;
  final String overline;
  final String title;
  final String subtitle;
  final Color backgroundColor;

  @override
  State<TestimonialsShowcaseSection> createState() =>
      _TestimonialsShowcaseSectionState();
}

class _TestimonialsShowcaseSectionState
    extends State<TestimonialsShowcaseSection>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  int _activeIndex = 0;
  bool _scrollingForward = true;
  late final AnimationController _glowController;

  static const _cardGap = AppSpacing.base;
  static const _autoScrollInterval = Duration(seconds: 5);
  static const _scrollDuration = Duration(milliseconds: 750);

  bool get _shouldAutoScroll => widget.items.length > 3;

  double _cardWidth(BuildContext context) {
    if (context.isMobile) {
      return math.min(320, MediaQuery.sizeOf(context).width - 48);
    }
    if (context.isTablet) return 300.0;
    return 340.0;
  }

  double _cardHeight(BuildContext context) => context.isMobile ? 300.0 : 280.0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    if (_shouldAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _armAutoScroll());
    }
  }

  @override
  void didUpdateWidget(covariant TestimonialsShowcaseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _autoScrollTimer?.cancel();
      _activeIndex = 0;
      if (_shouldAutoScroll) {
        _armAutoScroll();
      } else {
        _autoScrollTimer = null;
      }
    }
  }

  void _armAutoScroll() {
    _autoScrollTimer?.cancel();
    if (!_shouldAutoScroll) return;
    _autoScrollTimer =
        Timer.periodic(_autoScrollInterval, (_) => _tickScroll());
  }

  Future<void> _tickScroll() async {
    if (!mounted || !_scrollController.hasClients || widget.items.isEmpty) {
      return;
    }
    final cardW = _cardWidth(context) + _cardGap;
    final maxIndex = widget.items.length - 1;

    if (_scrollingForward) {
      if (_activeIndex >= maxIndex) {
        _scrollingForward = false;
        _activeIndex = math.max(0, maxIndex - 1);
      } else {
        _activeIndex += 1;
      }
    } else {
      if (_activeIndex <= 0) {
        _scrollingForward = true;
        _activeIndex = math.min(1, maxIndex);
      } else {
        _activeIndex -= 1;
      }
    }

    final target = (_activeIndex * cardW).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: _scrollDuration,
      curve: Curves.easeInOutCubic,
    );
    if (mounted) setState(() {});
  }

  void _goTo(int index) {
    if (!_shouldAutoScroll || !_scrollController.hasClients) {
      setState(() => _activeIndex = index.clamp(0, widget.items.length - 1));
      return;
    }
    final cardW = _cardWidth(context) + _cardGap;
    _activeIndex = index.clamp(0, widget.items.length - 1);
    _scrollController.animateTo(
      (_activeIndex * cardW)
          .clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: _scrollDuration,
      curve: Curves.easeInOutCubic,
    );
    setState(() {});
    _armAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _glowController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _cardAt(int index, double cardW) {
    final item = widget.items[index];
    final focused = !_shouldAutoScroll || index == _activeIndex;
    return SizedBox(
      width: cardW,
      child: _TestimonialCard(
        item: item,
        focused: focused,
        animateTyping: focused,
        index: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final cardW = _cardWidth(context);
    final cardH = _cardHeight(context);

    return SectionWrapper(
      backgroundColor: widget.backgroundColor,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final glow = 0.08 + (_glowController.value * 0.12);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.2,
                colors: [
                  AppColors.gold.withValues(alpha: glow),
                  Colors.transparent,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Column(
          children: [
            Text(
              widget.overline,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.gold,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: context.isMobile ? 28 : 36,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              height: cardH,
              width: double.infinity,
              child: _shouldAutoScroll
                  ? ListView.separated(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: _cardGap),
                      itemBuilder: (context, index) => _cardAt(index, cardW),
                    )
                  : Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) const SizedBox(width: _cardGap),
                              _cardAt(i, cardW),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
            if (items.length > 1) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_shouldAutoScroll) ...[
                    _NavChip(
                      icon: LucideIcons.chevronLeft,
                      onTap: () => _goTo(_activeIndex - 1),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  ...List.generate(items.length, (i) {
                    final active = i == _activeIndex || !_shouldAutoScroll;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: active && _shouldAutoScroll ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.gold
                              : AppColors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                  if (_shouldAutoScroll) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _NavChip(
                      icon: LucideIcons.chevronRight,
                      onTap: () => _goTo(_activeIndex + 1),
                    ),
                  ],
                ],
              ),
            ],
            if (_shouldAutoScroll) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Auto-scrolling · ${items.length} stories',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                      letterSpacing: 0.6,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: AppColors.gold),
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatefulWidget {
  const _TestimonialCard({
    required this.item,
    required this.focused,
    required this.animateTyping,
    required this.index,
  });

  final TestimonialShowcaseItem item;
  final bool focused;
  final bool animateTyping;
  final int index;

  @override
  State<_TestimonialCard> createState() => _TestimonialCardState();
}

class _TestimonialCardState extends State<_TestimonialCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 420 + (widget.index % 3) * 80),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.item.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'H';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, math.min(2, s.length)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic)),
        child: AnimatedScale(
          scale: widget.focused ? 1.0 : 0.96,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white
                      .withValues(alpha: widget.focused ? 0.09 : 0.05),
                  AppColors.charcoal.withValues(alpha: 0.55),
                ],
              ),
              border: Border.all(
                color: widget.focused
                    ? AppColors.gold.withValues(alpha: 0.55)
                    : AppColors.white.withValues(alpha: 0.1),
                width: widget.focused ? 1.4 : 1,
              ),
              boxShadow: widget.focused
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < item.rating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: AppColors.gold,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    if (item.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.badgeCheck,
                              size: 12,
                              color: AppColors.gold,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Icon(
                  LucideIcons.quote,
                  size: 22,
                  color: AppColors.gold.withValues(alpha: 0.7),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: _TypingQuote(
                    quote: item.quote,
                    active: widget.animateTyping,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.92),
                          height: 1.45,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Row(
                  children: [
                    _ProfileAvatar(
                      initials: _initials,
                      avatarUrl: item.avatarUrl,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            item.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondaryDark,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    this.avatarUrl,
  });

  final String initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: AppColors.charcoal,
        child: hasUrl
            ? ClipOval(
                child: MediaDeliveryImage(
                  url: url,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  thumbnail: true,
                  errorWidget: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              )
            : Text(
                initials,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}

class _TypingQuote extends StatefulWidget {
  const _TypingQuote({
    required this.quote,
    required this.active,
    this.style,
  });

  final String quote;
  final bool active;
  final TextStyle? style;

  @override
  State<_TypingQuote> createState() => _TypingQuoteState();
}

class _TypingQuoteState extends State<_TypingQuote> {
  Timer? _timer;
  int _chars = 0;
  String _lastQuote = '';
  bool _lastActive = false;

  @override
  void initState() {
    super.initState();
    _lastQuote = widget.quote;
    _lastActive = widget.active;
    if (widget.active) {
      _startTyping();
    } else {
      _chars = '"${widget.quote}"'.length;
    }
  }

  @override
  void didUpdateWidget(covariant _TypingQuote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quote != _lastQuote) {
      _lastQuote = widget.quote;
      if (widget.active) {
        _startTyping();
      } else {
        _chars = '"${widget.quote}"'.length;
      }
    } else if (widget.active && !_lastActive) {
      _startTyping();
    } else if (!widget.active && _lastActive) {
      _timer?.cancel();
      _chars = '"${widget.quote}"'.length;
    }
    _lastActive = widget.active;
  }

  void _startTyping() {
    _timer?.cancel();
    _chars = 0;
    if (mounted) setState(() {});
    final text = '"${widget.quote}"';
    _timer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_chars >= text.length) {
        t.cancel();
        return;
      }
      setState(() => _chars += 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final full = '"${widget.quote}"';
    final visible = full.substring(0, _chars.clamp(0, full.length));
    final showCaret = widget.active && _chars < full.length;

    return RichText(
      maxLines: 5,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: visible),
          if (showCaret)
            TextSpan(
              text: '▌',
              style: widget.style?.copyWith(color: AppColors.gold),
            ),
        ],
      ),
    );
  }
}
