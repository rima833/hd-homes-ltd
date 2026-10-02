import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_filters.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';

MarketplaceProperty _p({
  required String id,
  required String title,
  PropertyCategory category = PropertyCategory.residential,
  PropertyPurpose purpose = PropertyPurpose.buy,
  int bedrooms = 2,
  int priceValue = 50000000,
  List<String> lifestyleTags = const [],
  bool isFeatured = false,
  bool isNew = false,
  CompletionStatus completion = CompletionStatus.readyToMove,
}) {
  return MarketplaceProperty(
    id: id,
    title: title,
    slug: id,
    price: '₦$priceValue',
    priceValue: priceValue,
    location: 'Lagos',
    city: 'Lagos',
    state: 'Lagos',
    estate: '',
    type: 'Home',
    category: category,
    purpose: purpose,
    bedrooms: bedrooms,
    bathrooms: 2,
    landSize: '',
    buildingSize: '',
    status: 'Available',
    completionStatus: completion,
    amenities: const [],
    paymentOptions: const [],
    developer: 'HD Homes',
    isFeatured: isFeatured,
    isNew: isNew,
    isVerified: true,
    hasPaymentPlan: false,
    matchScore: 0,
    investmentScore: 0,
    availability: AvailabilityLevel.available,
    roiEstimate: '—',
    rentalYield: '—',
    capitalAppreciation: '—',
    riskLevel: '—',
    lifestyleTags: lifestyleTags,
    imageUrl: null,
    galleryUrls: const [],
    lat: 0,
    lng: 0,
    createdAt: DateTime(2026, 1, 1),
    popularity: 0,
  );
}

void main() {
  test('category keys count live listings', () {
    final list = [
      _p(id: '1', title: 'Luxury Villa', priceValue: 120000000, isFeatured: true),
      _p(id: '2', title: 'Starter Home', priceValue: 25000000),
      _p(id: '3', title: 'Family Duplex', bedrooms: 4),
      _p(
        id: '4',
        title: 'Office Plaza',
        category: PropertyCategory.commercial,
      ),
      _p(id: '5', title: 'Plot A', category: PropertyCategory.land),
      _p(
        id: '6',
        title: 'ROI Estate',
        purpose: PropertyPurpose.invest,
        category: PropertyCategory.investment,
      ),
      _p(
        id: '7',
        title: 'Off-plan Launch',
        completion: CompletionStatus.underConstruction,
      ),
    ];

    expect(countCategoryKey(list, 'luxury'), greaterThanOrEqualTo(1));
    expect(countCategoryKey(list, 'affordable'), greaterThanOrEqualTo(1));
    expect(countCategoryKey(list, 'family'), greaterThanOrEqualTo(1));
    expect(countCategoryKey(list, 'commercial'), 1);
    expect(countCategoryKey(list, 'land'), 1);
    expect(countCategoryKey(list, 'investment'), greaterThanOrEqualTo(1));
    expect(countCategoryKey(list, 'new'), greaterThanOrEqualTo(1));
  });

  test('categoryKey filters marketplace results', () {
    final list = [
      _p(id: '1', title: 'Land Parcel', category: PropertyCategory.land),
      _p(id: '2', title: 'City Flat', priceValue: 40000000),
    ];
    final filtered = filterProperties(
      list,
      const MarketplaceFilters(categoryKey: 'land'),
    );
    expect(filtered.length, 1);
    expect(filtered.first.id, '1');
  });
}
