import 'package:intl/intl.dart';

/// Client portal domain models — Volume 3 Client Portal.

Map<String, dynamic> _clientAsMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _clientRelationList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map(_clientAsMap).where((m) => m.isNotEmpty).toList();
  }
  final single = _clientAsMap(value);
  return single.isEmpty ? const [] : [single];
}

Map<String, dynamic>? _clientFirstRelationMap(dynamic value) {
  final list = _clientRelationList(value);
  return list.isEmpty ? null : list.first;
}

String? _clientRelationTitle(dynamic value) {
  return _clientFirstRelationMap(value)?['title'] as String?;
}

class ClientRecord {
  const ClientRecord({
    required this.id,
    this.userId,
    this.clientCode,
    this.assignedSalesId,
    this.status = 'active',
  });

  factory ClientRecord.fromJson(Map<String, dynamic> json) => ClientRecord(
    id: json['id'] as String,
    userId: json['user_id'] as String?,
    clientCode: json['client_code'] as String?,
    assignedSalesId: json['assigned_sales_id'] as String?,
    status: json['status'] as String? ?? 'active',
  );

  final String id;
  final String? userId;
  final String? clientCode;
  final String? assignedSalesId;
  final String status;
}

class ClientProperty {
  const ClientProperty({
    required this.id,
    required this.clientId,
    required this.propertyId,
    required this.title,
    this.slug,
    this.imageUrl,
    this.location,
    this.purchaseDate,
    this.purchasePrice,
    this.currency = 'NGN',
    this.paymentProgressPct = 0,
    this.constructionProgressPct = 0,
    this.allocationStatus = 'pending',
    this.relationshipManagerName,
    this.brochureUrl,
    this.status = 'active',
    this.propertyCode,
    this.propertyType,
    this.bedrooms,
    this.photoCount = 0,
    this.nextDueDate,
    this.installmentCount = 0,
    this.paymentPlanCode,
  });

  factory ClientProperty.fromJson(Map<String, dynamic> json) {
    final property = _clientAsMap(json['properties']);
    final loc = _clientFirstRelationMap(property['property_locations']);
    final images = _clientRelationList(property['property_images']);
    String? cover;
    for (final m in images) {
      if (m['is_cover'] == true) {
        cover = m['url'] as String?;
        break;
      }
    }
    cover ??= images.isNotEmpty ? images.first['url'] as String? : null;
    final priceRow = _clientFirstRelationMap(property['property_pricing']);

    final city = loc?['city'] as String? ?? property['city'] as String?;
    final state = loc?['state'] as String? ?? property['state'] as String?;
    final location = [
      city,
      state,
    ].whereType<String>().where((v) => v.isNotEmpty).join(', ');

    return ClientProperty(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      propertyId: json['property_id'] as String,
      title: property['title'] as String? ?? 'Property',
      slug: property['slug'] as String?,
      imageUrl: cover,
      location: location.isEmpty ? null : location,
      purchaseDate: json['purchase_date'] != null
          ? DateTime.tryParse(json['purchase_date'] as String)
          : null,
      purchasePrice:
          (json['purchase_price'] as num?)?.toDouble() ??
          (priceRow?['price'] as num?)?.toDouble() ??
          (property['listing_price'] as num?)?.toDouble(),
      currency:
          json['currency'] as String? ??
          property['currency'] as String? ??
          'NGN',
      paymentProgressPct:
          (json['payment_progress_pct'] as num?)?.toDouble() ?? 0,
      constructionProgressPct:
          (json['construction_progress_pct'] as num?)?.toDouble() ?? 0,
      allocationStatus: json['allocation_status'] as String? ?? 'pending',
      brochureUrl: json['brochure_url'] as String?,
      status: json['status'] as String? ?? 'active',
      propertyCode: property['property_code'] as String?,
      propertyType: property['category_slug'] as String?,
      bedrooms: (property['bedrooms'] as num?)?.toInt(),
      photoCount: images.length,
    );
  }

  final String id;
  final String clientId;
  final String propertyId;
  final String title;
  final String? slug;
  final String? imageUrl;
  final String? location;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String currency;
  final double paymentProgressPct;
  final double constructionProgressPct;
  final String allocationStatus;
  final String? relationshipManagerName;
  final String? brochureUrl;
  final String status;
  final String? propertyCode;
  final String? propertyType;
  final int? bedrooms;
  final int photoCount;
  final DateTime? nextDueDate;
  final int installmentCount;
  final String? paymentPlanCode;

  ClientProperty copyWith({
    DateTime? nextDueDate,
    int? installmentCount,
    String? paymentPlanCode,
    double? paymentProgressPct,
    double? constructionProgressPct,
  }) => ClientProperty(
    id: id,
    clientId: clientId,
    propertyId: propertyId,
    title: title,
    slug: slug,
    imageUrl: imageUrl,
    location: location,
    purchaseDate: purchaseDate,
    purchasePrice: purchasePrice,
    currency: currency,
    paymentProgressPct: paymentProgressPct ?? this.paymentProgressPct,
    constructionProgressPct:
        constructionProgressPct ?? this.constructionProgressPct,
    allocationStatus: allocationStatus,
    relationshipManagerName: relationshipManagerName,
    brochureUrl: brochureUrl,
    status: status,
    propertyCode: propertyCode,
    propertyType: propertyType,
    bedrooms: bedrooms,
    photoCount: photoCount,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    installmentCount: installmentCount ?? this.installmentCount,
    paymentPlanCode: paymentPlanCode ?? this.paymentPlanCode,
  );

  String get formattedPrice {
    if (purchasePrice == null) return '—';
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    return fmt.format(purchasePrice);
  }

  double get amountPaid {
    if (purchasePrice == null) return 0;
    return purchasePrice! * (paymentProgressPct.clamp(0, 100) / 100);
  }

  String get formattedAmountPaid {
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    return fmt.format(amountPaid);
  }

  String get constructionPhaseLabel {
    final pct = constructionProgressPct;
    if (pct <= 0) return 'Not started';
    if (pct >= 100) return 'Completed';
    return 'In Progress';
  }

  String get constructionStatusLabel {
    if (allocationStatus == 'handed_over') return 'Handed Over';
    if (allocationStatus == 'handover_pending') return 'Handover Pending';
    if (constructionProgressPct >= 100) return 'Completed';
    if (constructionProgressPct > 0) return 'Under Construction';
    return 'Not started';
  }

  String get displayBadgeLabel {
    if (allocationStatus == 'handed_over') return 'Completed';
    if (allocationStatus == 'handover_pending') return 'Almost home';
    if (status.isEmpty) return 'Active';
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  bool get isFullyPaid => paymentProgressPct >= 100;
  bool get isHandedOver => allocationStatus == 'handed_over';
  bool get isNearHandover =>
      allocationStatus == 'handover_pending' ||
      (isFullyPaid && constructionProgressPct >= 100);

  String get celebrationMessage {
    if (isHandedOver) {
      return 'Congratulations! Handover is complete — welcome home. We’re so happy for you!';
    }
    if (allocationStatus == 'handover_pending') {
      return 'Exciting news — your property is being prepared for handover. You’re nearly home!';
    }
    if (isFullyPaid && constructionProgressPct >= 100) {
      return 'Payments and construction are complete. Handover is next — almost there!';
    }
    if (isFullyPaid) {
      return 'You’re fully paid up — fantastic! Construction progress continues below.';
    }
    return '';
  }

  /// Outright vs installment-friendly label for the card.
  String get paymentStyleLabel {
    final plan = (paymentPlanCode ?? '').toLowerCase();
    if (plan.contains('outright') || plan == 'full' || plan == 'once') {
      return 'Pay once';
    }
    if (installmentCount > 1 ||
        plan.contains('month') ||
        plan.contains('install')) {
      return 'Pay in installments';
    }
    if (isFullyPaid) return 'Paid in full';
    if (paymentProgressPct > 0 && paymentProgressPct < 100) {
      return 'Paying gradually';
    }
    return 'Payment plan';
  }

  String get unitLabel {
    if (bedrooms == null) return '—';
    return '$bedrooms Bedroom';
  }

  String get typeLabel {
    final raw = propertyType;
    if (raw == null || raw.isEmpty) return 'Property';
    return raw
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class ClientPayment {
  const ClientPayment({
    required this.id,
    required this.amount,
    this.currency = 'NGN',
    this.paymentMethod,
    this.provider,
    this.providerReference,
    this.paidAt,
    this.status = 'pending',
    this.propertyTitle,
    this.propertyId,
  });

  factory ClientPayment.fromJson(Map<String, dynamic> json) => ClientPayment(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'NGN',
    paymentMethod: json['payment_method'] as String?,
    provider: json['payment_provider'] as String?,
    providerReference: json['provider_reference'] as String?,
    paidAt: json['paid_at'] != null
        ? DateTime.tryParse(json['paid_at'] as String)
        : null,
    status: json['status'] as String? ?? 'pending',
    propertyTitle: _clientRelationTitle(json['properties']),
    propertyId: json['property_id'] as String?,
  );

  final String id;
  final double amount;
  final String currency;
  final String? paymentMethod;
  final String? provider;
  final String? providerReference;
  final DateTime? paidAt;
  final String status;
  final String? propertyTitle;
  final String? propertyId;

  bool get isVerified =>
      status == 'completed' ||
      status == 'paid' ||
      status == 'success' ||
      status == 'verified';

  String get formattedAmount =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount);
}

class ClientInstallment {
  const ClientInstallment({
    required this.id,
    required this.amount,
    required this.dueDate,
    this.paidAt,
    this.status = 'pending',
    this.propertyTitle,
    this.propertyId,
    this.amountPaid = 0,
    this.amountOutstanding,
  });

  factory ClientInstallment.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num).toDouble();
    final paid = (json['amount_paid'] as num?)?.toDouble() ?? 0;
    final outstanding = (json['amount_outstanding'] as num?)?.toDouble();
    return ClientInstallment(
      id: json['id'] as String,
      amount: amount,
      dueDate: DateTime.parse(json['due_date'] as String),
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
      propertyTitle: _clientRelationTitle(json['properties']),
      propertyId: json['property_id'] as String?,
      amountPaid: paid,
      amountOutstanding: outstanding ?? (amount - paid).clamp(0, amount),
    );
  }

  final String id;
  final double amount;
  final DateTime dueDate;
  final DateTime? paidAt;
  final String status;
  final String? propertyTitle;
  final String? propertyId;
  final double amountPaid;
  final double? amountOutstanding;

  /// Remaining amount due for this installment (server-authoritative when set).
  double get payableAmount {
    final o = amountOutstanding;
    if (o != null) return o < 0 ? 0 : o;
    final rem = amount - amountPaid;
    return rem < 0 ? 0 : rem;
  }

  bool get isPayable =>
      status != 'paid' &&
      status != 'completed' &&
      status != 'cancelled' &&
      status != 'waived' &&
      payableAmount > 0;

  String get formattedAmount =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(amount);

  String get formattedPayable => NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
  ).format(payableAmount);
}

class ClientDocument {
  const ClientDocument({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.documentType,
    this.createdAt,
    this.applicationId,
    this.propertyId,
    this.reviewStatus = 'uploaded',
    this.fileName,
  });

  factory ClientDocument.fromJson(Map<String, dynamic> json) => ClientDocument(
    id: json['id'] as String,
    title: json['title'] as String,
    fileUrl: json['file_url'] as String,
    documentType: json['document_type'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
    applicationId: json['application_id'] as String?,
    propertyId: json['property_id'] as String?,
    reviewStatus: json['review_status'] as String? ?? 'uploaded',
    fileName: json['file_name'] as String?,
  );

  final String id;
  final String title;
  final String fileUrl;
  final String? documentType;
  final DateTime? createdAt;
  final String? applicationId;
  final String? propertyId;
  final String reviewStatus;
  final String? fileName;
}

class ClientConstructionUpdate {
  const ClientConstructionUpdate({
    required this.id,
    required this.title,
    this.description,
    this.completionPercent,
    this.updateDate,
    this.projectName,
    this.photos = const [],
  });

  factory ClientConstructionUpdate.fromJson(Map<String, dynamic> json) {
    final project = _clientFirstRelationMap(json['projects']);
    final photosRaw = _clientRelationList(json['construction_photos']);
    return ClientConstructionUpdate(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      completionPercent: (json['completion_percent'] as num?)?.toDouble(),
      updateDate: json['update_date'] != null
          ? DateTime.tryParse(json['update_date'] as String)
          : null,
      projectName: project?['name'] as String?,
      photos: photosRaw
          .map((e) => e['url'] as String?)
          .whereType<String>()
          .toList(),
    );
  }

  final String id;
  final String title;
  final String? description;
  final double? completionPercent;
  final DateTime? updateDate;
  final String? projectName;
  final List<String> photos;
}

class ClientInspection {
  const ClientInspection({
    required this.id,
    required this.propertyId,
    required this.scheduledAt,
    this.propertyTitle,
    this.notes,
    this.status = 'scheduled',
    this.inspectionType = 'site_visit',
    this.meetingUrl,
    this.reference,
  });

  factory ClientInspection.fromJson(Map<String, dynamic> json) =>
      ClientInspection(
        id: json['id'] as String,
        propertyId: json['property_id'] as String,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        propertyTitle: _clientRelationTitle(json['properties']),
        notes: json['report_summary'] as String? ?? json['notes'] as String?,
        status: json['status'] as String? ?? 'scheduled',
        inspectionType: json['inspection_type'] as String? ?? 'site_visit',
        meetingUrl: json['meeting_url'] as String?,
        reference: json['reference'] as String?,
      );

  final String id;
  final String propertyId;
  final DateTime scheduledAt;
  final String? propertyTitle;
  final String? notes;
  final String status;
  final String inspectionType;
  final String? meetingUrl;
  final String? reference;
}

class ClientTimelineEvent {
  const ClientTimelineEvent({
    required this.id,
    required this.eventType,
    required this.title,
    this.body,
    required this.occurredAt,
  });

  factory ClientTimelineEvent.fromJson(Map<String, dynamic> json) =>
      ClientTimelineEvent(
        id: json['id'] as String,
        eventType: json['event_type'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
      );

  final String id;
  final String eventType;
  final String title;
  final String? body;
  final DateTime occurredAt;
}

class ClientConversation {
  const ClientConversation({
    required this.id,
    required this.subject,
    required this.category,
    this.lastMessageAt,
    this.status = 'open',
    this.assignedStaffId,
    this.assignedStaffName,
    this.clientDisplayName,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.staffTypingAt,
    this.clientTypingAt,
  });

  factory ClientConversation.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    DateTime? staffTypingAt;
    DateTime? clientTypingAt;
    if (meta is Map) {
      final staffRaw = meta['staff_typing_at'];
      if (staffRaw != null && staffRaw.toString() != 'null') {
        staffTypingAt = DateTime.tryParse(staffRaw.toString());
      }
      final clientRaw = meta['client_typing_at'];
      if (clientRaw != null && clientRaw.toString() != 'null') {
        clientTypingAt = DateTime.tryParse(clientRaw.toString());
      }
    }
    String? staffName;
    final prof = json['profiles'];
    if (prof is Map) {
      staffName =
          prof['preferred_name'] as String? ??
          _joinName(prof['first_name'], prof['last_name']);
    }
    String? clientDisplayName;
    final clients = json['clients'];
    if (clients is Map) {
      final clientProf = clients['profiles'];
      if (clientProf is Map) {
        final preferred = (clientProf['preferred_name'] as String?)?.trim();
        clientDisplayName = (preferred != null && preferred.isNotEmpty)
            ? preferred
            : _joinName(clientProf['first_name'], clientProf['last_name']);
      }
      clientDisplayName ??= (clients['client_code'] as String?)?.trim();
    }
    return ClientConversation(
      id: json['id'] as String,
      subject: json['subject'] as String,
      category: json['category'] as String? ?? 'support',
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      status: json['status'] as String? ?? 'open',
      assignedStaffId: json['assigned_staff_id'] as String?,
      assignedStaffName: staffName,
      clientDisplayName: clientDisplayName,
      lastMessagePreview: json['last_message_preview'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      staffTypingAt: staffTypingAt,
      clientTypingAt: clientTypingAt,
    );
  }

  static String? _joinName(dynamic first, dynamic last) {
    final f = (first as String?)?.trim() ?? '';
    final l = (last as String?)?.trim() ?? '';
    final n = '$f $l'.trim();
    return n.isEmpty ? null : n;
  }

  final String id;
  final String subject;
  final String category;
  final DateTime? lastMessageAt;
  final String status;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final String? clientDisplayName;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime? staffTypingAt;
  final DateTime? clientTypingAt;

  String get listTitle {
    final name = clientDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final subj = subject.trim();
    if (subj.isNotEmpty) return subj;
    return teamLabel;
  }

  String get teamLabel => switch (category) {
    'sales' => 'Sales Team',
    'support' => 'Support Team',
    'finance' => 'Finance Team',
    'legal' => 'Legal Team',
    'manager' => 'Account Manager',
    _ =>
      category.isEmpty
          ? 'HD Homes Team'
          : '${category[0].toUpperCase()}${category.substring(1)} Team',
  };

  String get avatarInitial {
    final label = teamLabel.trim();
    return label.isEmpty ? 'H' : label[0].toUpperCase();
  }

  bool get staffIsTyping {
    if (staffTypingAt == null) return false;
    return DateTime.now().difference(staffTypingAt!) <
        const Duration(seconds: 4);
  }

  bool get clientIsTyping {
    if (clientTypingAt == null) return false;
    return DateTime.now().difference(clientTypingAt!) <
        const Duration(seconds: 4);
  }
}

class ClientMessage {
  const ClientMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.isMine = false,
    this.senderName,
  });

  factory ClientMessage.fromJson(Map<String, dynamic> json, {String? userId}) =>
      ClientMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] != null
            ? DateTime.tryParse(json['read_at'] as String)
            : null,
        isMine: userId != null && json['sender_id'] == userId,
        senderName: json['sender_name'] as String?,
      );

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMine;
  final String? senderName;

  bool get isRead => readAt != null;
}

class ClientSupportTicket {
  const ClientSupportTicket({
    required this.id,
    required this.subject,
    this.description,
    this.status = 'open',
    this.priority = 'normal',
    this.ticketNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory ClientSupportTicket.fromJson(Map<String, dynamic> json) =>
      ClientSupportTicket(
        id: json['id'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String?,
        status: json['status'] as String? ?? 'open',
        priority: json['priority'] as String? ?? 'normal',
        ticketNumber: json['ticket_number'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  final String id;
  final String subject;
  final String? description;
  final String status;
  final String priority;
  final String? ticketNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class ClientTicketMessage {
  const ClientTicketMessage({
    required this.id,
    required this.ticketId,
    required this.message,
    this.senderId,
    this.senderName,
    this.senderType = 'customer',
    this.createdAt,
    this.isMine = false,
  });

  factory ClientTicketMessage.fromJson(
    Map<String, dynamic> json, {
    String? userId,
  }) => ClientTicketMessage(
    id: json['id'] as String,
    ticketId: json['ticket_id'] as String,
    message: json['message'] as String,
    senderId: json['sender_id'] as String?,
    senderName: json['sender_name'] as String?,
    senderType: json['sender_type'] as String? ?? 'customer',
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
    isMine: userId != null && json['sender_id'] == userId,
  );

  final String id;
  final String ticketId;
  final String message;
  final String? senderId;
  final String? senderName;
  final String senderType;
  final DateTime? createdAt;
  final bool isMine;
}

class ClientPropertyApplication {
  const ClientPropertyApplication({
    required this.id,
    required this.propertyId,
    this.propertyTitle,
    this.propertyLocation,
    this.propertyType,
    this.propertyPrice,
    this.propertyImageUrl,
    this.amountOffered,
    this.paymentPlan,
    this.notes,
    this.status = 'draft',
    this.createdAt,
    this.updatedAt,
    this.clientId,
  });

  factory ClientPropertyApplication.fromJson(Map<String, dynamic> json) {
    final property = _clientAsMap(json['properties']);
    final loc = _clientFirstRelationMap(property['property_locations']);
    final priceRow = _clientFirstRelationMap(property['property_pricing']);
    final images = _clientRelationList(property['property_images']);
    String? cover;
    for (final m in images) {
      if (m['is_cover'] == true) {
        cover = m['url'] as String?;
        break;
      }
    }
    cover ??= images.isNotEmpty ? images.first['url'] as String? : null;

    return ClientPropertyApplication(
      id: json['id'] as String,
      clientId: json['client_id'] as String?,
      propertyId: json['property_id'] as String,
      propertyTitle: property['title'] as String?,
      propertyType:
          property['category_slug'] as String? ??
          property['category_id'] as String?,
      propertyPrice:
          (priceRow?['price'] as num?)?.toDouble() ??
          (property['listing_price'] as num?)?.toDouble(),
      propertyImageUrl: cover,
      propertyLocation: [
        loc?['city'],
        loc?['state'],
      ].whereType<String>().where((v) => v.isNotEmpty).join(', '),
      amountOffered: (json['amount_offered'] as num?)?.toDouble(),
      paymentPlan: json['payment_plan'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String? clientId;
  final String propertyId;
  final String? propertyTitle;
  final String? propertyLocation;
  final String? propertyType;
  final double? propertyPrice;
  final String? propertyImageUrl;
  final double? amountOffered;
  final String? paymentPlan;
  final String? notes;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get shortId {
    final raw = id.replaceAll('-', '').toUpperCase();
    return 'APP-${raw.substring(0, 8)}';
  }

  String get formattedOffer {
    if (amountOffered == null) return '—';
    return NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 0,
    ).format(amountOffered);
  }

  String get formattedPrice {
    if (propertyPrice == null) return '—';
    return NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 0,
    ).format(propertyPrice);
  }

  String get paymentPlanLabel => (paymentPlan ?? '—').replaceAll('_', ' ');

  /// Ordered client-visible journey stages.
  static const timelineStages = <String>[
    'submitted',
    'under_review',
    'documents_required',
    'approved',
    'payment_pending',
    'contract_pending',
    'completed',
  ];

  int get timelineStepIndex {
    final normalized = status.toLowerCase();
    if (normalized == 'draft') return -1;
    if (normalized == 'cancelled' || normalized == 'rejected') return -2;
    if (normalized == 'payment_active') {
      return timelineStages.indexOf('payment_pending');
    }
    final idx = timelineStages.indexOf(normalized);
    return idx < 0 ? 0 : idx;
  }

  static String statusLabel(String status) {
    return switch (status.toLowerCase()) {
      'draft' => 'Draft',
      'submitted' => 'Submitted',
      'under_review' => 'Under Review',
      'documents_required' => 'Documents Required',
      'approved' => 'Approved',
      'payment_pending' => 'Payment Pending',
      'payment_active' => 'Payment Active',
      'contract_pending' => 'Contract Pending',
      'completed' => 'Completed',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => status.replaceAll('_', ' '),
    };
  }
}

class ClientApplicationPropertyOption {
  const ClientApplicationPropertyOption({
    required this.propertyId,
    required this.title,
    this.location,
    this.propertyType,
    this.bedrooms,
    this.price,
    this.imageUrl,
    this.availability,
  });

  factory ClientApplicationPropertyOption.fromPropertyJson(
    Map<String, dynamic> json,
  ) {
    final loc = _clientFirstRelationMap(json['property_locations']);
    final location = [
      loc?['city'],
      loc?['state'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(', ');
    final priceRow = _clientFirstRelationMap(json['property_pricing']);
    final images = _clientRelationList(json['property_images']);
    String? cover;
    for (final m in images) {
      if (m['is_cover'] == true) {
        cover = m['url'] as String?;
        break;
      }
    }
    cover ??= images.isNotEmpty ? images.first['url'] as String? : null;

    return ClientApplicationPropertyOption(
      propertyId: json['id'] as String,
      title: (json['title'] as String?) ?? 'Property',
      location: location.isEmpty ? null : location,
      propertyType: json['category_slug'] as String?,
      bedrooms: (json['bedrooms'] as num?)?.toInt(),
      price:
          (priceRow?['price'] as num?)?.toDouble() ??
          (json['listing_price'] as num?)?.toDouble(),
      imageUrl: cover,
      availability:
          json['inventory_status'] as String? ??
          json['marketing_status'] as String? ??
          json['status'] as String?,
    );
  }

  final String propertyId;
  final String title;
  final String? location;
  final String? propertyType;
  final int? bedrooms;
  final double? price;
  final String? imageUrl;
  final String? availability;

  String get formattedPrice {
    if (price == null) return '—';
    return NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(price);
  }
}

class ApplicationPaymentPlan {
  const ApplicationPaymentPlan({
    required this.code,
    required this.name,
    this.description,
    this.installmentMonths,
    this.initialDepositPercent,
  });

  factory ApplicationPaymentPlan.fromJson(Map<String, dynamic> json) =>
      ApplicationPaymentPlan(
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        installmentMonths: (json['installment_months'] as num?)?.toInt(),
        initialDepositPercent: (json['initial_deposit_percent'] as num?)
            ?.toDouble(),
      );

  final String code;
  final String name;
  final String? description;
  final int? installmentMonths;
  final double? initialDepositPercent;
}

class ApplicationRequiredDocumentType {
  const ApplicationRequiredDocumentType({
    required this.code,
    required this.name,
    this.description,
    this.isRequired = true,
  });

  factory ApplicationRequiredDocumentType.fromJson(Map<String, dynamic> json) =>
      ApplicationRequiredDocumentType(
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        isRequired: json['is_required'] as bool? ?? true,
      );

  final String code;
  final String name;
  final String? description;
  final bool isRequired;
}

class ClientReferralSummary {
  const ClientReferralSummary({
    this.referralCode = '',
    this.pendingEarnings = 0,
    this.paidEarnings = 0,
    this.commissions = const [],
  });

  final String referralCode;
  final double pendingEarnings;
  final double paidEarnings;
  final List<ClientReferralCommission> commissions;
}

class ClientReferralCommission {
  const ClientReferralCommission({
    required this.id,
    required this.amount,
    this.referralCode,
    this.status = 'pending',
    this.paidAt,
  });

  factory ClientReferralCommission.fromJson(Map<String, dynamic> json) =>
      ClientReferralCommission(
        id: json['id'] as String,
        amount: (json['commission_amount'] as num).toDouble(),
        referralCode: json['referral_code'] as String?,
        status: json['status'] as String? ?? 'pending',
        paidAt: json['paid_at'] != null
            ? DateTime.tryParse(json['paid_at'] as String)
            : null,
      );

  final String id;
  final double amount;
  final String? referralCode;
  final String status;
  final DateTime? paidAt;
}

class ClientDashboardSnapshot {
  const ClientDashboardSnapshot({
    required this.client,
    this.displayName = 'Client',
    this.propertiesCount = 0,
    this.outstandingBalance = 0,
    this.totalPaid = 0,
    this.upcomingInspections = 0,
    this.unreadNotifications = 0,
    this.accountCompletionPct = 72,
    this.properties = const [],
    this.recentTimeline = const [],
    this.recentDocuments = const [],
    this.upcomingInstallments = const [],
    this.constructionProgress = const [],
    this.paymentHistory = const [],
    this.loadedAt,
  });

  final ClientRecord client;
  final String displayName;
  final int propertiesCount;
  final double outstandingBalance;
  final double totalPaid;
  final int upcomingInspections;
  final int unreadNotifications;
  final double accountCompletionPct;
  final List<ClientProperty> properties;
  final List<ClientTimelineEvent> recentTimeline;
  final List<ClientDocument> recentDocuments;
  final List<ClientInstallment> upcomingInstallments;
  final List<ClientProperty> constructionProgress;
  final List<ClientPayment> paymentHistory;
  final DateTime? loadedAt;

  String get formattedOutstanding => NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
  ).format(outstandingBalance);

  String get formattedTotalPaid =>
      NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(totalPaid);
}
