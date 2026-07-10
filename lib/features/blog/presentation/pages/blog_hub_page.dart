import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/blog/data/providers/blog_catalog_provider.dart';
import 'package:hdhomesproject/features/blog/presentation/sections/blog_closing_sections.dart';
import 'package:hdhomesproject/features/blog/presentation/sections/blog_hub_sections.dart';

/// Knowledge Center hub — Volume 2 Part 9.
class BlogHubPage extends ConsumerStatefulWidget {
  const BlogHubPage({super.key});

  @override
  ConsumerState<BlogHubPage> createState() => _BlogHubPageState();
}

class _BlogHubPageState extends ConsumerState<BlogHubPage> {
  final _articlesKey = GlobalKey();
  final _newsletterKey = GlobalKey();
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

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(blogHubCmsProvider);

    return Column(
      children: [
        BlogHeroSection(
          headline: cms.heroHeadline,
          subheadline: cms.heroSubheadline,
          searchController: _searchController,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          popularSearches: cms.popularSearches,
          onBrowseArticles: () => _scrollTo(_articlesKey),
        ),
        BlogHubSections(
          articlesKey: _articlesKey,
          searchQuery: _searchQuery,
          selectedCategoryId: _selectedCategoryId,
          onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
        ),
        BlogClosingSections(newsletterKey: _newsletterKey),
      ],
    );
  }
}
