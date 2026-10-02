import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared cinematic chrome for registration / verification auth screens.
class AuthCinematicShell extends StatefulWidget {
  const AuthCinematicShell({
    super.key,
    required this.child,
    this.headline = 'Your next chapter starts here',
    this.subtitle =
        'Join HD Homes for properties, investments, and support — crafted for a secure, effortless experience.',
    this.highlights = const [
      (LucideIcons.shieldCheck, 'Bank-grade security'),
      (LucideIcons.sparkles, 'Guided onboarding'),
      (LucideIcons.headphones, 'Human support when you need it'),
    ],
  });

  final Widget child;
  final String headline;
  final String subtitle;
  final List<(IconData, String)> highlights;

  @override
  State<AuthCinematicShell> createState() => _AuthCinematicShellState();
}

class _AuthCinematicShellState extends State<AuthCinematicShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: const Color(0xFF07080A),
      body: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.8 + t * 0.3, -1),
                    end: Alignment(1, 0.9 - t * 0.2),
                    colors: [
                      const Color(0xFF07080A),
                      Color.lerp(
                            const Color(0xFF12141A),
                            const Color(0xFF1A1610),
                            t,
                          ) ??
                          const Color(0xFF12141A),
                      Color.lerp(
                            const Color(0xFF0E0F12),
                            const Color(0xFF2A2114),
                            t * 0.55,
                          ) ??
                          const Color(0xFF0E0F12),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -80 + t * 40,
                right: -60,
                child: _GlowOrb(
                  size: 280,
                  color: AppColors.gold.withValues(alpha: 0.12 + t * 0.06),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -40,
                child: _GlowOrb(
                  size: 320,
                  color: AppColors.gold.withValues(alpha: 0.07 + t * 0.04),
                ),
              ),
              SafeArea(
                child: wide
                    ? Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _BrandPane(
                              headline: widget.headline,
                              subtitle: widget.subtitle,
                              highlights: widget.highlights,
                              pulse: t,
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: _FormStage(child: widget.child),
                          ),
                        ],
                      )
                    : _FormStage(showLogo: true, child: widget.child),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _BrandPane extends StatelessWidget {
  const _BrandPane({
    required this.headline,
    required this.subtitle,
    required this.highlights,
    required this.pulse,
  });

  final String headline;
  final String subtitle;
  final List<(IconData, String)> highlights;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 36, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            AppTheme.logoAsset,
            height: 44,
            errorBuilder: (_, _, _) => const Text(
              'HD Homes',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          Transform.translate(
            offset: Offset(0, math.sin(pulse * math.pi) * 4),
            child: Text(
              headline,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 28),
          for (final h in highlights) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(h.$1, size: 16, color: AppColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      h.$2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          Text(
            'Trusted by homeowners & investors across Nigeria',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                ),
          ),
        ],
      ),
    );
  }
}

class _FormStage extends StatelessWidget {
  const _FormStage({required this.child, this.showLogo = false});

  final Widget child;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: showLogo ? 20 : 28,
          vertical: 28,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF12141A).withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showLogo) ...[
                        Center(
                          child: Image.asset(AppTheme.logoAsset, height: 44),
                        ),
                        const SizedBox(height: 20),
                      ],
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
