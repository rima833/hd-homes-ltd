import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';

enum PortalInboxKind { conversation, ticket }

enum PortalInboxFilter { all, messages, tickets }

class PortalInboxItem {
  const PortalInboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.preview,
    required this.status,
    this.subtitle,
    this.updatedAt,
    this.unreadCount = 0,
    this.priority,
    this.category,
  });

  final String id;
  final PortalInboxKind kind;
  final String title;
  final String preview;
  final String status;
  final String? subtitle;
  final DateTime? updatedAt;
  final int unreadCount;
  final String? priority;
  final String? category;

  String get selectionKey => '${kind.name}:$id';

  bool get isTicket => kind == PortalInboxKind.ticket;
  bool get isConversation => kind == PortalInboxKind.conversation;

  factory PortalInboxItem.fromClientConversation(ClientConversation c) {
    return PortalInboxItem(
      id: c.id,
      kind: PortalInboxKind.conversation,
      title: c.teamLabel,
      preview: (c.lastMessagePreview?.trim().isNotEmpty == true)
          ? c.lastMessagePreview!.trim()
          : c.subject,
      status: c.status,
      subtitle: c.subject,
      updatedAt: c.lastMessageAt,
      unreadCount: c.unreadCount,
      category: c.category,
    );
  }

  factory PortalInboxItem.fromClientTicket(ClientSupportTicket t) {
    return PortalInboxItem(
      id: t.id,
      kind: PortalInboxKind.ticket,
      title: t.subject,
      preview: t.description?.trim().isNotEmpty == true
          ? t.description!.trim()
          : (t.ticketNumber ?? 'Support ticket'),
      status: t.status,
      subtitle: t.ticketNumber,
      updatedAt: t.updatedAt ?? t.createdAt,
      priority: t.priority,
    );
  }

  factory PortalInboxItem.fromInvestorConversation(InvestorConversation c) {
    return PortalInboxItem(
      id: c.id,
      kind: PortalInboxKind.conversation,
      title: c.subject,
      preview: c.category,
      status: c.status,
      subtitle: c.category,
      updatedAt: c.lastMessageAt,
      unreadCount: c.unreadCount,
      category: c.category,
    );
  }

  factory PortalInboxItem.fromInvestorTicket(InvestorSupportTicket t) {
    return PortalInboxItem(
      id: t.id,
      kind: PortalInboxKind.ticket,
      title: t.subject,
      preview: t.description?.trim().isNotEmpty == true
          ? t.description!.trim()
          : (t.ticketNumber ?? 'Support ticket'),
      status: t.status,
      subtitle: t.ticketNumber,
      updatedAt: t.updatedAt ?? t.createdAt,
      priority: t.priority,
    );
  }

  static List<PortalInboxItem> merge({
    List<PortalInboxItem> conversations = const [],
    List<PortalInboxItem> tickets = const [],
    PortalInboxFilter filter = PortalInboxFilter.all,
    String query = '',
  }) {
    final items = <PortalInboxItem>[
      if (filter != PortalInboxFilter.tickets) ...conversations,
      if (filter != PortalInboxFilter.messages) ...tickets,
    ];
    final needle = query.trim().toLowerCase();
    final filtered = needle.isEmpty
        ? items
        : items.where((item) {
            final hay = [
              item.title,
              item.preview,
              item.subtitle ?? '',
              item.status,
              item.category ?? '',
              item.priority ?? '',
            ].join(' ').toLowerCase();
            return hay.contains(needle);
          }).toList(growable: false);
    filtered.sort((a, b) {
      final at = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return filtered;
  }
}
