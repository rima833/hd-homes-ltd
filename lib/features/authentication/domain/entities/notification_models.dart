import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';

/// Delivery channels for the Communication Platform.
enum NotificationChannel {
  inApp,
  email,
  sms,
  whatsapp,
  push;

  String get slug => switch (this) {
        NotificationChannel.inApp => 'in_app',
        NotificationChannel.email => 'email',
        NotificationChannel.sms => 'sms',
        NotificationChannel.whatsapp => 'whatsapp',
        NotificationChannel.push => 'push',
      };

  String get label => switch (this) {
        NotificationChannel.inApp => 'In-app',
        NotificationChannel.email => 'Email',
        NotificationChannel.sms => 'SMS',
        NotificationChannel.whatsapp => 'WhatsApp',
        NotificationChannel.push => 'Push',
      };

  bool get enabledInPhase1 =>
      this == NotificationChannel.inApp || this == NotificationChannel.email;

  static NotificationChannel fromSlug(String? raw) {
    return switch ((raw ?? 'in_app').toLowerCase()) {
      'email' => NotificationChannel.email,
      'sms' => NotificationChannel.sms,
      'whatsapp' => NotificationChannel.whatsapp,
      'push' => NotificationChannel.push,
      _ => NotificationChannel.inApp,
    };
  }
}

enum NotificationType {
  information,
  success,
  warning,
  error,
  critical,
  marketing,
  reminder,
  announcement,
  actionRequired;

  String get slug => switch (this) {
        NotificationType.information => 'information',
        NotificationType.success => 'success',
        NotificationType.warning => 'warning',
        NotificationType.error => 'error',
        NotificationType.critical => 'critical',
        NotificationType.marketing => 'marketing',
        NotificationType.reminder => 'reminder',
        NotificationType.announcement => 'announcement',
        NotificationType.actionRequired => 'action_required',
      };

  static NotificationType fromSlug(String? raw) {
    return switch ((raw ?? 'information').toLowerCase()) {
      'success' => NotificationType.success,
      'warning' => NotificationType.warning,
      'error' => NotificationType.error,
      'critical' => NotificationType.critical,
      'marketing' => NotificationType.marketing,
      'reminder' => NotificationType.reminder,
      'announcement' => NotificationType.announcement,
      'action_required' => NotificationType.actionRequired,
      _ => NotificationType.information,
    };
  }
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
  critical;

  String get slug => name;

  int get rank => index;

  bool get bypassesQuietHours =>
      this == NotificationPriority.urgent || this == NotificationPriority.critical;

  static NotificationPriority fromSlug(String? raw) {
    return switch ((raw ?? 'normal').toLowerCase()) {
      'low' => NotificationPriority.low,
      'high' => NotificationPriority.high,
      'urgent' => NotificationPriority.urgent,
      'critical' => NotificationPriority.critical,
      _ => NotificationPriority.normal,
    };
  }
}

enum NotificationCategory {
  account,
  security,
  properties,
  investments,
  bookings,
  payments,
  crm,
  marketing,
  support,
  announcements,
  system,
  aiAssistant,
  kyc;

  String get slug => switch (this) {
        NotificationCategory.aiAssistant => 'ai_assistant',
        _ => name,
      };

  String get label => switch (this) {
        NotificationCategory.account => 'Account',
        NotificationCategory.security => 'Security',
        NotificationCategory.properties => 'Properties',
        NotificationCategory.investments => 'Investments',
        NotificationCategory.bookings => 'Bookings',
        NotificationCategory.payments => 'Payments',
        NotificationCategory.crm => 'CRM',
        NotificationCategory.marketing => 'Marketing',
        NotificationCategory.support => 'Support',
        NotificationCategory.announcements => 'Announcements',
        NotificationCategory.system => 'System',
        NotificationCategory.aiAssistant => 'AI Assistant',
        NotificationCategory.kyc => 'KYC',
      };

  static NotificationCategory fromSlug(String? raw) {
    final s = (raw ?? 'system').toLowerCase();
    for (final c in NotificationCategory.values) {
      if (c.slug == s) return c;
    }
    return NotificationCategory.system;
  }
}

enum DeliveryStatus {
  queued,
  sending,
  delivered,
  read,
  clicked,
  failed,
  retrying,
  expired;

  String get slug => name;

  static DeliveryStatus fromSlug(String? raw) {
    return switch ((raw ?? 'queued').toLowerCase()) {
      'sending' => DeliveryStatus.sending,
      'delivered' => DeliveryStatus.delivered,
      'read' => DeliveryStatus.read,
      'clicked' => DeliveryStatus.clicked,
      'failed' => DeliveryStatus.failed,
      'retrying' => DeliveryStatus.retrying,
      'expired' => DeliveryStatus.expired,
      _ => DeliveryStatus.queued,
    };
  }
}

/// Simple {{variable}} template renderer.
abstract final class NotificationTemplateEngine {
  static String render(String template, Map<String, String> variables) {
    var out = template;
    for (final entry in variables.entries) {
      out = out.replaceAll('{{${entry.key}}}', entry.value);
    }
    // Strip unresolved tokens for safety
    out = out.replaceAll(RegExp(r'\{\{[a-zA-Z0-9_]+\}\}'), '');
    return out.trim();
  }
}

class NotificationTemplate {
  const NotificationTemplate({
    required this.slug,
    required this.titleTemplate,
    required this.bodyTemplate,
    this.category = NotificationCategory.system,
    this.type = NotificationType.information,
    this.defaultChannels = const [NotificationChannel.inApp],
  });

  final String slug;
  final String titleTemplate;
  final String bodyTemplate;
  final NotificationCategory category;
  final NotificationType type;
  final List<NotificationChannel> defaultChannels;

  String title(Map<String, String> vars) =>
      NotificationTemplateEngine.render(titleTemplate, vars);

  String body(Map<String, String> vars) =>
      NotificationTemplateEngine.render(bodyTemplate, vars);
}

/// Built-in templates (Admin Panel can override via DB later).
abstract final class NotificationTemplateCatalog {
  static const welcome = NotificationTemplate(
    slug: 'welcome',
    titleTemplate: 'Welcome to HD Homes, {{first_name}}',
    bodyTemplate:
        'Your account is ready. Complete your profile to unlock personalized property recommendations.',
    category: NotificationCategory.account,
    type: NotificationType.success,
    defaultChannels: [NotificationChannel.inApp, NotificationChannel.email],
  );

  static const kycApproved = NotificationTemplate(
    slug: 'kyc_approved',
    titleTemplate: 'Identity verified',
    bodyTemplate:
        'Congratulations {{first_name}} — your KYC is approved. Status: {{verification_status}}.',
    category: NotificationCategory.kyc,
    type: NotificationType.success,
  );

  static const securityAlert = NotificationTemplate(
    slug: 'security_alert',
    titleTemplate: 'Security alert',
    bodyTemplate: '{{message}}',
    category: NotificationCategory.security,
    type: NotificationType.critical,
    defaultChannels: [
      NotificationChannel.inApp,
      NotificationChannel.email,
      NotificationChannel.sms,
    ],
  );

  static const bookingConfirmed = NotificationTemplate(
    slug: 'booking_confirmed',
    titleTemplate: 'Booking confirmed',
    bodyTemplate:
        'Your booking {{booking_reference}} for {{property_name}} is confirmed.',
    category: NotificationCategory.bookings,
    type: NotificationType.success,
  );

  static const paymentSuccessful = NotificationTemplate(
    slug: 'payment_successful',
    titleTemplate: 'Payment received',
    bodyTemplate: 'We received {{payment_amount}} for {{property_name}}.',
    category: NotificationCategory.payments,
    type: NotificationType.success,
  );

  static const announcement = NotificationTemplate(
    slug: 'announcement',
    titleTemplate: '{{title}}',
    bodyTemplate: '{{body}}',
    category: NotificationCategory.announcements,
    type: NotificationType.announcement,
  );

  static NotificationTemplate? bySlug(String slug) {
    const all = [
      welcome,
      kycApproved,
      securityAlert,
      bookingConfirmed,
      paymentSuccessful,
      announcement,
    ];
    for (final t in all) {
      if (t.slug == slug) return t;
    }
    return null;
  }
}

class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.startHour = 22,
    this.endHour = 7,
    this.timezone = 'Africa/Lagos',
  });

  final bool enabled;
  final int startHour;
  final int endHour;
  final String timezone;

  bool isQuiet(DateTime now) {
    if (!enabled) return false;
    final hour = now.hour;
    if (startHour == endHour) return false;
    if (startHour < endHour) {
      return hour >= startHour && hour < endHour;
    }
    // Wraps midnight
    return hour >= startHour || hour < endHour;
  }

  factory QuietHours.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const QuietHours();
    return QuietHours(
      enabled: json['enabled'] as bool? ?? false,
      startHour: json['start_hour'] as int? ?? 22,
      endHour: json['end_hour'] as int? ?? 7,
      timezone: json['timezone'] as String? ?? 'Africa/Lagos',
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'start_hour': startHour,
        'end_hour': endHour,
        'timezone': timezone,
      };
}

class CommunicationChannelPrefs {
  const CommunicationChannelPrefs({
    this.inApp = true,
    this.email = true,
    this.sms = false,
    this.whatsapp = false,
    this.push = true,
    this.marketing = false,
    this.securityAlerts = true,
    this.quietHours = const QuietHours(),
  });

  final bool inApp;
  final bool email;
  final bool sms;
  final bool whatsapp;
  final bool push;
  final bool marketing;
  final bool securityAlerts;
  final QuietHours quietHours;

  bool allows(NotificationChannel channel) => switch (channel) {
        NotificationChannel.inApp => inApp,
        NotificationChannel.email => email,
        NotificationChannel.sms => sms,
        NotificationChannel.whatsapp => whatsapp,
        NotificationChannel.push => push,
      };

  CommunicationChannelPrefs copyWith({
    bool? inApp,
    bool? email,
    bool? sms,
    bool? whatsapp,
    bool? push,
    bool? marketing,
    bool? securityAlerts,
    QuietHours? quietHours,
  }) {
    return CommunicationChannelPrefs(
      inApp: inApp ?? this.inApp,
      email: email ?? this.email,
      sms: sms ?? this.sms,
      whatsapp: whatsapp ?? this.whatsapp,
      push: push ?? this.push,
      marketing: marketing ?? this.marketing,
      securityAlerts: securityAlerts ?? this.securityAlerts,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  Map<String, dynamic> toUpsertMap(String userId) => {
        'user_id': userId,
        'email_enabled': email,
        'sms_enabled': sms,
        'push_enabled': push,
        'marketing_email': marketing,
        'security_alerts': securityAlerts,
        'extras': {
          'in_app': inApp,
          'whatsapp': whatsapp,
          'quiet_hours': quietHours.toJson(),
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory CommunicationChannelPrefs.fromNotificationPrefsJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) return const CommunicationChannelPrefs();
    final extras = Map<String, dynamic>.from(
      (json['extras'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    return CommunicationChannelPrefs(
      email: json['email_enabled'] as bool? ?? true,
      sms: json['sms_enabled'] as bool? ?? false,
      push: json['push_enabled'] as bool? ?? true,
      marketing: json['marketing_email'] as bool? ?? false,
      securityAlerts: json['security_alerts'] as bool? ?? true,
      inApp: extras['in_app'] as bool? ?? true,
      whatsapp: extras['whatsapp'] as bool? ?? false,
      quietHours: QuietHours.fromJson(
        (extras['quiet_hours'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

/// Smart Communication Orchestrator™ decision.
class OrchestrationPlan {
  const OrchestrationPlan({
    required this.channels,
    required this.sendImmediately,
    this.deferUntil,
    this.reason = 'ok',
  });

  final List<NotificationChannel> channels;
  final bool sendImmediately;
  final DateTime? deferUntil;
  final String reason;
}

abstract final class SmartCommunicationOrchestrator {
  static OrchestrationPlan plan({
    required List<NotificationChannel> requested,
    required CommunicationChannelPrefs prefs,
    required NotificationPriority priority,
    required NotificationType type,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final channels = <NotificationChannel>[];

    for (final channel in requested) {
      if (!channel.enabledInPhase1 && channel != NotificationChannel.sms) {
        // Phase 1: queue email/in-app; others logged as future.
        if (channel == NotificationChannel.email ||
            channel == NotificationChannel.inApp) {
          // continue
        } else {
          continue;
        }
      }

      if (type == NotificationType.marketing && !prefs.marketing) continue;
      if (type == NotificationType.critical ||
          priority.bypassesQuietHours ||
          prefs.securityAlerts && type == NotificationType.critical) {
        if (prefs.allows(channel) || priority.bypassesQuietHours) {
          channels.add(channel);
        }
        continue;
      }

      if (prefs.allows(channel)) {
        channels.add(channel);
      }
    }

    if (channels.isEmpty && prefs.inApp) {
      channels.add(NotificationChannel.inApp);
    }

    final quiet = prefs.quietHours.isQuiet(at) && !priority.bypassesQuietHours;
    if (quiet) {
      final tomorrow = DateTime(at.year, at.month, at.day + 1, prefs.quietHours.endHour);
      return OrchestrationPlan(
        channels: channels,
        sendImmediately: false,
        deferUntil: tomorrow,
        reason: 'quiet_hours',
      );
    }

    return OrchestrationPlan(
      channels: channels,
      sendImmediately: true,
      reason: 'immediate',
    );
  }

  static List<NotificationChannel> channelsForRole(AppRole? role) {
    return const [NotificationChannel.inApp, NotificationChannel.email];
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.category,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.actionUrl,
    this.isRead = false,
    this.isPinned = false,
    this.isArchived = false,
    this.templateSlug,
    this.metadata = const {},
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationCategory category;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime createdAt;
  final String? actionUrl;
  final bool isRead;
  final bool isPinned;
  final bool isArchived;
  final String? templateSlug;
  final Map<String, dynamic> metadata;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: NotificationCategory.fromSlug(json['category'] as String?),
      type: NotificationType.fromSlug(json['type'] as String?),
      priority: NotificationPriority.fromSlug(json['priority'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      actionUrl: json['action_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      templateSlug: json['template_slug'] as String?,
      metadata: Map<String, dynamic>.from(
        (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }
}

class AnnouncementPost {
  const AnnouncementPost({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.targetAudience = 'everyone',
    this.published = false,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String targetAudience;
  final bool published;
  final DateTime? publishedAt;

  factory AnnouncementPost.fromJson(Map<String, dynamic> json) {
    return AnnouncementPost(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      targetAudience: json['target_audience'] as String? ?? 'everyone',
      published: json['published'] as bool? ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
    );
  }
}

class CommunicationDispatchRequest {
  const CommunicationDispatchRequest({
    required this.userId,
    required this.templateSlug,
    this.variables = const {},
    this.channels,
    this.priority = NotificationPriority.normal,
    this.actionUrl,
    this.metadata = const {},
  });

  final String userId;
  final String templateSlug;
  final Map<String, String> variables;
  final List<NotificationChannel>? channels;
  final NotificationPriority priority;
  final String? actionUrl;
  final Map<String, dynamic> metadata;
}

class NotificationCenterSnapshot {
  const NotificationCenterSnapshot({
    required this.items,
    required this.unreadCount,
    required this.prefs,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final CommunicationChannelPrefs prefs;
}
