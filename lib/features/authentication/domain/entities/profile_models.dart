import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Profile section tabs (Dynamic User Identity™).
enum ProfileSection {
  overview,
  personal,
  contact,
  company,
  communication,
  regional,
  appearance,
  privacy,
  connected,
  summary,
}

extension ProfileSectionX on ProfileSection {
  String get label => switch (this) {
        ProfileSection.overview => 'Overview',
        ProfileSection.personal => 'Personal',
        ProfileSection.contact => 'Contact',
        ProfileSection.company => 'Company',
        ProfileSection.communication => 'Notifications',
        ProfileSection.regional => 'Regional',
        ProfileSection.appearance => 'Appearance',
        ProfileSection.privacy => 'Privacy',
        ProfileSection.connected => 'Connected',
        ProfileSection.summary => 'Account',
      };
}

/// Which sections appear for a role (same architecture, different surface).
abstract final class DynamicUserIdentity {
  static List<ProfileSection> sectionsFor(AppRole? role) {
    final base = [
      ProfileSection.overview,
      ProfileSection.personal,
      ProfileSection.contact,
      ProfileSection.communication,
      ProfileSection.regional,
      ProfileSection.appearance,
      ProfileSection.privacy,
      ProfileSection.summary,
    ];
    final showCompany = role == AppRole.investor ||
        role == AppRole.admin ||
        role == AppRole.superAdmin ||
        role == AppRole.finance ||
        role == AppRole.salesTeam;
    if (showCompany) {
      base.insert(3, ProfileSection.company);
    }
    // Connected accounts — future OAuth; always listed as coming soon.
    base.insert(base.length - 1, ProfileSection.connected);
    return base;
  }
}

/// Editable personal + contact fields stored on `profiles` (+ extensions).
class ProfileDetails {
  const ProfileDetails({
    required this.id,
    required this.email,
    this.firstName,
    this.middleName,
    this.lastName,
    this.preferredName,
    this.gender,
    this.dateOfBirth,
    this.nationality,
    this.occupation,
    this.biography,
    this.phone,
    this.secondaryPhone,
    this.whatsapp,
    this.country,
    this.state,
    this.city,
    this.address,
    this.postalCode,
    this.avatarUrl,
    this.preferredLanguage = 'en',
    this.accountStatus,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.createdAt,
    this.lastLoginAt,
    this.primaryRole,
  });

  final String id;
  final String email;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? preferredName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? nationality;
  final String? occupation;
  final String? biography;
  final String? phone;
  final String? secondaryPhone;
  final String? whatsapp;
  final String? country;
  final String? state;
  final String? city;
  final String? address;
  final String? postalCode;
  final String? avatarUrl;
  final String preferredLanguage;
  final String? accountStatus;
  final bool phoneVerified;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final AppRole? primaryRole;

  String get displayName {
    final preferred = preferredName?.trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    final name = [firstName, lastName].where((n) => n?.trim().isNotEmpty == true).join(' ');
    return name.isNotEmpty ? name : email;
  }

  String get fullName {
    return [firstName, middleName, lastName]
        .where((n) => n?.trim().isNotEmpty == true)
        .join(' ');
  }

  ProfileDetails copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? preferredName,
    String? gender,
    DateTime? dateOfBirth,
    String? nationality,
    String? occupation,
    String? biography,
    String? phone,
    String? secondaryPhone,
    String? whatsapp,
    String? country,
    String? state,
    String? city,
    String? address,
    String? postalCode,
    String? avatarUrl,
    String? preferredLanguage,
    bool? phoneVerified,
    bool clearDob = false,
  }) {
    return ProfileDetails(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      preferredName: preferredName ?? this.preferredName,
      gender: gender ?? this.gender,
      dateOfBirth: clearDob ? null : (dateOfBirth ?? this.dateOfBirth),
      nationality: nationality ?? this.nationality,
      occupation: occupation ?? this.occupation,
      biography: biography ?? this.biography,
      phone: phone ?? this.phone,
      secondaryPhone: secondaryPhone ?? this.secondaryPhone,
      whatsapp: whatsapp ?? this.whatsapp,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      address: address ?? this.address,
      postalCode: postalCode ?? this.postalCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      accountStatus: accountStatus,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      primaryRole: primaryRole,
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'first_name': firstName?.trim(),
      'middle_name': middleName?.trim(),
      'last_name': lastName?.trim(),
      'preferred_name': preferredName?.trim(),
      'gender': gender,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'nationality': nationality?.trim(),
      'occupation': occupation?.trim(),
      'biography': biography?.trim(),
      'phone': phone?.trim(),
      'secondary_phone': secondaryPhone?.trim(),
      'whatsapp': whatsapp?.trim(),
      'country': country?.trim(),
      'state': state?.trim(),
      'city': city?.trim(),
      'address': address?.trim(),
      'postal_code': postalCode?.trim(),
      'preferred_language': preferredLanguage,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory ProfileDetails.fromJson(
    Map<String, dynamic> json, {
    bool emailVerified = false,
    AppRole? primaryRole,
  }) {
    DateTime? parseDate(dynamic v) {
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ProfileDetails(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String?,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String?,
      preferredName: json['preferred_name'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: parseDate(json['date_of_birth']),
      nationality: json['nationality'] as String?,
      occupation: json['occupation'] as String?,
      biography: json['biography'] as String?,
      phone: json['phone'] as String?,
      secondaryPhone: json['secondary_phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      country: json['country'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      postalCode: json['postal_code'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      accountStatus: json['account_status'] as String?,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      emailVerified: emailVerified,
      createdAt: parseDate(json['created_at']),
      lastLoginAt: parseDate(json['last_login_at']),
      primaryRole: primaryRole,
    );
  }
}

class CompanyProfile {
  const CompanyProfile({
    this.companyName,
    this.businessType,
    this.registrationNumber,
    this.taxId,
    this.position,
    this.companyAddress,
    this.companyWebsite,
  });

  final String? companyName;
  final String? businessType;
  final String? registrationNumber;
  final String? taxId;
  final String? position;
  final String? companyAddress;
  final String? companyWebsite;

  bool get isEmpty =>
      (companyName == null || companyName!.trim().isEmpty) &&
      (businessType == null || businessType!.trim().isEmpty);

  CompanyProfile copyWith({
    String? companyName,
    String? businessType,
    String? registrationNumber,
    String? taxId,
    String? position,
    String? companyAddress,
    String? companyWebsite,
  }) {
    return CompanyProfile(
      companyName: companyName ?? this.companyName,
      businessType: businessType ?? this.businessType,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      taxId: taxId ?? this.taxId,
      position: position ?? this.position,
      companyAddress: companyAddress ?? this.companyAddress,
      companyWebsite: companyWebsite ?? this.companyWebsite,
    );
  }

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'company_name': companyName?.trim(),
        'business_type': businessType?.trim(),
        'registration_number': registrationNumber?.trim(),
        'tax_id': taxId?.trim(),
        'position': position?.trim(),
        'company_address': companyAddress?.trim(),
        'company_website': companyWebsite?.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory CompanyProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CompanyProfile();
    return CompanyProfile(
      companyName: json['company_name'] as String?,
      businessType: json['business_type'] as String?,
      registrationNumber: json['registration_number'] as String?,
      taxId: json['tax_id'] as String?,
      position: json['position'] as String?,
      companyAddress: json['company_address'] as String?,
      companyWebsite: json['company_website'] as String?,
    );
  }
}

class CommunicationPreferences {
  const CommunicationPreferences({
    this.emailEnabled = true,
    this.smsEnabled = false,
    this.pushEnabled = true,
    this.whatsappEnabled = false,
    this.marketingEmail = false,
    this.securityAlerts = true,
    this.investmentUpdates = true,
    this.propertyAlerts = true,
    this.newsletters = false,
    this.productAnnouncements = true,
  });

  final bool emailEnabled;
  final bool smsEnabled;
  final bool pushEnabled;
  final bool whatsappEnabled;
  final bool marketingEmail;
  final bool securityAlerts;
  final bool investmentUpdates;
  final bool propertyAlerts;
  final bool newsletters;
  final bool productAnnouncements;

  CommunicationPreferences copyWith({
    bool? emailEnabled,
    bool? smsEnabled,
    bool? pushEnabled,
    bool? whatsappEnabled,
    bool? marketingEmail,
    bool? securityAlerts,
    bool? investmentUpdates,
    bool? propertyAlerts,
    bool? newsletters,
    bool? productAnnouncements,
  }) {
    return CommunicationPreferences(
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      marketingEmail: marketingEmail ?? this.marketingEmail,
      securityAlerts: securityAlerts ?? this.securityAlerts,
      investmentUpdates: investmentUpdates ?? this.investmentUpdates,
      propertyAlerts: propertyAlerts ?? this.propertyAlerts,
      newsletters: newsletters ?? this.newsletters,
      productAnnouncements: productAnnouncements ?? this.productAnnouncements,
    );
  }

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'email_enabled': emailEnabled,
        'sms_enabled': smsEnabled,
        'push_enabled': pushEnabled,
        'marketing_email': marketingEmail,
        'security_alerts': securityAlerts,
        'extras': {
          'whatsapp_enabled': whatsappEnabled,
          'investment_updates': investmentUpdates,
          'property_alerts': propertyAlerts,
          'newsletters': newsletters,
          'product_announcements': productAnnouncements,
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory CommunicationPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CommunicationPreferences();
    final extras = Map<String, dynamic>.from(
      (json['extras'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    return CommunicationPreferences(
      emailEnabled: json['email_enabled'] as bool? ?? true,
      smsEnabled: json['sms_enabled'] as bool? ?? false,
      pushEnabled: json['push_enabled'] as bool? ?? true,
      marketingEmail: json['marketing_email'] as bool? ?? false,
      securityAlerts: json['security_alerts'] as bool? ?? true,
      whatsappEnabled: extras['whatsapp_enabled'] as bool? ?? false,
      investmentUpdates: extras['investment_updates'] as bool? ?? true,
      propertyAlerts: extras['property_alerts'] as bool? ?? true,
      newsletters: extras['newsletters'] as bool? ?? false,
      productAnnouncements: extras['product_announcements'] as bool? ?? true,
    );
  }
}

class UserAppPreferences {
  const UserAppPreferences({
    this.theme = 'system',
    this.locale = 'en',
    this.timezone = 'Africa/Lagos',
    this.currency = 'NGN',
    this.dateFormat = 'dd/MM/yyyy',
    this.numberFormat = 'en_NG',
    this.marketingOptIn = false,
    this.productUpdatesOptIn = true,
    this.profileVisibility = 'private',
    this.cookiePreferencesAccepted = true,
    this.dataSharingOptIn = false,
  });

  final String theme;
  final String locale;
  final String timezone;
  final String currency;
  final String dateFormat;
  final String numberFormat;
  final bool marketingOptIn;
  final bool productUpdatesOptIn;
  final String profileVisibility;
  final bool cookiePreferencesAccepted;
  final bool dataSharingOptIn;

  UserAppPreferences copyWith({
    String? theme,
    String? locale,
    String? timezone,
    String? currency,
    String? dateFormat,
    String? numberFormat,
    bool? marketingOptIn,
    bool? productUpdatesOptIn,
    String? profileVisibility,
    bool? cookiePreferencesAccepted,
    bool? dataSharingOptIn,
  }) {
    return UserAppPreferences(
      theme: theme ?? this.theme,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      numberFormat: numberFormat ?? this.numberFormat,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      productUpdatesOptIn: productUpdatesOptIn ?? this.productUpdatesOptIn,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      cookiePreferencesAccepted:
          cookiePreferencesAccepted ?? this.cookiePreferencesAccepted,
      dataSharingOptIn: dataSharingOptIn ?? this.dataSharingOptIn,
    );
  }

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'theme': theme,
        'locale': locale,
        'timezone': timezone,
        'marketing_opt_in': marketingOptIn,
        'product_updates_opt_in': productUpdatesOptIn,
        'extras': {
          'currency': currency,
          'date_format': dateFormat,
          'number_format': numberFormat,
          'profile_visibility': profileVisibility,
          'cookie_preferences_accepted': cookiePreferencesAccepted,
          'data_sharing_opt_in': dataSharingOptIn,
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory UserAppPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserAppPreferences();
    final extras = Map<String, dynamic>.from(
      (json['extras'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    return UserAppPreferences(
      theme: json['theme'] as String? ?? 'system',
      locale: json['locale'] as String? ?? 'en',
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
      marketingOptIn: json['marketing_opt_in'] as bool? ?? false,
      productUpdatesOptIn: json['product_updates_opt_in'] as bool? ?? true,
      currency: extras['currency'] as String? ?? 'NGN',
      dateFormat: extras['date_format'] as String? ?? 'dd/MM/yyyy',
      numberFormat: extras['number_format'] as String? ?? 'en_NG',
      profileVisibility: extras['profile_visibility'] as String? ?? 'private',
      cookiePreferencesAccepted:
          extras['cookie_preferences_accepted'] as bool? ?? true,
      dataSharingOptIn: extras['data_sharing_opt_in'] as bool? ?? false,
    );
  }
}

class ProfileActivityItem {
  const ProfileActivityItem({
    required this.eventType,
    required this.createdAt,
    this.metadata = const {},
  });

  final String eventType;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  factory ProfileActivityItem.fromJson(Map<String, dynamic> json) {
    return ProfileActivityItem(
      eventType: json['event_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: Map<String, dynamic>.from(
        (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }
}

/// Intelligent Profile Completion Engine™ checklist item.
class ProfileCompletionItem {
  const ProfileCompletionItem({
    required this.id,
    required this.label,
    required this.weight,
    required this.completed,
    this.actionLabel,
    this.actionPath,
  });

  final String id;
  final String label;
  final int weight;
  final bool completed;
  final String? actionLabel;
  final String? actionPath;
}

class ProfileCompletionResult {
  const ProfileCompletionResult({
    required this.percent,
    required this.items,
  });

  final int percent;
  final List<ProfileCompletionItem> items;

  List<ProfileCompletionItem> get missing =>
      items.where((i) => !i.completed).toList();
}

/// Intelligent Profile Completion Engine™
abstract final class ProfileCompletionEngine {
  static ProfileCompletionResult evaluate({
    required ProfileDetails profile,
    required CompanyProfile company,
    required CommunicationPreferences communication,
    required bool mfaEnabled,
    required bool isInvestor,
  }) {
    final items = <ProfileCompletionItem>[
      ProfileCompletionItem(
        id: 'avatar',
        label: 'Add a profile photo',
        weight: 10,
        completed: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty,
        actionLabel: 'Upload photo',
      ),
      ProfileCompletionItem(
        id: 'phone',
        label: 'Verify your phone number',
        weight: 10,
        completed: profile.phoneVerified,
        actionLabel: 'Verify phone',
        actionPath: '/account/verify-phone',
      ),
      ProfileCompletionItem(
        id: 'address',
        label: 'Complete your address',
        weight: 15,
        completed: (profile.address?.trim().isNotEmpty ?? false) &&
            (profile.city?.trim().isNotEmpty ?? false),
        actionLabel: 'Add address',
      ),
      ProfileCompletionItem(
        id: 'occupation',
        label: 'Add your occupation',
        weight: 10,
        completed: profile.occupation?.trim().isNotEmpty ?? false,
        actionLabel: 'Add occupation',
      ),
      ProfileCompletionItem(
        id: 'preferences',
        label: 'Set communication preferences',
        weight: 10,
        completed: true, // defaults exist; marked complete once loaded
        actionLabel: 'Review preferences',
      ),
      ProfileCompletionItem(
        id: 'company',
        label: 'Complete company profile',
        weight: 15,
        completed: !isInvestor || !company.isEmpty,
        actionLabel: 'Add company',
      ),
      ProfileCompletionItem(
        id: 'mfa',
        label: 'Enable multi-factor authentication',
        weight: 10,
        completed: mfaEnabled,
        actionLabel: 'Enable MFA',
        actionPath: '/account/mfa/setup',
      ),
      ProfileCompletionItem(
        id: 'name',
        label: 'Add your full name',
        weight: 10,
        completed: (profile.firstName?.trim().isNotEmpty ?? false) &&
            (profile.lastName?.trim().isNotEmpty ?? false),
        actionLabel: 'Edit name',
      ),
      const ProfileCompletionItem(
        id: 'kyc',
        label: 'Complete KYC verification',
        weight: 10,
        completed: false,
        actionLabel: 'Start KYC',
        actionPath: '/account/kyc',
      ),
    ];

    // Preferences: bump incomplete if marketing channels never touched — treat
    // as complete when email channel is on (default) AND user has phone or
    // explicitly set SMS/WhatsApp preference path.
    final adjusted = items.map((item) {
      if (item.id != 'preferences') return item;
      final touched = communication.smsEnabled ||
          communication.whatsappEnabled ||
          !communication.marketingEmail ||
          communication.newsletters;
      return ProfileCompletionItem(
        id: item.id,
        label: item.label,
        weight: item.weight,
        completed: touched || communication.emailEnabled,
        actionLabel: item.actionLabel,
        actionPath: item.actionPath,
      );
    }).toList();

    final totalWeight = adjusted.fold<int>(0, (s, i) => s + i.weight);
    final earned = adjusted
        .where((i) => i.completed)
        .fold<int>(0, (s, i) => s + i.weight);
    final percent =
        totalWeight == 0 ? 0 : ((earned / totalWeight) * 100).round().clamp(0, 100);

    return ProfileCompletionResult(percent: percent, items: adjusted);
  }
}

/// Account Health Score (profile + security readiness).
abstract final class AccountHealthScore {
  static int compute({
    required int profileCompletionPercent,
    required bool emailVerified,
    required bool phoneVerified,
    required bool mfaEnabled,
    required int securityReadiness,
  }) {
    var score = 0;
    score += (profileCompletionPercent * 0.35).round();
    if (emailVerified) score += 15;
    if (phoneVerified) score += 15;
    if (mfaEnabled) score += 20;
    score += (securityReadiness * 0.15).round();
    return score.clamp(0, 100);
  }
}

/// Full hub snapshot for UI.
class ProfileHubSnapshot {
  const ProfileHubSnapshot({
    required this.profile,
    required this.company,
    required this.communication,
    required this.appPreferences,
    required this.completion,
    required this.accountHealth,
    this.activity = const [],
    this.mfaEnabled = false,
  });

  final ProfileDetails profile;
  final CompanyProfile company;
  final CommunicationPreferences communication;
  final UserAppPreferences appPreferences;
  final ProfileCompletionResult completion;
  final int accountHealth;
  final List<ProfileActivityItem> activity;
  final bool mfaEnabled;
}
