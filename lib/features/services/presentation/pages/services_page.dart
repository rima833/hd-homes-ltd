import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/services/data/models/service_models.dart';
import 'package:hdhomesproject/features/services/data/providers/services_catalog_provider.dart';
import 'package:hdhomesproject/features/services/presentation/sections/services_catalog_sections.dart';
import 'package:hdhomesproject/features/services/presentation/sections/services_closing_sections.dart';
import 'package:hdhomesproject/features/services/presentation/sections/services_hero_section.dart';

/// Premium services hub — Volume 2 Part 8.
class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({super.key});

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends ConsumerState<ServicesPage> {
  final _categoriesKey = GlobalKey();
  final _consultationKey = GlobalKey();
  ServiceCategoryId? _selectedCategory;

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
    final cms = ref.watch(servicesCmsProvider);

    return Column(
      children: [
        ServicesHeroSection(
          headline: cms.heroHeadline,
          subheadline: cms.heroSubheadline,
          onExploreServices: () => _scrollTo(_categoriesKey),
        ),
        ServicesCatalogSections(
          categoriesKey: _categoriesKey,
          selectedCategory: _selectedCategory,
          onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
        ),
        ServicesClosingSections(consultationKey: _consultationKey),
      ],
    );
  }
}
