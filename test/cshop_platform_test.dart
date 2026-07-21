import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/services/cshop_service.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';

void main() {
  group('CshopDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = CshopDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.tickets, isNotEmpty);
      expect(snap.inbox, isNotEmpty);
      expect(snap.liveChats, isNotEmpty);
      expect(snap.chatMessages, isNotEmpty);
      expect(snap.emailThreads, isNotEmpty);
      expect(snap.whatsapp, isNotEmpty);
      expect(snap.knowledge, isNotEmpty);
      expect(snap.slas, isNotEmpty);
      expect(snap.escalations, isNotEmpty);
      expect(snap.agents, isNotEmpty);
      expect(snap.feedback, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.timeline, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes support command-center labels', () {
      final snap = CshopDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Open Tickets',
          'SLA Breaches',
          'Live Chats',
          'CSAT',
          'NPS',
          'Escalations',
          'Agents Online',
        ]),
      );
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = CshopDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('tickets span channels and include SLA breach', () {
      final snap = CshopDemo.snapshot();
      expect(snap.tickets.any((t) => t.channel == 'whatsapp'), isTrue);
      expect(snap.tickets.any((t) => t.channel == 'chat'), isTrue);
      expect(snap.tickets.any((t) => t.channel == 'email'), isTrue);
      expect(snap.tickets.any((t) => t.slaBreached), isTrue);
      expect(snap.tickets.any((t) => t.status == 'escalated'), isTrue);
    });
  });

  group('CshopService', () {
    test('offline client returns demo command center', () async {
      final service = CshopService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
      expect(snap.tickets, isNotEmpty);
    });

    test('AI resolution briefing stub includes disclaimer and signals', () {
      final service = CshopService();
      final snap = CshopDemo.snapshot();
      final briefing = service.generateResolutionBriefing(snap);
      expect(briefing.toLowerCase(), contains('resolution'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('sla'));
    });

    test('support signals flag SLA breaches and waiting chats', () {
      final snap = CshopDemo.snapshot();
      final signals = CshopService.detectSupportSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('sla')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('chat')),
        isTrue,
      );
    });
  });

  group('CshopController contract', () {
    test('tabs cover required support surfaces without state-in-build', () {
      expect(CshopCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'tickets',
        'inbox',
        'liveChat',
        'email',
        'whatsapp',
        'knowledge',
        'sla',
        'agents',
        'analytics',
        'ai',
        'feedback',
      ]));
      const initial = CshopUiState();
      expect(initial.selectedTab, CshopCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
