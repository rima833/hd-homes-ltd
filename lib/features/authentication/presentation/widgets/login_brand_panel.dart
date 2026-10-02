import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_audience.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Left-panel brand experience for desktop login (Smart Login gateway).
///
/// Stats come from Admin → Website → Company Statistics and rotate through
/// the full published set when more than three exist.
class LoginBrandPanel extends ConsumerStatefulWidget {
  const LoginBrandPanel({super.key, this.audience});

  /// When set, supporting copy adapts to the detected login audience.
  final LoginAudience? audience;

  @override
  ConsumerState<LoginBrandPanel> createState() => _LoginBrandPanelState();
}

class _LoginBrandPanelState extends ConsumerState<LoginBrandPanel>
    with SingleTickerProviderStateMixin {
  static const _fallback = <_LoginStatView>[
    _LoginStatView(
      icon: LucideIcons.building2,
      value: '50+',
      label: 'Estates delivered',
    ),
    _LoginStatView(
      icon: LucideIcons.users,
      value: '2k+',
      label: 'Happy clients',
    ),
    _LoginStatView(
      icon: LucideIcons.shieldCheck,
      value: '100%',
      label: 'Escrow protected',
    ),
  ];

  static const _visibleCount = 3;
  static const _rotateInterval = Duration(seconds: 4);

  late final AnimationController _fade;
  Timer? _rotateTimer;
  int _page = 0;
  List<_LoginStatView> _stats = _fallback;
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _applyStats(List<_LoginStatView> next) {
    final source = next.isEmpty ? _fallback : next;
    final signature = source
        .map((s) => '${s.value}|${s.label}|${s.logoUrl ?? ''}')
        .join('||');
    if (signature == _signature) {
      _ensureRotateTimer();
      return;
    }
    _signature = signature;
    setState(() {
      _stats = source;
      _page = 0;
    });
    _ensureRotateTimer();
  }

  void _ensureRotateTimer() {
    _rotateTimer?.cancel();
    if (_stats.length <= _visibleCount) return;
    _rotateTimer = Timer.periodic(_rotateInterval, (_) => unawaited(_advance()));
  }

  Future<void> _advance() async {
    if (!mounted || _stats.length <= _visibleCount) return;
    await _fade.reverse();
    if (!mounted) return;
    setState(() {
      _page = (_page + _visibleCount) % _stats.length;
    });
    await _fade.forward();
  }

  List<_LoginStatView> get _visible {
    if (_stats.isEmpty) return _fallback;
    if (_stats.length <= _visibleCount) return _stats;
    return [
      for (var i = 0; i < _visibleCount; i++)
        _stats[(_page + i) % _stats.length],
    ];
  }

  IconData _iconFor(String? name) {
    switch ((name ?? '').toLowerCase()) {
      case 'home':
        return LucideIcons.home;
      case 'users':
        return LucideIcons.users;
      case 'calendar':
        return LucideIcons.calendar;
      case 'building':
      case 'building2':
        return LucideIcons.building2;
      case 'trendingup':
        return LucideIcons.trendingUp;
      case 'hardhat':
        return LucideIcons.hardHat;
      case 'briefcase':
        return LucideIcons.briefcase;
      case 'handshake':
        return LucideIcons.heartHandshake;
      case 'award':
        return LucideIcons.award;
      case 'shield':
      case 'shieldcheck':
        return LucideIcons.shieldCheck;
      case 'heart':
        return LucideIcons.heart;
      default:
        return LucideIcons.barChart3;
    }
  }

  String _formatValue(CmsCompanyStat s) {
    final suffix = s.suffix.trim();
    if (suffix.isEmpty && s.value >= 1000) {
      final k = s.value / 1000;
      final text = k == k.roundToDouble()
          ? k.toInt().toString()
          : k.toStringAsFixed(1);
      return '${text}k+';
    }
    return '${s.value}$suffix';
  }

  List<_LoginStatView> _fromCms(List<CmsCompanyStat> rows) {
    return [
      for (final s in rows)
        _LoginStatView(
          icon: _iconFor(s.iconName),
          value: _formatValue(s),
          label: s.label.trim().isEmpty ? 'Statistic' : s.label.trim(),
          logoUrl: s.logoUrl,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(companyStatsRealtimeProvider);

    ref.listen<AsyncValue<List<CmsCompanyStat>>>(
      publishedCompanyStatsHomeProvider,
      (prev, next) {
        next.whenData((rows) => _applyStats(_fromCms(rows)));
      },
    );

    final cached = ref.watch(publishedCompanyStatsHomeProvider).valueOrNull;
    if (cached != null && _signature.isEmpty) {
      final mapped = _fromCms(cached);
      final signature = mapped
          .map((s) => '${s.value}|${s.label}|${s.logoUrl ?? ''}')
          .join('||');
      if (signature.isNotEmpty) {
        _signature = signature;
        _stats = mapped.isEmpty ? _fallback : mapped;
        _ensureRotateTimer();
      }
    }

    final pageCount = _stats.length <= _visibleCount
        ? 1
        : (_stats.length / _visibleCount).ceil();
    final pageIndex = pageCount <= 1
        ? 0
        : (_page / _visibleCount).floor() % pageCount;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepBlack,
            AppColors.charcoal,
            Color(0xFF2A2418),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -40,
            bottom: -40,
            child: Icon(
              LucideIcons.home,
              size: 280,
              color: AppColors.gold.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  AppTheme.logoAsset,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'HD Homes',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  LoginAudienceCopy.brandHeadline,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.base),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Text(
                    LoginAudienceCopy.brandBody(widget.audience),
                    key: ValueKey(widget.audience?.name ?? 'default'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _fade,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.base,
                      children: [
                        for (final s in _visible)
                          SizedBox(
                            width: 140,
                            child: _LoginStatTile(stat: s),
                          ),
                      ],
                    ),
                  ),
                ),
                if (pageCount > 1) ...[
                  const SizedBox(height: AppSpacing.base),
                  _PageDots(count: pageCount, index: pageIndex),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginStatView {
  const _LoginStatView({
    required this.icon,
    required this.value,
    required this.label,
    this.logoUrl,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? logoUrl;
}

class _LoginStatTile extends StatelessWidget {
  const _LoginStatTile({required this.stat});

  final _LoginStatView stat;

  @override
  Widget build(BuildContext context) {
    final logo = stat.logoUrl?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logo != null && logo.isNotEmpty)
          SizedBox(
            width: 22,
            height: 22,
            child: MediaDeliveryImage(
              url: logo,
              fit: BoxFit.contain,
              errorWidget: Icon(stat.icon, color: AppColors.gold, size: 22),
            ),
          )
        else
          Icon(stat.icon, color: AppColors.gold, size: 22),
        const SizedBox(height: AppSpacing.sm),
        Text(
          stat.value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.white,
              ),
        ),
        Text(
          stat.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.gold
                  : AppColors.gold.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
