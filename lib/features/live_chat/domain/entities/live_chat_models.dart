/// Public visitor ↔ admin live chat models (Supabase `live_chat_*`).
library;

/// Whether any support agent is heartbeating as available/busy.
class LiveChatSupportPresence {
  const LiveChatSupportPresence({required this.online, this.agentsPresent = 0});

  final bool online;
  final int agentsPresent;
}

class LiveChatAttachment {
  const LiveChatAttachment({
    required this.name,
    required this.url,
    this.mimeType,
    this.sizeBytes,
  });

  final String name;
  final String url;
  final String? mimeType;
  final int? sizeBytes;

  bool get isImage =>
      (mimeType ?? '').startsWith('image/') ||
      RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(name);

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    if (mimeType != null) 'mime': mimeType,
    if (sizeBytes != null) 'size': sizeBytes,
  };

  factory LiveChatAttachment.fromJson(Map<String, dynamic> json) {
    return LiveChatAttachment(
      name: json['name'] as String? ?? 'file',
      url: json['url'] as String? ?? '',
      mimeType: json['mime'] as String? ?? json['mime_type'] as String?,
      sizeBytes: (json['size'] as num?)?.toInt(),
    );
  }
}

class LiveChatSession {
  const LiveChatSession({
    required this.id,
    required this.sessionCode,
    this.visitorKey,
    this.customerName,
    this.customerEmail,
    this.status = 'waiting',
    this.channel = 'web',
    this.startedAt,
    this.endedAt,
    this.visitorTypingAt,
    this.agentTypingAt,
  });

  final String id;
  final String sessionCode;
  final String? visitorKey;
  final String? customerName;
  final String? customerEmail;
  final String status;
  final String channel;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? visitorTypingAt;
  final DateTime? agentTypingAt;

  bool get isOpen =>
      status == 'waiting' || status == 'active' || status == 'queued';

  bool get agentIsTyping {
    final at = agentTypingAt;
    if (at == null) return false;
    return DateTime.now().difference(at) <= const Duration(seconds: 4);
  }

  bool get visitorIsTyping {
    final at = visitorTypingAt;
    if (at == null) return false;
    return DateTime.now().difference(at) <= const Duration(seconds: 4);
  }

  factory LiveChatSession.fromJson(Map<String, dynamic> json) {
    return LiveChatSession(
      id: json['id'] as String? ?? '',
      sessionCode: json['session_code'] as String? ?? '',
      visitorKey: json['visitor_key'] as String?,
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      status: json['status'] as String? ?? 'waiting',
      channel: json['channel'] as String? ?? 'web',
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
      endedAt: DateTime.tryParse(json['ended_at'] as String? ?? ''),
      visitorTypingAt: DateTime.tryParse(
        json['visitor_typing_at'] as String? ?? '',
      ),
      agentTypingAt: DateTime.tryParse(
        json['agent_typing_at'] as String? ?? '',
      ),
    );
  }
}

class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.sessionId,
    required this.body,
    this.senderType = 'customer',
    this.senderName,
    this.createdAt,
    this.messageType = 'text',
    this.attachments = const [],
  });

  final String id;
  final String sessionId;
  final String body;
  final String senderType;
  final String? senderName;
  final DateTime? createdAt;
  final String messageType;
  final List<LiveChatAttachment> attachments;

  bool get isVisitor => senderType == 'customer' || senderType == 'visitor';
  bool get isAgent => senderType == 'agent';
  bool get isSystem => senderType == 'system' || senderType == 'bot';

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) {
    final rawAtt = json['attachments'];
    final attachments = <LiveChatAttachment>[];
    if (rawAtt is List) {
      for (final e in rawAtt) {
        if (e is Map) {
          attachments.add(
            LiveChatAttachment.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return LiveChatMessage(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      senderType: json['sender_type'] as String? ?? 'customer',
      senderName: json['sender_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      messageType: json['message_type'] as String? ?? 'text',
      attachments: attachments,
    );
  }
}
