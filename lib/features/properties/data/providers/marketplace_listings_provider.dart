import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';

/// Public properties marketplace — backed by published CMS properties when
/// Supabase is configured, falling back to the curated sample list
/// otherwise (or while the CMS has no published properties yet).
final marketplaceListingsProvider = Provider<List<MarketplaceProperty>>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  if (!configured) return _sampleListings;

  ref.watch(publishedPropertiesRealtimeProvider);
  final publishedAsync = ref.watch(publishedPropertiesCatalogProvider);
  return publishedAsync.when(
    skipLoadingOnReload: true,
    skipLoadingOnRefresh: true,
    data: (properties) => properties.map(toMarketplaceProperty).toList(),
    loading: () => const [],
    error: (_, _) => const [],
  );
});

/// True while the live catalog has never resolved (first paint).
final marketplaceListingsLoadingProvider = Provider<bool>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return false;
  final async = ref.watch(publishedPropertiesCatalogProvider);
  return async.isLoading && async.valueOrNull == null;
});

MarketplaceProperty toMarketplaceProperty(CmsPropertyFeatured p) {
  final statusText = '${p.marketingStatus ?? ''} ${p.displayStatus}'.toLowerCase();
  final typeRaw = (p.propertyType ?? p.homepageBadge ?? '').toLowerCase();
  final titleRaw = p.title.toLowerCase();
  final amenityHay = p.amenities.join(' ').toLowerCase();
  final investHay = (p.investmentPotential ?? '').toLowerCase();
  final hay = '$typeRaw $titleRaw $statusText $amenityHay $investHay';

  final completionStatus = hay.contains('off-plan') || hay.contains('off plan')
      ? CompletionStatus.offPlan
      : hay.contains('construction') || hay.contains('building')
          ? CompletionStatus.underConstruction
          : CompletionStatus.readyToMove;

  final typeLabel = (p.propertyType ?? 'Property').replaceAll('_', ' ');
  final capitalizedType = typeLabel.isEmpty
      ? 'Property'
      : '${typeLabel[0].toUpperCase()}${typeLabel.substring(1)}';

  final category = hay.contains('land') || hay.contains('plot')
      ? PropertyCategory.land
      : hay.contains('commercial') ||
              hay.contains('retail') ||
              hay.contains('office') ||
              hay.contains('plaza')
          ? PropertyCategory.commercial
          : hay.contains('invest') ||
                  hay.contains('off-plan') ||
                  hay.contains('off plan')
              ? PropertyCategory.investment
              : PropertyCategory.residential;

  final purpose = hay.contains('rent') || hay.contains('lease')
      ? PropertyPurpose.rent
      : hay.contains('invest') ||
              category == PropertyCategory.commercial ||
              category == PropertyCategory.land ||
              category == PropertyCategory.investment
          ? PropertyPurpose.invest
          : PropertyPurpose.buy;

  final created = p.createdAt ?? p.updatedAt ?? DateTime.now();
  final isNew = p.homepageBadge?.toLowerCase().contains('new') ?? false;
  final availability = statusText.contains('sold')
      ? AvailabilityLevel.soldOut
      : statusText.contains('reserved') || statusText.contains('limited')
          ? AvailabilityLevel.limited
          : AvailabilityLevel.available;

  final priceValue = p.listingPrice?.round() ?? 0;
  final bedrooms = p.bedrooms?.round() ?? 0;
  final lifestyleTags = p.amenities
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .take(6)
      .toList();

  final hasPaymentPlan = p.detailExtras?.paymentPlans.any(
        (plan) => plan.name.trim().isNotEmpty && plan.months > 0,
      ) ??
      false;

  // Scores are not admin-entered. Keep them off the public listing.
  const matchScore = 0;
  const investmentScore = 0;

  final geo = _approxGeo(p.city, p.state);

  return MarketplaceProperty(
    id: p.id,
    title: p.title,
    slug: p.slug,
    price: p.displayPrice,
    priceValue: priceValue,
    location: p.location,
    city: p.city ?? '',
    state: p.state ?? '',
    estate: p.estateName ?? '',
    type: capitalizedType,
    category: category,
    purpose: purpose,
    bedrooms: bedrooms,
    bathrooms: p.bathrooms?.round() ?? 0,
    landSize: p.landSizeLabel,
    buildingSize: p.buildingSizeLabel,
    status: p.displayStatus,
    completionStatus: completionStatus,
    amenities: p.amenities,
    paymentOptions: hasPaymentPlan
        ? const ['Installment', 'Outright']
        : const ['Outright'],
    developer: 'HD Homes',
    isFeatured: p.isFeatured,
    isNew: isNew,
    isVerified: false,
    hasPaymentPlan: hasPaymentPlan,
    matchScore: matchScore,
    investmentScore: investmentScore,
    availability: availability,
    roiEstimate: p.investmentPotential ?? '',
    rentalYield: '',
    capitalAppreciation: p.detailExtras?.appreciationEstimate ?? '',
    riskLevel: '',
    lifestyleTags: lifestyleTags,
    imageUrl: p.coverImageUrl,
    galleryUrls: p.galleryUrls.isNotEmpty
        ? p.galleryUrls
        : (p.coverImageUrl != null ? [p.coverImageUrl!] : const []),
    lat: geo.$1,
    lng: geo.$2,
    createdAt: created,
    popularity: p.isFeatured ? 80 : (isNew ? 65 : 40),
    toilets: p.toilets?.round(),
    kitchens: p.kitchens?.round(),
    parkingSpaces: p.parkingSpaces,
    floors: p.floors,
    yearBuilt: p.yearBuilt,
    powerSupply: p.powerSupply,
    waterSupply: p.waterSupply,
    internetConnectivity: p.internetConnectivity,
    overviewSummary: p.overviewText.isEmpty ? null : p.overviewText,
    architecturalConcept: p.architecturalConcept,
    investmentPotentialText: p.investmentPotential,
    propertyCodeOverride: p.propertyCode,
    detailExtras: p.detailExtras,
    promoPrice: p.promoPrice,
  );
}

(double, double) _approxGeo(String? city, String? state) {
  final hay = '${city ?? ''} ${state ?? ''}'.toLowerCase();
  if (hay.contains('abuja') || hay.contains('fct')) return (9.0765, 7.3986);
  if (hay.contains('port harcourt') || hay.contains('rivers')) {
    return (4.8156, 7.0498);
  }
  if (hay.contains('enugu')) return (6.4413, 7.4983);
  if (hay.contains('ibadan') || hay.contains('oyo')) return (7.3775, 3.9470);
  // Default Lagos corridor
  return (6.4474, 3.5562);
}

final _sampleListings = [
  MarketplaceProperty(
    id: 'h001',
    title: '4-Bedroom Luxury Duplex',
    slug: '4-bedroom-luxury-duplex-horizon',
    price: '₦68M',
    priceValue: 68000000,
    location: 'Horizon Gardens, Lekki',
    city: 'Lagos',
    state: 'Lagos',
    estate: 'Horizon Gardens',
    type: 'Duplex',
    category: PropertyCategory.residential,
    purpose: PropertyPurpose.buy,
    bedrooms: 4,
    bathrooms: 5,
    landSize: '450 sqm',
    buildingSize: '380 sqm',
    status: 'Available',
    completionStatus: CompletionStatus.readyToMove,
    amenities: ['Swimming Pool', 'Gym', 'Security', 'Parking', 'Smart Home'],
    paymentOptions: ['Outright', 'Installment'],
    developer: 'HD Homes',
    isFeatured: true,
    isNew: true,
    isVerified: true,
    hasPaymentPlan: true,
    matchScore: 92,
    investmentScore: 78,
    availability: AvailabilityLevel.limited,
    roiEstimate: '16–20%',
    rentalYield: '8.5%',
    capitalAppreciation: '12%',
    riskLevel: 'Moderate',
    lifestyleTags: ['Luxury Living', 'Family Living'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 6.4474,
    lng: 3.5562,
    createdAt: DateTime(2026, 3, 1),
    popularity: 95,
  ),
  MarketplaceProperty(
    id: 'h002',
    title: '3-Bedroom Terrace',
    slug: '3-bedroom-terrace-emerald',
    price: '₦42M',
    priceValue: 42000000,
    location: 'Emerald Heights, Abuja',
    city: 'Abuja',
    state: 'FCT',
    estate: 'Emerald Heights',
    type: 'Terrace',
    category: PropertyCategory.residential,
    purpose: PropertyPurpose.buy,
    bedrooms: 3,
    bathrooms: 4,
    landSize: '320 sqm',
    buildingSize: '240 sqm',
    status: 'New',
    completionStatus: CompletionStatus.underConstruction,
    amenities: ['Security', 'Parking', 'Garden', "Children's Play Area"],
    paymentOptions: ['Installment', 'Mortgage'],
    developer: 'HD Homes',
    isFeatured: true,
    isNew: true,
    isVerified: true,
    hasPaymentPlan: true,
    matchScore: 88,
    investmentScore: 85,
    availability: AvailabilityLevel.available,
    roiEstimate: '18–22%',
    rentalYield: '9.2%',
    capitalAppreciation: '14%',
    riskLevel: 'Moderate',
    lifestyleTags: ['Family Living', 'Investment Focus'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 9.0765,
    lng: 7.3986,
    createdAt: DateTime(2026, 2, 15),
    popularity: 88,
  ),
  MarketplaceProperty(
    id: 'h003',
    title: 'Luxury Penthouse',
    slug: 'luxury-penthouse-vi',
    price: '₦125M',
    priceValue: 125000000,
    location: 'Victoria Island, Lagos',
    city: 'Lagos',
    state: 'Lagos',
    estate: 'VI Residences',
    type: 'Penthouse',
    category: PropertyCategory.residential,
    purpose: PropertyPurpose.buy,
    bedrooms: 5,
    bathrooms: 6,
    landSize: '580 sqm',
    buildingSize: '520 sqm',
    status: 'Premium',
    completionStatus: CompletionStatus.readyToMove,
    amenities: ['Swimming Pool', 'Gym', 'Elevator', 'Smart Home', 'Security'],
    paymentOptions: ['Outright'],
    developer: 'HD Homes',
    isFeatured: true,
    isNew: false,
    isVerified: true,
    hasPaymentPlan: false,
    matchScore: 75,
    investmentScore: 70,
    availability: AvailabilityLevel.limited,
    roiEstimate: '12–15%',
    rentalYield: '7.0%',
    capitalAppreciation: '10%',
    riskLevel: 'Low',
    lifestyleTags: ['Luxury Living'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 6.4281,
    lng: 3.4219,
    createdAt: DateTime(2025, 11, 1),
    popularity: 72,
  ),
  MarketplaceProperty(
    id: 'h004',
    title: 'Affordable 2-Bed Apartment',
    slug: 'affordable-2bed-palm-grove',
    price: '₦28M',
    priceValue: 28000000,
    location: 'Palm Grove Estate, PH',
    city: 'Port Harcourt',
    state: 'Rivers',
    estate: 'Palm Grove Estate',
    type: 'Apartment',
    category: PropertyCategory.residential,
    purpose: PropertyPurpose.buy,
    bedrooms: 2,
    bathrooms: 2,
    landSize: '180 sqm',
    buildingSize: '120 sqm',
    status: 'Hot Deal',
    completionStatus: CompletionStatus.readyToMove,
    amenities: ['Security', 'Parking'],
    paymentOptions: ['Installment', 'Outright'],
    developer: 'HD Homes',
    isFeatured: false,
    isNew: false,
    isVerified: true,
    hasPaymentPlan: true,
    matchScore: 94,
    investmentScore: 82,
    availability: AvailabilityLevel.almostSoldOut,
    roiEstimate: '20–24%',
    rentalYield: '10.5%',
    capitalAppreciation: '15%',
    riskLevel: 'Moderate',
    lifestyleTags: ['Family Living', 'Investment Focus'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 4.8156,
    lng: 7.0498,
    createdAt: DateTime(2026, 1, 20),
    popularity: 91,
  ),
  MarketplaceProperty(
    id: 'c001',
    title: 'Retail Plaza Unit',
    slug: 'retail-plaza-lekki',
    price: '₦95M',
    priceValue: 95000000,
    location: 'Lekki Phase 1',
    city: 'Lagos',
    state: 'Lagos',
    estate: 'Lekki Commercial Hub',
    type: 'Retail Shop',
    category: PropertyCategory.commercial,
    purpose: PropertyPurpose.invest,
    bedrooms: 0,
    bathrooms: 2,
    landSize: '200 sqm',
    buildingSize: '180 sqm',
    status: 'Available',
    completionStatus: CompletionStatus.readyToMove,
    amenities: ['Security', 'Parking', 'Elevator'],
    paymentOptions: ['Outright', 'Installment'],
    developer: 'HD Homes',
    isFeatured: false,
    isNew: true,
    isVerified: true,
    hasPaymentPlan: true,
    matchScore: 80,
    investmentScore: 91,
    availability: AvailabilityLevel.available,
    roiEstimate: '22–26%',
    rentalYield: '12%',
    capitalAppreciation: '11%',
    riskLevel: 'Moderate',
    lifestyleTags: ['Commercial Growth', 'Investment Focus'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 6.4361,
    lng: 3.4723,
    createdAt: DateTime(2026, 2, 28),
    popularity: 65,
  ),
  MarketplaceProperty(
    id: 'l001',
    title: 'Residential Plot — 600 sqm',
    slug: 'residential-plot-abuja',
    price: '₦18M',
    priceValue: 18000000,
    location: 'Lugbe, Abuja',
    city: 'Abuja',
    state: 'FCT',
    estate: 'Greenfield Plots',
    type: 'Residential Plot',
    category: PropertyCategory.land,
    purpose: PropertyPurpose.invest,
    bedrooms: 0,
    bathrooms: 0,
    landSize: '600 sqm',
    buildingSize: '—',
    status: 'Available',
    completionStatus: CompletionStatus.readyToMove,
    amenities: ['Security'],
    paymentOptions: ['Outright', 'Installment'],
    developer: 'HD Homes',
    isFeatured: false,
    isNew: false,
    isVerified: true,
    hasPaymentPlan: true,
    matchScore: 86,
    investmentScore: 88,
    availability: AvailabilityLevel.available,
    roiEstimate: '25–30%',
    rentalYield: '—',
    capitalAppreciation: '18%',
    riskLevel: 'Moderate',
    lifestyleTags: ['Investment Focus'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 8.9508,
    lng: 7.3697,
    createdAt: DateTime(2025, 12, 5),
    popularity: 58,
  ),
  MarketplaceProperty(
    id: 'i001',
    title: 'Off-Plan Investment Block',
    slug: 'off-plan-horizon-phase-3',
    price: '₦35M',
    priceValue: 35000000,
    location: 'Horizon Gardens Phase III',
    city: 'Lagos',
    state: 'Lagos',
    estate: 'Horizon Gardens',
    type: 'Off-plan',
    category: PropertyCategory.investment,
    purpose: PropertyPurpose.invest,
    bedrooms: 3,
    bathrooms: 3,
    landSize: '300 sqm',
    buildingSize: '220 sqm',
    status: 'Off-plan',
    completionStatus: CompletionStatus.offPlan,
    amenities: ['Swimming Pool', 'Gym', 'Security'],
    paymentOptions: ['Installment'],
    developer: 'HD Homes',
    isFeatured: true,
    isNew: true,
    isVerified: true,
    hasPaymentPlan: true,
    matchScore: 90,
    investmentScore: 95,
    availability: AvailabilityLevel.limited,
    roiEstimate: '28–35%',
    rentalYield: '11%',
    capitalAppreciation: '20%',
    riskLevel: 'Moderate-High',
    lifestyleTags: ['Investment Focus', 'Waterfront Living'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 6.4501,
    lng: 3.5601,
    createdAt: DateTime(2026, 3, 10),
    popularity: 82,
  ),
  MarketplaceProperty(
    id: 'h005',
    title: 'Eco-Friendly Bungalow',
    slug: 'eco-bungalow-enugu',
    price: '₦32M',
    priceValue: 32000000,
    location: 'Independence Layout, Enugu',
    city: 'Enugu',
    state: 'Enugu',
    estate: 'Green Valley',
    type: 'Bungalow',
    category: PropertyCategory.residential,
    purpose: PropertyPurpose.buy,
    bedrooms: 3,
    bathrooms: 3,
    landSize: '400 sqm',
    buildingSize: '200 sqm',
    status: 'Available',
    completionStatus: CompletionStatus.readyToMove,
    amenities: ['Garden', 'Security', 'Parking'],
    paymentOptions: ['Outright', 'Installment'],
    developer: 'HD Homes',
    isFeatured: false,
    isNew: false,
    isVerified: true,
    hasPaymentPlan: true,
    matchScore: 83,
    investmentScore: 74,
    availability: AvailabilityLevel.available,
    roiEstimate: '14–18%',
    rentalYield: '7.5%',
    capitalAppreciation: '9%',
    riskLevel: 'Low',
    lifestyleTags: ['Eco-Friendly Living', 'Retirement'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 6.4413,
    lng: 7.4983,
    createdAt: DateTime(2025, 10, 12),
    popularity: 45,
  ),
  MarketplaceProperty(
    id: 'h006',
    title: 'Studio Apartment',
    slug: 'studio-lekki',
    price: '₦22M',
    priceValue: 22000000,
    location: 'Chevron Drive, Lekki',
    city: 'Lagos',
    state: 'Lagos',
    estate: 'Chevron Residences',
    type: 'Studio',
    category: PropertyCategory.residential,
    purpose: PropertyPurpose.buy,
    bedrooms: 1,
    bathrooms: 1,
    landSize: '80 sqm',
    buildingSize: '55 sqm',
    status: 'New',
    completionStatus: CompletionStatus.readyToMove,
    amenities: ['Security', 'Gym', 'Parking'],
    paymentOptions: ['Installment'],
    developer: 'HD Homes',
    isFeatured: false,
    isNew: true,
    isVerified: true,
    hasPaymentPlan: true,
    matchScore: 79,
    investmentScore: 86,
    availability: AvailabilityLevel.available,
    roiEstimate: '18–22%',
    rentalYield: '11%',
    capitalAppreciation: '13%',
    riskLevel: 'Moderate',
    lifestyleTags: ['Investment Focus'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 6.4402,
    lng: 3.4889,
    createdAt: DateTime(2026, 3, 5),
    popularity: 70,
  ),
  MarketplaceProperty(
    id: 'h007',
    title: 'Waterfront Villa',
    slug: 'waterfront-villa-ikoyi',
    price: '₦280M',
    priceValue: 280000000,
    location: 'Ikoyi, Lagos',
    city: 'Lagos',
    state: 'Lagos',
    estate: 'Ikoyi Waterfront',
    type: 'Villa',
    category: PropertyCategory.residential,
    purpose: PropertyPurpose.buy,
    bedrooms: 6,
    bathrooms: 7,
    landSize: '900 sqm',
    buildingSize: '750 sqm',
    status: 'Exclusive',
    completionStatus: CompletionStatus.readyToMove,
    amenities: [
      'Swimming Pool',
      'Gym',
      'Smart Home',
      'Security',
      'Garden',
      'Parking',
    ],
    paymentOptions: ['Outright'],
    developer: 'HD Homes',
    isFeatured: true,
    isNew: false,
    isVerified: true,
    hasPaymentPlan: false,
    matchScore: 68,
    investmentScore: 65,
    availability: AvailabilityLevel.limited,
    roiEstimate: '10–12%',
    rentalYield: '5.5%',
    capitalAppreciation: '8%',
    riskLevel: 'Low',
    lifestyleTags: ['Luxury Living', 'Waterfront Living'],
    imageUrl: null,
    galleryUrls: const [],
    lat: 6.4541,
    lng: 3.4316,
    createdAt: DateTime(2025, 8, 1),
    popularity: 60,
  ),
];
