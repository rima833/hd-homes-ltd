import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/layout/public/public_drawer.dart';
import 'package:hdhomesproject/core/layout/public/public_footer.dart';
import 'package:hdhomesproject/core/layout/public/public_nav_bar.dart';
import 'package:hdhomesproject/core/growth/widgets/ai_concierge_fab.dart';
import 'package:hdhomesproject/core/website/components/cookie_consent_banner.dart';
import 'package:hdhomesproject/core/website/components/global_notification_bar.dart';
import 'package:hdhomesproject/core/website/components/scroll_progress_bar.dart';
import 'package:hdhomesproject/core/website/components/scroll_to_top_button.dart';
import 'package:hdhomesproject/core/website/components/search_overlay.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';

/// Global shell for the public marketing website (AppShell).
class PublicShell extends StatefulWidget {
  const PublicShell({super.key, required this.child});

  final Widget child;

  @override
  State<PublicShell> createState() => _PublicShellState();
}

/// Alias matching Volume 2 Part 1 naming.
typedef WebsiteAppShell = PublicShell;

class _PublicShellState extends State<PublicShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();
  final _scrollProgress = ValueNotifier<double>(0);

  bool _scrolled = false;
  bool _showScrollTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final max = _scrollController.position.maxScrollExtent;
    final scrolled = offset > 48;
    final showTop = offset > 400;
    final progress = max > 0 ? (offset / max).clamp(0.0, 1.0) : 0.0;

    // Progress bar updates without rebuilding the whole page tree.
    if (progress != _scrollProgress.value) {
      _scrollProgress.value = progress;
    }

    // Only rebuild chrome when boolean chrome state flips.
    if (scrolled != _scrolled || showTop != _showScrollTop) {
      setState(() {
        _scrolled = scrolled;
        _showScrollTop = showTop;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlobalNotificationBar(
          message: AppStrings.announcementDefault,
          actionLabel: 'Explore',
          onAction: () {},
        ),
        Expanded(
          child: Scaffold(
            key: _scaffoldKey,
            extendBodyBehindAppBar: true,
            drawer: const PublicDrawer(),
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(74),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PublicNavBar(
                    scrolled: _scrolled,
                    onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                    onSearchTap: () => WebsiteSearchOverlay.show(context),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _scrollProgress,
                    builder: (context, progress, _) =>
                        ScrollProgressBar(progress: progress),
                  ),
                ],
              ),
            ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      widget.child,
                      const PublicFooter(),
                    ],
                  ),
                ),
                const PublicFloatingActions(),
                const Positioned(
                  right: 16,
                  bottom: 200,
                  child: AiConciergeFab(),
                ),
                Positioned(
                  right: 16,
                  bottom: 88,
                  child: ScrollToTopButton(
                    visible: _showScrollTop,
                    onPressed: _scrollToTop,
                  ),
                ),
                const CookieConsentBanner(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
