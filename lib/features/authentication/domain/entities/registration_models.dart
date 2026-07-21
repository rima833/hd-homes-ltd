import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Account types supported at registration (extensible for future roles).
enum RegistrationAccountType {
  client(
    id: 'client',
    title: 'Registered Client',
    description: 'Buy property, book inspections, and track your journey.',
    benefits: [
      'Save and compare properties',
      'Book site inspections',
      'Track purchases and payments',
      'Access the Client Dashboard',
    ],
    enabled: true,
  ),
  investor(
    id: 'investor',
    title: 'Investor',
    description: 'Explore opportunities, portfolios, and ROI reporting.',
    benefits: [
      'Investor Portal access',
      'Investment opportunities',
      'Portfolio and ROI tracking',
      'Investment documents',
    ],
    enabled: true,
  ),
  // Future-ready (disabled in UI)
  propertyOwner(
    id: 'property_owner',
    title: 'Property Owner',
    description: 'Manage owned assets and estate services.',
    benefits: ['Coming soon'],
    enabled: false,
  ),
  businessPartner(
    id: 'business_partner',
    title: 'Business Partner',
    description: 'Partner with HD Homes on developments and channels.',
    benefits: ['Coming soon'],
    enabled: false,
  ),
  contractor(
    id: 'contractor',
    title: 'Contractor',
    description: 'Construction and project delivery partners.',
    benefits: ['Coming soon'],
    enabled: false,
  ),
  vendor(
    id: 'vendor',
    title: 'Vendor',
    description: 'Supply and service vendors.',
    benefits: ['Coming soon'],
    enabled: false,
  ),
  estateManager(
    id: 'estate_manager',
    title: 'Estate Manager',
    description: 'Operate and manage HD Homes communities.',
    benefits: ['Coming soon'],
    enabled: false,
  );

  const RegistrationAccountType({
    required this.id,
    required this.title,
    required this.description,
    required this.benefits,
    required this.enabled,
  });

  final String id;
  final String title;
  final String description;
  final List<String> benefits;
  final bool enabled;

  static RegistrationAccountType? fromId(String? id) {
    if (id == null) return null;
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }

  AppRole get defaultRole => switch (this) {
        RegistrationAccountType.investor => AppRole.investor,
        _ => AppRole.client,
      };

  static List<RegistrationAccountType> get selectable =>
      values.where((t) => t.enabled).toList();

  static List<RegistrationAccountType> get upcoming =>
      values.where((t) => !t.enabled).toList();
}

enum RegistrationStep {
  accountType,
  personalInfo,
  credentials,
  legal,
  review,
}

extension RegistrationStepX on RegistrationStep {
  int get index => RegistrationStep.values.indexOf(this);

  String get title => switch (this) {
        RegistrationStep.accountType => 'Account type',
        RegistrationStep.personalInfo => 'Personal details',
        RegistrationStep.credentials => 'Credentials',
        RegistrationStep.legal => 'Agreements',
        RegistrationStep.review => 'Review',
      };

  RegistrationStep? get previous {
    final i = index;
    if (i <= 0) return null;
    return RegistrationStep.values[i - 1];
  }

  RegistrationStep? get next {
    final i = index;
    if (i >= RegistrationStep.values.length - 1) return null;
    return RegistrationStep.values[i + 1];
  }
}

/// Current versions of legal documents (CMS-backed later).
abstract final class LegalDocumentVersions {
  static const terms = 'terms-v1.0';
  static const privacy = 'privacy-v1.0';
  static const cookies = 'cookies-v1.0';
}

/// Progressive registration draft held in memory until submit.
class RegistrationDraft {
  const RegistrationDraft({
    this.accountType,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.country = 'Nigeria',
    this.state = '',
    this.city = '',
    this.password = '',
    this.confirmPassword = '',
    this.acceptTerms = false,
    this.acceptPrivacy = false,
    this.acceptCookies = false,
    this.marketingOptIn = false,
    this.productUpdatesOptIn = true,
    this.newsletterOptIn = false,
    this.referralCode = '',
    this.invitationToken,
  });

  final RegistrationAccountType? accountType;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String country;
  final String state;
  final String city;
  final String password;
  final String confirmPassword;
  final bool acceptTerms;
  final bool acceptPrivacy;
  final bool acceptCookies;
  final bool marketingOptIn;
  final bool productUpdatesOptIn;
  final bool newsletterOptIn;
  final String referralCode;
  final String? invitationToken;

  RegistrationDraft copyWith({
    RegistrationAccountType? accountType,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? country,
    String? state,
    String? city,
    String? password,
    String? confirmPassword,
    bool? acceptTerms,
    bool? acceptPrivacy,
    bool? acceptCookies,
    bool? marketingOptIn,
    bool? productUpdatesOptIn,
    bool? newsletterOptIn,
    String? referralCode,
    String? invitationToken,
  }) {
    return RegistrationDraft(
      accountType: accountType ?? this.accountType,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      acceptTerms: acceptTerms ?? this.acceptTerms,
      acceptPrivacy: acceptPrivacy ?? this.acceptPrivacy,
      acceptCookies: acceptCookies ?? this.acceptCookies,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      productUpdatesOptIn: productUpdatesOptIn ?? this.productUpdatesOptIn,
      newsletterOptIn: newsletterOptIn ?? this.newsletterOptIn,
      referralCode: referralCode ?? this.referralCode,
      invitationToken: invitationToken ?? this.invitationToken,
    );
  }

  Map<String, dynamic> toAuthMetadata() => {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'country': country.trim(),
        'state': state.trim(),
        'city': city.trim(),
        'account_type': accountType?.id ?? 'client',
        'referral_code': referralCode.trim().isEmpty ? null : referralCode.trim(),
        'invitation_token': invitationToken,
        'marketing_opt_in': marketingOptIn,
        'product_updates_opt_in': productUpdatesOptIn,
        'newsletter_opt_in': newsletterOptIn,
        'terms_version': LegalDocumentVersions.terms,
        'privacy_version': LegalDocumentVersions.privacy,
        'cookies_version': LegalDocumentVersions.cookies,
        'accepted_legal_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class RegistrationResult {
  const RegistrationResult({
    required this.userId,
    required this.email,
    required this.accountType,
    required this.needsEmailVerification,
    this.sessionCreated = false,
  });

  final String userId;
  final String email;
  final RegistrationAccountType accountType;
  final bool needsEmailVerification;
  final bool sessionCreated;
}

enum RegistrationAnalyticsEvent {
  started,
  stepCompleted,
  stepAbandoned,
  accountTypeSelected,
  submitted,
  succeeded,
  failed,
  referralApplied,
}
