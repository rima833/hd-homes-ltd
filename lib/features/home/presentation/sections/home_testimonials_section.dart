import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/website/components/testimonials_showcase_section.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';

/// Homepage adapter for the shared testimonials showcase.
class HomeTestimonialsSection extends StatelessWidget {
  const HomeTestimonialsSection({super.key, required this.items});

  final List<HomeTestimonialItem> items;

  @override
  Widget build(BuildContext context) {
    return TestimonialsShowcaseSection(
      items: [
        for (final t in items)
          TestimonialShowcaseItem(
            name: t.name,
            role: t.role,
            quote: t.quote,
            rating: t.rating,
            verified: t.verified,
            avatarUrl: t.avatarUrl,
          ),
      ],
    );
  }
}
