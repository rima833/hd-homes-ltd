import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';

/// Public-site gates derived from `app_settings.website_features`.
///
/// CMS section visibility still applies; these flags are an additional kill
/// switch from Platform Control Center → Public Website.
extension PublicWebsiteGates on PlatformSettingsBundle {
  bool get allowPublicSearch => enablePublicSearch;
  bool get allowBlog => enableBlog;
  bool get allowNewsletter => enableNewsletter;
  bool get allowTestimonials => enableTestimonials;
  bool get allowPartners => enablePartners;
  bool get allowFaq => enableFaq;
  bool get allowFeaturedProperties => enableFeaturedProperties;
  bool get allowFeaturedEstates => enablePropertyListings;
  bool get allowInvestment => enableInvestmentSection;
  bool get allowConstruction => enableConstructionUpdates;
  bool get allowPaymentCalculator => enablePaymentCalculator;
  bool get allowRoiCalculator => enableRoiCalculator;
  bool get allowClientPortalEntry => enableClientPortalEntry;
  bool get allowInvestorPortalEntry => enableInvestorPortalEntry;
  bool get allowContactForms => enableContactForms;

  /// Whether a public nav path should remain visible.
  bool allowsPublicPath(String path) {
    if (path == RoutePaths.blog || path.startsWith('${RoutePaths.blog}/')) {
      return allowBlog;
    }
    if (path == RoutePaths.paymentCalculator) {
      return allowPaymentCalculator;
    }
    if (path == RoutePaths.roiCalculator) {
      return allowRoiCalculator;
    }
    if (path == RoutePaths.investment ||
        path.startsWith('${RoutePaths.investment}/')) {
      return allowInvestment;
    }
    if (path == RoutePaths.construction ||
        path.startsWith('${RoutePaths.construction}/')) {
      return allowConstruction;
    }
    if (path == RoutePaths.properties ||
        path.startsWith('${RoutePaths.properties}/')) {
      return allowFeaturedEstates || allowFeaturedProperties;
    }
    if (path == RoutePaths.contact) {
      return allowContactForms;
    }
    return true;
  }

  /// Footer / welcome portal entry labels.
  bool allowsFooterLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.contains('client login') ||
        normalized.contains('client portal')) {
      return allowClientPortalEntry;
    }
    if (normalized.contains('investor login') ||
        normalized.contains('investor portal')) {
      return allowInvestorPortalEntry;
    }
    if (normalized == 'investment' || normalized.startsWith('invest ')) {
      return allowInvestment;
    }
    return true;
  }

  /// Filters nav children (e.g. Properties dropdown) by feature flags.
  List<T> filterNavChildren<T>(
    List<T> children, {
    required String Function(T item) pathOf,
  }) {
    return [
      for (final child in children)
        if (allowsPublicPath(pathOf(child))) child,
    ];
  }
}
