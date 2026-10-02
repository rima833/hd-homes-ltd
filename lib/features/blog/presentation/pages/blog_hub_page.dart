import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hdhomesproject/features/blog/presentation/sections/blog_closing_sections.dart';
import 'package:hdhomesproject/features/blog/presentation/sections/blog_hub_sections.dart';

/// Public blog hub — CMS-backed, realtime.
class BlogHubPage extends ConsumerStatefulWidget {
  const BlogHubPage({super.key});

  @override
  ConsumerState<BlogHubPage> createState() => _BlogHubPageState();
}

class _BlogHubPageState extends ConsumerState<BlogHubPage> {
  final _articlesKey = GlobalKey();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onCategorySelected(String? id) {
    setState(() => _selectedCategoryId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_articlesKey));
  }

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(blogHubCmsProvider);

    return Column(
      children: [
        BlogHeroSection(
          headline: cms.heroHeadline,
          subheadline: cms.heroSubheadline,
          primaryCtaLabel: cms.primaryCtaLabel,
          secondaryCtaLabel: cms.secondaryCtaLabel,
          backgroundImageUrl: cms.backgroundImageUrl,
          backgroundVideoUrl: cms.backgroundVideoUrl,
          searchController: _searchController,
          onSearchChanged: (q) {
            setState(() => _searchQuery = q);
            _scrollTo(_articlesKey);
          },
          onBrowseArticles: () => _scrollTo(_articlesKey),
        ),
        BlogHubSections(
          articlesKey: _articlesKey,
          searchQuery: _searchQuery,
          selectedCategoryId: _selectedCategoryId,
          onCategorySelected: _onCategorySelected,
        ),
        const BlogClosingSections(),
      ],
    );
  }
}
