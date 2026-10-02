class PlatformSettingRecord {
  const PlatformSettingRecord({
    required this.key,
    required this.value,
    required this.category,
    required this.isPublic,
    this.description,
    this.updatedAt,
    this.updatedBy,
  });

  final String key;
  final Map<String, dynamic> value;
  final String category;
  final bool isPublic;
  final String? description;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory PlatformSettingRecord.fromJson(Map<String, dynamic> json) {
    final raw = json['value'];
    return PlatformSettingRecord(
      key: '${json['key'] ?? ''}',
      value: raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
      category: '${json['category'] ?? 'general'}',
      isPublic: json['is_public'] == true,
      description: json['description']?.toString(),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
      updatedBy: json['updated_by']?.toString(),
    );
  }
}

class PlatformSettingsBundle {
  const PlatformSettingsBundle({
    this.company = const {},
    this.contact = const {},
    this.theme = const {},
    this.seo = const {},
    this.social = const {},
    this.websiteFeatures = const {},
    this.maintenance = const {},
    this.portalFeatures = const {},
    this.integrations = const {},
  });

  final Map<String, dynamic> company;
  final Map<String, dynamic> contact;
  final Map<String, dynamic> theme;
  final Map<String, dynamic> seo;
  final Map<String, dynamic> social;
  final Map<String, dynamic> websiteFeatures;
  final Map<String, dynamic> maintenance;
  final Map<String, dynamic> portalFeatures;
  final Map<String, dynamic> integrations;

  String get companyName =>
      _text(company, 'name', fallback: 'HD Homes Limited');
  String get tagline => _text(company, 'tagline');
  String get legalName => _text(company, 'legal_name', fallback: companyName);
  String get registrationNumber => _text(company, 'registration_number');
  String get country => _text(company, 'country', fallback: 'Nigeria');
  String get timezone => _text(company, 'timezone', fallback: 'Africa/Lagos');
  String get city => _text(company, 'city');
  String get stateRegion => _text(company, 'state');
  String get currency => _text(company, 'currency', fallback: 'NGN');
  String get currencySymbol => _text(company, 'currency_symbol', fallback: '₦');
  String get websiteUrl => _text(company, 'website_url', fallback: siteUrl);

  String get supportEmail => _text(contact, 'email');
  String get supportPhone => _text(contact, 'phone');
  String get supportWhatsapp => _text(contact, 'whatsapp');
  String get officeAddress => _text(contact, 'address');
  String get supportHours => _text(contact, 'support_hours');
  String get emergencyContact => _text(contact, 'emergency_contact');

  String get brandPrimary => _text(theme, 'primary', fallback: '#B48743');
  String get brandAccent => _text(
    theme,
    'accent',
    fallback: _text(theme, 'secondary', fallback: '#D4A34E'),
  );

  String get seoTitle => _text(seo, 'default_title', fallback: companyName);
  String get seoDescription =>
      _text(seo, 'default_description', fallback: tagline);
  String get siteUrl => _text(seo, 'site_url');
  String get ogImageUrl => _text(seo, 'og_image_url');
  String get twitterHandle => _text(seo, 'twitter_handle');

  String get facebookUrl => _text(social, 'facebook_url');
  String get instagramUrl => _text(social, 'instagram_url');
  String get twitterUrl => _text(social, 'twitter_url');
  String get linkedinUrl => _text(social, 'linkedin_url');
  String get youtubeUrl => _text(social, 'youtube_url');

  bool get showWhatsappFab => _bool(websiteFeatures, 'show_whatsapp_fab', true);
  bool get showLiveChatFab =>
      _bool(websiteFeatures, 'show_live_chat_fab', true);
  bool get showCallFabMobile =>
      _bool(websiteFeatures, 'show_call_fab_mobile', true);
  bool get showBookFabMobile =>
      _bool(websiteFeatures, 'show_book_fab_mobile', true);
  bool get enablePaymentCalculator =>
      _bool(websiteFeatures, 'enable_payment_calculator', true);
  bool get enableRoiCalculator =>
      _bool(websiteFeatures, 'enable_roi_calculator', true);
  bool get enablePublicSearch =>
      _bool(websiteFeatures, 'enable_public_search', true);
  bool get enableBlog => _bool(websiteFeatures, 'enable_blog', true);
  bool get enableTestimonials =>
      _bool(websiteFeatures, 'enable_testimonials', true);
  bool get enablePartners => _bool(websiteFeatures, 'enable_partners', true);
  bool get enableFaq => _bool(websiteFeatures, 'enable_faq', true);
  bool get enableNewsletter =>
      _bool(websiteFeatures, 'enable_newsletter', true);
  bool get enableContactForms =>
      _bool(websiteFeatures, 'enable_contact_forms', true);
  bool get enablePropertyListings =>
      _bool(websiteFeatures, 'enable_property_listings', true);
  bool get enableFeaturedProperties =>
      _bool(websiteFeatures, 'enable_featured_properties', true);
  bool get enableInvestmentSection =>
      _bool(websiteFeatures, 'enable_investment_section', true);
  bool get enableConstructionUpdates =>
      _bool(websiteFeatures, 'enable_construction_updates', true);
  bool get enableClientPortalEntry =>
      _bool(websiteFeatures, 'enable_client_portal_entry', true);
  bool get enableInvestorPortalEntry =>
      _bool(websiteFeatures, 'enable_investor_portal_entry', true);

  bool get maintenanceEnabled => _bool(maintenance, 'enabled', false);
  bool get showMaintenanceBanner => _bool(maintenance, 'show_banner', false);
  bool get allowAdminBypass => _bool(maintenance, 'allow_admin_bypass', true);
  String get maintenanceTitle =>
      _text(maintenance, 'title', fallback: 'We will be right back');
  String get maintenanceMessage => _text(
    maintenance,
    'message',
    fallback:
        'HD Homes is performing scheduled maintenance. Please check again shortly.',
  );
  String get bannerMessage => _text(maintenance, 'banner_message');

  Map<String, dynamic> get clientPortal =>
      _map(portalFeatures, 'client');
  Map<String, dynamic> get investorPortal =>
      _map(portalFeatures, 'investor');

  bool get clientPortalEnabled => _bool(clientPortal, 'enabled', true);
  bool get investorPortalEnabled => _bool(investorPortal, 'enabled', true);

  String get clientWelcomeMessage => _text(
    clientPortal,
    'welcome_message',
    fallback: 'Welcome to your HD Homes client portal.',
  );
  String get investorWelcomeMessage => _text(
    investorPortal,
    'welcome_message',
    fallback: 'Welcome to your HD Homes investor portal.',
  );

  bool clientModuleEnabled(String key, {bool fallback = true}) =>
      _bool(clientPortal, key, fallback);
  bool investorModuleEnabled(String key, {bool fallback = true}) =>
      _bool(investorPortal, key, fallback);

  /// Legacy company blob shape used by footer / contact / WhatsApp FABs.
  Map<String, dynamic> toCompanyCompatibilityMap() => {
    'company_name': companyName,
    'tagline': tagline,
    'support_email': supportEmail,
    'support_phone': supportPhone,
    'support_whatsapp': supportWhatsapp,
    'address': officeAddress,
    'brand_primary_color': brandPrimary,
    'brand_accent_color': brandAccent,
    'facebook_url': facebookUrl,
    'instagram_url': instagramUrl,
    'twitter_url': twitterUrl,
    'linkedin_url': linkedinUrl,
    'youtube_url': youtubeUrl,
    'support_hours': supportHours,
    'legal_name': legalName,
    'registration_number': registrationNumber,
    'country': country,
    'city': city,
    'state': stateRegion,
    'timezone': timezone,
    'currency': currency,
    'currency_symbol': currencySymbol,
    'website_url': websiteUrl,
    'seo_title': seoTitle,
    'seo_description': seoDescription,
    'site_url': siteUrl,
    'og_image_url': ogImageUrl,
    'emergency_contact': emergencyContact,
  };

  PlatformSettingsBundle copyWith({
    Map<String, dynamic>? company,
    Map<String, dynamic>? contact,
    Map<String, dynamic>? theme,
    Map<String, dynamic>? seo,
    Map<String, dynamic>? social,
    Map<String, dynamic>? websiteFeatures,
    Map<String, dynamic>? maintenance,
    Map<String, dynamic>? portalFeatures,
    Map<String, dynamic>? integrations,
  }) {
    return PlatformSettingsBundle(
      company: company ?? this.company,
      contact: contact ?? this.contact,
      theme: theme ?? this.theme,
      seo: seo ?? this.seo,
      social: social ?? this.social,
      websiteFeatures: websiteFeatures ?? this.websiteFeatures,
      maintenance: maintenance ?? this.maintenance,
      portalFeatures: portalFeatures ?? this.portalFeatures,
      integrations: integrations ?? this.integrations,
    );
  }

  static PlatformSettingsBundle fromRecords(
    Iterable<PlatformSettingRecord> records,
  ) {
    final byKey = {for (final r in records) r.key: r.value};
    return PlatformSettingsBundle(
      company: Map<String, dynamic>.from(byKey['company'] ?? const {}),
      contact: Map<String, dynamic>.from(byKey['contact'] ?? const {}),
      theme: Map<String, dynamic>.from(byKey['theme'] ?? const {}),
      seo: Map<String, dynamic>.from(byKey['seo'] ?? const {}),
      social: Map<String, dynamic>.from(byKey['social'] ?? const {}),
      websiteFeatures: Map<String, dynamic>.from(
        byKey['website_features'] ?? const {},
      ),
      maintenance: Map<String, dynamic>.from(byKey['maintenance'] ?? const {}),
      portalFeatures: Map<String, dynamic>.from(
        byKey['portal_features'] ?? const {},
      ),
      integrations: Map<String, dynamic>.from(
        byKey['integrations'] ?? const {},
      ),
    );
  }

  static Map<String, dynamic> _map(Map<String, dynamic> parent, String key) {
    final raw = parent[key];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static String _text(
    Map<String, dynamic> map,
    String key, {
    String fallback = '',
  }) {
    final value = '${map[key] ?? ''}'.trim();
    return value.isEmpty ? fallback : value;
  }

  static bool _bool(Map<String, dynamic> map, String key, bool fallback) {
    final value = map[key];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }
}
