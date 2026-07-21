import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/services/cshop_service.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 11 — Support Command Center (CSHOP).
class SupportCommandCenterPage extends ConsumerWidget {
  const SupportCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(cshopSnapshotProvider);
    final ui = ref.watch(cshopControllerProvider);
    final controller = ref.read(cshopControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Support Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Support Command Center live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _CshopHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenAi: () => controller.setTab(CshopCommandTab.ai),
                    onOpenInbox: () => controller.setTab(CshopCommandTab.inbox),
                  ),
                ),
                if (ui.lastMessage != null)
                  ContainedPadding(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Material(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.cardBorder,
                        child: ListTile(
                          leading: const Icon(
                            LucideIcons.info,
                            color: AppColors.gold,
                          ),
                          title: Text(ui.lastMessage!),
                          dense: true,
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: controller.clearMessage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ContainedPadding(child: _KpiStrip(kpis: snap.kpis)),
                ContainedPadding(
                  child: _EnterpriseFeatureStrip(
                    onSelect: controller.setTab,
                  ),
                ),
                ContainedPadding(
                  child: _SearchAndFilters(
                    ui: ui,
                    onSearch: controller.setSearch,
                    onStatus: controller.setStatusFilter,
                    onChannel: controller.setChannelFilter,
                  ),
                ),
                ContainedPadding(
                  child: _TabBar(
                    selected: ui.selectedTab,
                    onSelect: controller.setTab,
                  ),
                ),
                ..._tabSlivers(context, ref, snap, ui, controller),
                const ContainedPadding(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _tabSlivers(
    BuildContext context,
    WidgetRef ref,
    CshopCommandCenterSnapshot snap,
    CshopUiState ui,
    CshopController controller,
  ) {
    switch (ui.selectedTab) {
      case CshopCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Unified Customer Conversation Hub™',
              icon: LucideIcons.messagesSquare,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Omnichannel · tickets · chat · email · WhatsApp',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  _ActivityList(activities: snap.activities),
                ],
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Customer 360° Service Timeline™',
              icon: LucideIcons.history,
              child: _TimelineList(events: snap.timeline),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Open escalations',
              icon: LucideIcons.siren,
              child: _EscalationList(items: snap.escalations.take(3).toList()),
            ),
          ),
        ];
      case CshopCommandTab.tickets:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Help Desk Tickets',
              icon: LucideIcons.ticket,
              child: _TicketList(
                tickets: controller.filteredTickets(snap),
              ),
            ),
          ),
        ];
      case CshopCommandTab.inbox:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Unified Inbox',
              icon: LucideIcons.inbox,
              child: _InboxList(threads: controller.filteredInbox(snap)),
            ),
          ),
        ];
      case CshopCommandTab.liveChat:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Live Chat Sessions',
              icon: LucideIcons.messageCircle,
              child: _LiveChatList(chats: snap.liveChats),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Recent chat messages',
              icon: LucideIcons.messageSquare,
              child: _ChatMessageList(messages: snap.chatMessages),
            ),
          ),
        ];
      case CshopCommandTab.email:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Email Threads',
              icon: LucideIcons.mail,
              child: _EmailList(threads: snap.emailThreads),
            ),
          ),
        ];
      case CshopCommandTab.whatsapp:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'WhatsApp Conversations',
              icon: LucideIcons.smartphone,
              child: _WhatsappList(items: snap.whatsapp),
            ),
          ),
        ];
      case CshopCommandTab.knowledge:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Support Knowledge Base',
              icon: LucideIcons.bookOpen,
              child: _KnowledgeList(
                articles: controller.filteredKnowledge(snap),
              ),
            ),
          ),
        ];
      case CshopCommandTab.sla:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'SLA Policies',
              icon: LucideIcons.timer,
              child: _SlaList(slas: snap.slas),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Escalations',
              icon: LucideIcons.arrowUpRight,
              child: _EscalationList(items: snap.escalations),
            ),
          ),
        ];
      case CshopCommandTab.agents:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Support Agents',
              icon: LucideIcons.headphones,
              child: _AgentList(agents: snap.agents),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Intelligent Case Routing™',
              icon: LucideIcons.gitBranch,
              child: Text(
                'Skill-based assignment stubs: billing → Adaeze, sales care → Fatima, portal/KYC → Ibrahim.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ];
      case CshopCommandTab.analytics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Executive Customer Experience Center™',
              icon: LucideIcons.barChart3,
              child: _KpiDetailList(kpis: snap.kpis),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Channel mix (demo)',
              icon: LucideIcons.pieChart,
              child: Text(
                'Email · WhatsApp · Live Chat · Portal — see KPI strip and ticket filters for Phase 1 signals.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ];
      case CshopCommandTab.ai:
        final service = ref.read(cshopServiceProvider);
        final briefing = service.generateResolutionBriefing(snap);
        final signals = CshopService.detectSupportSignals(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Resolution Intelligence™',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(briefing, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text(
                    snap.aiDisclaimer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.charcoal.withValues(alpha: 0.7),
                        ),
                  ),
                  const Divider(height: 24),
                  ...signals.map(
                    (s) => ListTile(
                      dense: true,
                      leading: const Icon(LucideIcons.alertTriangle, size: 18),
                      title: Text(s),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Insights',
              icon: LucideIcons.brain,
              child: _AiInsightList(insights: snap.aiInsights),
            ),
          ),
        ];
      case CshopCommandTab.feedback:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'CSAT / NPS / Feedback',
              icon: LucideIcons.smile,
              child: _FeedbackList(items: snap.feedback),
            ),
          ),
        ];
    }
  }
}

class ContainedPadding extends StatelessWidget {
  const ContainedPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _CshopHeader extends StatelessWidget {
  const _CshopHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenAi,
    required this.onOpenInbox,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenInbox;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.deepBlack.withValues(alpha: 0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final title = Text(
                'Support Command Center',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: fromRemote
                          ? Colors.green.withValues(alpha: 0.2)
                          : AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: fromRemote
                            ? Colors.greenAccent.withValues(alpha: 0.5)
                            : AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      fromRemote ? 'Live' : 'Demo',
                      style: TextStyle(
                        color: fromRemote ? Colors.greenAccent : AppColors.gold,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onOpenAi,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('AI Resolution'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenInbox,
                    icon: const Icon(LucideIcons.inbox, size: 16),
                    label: const Text('Inbox'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(LucideIcons.refreshCw, color: AppColors.white),
                    tooltip: 'Refresh',
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Customer Support · Help Desk · Omnichannel Communication Platform',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ticker,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnterpriseFeatureStrip extends StatelessWidget {
  const _EnterpriseFeatureStrip({required this.onSelect});

  final void Function(CshopCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (CshopCommandTab.inbox, 'Conversation Hub™', LucideIcons.messagesSquare),
      (CshopCommandTab.agents, 'Case Routing™', LucideIcons.gitBranch),
      (CshopCommandTab.ai, 'AI Resolution™', LucideIcons.sparkles),
      (CshopCommandTab.overview, '360° Timeline™', LucideIcons.history),
      (CshopCommandTab.analytics, 'CX Center™', LucideIcons.barChart3),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (e) => ActionChip(
                avatar: Icon(e.$3, size: 16),
                label: Text(e.$2),
                onPressed: () => onSelect(e.$1),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<CshopKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final k = kpis[i];
            return Container(
              width: 148,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.charcoal.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    k.displayValue,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: k.status == 'watch'
                              ? AppColors.gold
                              : AppColors.charcoal,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.onSearch,
    required this.onStatus,
    required this.onChannel,
  });

  final CshopUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onChannel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search tickets, customers, knowledge…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(borderRadius: AppRadius.cardBorder),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All statuses'),
                selected: ui.statusFilter == null,
                onSelected: (_) => onStatus(null),
              ),
              ...['open', 'in_progress', 'escalated', 'resolved'].map(
                (s) => FilterChip(
                  label: Text(s.replaceAll('_', ' ')),
                  selected: ui.statusFilter == s,
                  onSelected: (v) => onStatus(v ? s : null),
                ),
              ),
              FilterChip(
                label: const Text('All channels'),
                selected: ui.channelFilter == null,
                onSelected: (_) => onChannel(null),
              ),
              ...['email', 'chat', 'whatsapp', 'portal'].map(
                (c) => FilterChip(
                  label: Text(c),
                  selected: ui.channelFilter == c,
                  onSelected: (v) => onChannel(v ? c : null),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final CshopCommandTab selected;
  final ValueChanged<CshopCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: CshopCommandTab.values.map((tab) {
            final active = tab == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab.label),
                selected: active,
                onSelected: (_) => onSelect(tab),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: AppColors.white,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({required this.tickets});
  final List<CshopTicket> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Text('No tickets match filters.');
    }
    return Column(
      children: tickets
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.ticket,
                color: t.slaBreached ? Colors.redAccent : AppColors.charcoal,
              ),
              title: Text(t.subject),
              subtitle: Text(
                '${t.ticketNumber ?? t.id} · ${t.channel} · ${t.status} · ${t.priority}'
                '${t.slaBreached ? ' · SLA BREACH' : ''}',
              ),
              trailing: t.customerName != null
                  ? Text(t.customerName!, style: Theme.of(context).textTheme.labelSmall)
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.threads});
  final List<CshopInboxThread> threads;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: threads
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_channelIcon(t.channel)),
              title: Text(t.title),
              subtitle: Text('${t.customerName ?? ''} · ${t.preview ?? ''}'),
            ),
          )
          .toList(),
    );
  }
}

class _LiveChatList extends StatelessWidget {
  const _LiveChatList({required this.chats});
  final List<CshopLiveChat> chats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: chats
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.messageCircle,
                color: c.status == 'waiting' ? AppColors.gold : Colors.green,
              ),
              title: Text('${c.sessionCode} — ${c.customerName ?? 'Visitor'}'),
              subtitle: Text('${c.status} · agent: ${c.agentName ?? 'unassigned'}'),
              trailing: Text('${c.messageCount}'),
            ),
          )
          .toList(),
    );
  }
}

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({required this.messages});
  final List<CshopChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: messages
          .take(8)
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${m.senderName ?? m.senderType}: ${m.body}'),
            ),
          )
          .toList(),
    );
  }
}

class _EmailList extends StatelessWidget {
  const _EmailList({required this.threads});
  final List<CshopEmailThread> threads;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: threads
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.mail),
              title: Text(t.subject),
              subtitle: Text('${t.counterpartEmail ?? ''} · ${t.status}'),
            ),
          )
          .toList(),
    );
  }
}

class _WhatsappList extends StatelessWidget {
  const _WhatsappList({required this.items});
  final List<CshopWhatsappConversation> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.smartphone),
              title: Text(w.customerName ?? w.phoneE164),
              subtitle: Text('${w.phoneE164} · ${w.lastPreview ?? w.status}'),
            ),
          )
          .toList(),
    );
  }
}

class _KnowledgeList extends StatelessWidget {
  const _KnowledgeList({required this.articles});
  final List<CshopKnowledgeArticle> articles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: articles
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.bookOpen),
              title: Text(a.title),
              subtitle: Text('${a.category} · ${a.summary ?? a.body}'),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}

class _SlaList extends StatelessWidget {
  const _SlaList({required this.slas});
  final List<CshopSla> slas;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: slas
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.timer),
              title: Text('${s.code} — ${s.name}'),
              subtitle: Text(
                '${s.channel} · first ${s.firstResponseMins}m · resolve ${s.resolveMins}m',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EscalationList extends StatelessWidget {
  const _EscalationList({required this.items});
  final List<CshopEscalation> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.siren),
              title: Text('L${e.level} · ${e.ticketLabel ?? e.id}'),
              subtitle: Text('${e.status} → ${e.escalatedTo ?? ''} · ${e.reason}'),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}

class _AgentList extends StatelessWidget {
  const _AgentList({required this.agents});
  final List<CshopAgent> agents;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: agents
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.user,
                color: a.status == 'available'
                    ? Colors.green
                    : a.status == 'busy'
                        ? AppColors.gold
                        : AppColors.charcoal.withValues(alpha: 0.4),
              ),
              title: Text(a.displayName),
              subtitle: Text(
                '${a.roleTitle} · ${a.teamName ?? ''} · ${a.status}'
                '${a.skills.isNotEmpty ? ' · ${a.skills.join(', ')}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FeedbackList extends StatelessWidget {
  const _FeedbackList({required this.items});
  final List<CshopFeedback> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                f.kind == 'nps' ? LucideIcons.gauge : LucideIcons.star,
              ),
              title: Text('${f.label} · ${f.score ?? '-'}'),
              subtitle: Text(
                '${f.customerName ?? ''} · ${f.comment ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AiInsightList extends StatelessWidget {
  const _AiInsightList({required this.insights});
  final List<CshopAiInsight> insights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: insights
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.sparkles, color: AppColors.gold),
              title: Text(i.title),
              subtitle: Text(
                '${i.body}\n'
                '${i.confidencePct != null ? 'Confidence ${i.confidencePct!.toStringAsFixed(0)}% · ' : ''}'
                '${i.disclaimer}',
              ),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});
  final List<CshopActivity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.activity, size: 16),
              title: Text(a.summary),
              subtitle: Text('${a.actorLabel ?? ''} · ${a.channel ?? ''}'),
            ),
          )
          .toList(),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.events});
  final List<CshopTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: events
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_channelIcon(e.channel), size: 16),
              title: Text(e.label),
              subtitle: Text(e.detail ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _KpiDetailList extends StatelessWidget {
  const _KpiDetailList({required this.kpis});
  final List<CshopKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: kpis
          .map(
            (k) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(k.label),
              trailing: Text(
                k.displayValue,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: k.changePct != null
                  ? Text('${k.changePct! >= 0 ? '+' : ''}${k.changePct!.toStringAsFixed(1)}%')
                  : null,
            ),
          )
          .toList(),
    );
  }
}

IconData _channelIcon(String? channel) {
  return switch (channel) {
    'email' => LucideIcons.mail,
    'chat' => LucideIcons.messageCircle,
    'whatsapp' => LucideIcons.smartphone,
    'phone' => LucideIcons.phone,
    _ => LucideIcons.globe,
  };
}
