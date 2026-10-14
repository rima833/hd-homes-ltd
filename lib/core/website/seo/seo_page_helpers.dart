import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';

/// Builds human-readable SEO for published property detail pages.
abstract final class SeoPageHelpers {
  static String publicPropertyPath(MarketplaceProperty property) {
    final slug = property.slug.trim();
    final segment = slug.isNotEmpty ? slug : property.id;
    return '/properties/$segment';
  }

  static SeoMetadata propertyDetail(MarketplaceProperty property) {
    final location = _locationLabel(property);
    final beds = property.bedrooms > 0 ? '${property.bedrooms}-Bedroom ' : '';
    final type = property.type.trim();
    final headline = property.title.trim().isNotEmpty
        ? property.title.trim()
        : (beds + (type.isNotEmpty ? type : 'Property')).trim();

    final titleParts = <String>[headline];
    if (location.isNotEmpty) titleParts.add('in $location');
    final title = '${titleParts.join(' ')} | HD Homes Limited';

    final description = _propertyDescription(property, location);
    final path = publicPropertyPath(property);
    final image = property.imageUrl?.trim();

    return SeoMetadata(
      title: title,
      description: description,
      canonicalUrl: SeoConfig.canonicalFor(path),
      ogImageUrl: image != null && image.isNotEmpty ? image : null,
      structuredData: {
        '@context': 'https://schema.org',
        '@type': 'RealEstateListing',
        'name': headline,
        'description': description,
        if (location.isNotEmpty) 'address': location,
        if (property.price.trim().isNotEmpty) 'price': property.price,
      },
    );
  }

  static String _locationLabel(MarketplaceProperty property) {
    final city = property.city.trim();
    final state = property.state.trim();
    if (city.isNotEmpty && state.isNotEmpty) return '$city, $state';
    if (city.isNotEmpty) return city;
    final loc = property.location.trim();
    return loc;
  }

  static String _propertyDescription(
    MarketplaceProperty property,
    String location,
  ) {
    final overview = property.overviewSummary?.trim() ?? '';
    if (overview.isNotEmpty) return overview;

    final parts = <String>[];
    if (property.bedrooms > 0) parts.add('${property.bedrooms} bedrooms');
    if (property.bathrooms > 0) parts.add('${property.bathrooms} bathrooms');
    if (property.type.trim().isNotEmpty) parts.add(property.type.trim());
    if (location.isNotEmpty) parts.add(location);
    if (property.price.trim().isNotEmpty) parts.add('from ${property.price}');
    parts.add('View photos, plans, and book an inspection with HD Homes.');
    return parts.join(' · ');
  }
}
