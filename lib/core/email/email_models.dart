/// HD Homes transactional email models (client-safe; no provider secrets).
library;

enum EmailDeliveryStatus {
  queued,
  sending,
  sent,
  delivered,
  failed;

  static EmailDeliveryStatus fromSlug(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'sending':
        return EmailDeliveryStatus.sending;
      case 'sent':
        return EmailDeliveryStatus.sent;
      case 'delivered':
        return EmailDeliveryStatus.delivered;
      case 'failed':
        return EmailDeliveryStatus.failed;
      default:
        return EmailDeliveryStatus.queued;
    }
  }

  String get slug => name;
}

/// Canonical template keys used by queue + Auth/admin surfaces.
abstract final class EmailTemplateKeys {
  static const welcome = 'welcome';
  static const securityAlert = 'security_alert';
  static const passwordChanged = 'password_changed';
  static const emailChanged = 'email_changed';
  static const paymentSuccessful = 'payment_successful';
  static const paymentSubmitted = 'payment_submitted';
  static const paymentVerified = 'payment_verified';
  static const paymentRejected = 'payment_rejected';
  static const bookingConfirmed = 'booking_confirmed';
  static const inspectionConfirmed = 'inspection_confirmed';
  static const inspectionReminder = 'inspection_reminder';
  static const supportTicketCreated = 'support_ticket_created';
  static const supportTicketUpdated = 'support_ticket_updated';
  static const supportTicketResolved = 'support_ticket_resolved';
  static const constructionUpdate = 'construction_update';
  static const documentPublished = 'document_published';
  static const investorKycUpdate = 'investor_kyc_update';
  static const investorPaymentUpdate = 'investor_payment_update';
  static const staffInvite = 'staff_invite';
  static const portalInvite = 'portal_invite';
  static const announcement = 'announcement';
  static const kycApproved = 'kyc_approved';

  /// Templates that cannot be disabled in Admin.
  static const securityLocked = {
    securityAlert,
    passwordChanged,
    emailChanged,
  };
}

class EmailBrandConfig {
  const EmailBrandConfig({
    this.logoUrl =
        'https://wbonjdqsifwsawhhxygl.supabase.co/storage/v1/object/public/logos/hd_homes_logo.png',
    this.senderName = 'HD Homes Limited',
    this.senderEmail = 'no-reply@hdhomesltd.com',
    this.replyTo = 'support@hdhomesltd.com',
    this.supportEmail = 'support@hdhomesltd.com',
    this.websiteUrl = 'https://hdhomesltd.com',
    this.privacyUrl = 'https://hdhomesltd.com/trust',
    this.termsUrl = 'https://hdhomesltd.com/trust',
    this.primaryColor = '#D4A34E',
    this.companyName = 'HD Homes Limited',
    this.tagline = 'Making Quality Housing Accessible',
  });

  final String logoUrl;
  final String senderName;
  final String senderEmail;
  final String replyTo;
  final String supportEmail;
  final String websiteUrl;
  final String privacyUrl;
  final String termsUrl;
  final String primaryColor;
  final String companyName;
  final String tagline;

  factory EmailBrandConfig.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const {};
    String s(String key, String fallback) =>
        (m[key] as String?)?.trim().isNotEmpty == true
        ? (m[key] as String).trim()
        : fallback;
    const d = EmailBrandConfig();
    return EmailBrandConfig(
      logoUrl: s('logo_url', d.logoUrl),
      senderName: s('sender_name', d.senderName),
      senderEmail: s('sender_email', d.senderEmail),
      replyTo: s('reply_to', d.replyTo),
      supportEmail: s('support_email', d.supportEmail),
      websiteUrl: s('website_url', d.websiteUrl),
      privacyUrl: s('privacy_url', d.privacyUrl),
      termsUrl: s('terms_url', d.termsUrl),
      primaryColor: s('primary_color', d.primaryColor),
      companyName: s('company_name', d.companyName),
      tagline: s('tagline', d.tagline),
    );
  }

  Map<String, dynamic> toJson() => {
    'logo_url': logoUrl,
    'sender_name': senderName,
    'sender_email': senderEmail,
    'reply_to': replyTo,
    'support_email': supportEmail,
    'website_url': websiteUrl,
    'privacy_url': privacyUrl,
    'terms_url': termsUrl,
    'primary_color': primaryColor,
    'company_name': companyName,
    'tagline': tagline,
  };

  EmailBrandConfig copyWith({
    String? logoUrl,
    String? senderName,
    String? senderEmail,
    String? replyTo,
    String? supportEmail,
    String? websiteUrl,
    String? privacyUrl,
    String? termsUrl,
    String? primaryColor,
    String? companyName,
    String? tagline,
  }) {
    return EmailBrandConfig(
      logoUrl: logoUrl ?? this.logoUrl,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      replyTo: replyTo ?? this.replyTo,
      supportEmail: supportEmail ?? this.supportEmail,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      privacyUrl: privacyUrl ?? this.privacyUrl,
      termsUrl: termsUrl ?? this.termsUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      companyName: companyName ?? this.companyName,
      tagline: tagline ?? this.tagline,
    );
  }
}

class EmailTemplateRecord {
  const EmailTemplateRecord({
    required this.id,
    required this.name,
    required this.slug,
    required this.subject,
    this.bodyHtml,
    this.textBody,
    this.category = 'system',
    this.variables = const [],
    this.isSecurity = false,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String subject;
  final String? bodyHtml;
  final String? textBody;
  final String category;
  final List<String> variables;
  final bool isSecurity;
  final bool isActive;

  factory EmailTemplateRecord.fromJson(Map<String, dynamic> json) {
    final vars = json['variables'];
    return EmailTemplateRecord(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      subject: '${json['subject'] ?? ''}',
      bodyHtml: json['body_html'] as String?,
      textBody: json['text_body'] as String?,
      category: '${json['category'] ?? 'system'}',
      variables: vars is List
          ? vars.map((e) => '$e').toList()
          : const <String>[],
      isSecurity: json['is_security'] == true,
      isActive: json['is_active'] != false,
    );
  }
}

class EmailDeliveryRecord {
  const EmailDeliveryRecord({
    required this.id,
    this.userId,
    this.recipientEmail,
    this.templateSlug,
    this.title,
    required this.status,
    this.provider,
    this.providerMessageId,
    this.errorMessage,
    this.attemptCount = 0,
    this.sentAt,
    required this.createdAt,
    this.payload = const {},
  });

  final String id;
  final String? userId;
  final String? recipientEmail;
  final String? templateSlug;
  final String? title;
  final EmailDeliveryStatus status;
  final String? provider;
  final String? providerMessageId;
  final String? errorMessage;
  final int attemptCount;
  final DateTime? sentAt;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  factory EmailDeliveryRecord.fromJson(Map<String, dynamic> json) {
    return EmailDeliveryRecord(
      id: '${json['id']}',
      userId: json['user_id'] as String?,
      recipientEmail: json['recipient_email'] as String?,
      templateSlug: json['template_slug'] as String?,
      title: json['title'] as String?,
      status: EmailDeliveryStatus.fromSlug(json['status'] as String?),
      provider: json['provider'] as String?,
      providerMessageId: json['provider_message_id'] as String?,
      errorMessage: json['error_message'] as String?,
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      sentAt: DateTime.tryParse('${json['sent_at'] ?? ''}'),
      createdAt:
          DateTime.tryParse('${json['created_at']}') ?? DateTime.now().toUtc(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }
}

class EmailSystemStatus {
  const EmailSystemStatus({
    this.brand = const EmailBrandConfig(),
    this.configured = false,
    this.provider = 'resend',
    this.notes = '',
    this.queued = 0,
    this.sent = 0,
    this.failed = 0,
    this.outboxQueued = 0,
    this.templateCount = 0,
    this.lastSentAt,
    this.lastFailedAt,
  });

  final EmailBrandConfig brand;
  final bool configured;
  final String provider;
  final String notes;
  final int queued;
  final int sent;
  final int failed;
  final int outboxQueued;
  final int templateCount;
  final DateTime? lastSentAt;
  final DateTime? lastFailedAt;

  factory EmailSystemStatus.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] is Map
        ? Map<String, dynamic>.from(json['provider'] as Map)
        : const <String, dynamic>{};
    final brand = json['brand'] is Map
        ? EmailBrandConfig.fromJson(Map<String, dynamic>.from(json['brand'] as Map))
        : const EmailBrandConfig();
    return EmailSystemStatus(
      brand: brand,
      configured: provider['configured'] == true,
      provider: '${provider['provider'] ?? 'resend'}',
      notes: '${provider['notes'] ?? ''}',
      queued: (json['queued'] as num?)?.toInt() ?? 0,
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      outboxQueued: (json['outbox_queued'] as num?)?.toInt() ?? 0,
      templateCount: (json['template_count'] as num?)?.toInt() ?? 0,
      lastSentAt: DateTime.tryParse('${json['last_sent_at'] ?? ''}'),
      lastFailedAt: DateTime.tryParse('${json['last_failed_at'] ?? ''}'),
    );
  }
}
