import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';

enum StaffPortalKind { client, investor }

/// Unified staff view of portal account threads (client + investor).
class StaffPortalConversation {
  const StaffPortalConversation({
    required this.kind,
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.displayName,
    this.accountId,
    this.unreadCount = 0,
    this.peerTyping = false,
  });

  factory StaffPortalConversation.fromClient(ClientConversation c) {
    return StaffPortalConversation(
      kind: StaffPortalKind.client,
      id: c.id,
      subject: c.subject,
      category: c.category,
      status: c.status,
      lastMessageAt: c.lastMessageAt,
      lastMessagePreview: c.lastMessagePreview,
      displayName: c.clientDisplayName,
      unreadCount: c.unreadCount,
      peerTyping: c.clientIsTyping,
    );
  }

  factory StaffPortalConversation.fromInvestor(InvestorConversation c) {
    return StaffPortalConversation(
      kind: StaffPortalKind.investor,
      id: c.id,
      subject: c.subject,
      category: c.category,
      status: c.status,
      lastMessageAt: c.lastMessageAt,
      lastMessagePreview: c.lastMessagePreview,
      displayName: c.investorDisplayName,
      accountId: c.investorId,
      unreadCount: c.unreadCount,
      peerTyping: c.investorIsTyping,
    );
  }

  final StaffPortalKind kind;
  final String id;
  final String subject;
  final String category;
  final String status;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? displayName;
  final String? accountId;
  final int unreadCount;
  final bool peerTyping;

  /// Composite selection key used by Support desk UI state.
  String get selectionKey => '${kind.name}:$id';

  String get listTitle {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final subj = subject.trim();
    if (subj.isNotEmpty) return subj;
    return kind == StaffPortalKind.client ? 'Client' : 'Investor';
  }

  String get kindLabel =>
      kind == StaffPortalKind.client ? 'Client' : 'Investor';

  String get channelLabel => kind == StaffPortalKind.client
      ? 'Client portal'
      : 'Investor portal';

  static (StaffPortalKind kind, String id)? parseSelectionKey(String? key) {
    if (key == null || key.isEmpty) return null;
    final idx = key.indexOf(':');
    if (idx <= 0 || idx >= key.length - 1) {
      // Legacy bare UUID → treat as client for backwards compatibility.
      return (StaffPortalKind.client, key);
    }
    final kindRaw = key.substring(0, idx);
    final id = key.substring(idx + 1);
    if (id.isEmpty) return null;
    if (kindRaw == StaffPortalKind.investor.name) {
      return (StaffPortalKind.investor, id);
    }
    if (kindRaw == StaffPortalKind.client.name) {
      return (StaffPortalKind.client, id);
    }
    return (StaffPortalKind.client, key);
  }
}

class StaffPortalMessage {
  const StaffPortalMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.isMine,
    this.isRead = false,
    this.senderName,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final bool isMine;
  final bool isRead;
  final String? senderName;
}
