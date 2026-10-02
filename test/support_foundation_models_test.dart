import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/support_foundation_models.dart';
import 'package:hdhomesproject/features/live_chat/domain/entities/live_chat_models.dart';

void main() {
  test('support settings map database fields without losing metadata', () {
    final settings = SupportSettings.fromJson({
      'id': 'settings-1',
      'timezone': 'Africa/Lagos',
      'welcome_message': 'Welcome',
      'offline_message': 'Leave a message',
      'business_hours_enabled': true,
      'offline_ticket_enabled': true,
      'auto_assignment_enabled': false,
      'metadata': {'source': 'test'},
      'updated_at': '2026-09-08T08:00:00Z',
    });

    expect(settings.id, 'settings-1');
    expect(settings.metadata['source'], 'test');
    expect(settings.updatedAt, DateTime.utc(2026, 9, 8, 8));
    expect(settings.toUpdateJson()['welcome_message'], 'Welcome');
  });

  test('ticket event preserves internal visibility and transition fields', () {
    final event = SupportTicketEvent.fromJson({
      'id': 'event-1',
      'ticket_id': 'ticket-1',
      'action': 'status_changed',
      'from_status': 'open',
      'to_status': 'pending',
      'is_internal': true,
      'metadata': {'reason': 'waiting_on_customer'},
    });

    expect(event.isInternal, isTrue);
    expect(event.fromStatus, 'open');
    expect(event.toStatus, 'pending');
    expect(event.metadata['reason'], 'waiting_on_customer');
  });

  test('operating hour writes null times when a day is closed', () {
    const hour = SupportOperatingHour(
      id: 'hour-1',
      dayOfWeek: 0,
      isOpen: false,
      opensAt: '09:00',
      closesAt: '17:00',
    );

    expect(hour.toUpsertJson()['opens_at'], isNull);
    expect(hour.toUpsertJson()['closes_at'], isNull);
  });

  test('database customer sender renders as the public live-chat visitor', () {
    final message = LiveChatMessage.fromJson({
      'id': 'message-1',
      'session_id': 'session-1',
      'body': 'Hello',
      'sender_type': 'customer',
    });

    expect(message.isVisitor, isTrue);
    expect(message.isAgent, isFalse);
  });

  test('ticket lifecycle exposes both waiting states with canonical slugs', () {
    expect(
      TicketStatus.fromSlug('pending_customer'),
      TicketStatus.pendingCustomer,
    );
    expect(TicketStatus.pendingCustomer.slug, 'waiting_for_customer');
    expect(TicketStatus.waitingHdHomes.slug, 'waiting_for_hd_homes');
    expect(TicketStatus.actionable, contains(TicketStatus.waitingHdHomes));
  });

  test('ticket model maps customer, property and timeline context', () {
    final ticket = CshopTicket.fromJson({
      'id': 'ticket-1',
      'subject': 'Inspection',
      'customer_type': 'investor',
      'source': 'investor_portal',
      'category_id': 'category-1',
      'category': {'name': 'Inspection'},
      'property_id': 'property-1',
      'property': {'title': 'Palm Residence'},
      'estate_id': 'estate-1',
      'estate': {'name': 'HD City'},
      'attachments': [
        {'id': 'attachment-1'},
      ],
      'last_customer_response_at': '2026-09-08T08:00:00Z',
      'last_agent_response_at': '2026-09-08T09:00:00Z',
    });

    expect(ticket.customerType, 'investor');
    expect(ticket.category, 'Inspection');
    expect(ticket.propertyName, 'Palm Residence');
    expect(ticket.developmentName, 'HD City');
    expect(ticket.attachmentCount, 1);
    expect(ticket.lastResponseAt, DateTime.utc(2026, 9, 8, 9));
  });

  test('ticket property option includes its development label', () {
    final property = SupportPropertyOption.fromJson({
      'id': 'property-1',
      'title': 'Palm Residence',
      'estate': {'name': 'HD City'},
    });

    expect(property.id, 'property-1');
    expect(property.developmentName, 'HD City');
    expect(property.label, 'Palm Residence · HD City');
  });
}
