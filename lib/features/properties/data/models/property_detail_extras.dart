bool _jsonBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

/// Structured extras for the public property detail page (stored as JSONB).
class PropertyDetailExtras {
  const PropertyDetailExtras({
    this.tour360Url = '',
    this.videoTourUrl = '',
    this.droneTourUrl = '',
    this.reservationFeePercent = 0,
    this.taxesAndFees = '',
    this.mortgageEligible = false,
    this.showMortgageCalculator = false,
    this.mortgageDepositPercent = 20,
    this.mortgageDepositMinPercent = 10,
    this.mortgageDepositMaxPercent = 50,
    this.mortgageInterestRate = 14,
    this.mortgageInterestMin = 5,
    this.mortgageInterestMax = 30,
    this.mortgageTermYears = 20,
    this.mortgageTermMinYears = 5,
    this.mortgageTermMaxYears = 30,
    this.paymentPlans = const [],
    this.floorPlans = const [],
    this.documents = const [],
    this.masterPlanDescription = '',
    this.masterPlanLegend = const [],
    this.nearbyPlaces = const [],
    this.totalUnits = 0,
    this.availableUnits = 0,
    this.reservedUnits = 0,
    this.soldUnits = 0,
    this.inspectionSlots = const [],
    this.safetyScore = 0,
    this.walkabilityScore = 0,
    this.lifestyleScore = 0,
    this.appreciationEstimate = '',
    this.trafficConditions = '',
    this.plannedInfrastructure = '',
    this.targetBuyers = '',
    this.communityFeatures = const [],
    this.developerHighlights = const [],
    this.reviews = const [],
    this.faqs = const [],
  });

  final String tour360Url;
  final String videoTourUrl;
  final String droneTourUrl;
  final double reservationFeePercent;
  final String taxesAndFees;
  final bool mortgageEligible;
  final bool showMortgageCalculator;
  final double mortgageDepositPercent;
  final double mortgageDepositMinPercent;
  final double mortgageDepositMaxPercent;
  final double mortgageInterestRate;
  final double mortgageInterestMin;
  final double mortgageInterestMax;
  final double mortgageTermYears;
  final double mortgageTermMinYears;
  final double mortgageTermMaxYears;
  final List<ExtrasPaymentPlan> paymentPlans;
  final List<ExtrasFloorPlan> floorPlans;
  final List<ExtrasDocument> documents;
  final String masterPlanDescription;
  final List<String> masterPlanLegend;
  final List<ExtrasNearbyPlace> nearbyPlaces;
  final int totalUnits;
  final int availableUnits;
  final int reservedUnits;
  final int soldUnits;
  final List<ExtrasInspectionSlot> inspectionSlots;
  final int safetyScore;
  final int walkabilityScore;
  final int lifestyleScore;
  final String appreciationEstimate;
  final String trafficConditions;
  final String plannedInfrastructure;
  final String targetBuyers;
  final List<String> communityFeatures;
  final List<String> developerHighlights;
  final List<ExtrasReview> reviews;
  final List<ExtrasFaq> faqs;

  factory PropertyDetailExtras.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return PropertyDetailExtras.emptyForWizard();
    }
    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) map) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList();
    }

    List<String> stringList(String key, List<String> fallback) {
      final raw = json[key];
      if (raw is! List || raw.isEmpty) return fallback;
      return raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
    }

    return PropertyDetailExtras(
      tour360Url: json['tour360Url'] as String? ?? '',
      videoTourUrl: json['videoTourUrl'] as String? ?? '',
      droneTourUrl: json['droneTourUrl'] as String? ?? '',
      reservationFeePercent:
          (json['reservationFeePercent'] as num?)?.toDouble() ?? 0,
      taxesAndFees: json['taxesAndFees'] as String? ?? '',
      mortgageEligible: _jsonBool(json['mortgageEligible']),
      showMortgageCalculator: _jsonBool(json['showMortgageCalculator']),
      mortgageDepositPercent:
          (json['mortgageDepositPercent'] as num?)?.toDouble() ?? 20,
      mortgageDepositMinPercent:
          (json['mortgageDepositMinPercent'] as num?)?.toDouble() ?? 10,
      mortgageDepositMaxPercent:
          (json['mortgageDepositMaxPercent'] as num?)?.toDouble() ?? 50,
      mortgageInterestRate:
          (json['mortgageInterestRate'] as num?)?.toDouble() ?? 14,
      mortgageInterestMin:
          (json['mortgageInterestMin'] as num?)?.toDouble() ?? 5,
      mortgageInterestMax:
          (json['mortgageInterestMax'] as num?)?.toDouble() ?? 30,
      mortgageTermYears: (json['mortgageTermYears'] as num?)?.toDouble() ?? 20,
      mortgageTermMinYears:
          (json['mortgageTermMinYears'] as num?)?.toDouble() ?? 5,
      mortgageTermMaxYears:
          (json['mortgageTermMaxYears'] as num?)?.toDouble() ?? 30,
      paymentPlans: listOf('paymentPlans', ExtrasPaymentPlan.fromJson),
      floorPlans: listOf('floorPlans', ExtrasFloorPlan.fromJson),
      documents: listOf('documents', ExtrasDocument.fromJson),
      masterPlanDescription: json['masterPlanDescription'] as String? ?? '',
      masterPlanLegend: stringList('masterPlanLegend', const []),
      nearbyPlaces: listOf('nearbyPlaces', ExtrasNearbyPlace.fromJson),
      totalUnits: (json['totalUnits'] as num?)?.toInt() ?? 0,
      availableUnits: (json['availableUnits'] as num?)?.toInt() ?? 0,
      reservedUnits: (json['reservedUnits'] as num?)?.toInt() ?? 0,
      soldUnits: (json['soldUnits'] as num?)?.toInt() ?? 0,
      inspectionSlots:
          listOf('inspectionSlots', ExtrasInspectionSlot.fromJson),
      safetyScore: (json['safetyScore'] as num?)?.toInt() ?? 0,
      walkabilityScore: (json['walkabilityScore'] as num?)?.toInt() ?? 0,
      lifestyleScore: (json['lifestyleScore'] as num?)?.toInt() ?? 0,
      appreciationEstimate: json['appreciationEstimate'] as String? ?? '',
      trafficConditions: json['trafficConditions'] as String? ?? '',
      plannedInfrastructure: json['plannedInfrastructure'] as String? ?? '',
      targetBuyers: json['targetBuyers'] as String? ?? '',
      communityFeatures: stringList('communityFeatures', const []),
      developerHighlights: stringList('developerHighlights', const []),
      reviews: listOf('reviews', ExtrasReview.fromJson),
      faqs: listOf('faqs', ExtrasFaq.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'tour360Url': tour360Url,
        'videoTourUrl': videoTourUrl,
        'droneTourUrl': droneTourUrl,
        'reservationFeePercent': reservationFeePercent,
        'taxesAndFees': taxesAndFees,
        'mortgageEligible': mortgageEligible,
        'showMortgageCalculator': showMortgageCalculator,
        'mortgageDepositPercent': mortgageDepositPercent,
        'mortgageDepositMinPercent': mortgageDepositMinPercent,
        'mortgageDepositMaxPercent': mortgageDepositMaxPercent,
        'mortgageInterestRate': mortgageInterestRate,
        'mortgageInterestMin': mortgageInterestMin,
        'mortgageInterestMax': mortgageInterestMax,
        'mortgageTermYears': mortgageTermYears,
        'mortgageTermMinYears': mortgageTermMinYears,
        'mortgageTermMaxYears': mortgageTermMaxYears,
        'paymentPlans': paymentPlans.map((e) => e.toJson()).toList(),
        'floorPlans': floorPlans.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
        'masterPlanDescription': masterPlanDescription,
        'masterPlanLegend': masterPlanLegend,
        'nearbyPlaces': nearbyPlaces.map((e) => e.toJson()).toList(),
        'totalUnits': totalUnits,
        'availableUnits': availableUnits,
        'reservedUnits': reservedUnits,
        'soldUnits': soldUnits,
        'inspectionSlots': inspectionSlots.map((e) => e.toJson()).toList(),
        'safetyScore': safetyScore,
        'walkabilityScore': walkabilityScore,
        'lifestyleScore': lifestyleScore,
        'appreciationEstimate': appreciationEstimate,
        'trafficConditions': trafficConditions,
        'plannedInfrastructure': plannedInfrastructure,
        'targetBuyers': targetBuyers,
        'communityFeatures': communityFeatures,
        'developerHighlights': developerHighlights,
        'reviews': reviews.map((e) => e.toJson()).toList(),
        'faqs': faqs.map((e) => e.toJson()).toList(),
      };

  PropertyDetailExtras copyWith({
    String? tour360Url,
    String? videoTourUrl,
    String? droneTourUrl,
    double? reservationFeePercent,
    String? taxesAndFees,
    bool? mortgageEligible,
    bool? showMortgageCalculator,
    double? mortgageDepositPercent,
    double? mortgageDepositMinPercent,
    double? mortgageDepositMaxPercent,
    double? mortgageInterestRate,
    double? mortgageInterestMin,
    double? mortgageInterestMax,
    double? mortgageTermYears,
    double? mortgageTermMinYears,
    double? mortgageTermMaxYears,
    List<ExtrasPaymentPlan>? paymentPlans,
    List<ExtrasFloorPlan>? floorPlans,
    List<ExtrasDocument>? documents,
    String? masterPlanDescription,
    List<String>? masterPlanLegend,
    List<ExtrasNearbyPlace>? nearbyPlaces,
    int? totalUnits,
    int? availableUnits,
    int? reservedUnits,
    int? soldUnits,
    List<ExtrasInspectionSlot>? inspectionSlots,
    int? safetyScore,
    int? walkabilityScore,
    int? lifestyleScore,
    String? appreciationEstimate,
    String? trafficConditions,
    String? plannedInfrastructure,
    String? targetBuyers,
    List<String>? communityFeatures,
    List<String>? developerHighlights,
    List<ExtrasReview>? reviews,
    List<ExtrasFaq>? faqs,
  }) {
    return PropertyDetailExtras(
      tour360Url: tour360Url ?? this.tour360Url,
      videoTourUrl: videoTourUrl ?? this.videoTourUrl,
      droneTourUrl: droneTourUrl ?? this.droneTourUrl,
      reservationFeePercent:
          reservationFeePercent ?? this.reservationFeePercent,
      taxesAndFees: taxesAndFees ?? this.taxesAndFees,
      mortgageEligible: mortgageEligible ?? this.mortgageEligible,
      showMortgageCalculator:
          showMortgageCalculator ?? this.showMortgageCalculator,
      mortgageDepositPercent:
          mortgageDepositPercent ?? this.mortgageDepositPercent,
      mortgageDepositMinPercent:
          mortgageDepositMinPercent ?? this.mortgageDepositMinPercent,
      mortgageDepositMaxPercent:
          mortgageDepositMaxPercent ?? this.mortgageDepositMaxPercent,
      mortgageInterestRate: mortgageInterestRate ?? this.mortgageInterestRate,
      mortgageInterestMin: mortgageInterestMin ?? this.mortgageInterestMin,
      mortgageInterestMax: mortgageInterestMax ?? this.mortgageInterestMax,
      mortgageTermYears: mortgageTermYears ?? this.mortgageTermYears,
      mortgageTermMinYears: mortgageTermMinYears ?? this.mortgageTermMinYears,
      mortgageTermMaxYears: mortgageTermMaxYears ?? this.mortgageTermMaxYears,
      paymentPlans: paymentPlans ?? this.paymentPlans,
      floorPlans: floorPlans ?? this.floorPlans,
      documents: documents ?? this.documents,
      masterPlanDescription:
          masterPlanDescription ?? this.masterPlanDescription,
      masterPlanLegend: masterPlanLegend ?? this.masterPlanLegend,
      nearbyPlaces: nearbyPlaces ?? this.nearbyPlaces,
      totalUnits: totalUnits ?? this.totalUnits,
      availableUnits: availableUnits ?? this.availableUnits,
      reservedUnits: reservedUnits ?? this.reservedUnits,
      soldUnits: soldUnits ?? this.soldUnits,
      inspectionSlots: inspectionSlots ?? this.inspectionSlots,
      safetyScore: safetyScore ?? this.safetyScore,
      walkabilityScore: walkabilityScore ?? this.walkabilityScore,
      lifestyleScore: lifestyleScore ?? this.lifestyleScore,
      appreciationEstimate: appreciationEstimate ?? this.appreciationEstimate,
      trafficConditions: trafficConditions ?? this.trafficConditions,
      plannedInfrastructure:
          plannedInfrastructure ?? this.plannedInfrastructure,
      targetBuyers: targetBuyers ?? this.targetBuyers,
      communityFeatures: communityFeatures ?? this.communityFeatures,
      developerHighlights: developerHighlights ?? this.developerHighlights,
      reviews: reviews ?? this.reviews,
      faqs: faqs ?? this.faqs,
    );
  }

  /// Blank extras for create-wizard so empty/0 fields show placeholders.
  static PropertyDetailExtras emptyForWizard() => const PropertyDetailExtras(
        reservationFeePercent: 0,
        taxesAndFees: '',
        mortgageEligible: false,
        showMortgageCalculator: false,
        paymentPlans: [
          ExtrasPaymentPlan(
            name: '',
            downPaymentPercent: 0,
            months: 0,
            interestRate: 0,
          ),
        ],
        floorPlans: [],
        documents: [],
        masterPlanDescription: '',
        masterPlanLegend: [],
        nearbyPlaces: [],
        totalUnits: 0,
        availableUnits: 0,
        reservedUnits: 0,
        soldUnits: 0,
        inspectionSlots: [],
        safetyScore: 0,
        walkabilityScore: 0,
        lifestyleScore: 0,
        appreciationEstimate: '',
        trafficConditions: '',
        plannedInfrastructure: '',
        targetBuyers: '',
        communityFeatures: [],
        developerHighlights: [],
        reviews: [],
        faqs: [],
      );

  /// Sensible starter content for public pages missing detail_extras.
  static PropertyDetailExtras defaultsForNewListing() => PropertyDetailExtras(
        paymentPlans: const [
          ExtrasPaymentPlan(
            name: '12-Month Plan',
            downPaymentPercent: 30,
            months: 12,
            interestRate: 0,
          ),
          ExtrasPaymentPlan(
            name: '24-Month Plan',
            downPaymentPercent: 20,
            months: 24,
            interestRate: 10,
          ),
        ],
        floorPlans: const [
          ExtrasFloorPlan(
            label: 'Ground Floor',
            dimensions: 'Open plan · 180 sqm',
            downloadUrl: '',
          ),
          ExtrasFloorPlan(
            label: 'First Floor',
            dimensions: 'Bedrooms · 200 sqm',
            downloadUrl: '',
          ),
        ],
        documents: const [
          ExtrasDocument(title: 'Property Brochure', type: 'PDF', url: ''),
          ExtrasDocument(title: 'Price List', type: 'PDF', url: ''),
          ExtrasDocument(title: 'Floor Plans', type: 'PDF', url: ''),
          ExtrasDocument(title: 'Payment Schedule', type: 'PDF', url: ''),
          ExtrasDocument(title: 'Site Plan', type: 'PDF', url: ''),
        ],
        nearbyPlaces: const [
          ExtrasNearbyPlace(
            name: 'Local School',
            category: 'School',
            distance: '1.2 km',
            travelTime: '4 min',
          ),
          ExtrasNearbyPlace(
            name: 'Shopping Centre',
            category: 'Shopping',
            distance: '3.5 km',
            travelTime: '12 min',
          ),
          ExtrasNearbyPlace(
            name: 'General Hospital',
            category: 'Hospital',
            distance: '2.8 km',
            travelTime: '10 min',
          ),
          ExtrasNearbyPlace(
            name: 'Bank Branch',
            category: 'Bank',
            distance: '0.8 km',
            travelTime: '3 min',
          ),
        ],
        inspectionSlots: const [
          ExtrasInspectionSlot(
            date: 'Sat 12 Jul',
            time: '10:00 AM',
            available: true,
          ),
          ExtrasInspectionSlot(
            date: 'Sat 12 Jul',
            time: '2:00 PM',
            available: true,
          ),
          ExtrasInspectionSlot(
            date: 'Mon 14 Jul',
            time: '3:00 PM',
            available: true,
          ),
        ],
        faqs: const [
          ExtrasFaq(
            question: 'Is the title verified?',
            answer:
                'Yes. All HD Homes estates include verified title documentation.',
          ),
          ExtrasFaq(
            question: 'Are installment plans available?',
            answer:
                'Multiple flexible plans are available. See pricing section or contact sales.',
          ),
          ExtrasFaq(
            question: 'Can I inspect before purchase?',
            answer:
                'Yes. Book an inspection slot online or contact our sales team.',
          ),
          ExtrasFaq(
            question: 'What documents are required?',
            answer:
                'Valid ID, proof of income, and reservation fee to secure your unit.',
          ),
        ],
        reviews: const [
          ExtrasReview(
            name: 'Chioma A.',
            role: 'Verified Buyer',
            rating: 5,
            comment:
                'Exceptional build quality and transparent process from start to finish.',
            verified: true,
            type: 'buyer',
          ),
          ExtrasReview(
            name: 'James O.',
            role: 'Investor',
            rating: 5,
            comment:
                'Strong rental demand in this corridor. HD Homes delivered on timelines.',
            verified: true,
            type: 'investor',
          ),
        ],
      );
}

class ExtrasPaymentPlan {
  const ExtrasPaymentPlan({
    required this.name,
    required this.downPaymentPercent,
    required this.months,
    required this.interestRate,
  });

  final String name;
  final double downPaymentPercent;
  final int months;
  final double interestRate;

  factory ExtrasPaymentPlan.fromJson(Map<String, dynamic> json) =>
      ExtrasPaymentPlan(
        name: json['name'] as String? ?? 'Plan',
        downPaymentPercent:
            (json['downPaymentPercent'] as num?)?.toDouble() ?? 30,
        months: (json['months'] as num?)?.toInt() ?? 12,
        interestRate: (json['interestRate'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'downPaymentPercent': downPaymentPercent,
        'months': months,
        'interestRate': interestRate,
      };
}

class ExtrasFloorPlan {
  const ExtrasFloorPlan({
    required this.label,
    required this.dimensions,
    required this.downloadUrl,
  });

  final String label;
  final String dimensions;
  final String downloadUrl;

  factory ExtrasFloorPlan.fromJson(Map<String, dynamic> json) =>
      ExtrasFloorPlan(
        label: json['label'] as String? ?? 'Floor',
        dimensions: json['dimensions'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'dimensions': dimensions,
        'downloadUrl': downloadUrl,
      };
}

class ExtrasDocument {
  const ExtrasDocument({
    required this.title,
    required this.type,
    required this.url,
  });

  final String title;
  final String type;
  final String url;

  factory ExtrasDocument.fromJson(Map<String, dynamic> json) => ExtrasDocument(
        title: json['title'] as String? ?? 'Document',
        type: json['type'] as String? ?? 'PDF',
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'type': type,
        'url': url,
      };
}

class ExtrasNearbyPlace {
  const ExtrasNearbyPlace({
    required this.name,
    required this.category,
    required this.distance,
    required this.travelTime,
  });

  final String name;
  final String category;
  final String distance;
  final String travelTime;

  factory ExtrasNearbyPlace.fromJson(Map<String, dynamic> json) =>
      ExtrasNearbyPlace(
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        distance: json['distance'] as String? ?? '',
        travelTime: json['travelTime'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'distance': distance,
        'travelTime': travelTime,
      };
}

class ExtrasInspectionSlot {
  const ExtrasInspectionSlot({
    required this.date,
    required this.time,
    required this.available,
  });

  final String date;
  final String time;
  final bool available;

  factory ExtrasInspectionSlot.fromJson(Map<String, dynamic> json) =>
      ExtrasInspectionSlot(
        date: json['date'] as String? ?? '',
        time: json['time'] as String? ?? '',
        available: json['available'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'time': time,
        'available': available,
      };
}

class ExtrasReview {
  const ExtrasReview({
    required this.name,
    required this.role,
    required this.rating,
    required this.comment,
    this.verified = true,
    this.type = 'buyer',
  });

  final String name;
  final String role;
  final int rating;
  final String comment;
  final bool verified;
  final String type;

  factory ExtrasReview.fromJson(Map<String, dynamic> json) => ExtrasReview(
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
        rating: (json['rating'] as num?)?.toInt() ?? 5,
        comment: json['comment'] as String? ?? '',
        verified: json['verified'] as bool? ?? true,
        type: json['type'] as String? ?? 'buyer',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'rating': rating,
        'comment': comment,
        'verified': verified,
        'type': type,
      };
}

class ExtrasFaq {
  const ExtrasFaq({required this.question, required this.answer});

  final String question;
  final String answer;

  factory ExtrasFaq.fromJson(Map<String, dynamic> json) => ExtrasFaq(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
      };
}
