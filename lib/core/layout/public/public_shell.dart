import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/layout/public/public_drawer.dart';
import 'package:hdhomesproject/core/layout/public/public_footer.dart';
import 'package:hdhomesproject/core/layout/public/public_nav_bar.dart';
import 'package:hdhomesproject/core/website/components/cookie_consent_banner.dart';
import 'package:hdhomesproject/core/website/components/global_notification_bar.dart';
import 'package:hdhomesproject/core/website/components/scroll_progress_bar.dart';
import 'package:hdhomesproject/core/website/components/scroll_to_top_button.dart';
import 'package:hdhomesproject/core/website/components/search_overlay.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Global shell for the public marketing website (AppShell).
class PublicShell extends ConsumerStatefulWidget {
  const PublicShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PublicShell> createState() => _PublicShellState();
}

/// Alias matching Volume 2 Part 1 naming.
typedef WebsiteAppShell = PublicShell;

class _PublicShellState extends ConsumerState<PublicShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();
  final _scrollProgress = ValueNotifier<double>(0);

  bool _scrolled = false;
  bool _showScrollTop = false;
  String? _lastLocation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    if (_lastLocation == location) return;
    final hadPrevious = _lastLocation != null;
    _lastLocation = location;
    if (hadPrevious) {
      setState(() {});
    }
    if (!hadPrevious) return;

    // PublicShell survives route changes — reset chrome so a prior overlay /
    // scroll position cannot leave the next page feeling "frozen".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scaffold = _scaffoldKey.currentState;
      if (scaffold?.isDrawerOpen == true) {
        scaffold!.closeDrawer();
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _scrollProgress.value = 0;
      if (_scrolled || _showScrollTop) {
        setState(() {
          _scrolled = false;
          _showScrollTop = false;
        });
      }
    });
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

  bool _showSiteBanner(String path) {
    if (path == RoutePaths.home || path.isEmpty) return false;
    if (path == RoutePaths.about || path.startsWith('${RoutePaths.about}/')) {
      return false;
    }
    if (path == RoutePaths.contact) return false;
    return true;
  }

  String _bannerMessage(CmsBanner banner) {
    final subtitle = banner.subtitle?.trim();
    if (subtitle == null || subtitle.isEmpty) return banner.title;
    return '${banner.title} — $subtitle';
  }

  Future<void> _openBannerLink(String? raw) async {
    final target = (raw ?? '').trim();
    if (target.isEmpty || !mounted) return;

    final uri = Uri.tryParse(target);
    final isHttp =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (isHttp) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    final path = target.startsWith('/') ? target : '/$target';
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    // Keep public CMS pages + homepage hero subscribed for live publish updates.
    ref.watch(publishedPagesRealtimeProvider);
    ref.watch(homepageHeroRealtimeProvider);
    ref.watch(bannersRealtimeProvider);
    ref.watch(menusRealtimeProvider);
    ref.watch(footerRealtimeProvider);

    final location = GoRouterState.of(context).uri.path;
    final showBanner = _showSiteBanner(location);
    final bannersAsync = ref.watch(publishedActiveBannersProvider);
    final banner = showBanner && bannersAsync.valueOrNull?.isNotEmpty == true
        ? bannersAsync.valueOrNull!.first
        : null;
    final link = banner?.linkUrl?.trim() ?? '';
    final hasLink = link.isNotEmpty;

    return Column(
      children: [
        GlobalNotificationBar(
          message: banner == null ? null : _bannerMessage(banner),
          imageUrl: banner?.imageUrl,
          actionLabel: hasLink ? 'Explore' : null,
          onAction: hasLink ? () => _openBannerLink(link) : null,
          visible: banner != null,
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
                  child: Column(children: [widget.child, const PublicFooter()]),
                ),
                const PublicFloatingActions(),
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
