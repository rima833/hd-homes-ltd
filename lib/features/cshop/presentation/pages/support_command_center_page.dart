import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/support_foundation_models.dart';
import 'package:hdhomesproject/features/cshop/domain/services/cshop_service.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/live_chat_light_desk.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/support_mockup_workspace.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/staff_client_messages_workspace.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/staff_ticket_workspace.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/support_desk_chrome.dart';
import 'package:hdhomesproject/features/live_chat/domain/entities/live_chat_models.dart';
import 'package:hdhomesproject/features/live_chat/domain/services/live_chat_service.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_composer.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 11 — Support Command Center (CSHOP).
enum SupportDesk { tickets, liveChat }

class SupportCommandCenterPage extends ConsumerStatefulWidget {
  const SupportCommandCenterPage({
    super.key,
    this.desk = SupportDesk.tickets,
    this.initialTab,
    this.initialPortalConversationKey,
    this.initialChannelFilter,
  });

  final SupportDesk desk;
  final CshopCommandTab? initialTab;

  /// Composite key `client:<id>` or `investor:<id>` for Portal Messages deep-link.
  final String? initialPortalConversationKey;
  final String? initialChannelFilter;

  @override
  ConsumerState<SupportCommandCenterPage> createState() =>
      _SupportCommandCenterPageState();
}

class _SupportCommandCenterPageState
    extends ConsumerState<SupportCommandCenterPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(cshopControllerProvider.notifier);
      final tab = widget.initialTab;
      if (tab != null) controller.setTab(tab);
      final channel = widget.initialChannelFilter?.trim();
      if (channel != null && channel.isNotEmpty) {
        controller.setTab(CshopCommandTab.tickets);
        controller.setChannelFilter(channel);
      }
      final key = widget.initialPortalConversationKey?.trim();
      if (key != null && key.isNotEmpty) {
        controller.setTab(CshopCommandTab.clientMessages);
        controller.selectClientConversation(key);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SupportCommandCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tab = widget.initialTab;
    if (tab != null && tab != oldWidget.initialTab) {
      ref.read(cshopControllerProvider.notifier).setTab(tab);
    }
    final channel = widget.initialChannelFilter?.trim();
    if (channel != null &&
        channel.isNotEmpty &&
        channel != oldWidget.initialChannelFilter) {
      final controller = ref.read(cshopControllerProvider.notifier);
      controller.setTab(CshopCommandTab.tickets);
      controller.setChannelFilter(channel);
    }
    final key = widget.initialPortalConversationKey?.trim();
    if (key != null &&
        key.isNotEmpty &&
        key != oldWidget.initialPortalConversationKey) {
      final controller = ref.read(cshopControllerProvider.notifier);
      controller.setTab(CshopCommandTab.clientMessages);
      controller.selectClientConversation(key);
    }
  }

  Future<void> _createTicket() async {
    final results = await Future.wait([
      ref.read(supportTicketCategoriesProvider.future),
      ref.read(supportTicketPropertiesProvider.future),
    ]);
    final categories = results[0] as List<SupportCategory>;
    final properties = results[1] as List<SupportPropertyOption>;
    if (!mounted) return;
    final subject = TextEditingController();
    final description = TextEditingController();
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final userId = TextEditingController();
    var customerType = 'website_visitor';
    var priority = 'normal';
    String? categoryId;
    String? propertyId;
    var saving = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF171C26),
          title: const Text(
            'New support ticket',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: customerType,
                          dropdownColor: const Color(0xFF171C26),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Customer type',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'website_visitor',
                              child: Text('Website Visitor'),
                            ),
                            DropdownMenuItem(
                              value: 'client',
                              child: Text('Client'),
                            ),
                            DropdownMenuItem(
                              value: 'investor',
                              child: Text('Investor'),
                            ),
                          ],
                          onChanged: (value) => setLocal(
                            () => customerType = value ?? customerType,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          dropdownColor: const Color(0xFF171C26),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                          ),
                          items: TicketPriority.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value.name,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setLocal(() => priority = value ?? priority),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: categoryId,
                    dropdownColor: const Color(0xFF171C26),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('General / Uncategorised'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setLocal(() => categoryId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: propertyId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF171C26),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Property / Development',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No property attached'),
                      ),
                      ...properties.map(
                        (property) => DropdownMenuItem<String?>(
                          value: property.id,
                          child: Text(
                            property.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setLocal(() => propertyId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subject,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Subject'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Customer name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                      ),
                    ],
                  ),
                  if (customerType != 'website_visitor') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: userId,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Customer account ID',
                        helperText: 'Required for Client and Investor tickets',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (subject.text.trim().length < 3 ||
                          description.text.trim().length < 10 ||
                          (customerType != 'website_visitor' &&
                              userId.text.trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Complete subject, description and customer account.',
                            ),
                          ),
                        );
                        return;
                      }
                      setLocal(() => saving = true);
                      try {
                        await ref
                            .read(cshopServiceProvider)
                            .createTicket(
                              subject: subject.text,
                              description: description.text,
                              priority: priority,
                              customerType: customerType,
                              categoryId: categoryId,
                              propertyId: propertyId,
                              customerUserId: userId.text.trim().isEmpty
                                  ? null
                                  : userId.text.trim(),
                              customerName: name.text,
                              customerEmail: email.text,
                              customerPhone: phone.text,
                            );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setLocal(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ticket failed: $error')),
                          );
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.plus, size: 16),
              label: const Text('Create ticket'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    description.dispose();
    name.dispose();
    email.dispose();
    phone.dispose();
    userId.dispose();
    if (created == true) {
      ref.invalidate(cshopSnapshotProvider);
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Ticket created successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnap = ref.watch(cshopSnapshotProvider);
    final ui = ref.watch(cshopControllerProvider);
    final controller = ref.read(cshopControllerProvider.notifier);

    return Scaffold(
      backgroundColor: widget.desk == SupportDesk.liveChat
          ? const Color(0xFFF3F5F8)
          : SupportDeskChrome.bg,
      body: SizedBox.expand(
        child: asyncSnap.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Failed to load Support: $e',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          data: (snap) {
            if (widget.desk == SupportDesk.liveChat ||
                ui.selectedTab == CshopCommandTab.liveChat) {
              return _LiveChatDesk(snap: snap, ui: ui, controller: controller);
            }

            final openChats = snap.liveChats
                .where(
                  (c) => {'waiting', 'active', 'queued'}.contains(c.status),
                )
                .length;
            final totalTickets = snap.tickets.length;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ui.lastMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: SupportDeskChrome.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            ui.lastMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              LucideIcons.x,
                              size: 14,
                              color: Colors.white70,
                            ),
                            onPressed: controller.clearMessage,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _immersiveBody(
                      snap,
                      ui,
                      controller,
                      openChats: openChats,
                      ticketCount: totalTickets,
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

  void _openDeskTab(CshopCommandTab tab, CshopController controller) {
    controller.setTab(tab);
    final path = tab == CshopCommandTab.liveChat
        ? RoutePaths.dashboardLiveChat
        : '${RoutePaths.dashboardSupport}?tab=${tab.name}';
    context.go(path);
  }

  Widget _immersiveBody(
    CshopCommandCenterSnapshot snap,
    CshopUiState ui,
    CshopController controller, {
    required int openChats,
    required int ticketCount,
  }) {
    final tabs = SupportDeskTabs(
      selected: ui.selectedTab,
      openChats: openChats,
      ticketCount: ticketCount,
      onSelect: (tab) => _openDeskTab(tab, controller),
    );
    switch (ui.selectedTab) {
      case CshopCommandTab.tickets:
        return StaffTicketWorkspace(
          tickets: controller.filteredTickets(snap),
          selectedTicketId: ui.selectedTicketId,
          onSelect: controller.selectTicket,
          onCreateTicket: _createTicket,
          listHeader: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tabs,
              SupportTicketListFilters(
                searchQuery: ui.searchQuery,
                statusFilter: ui.statusFilter,
                onSearch: controller.setSearch,
                onStatus: controller.setStatusFilter,
              ),
            ],
          ),
        );
      case CshopCommandTab.liveChat:
        return _LiveChatWorkspace(
          chats: snap.liveChats,
          selectedSessionId: ui.selectedLiveChatSessionId,
          onSelect: controller.selectLiveChatSession,
          fillHeight: true,
          deskNav: tabs,
        );
      case CshopCommandTab.clientMessages:
        return StaffClientMessagesWorkspace(
          selectedConversationId: ui.selectedClientConversationId,
          onSelect: controller.selectClientConversation,
          deskNav: tabs,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _tabBody(
    BuildContext context,
    WidgetRef ref,
    CshopCommandCenterSnapshot snap,
    CshopUiState ui,
    CshopController controller,
  ) {
    switch (ui.selectedTab) {
      case CshopCommandTab.overview:
        return [
          _SectionCard(
            title: 'Recent activity',
            icon: LucideIcons.history,
            child: _ActivityList(activities: snap.activities),
          ),
          _SectionCard(
            title: 'Timeline',
            icon: LucideIcons.listTree,
            child: _TimelineList(events: snap.timeline),
          ),
          if (snap.escalations.isNotEmpty)
            _SectionCard(
              title: 'Open escalations',
              icon: LucideIcons.siren,
              child: _EscalationList(items: snap.escalations.take(5).toList()),
            ),
        ];
      case CshopCommandTab.tickets:
        return const [];
      case CshopCommandTab.inbox:
        return [
          _SectionCard(
            title: 'Unified inbox',
            icon: LucideIcons.inbox,
            child: _InboxList(
              threads: controller.filteredInbox(snap),
              onOpen: controller.openInboxThread,
            ),
          ),
        ];
      case CshopCommandTab.liveChat:
      case CshopCommandTab.clientMessages:
        return const [];
      case CshopCommandTab.email:
        return [
          _SectionCard(
            title: 'Email threads',
            icon: LucideIcons.mail,
            child: snap.emailThreads.isEmpty
                ? const _EmptyHint(
                    'No live email threads yet. Connect an inbox in a later phase.',
                  )
                : _EmailList(threads: snap.emailThreads),
          ),
        ];
      case CshopCommandTab.whatsapp:
        return [
          _SectionCard(
            title: 'WhatsApp',
            icon: LucideIcons.smartphone,
            child: snap.whatsapp.isEmpty
                ? const _EmptyHint(
                    'No WhatsApp conversations yet. Channel connector ships later.',
                  )
                : _WhatsappList(items: snap.whatsapp),
          ),
        ];
      case CshopCommandTab.knowledge:
        return [
          _SectionCard(
            title: 'Knowledge base',
            icon: LucideIcons.bookOpen,
            trailing: TextButton.icon(
              onPressed: () => _openKnowledgeEditor(context, ref),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('New article'),
            ),
            child: _KnowledgeList(
              articles: controller.filteredKnowledge(snap),
              onEdit: (a) => _openKnowledgeEditor(context, ref, article: a),
              onArchive: (a) => _archiveKnowledge(context, ref, a),
            ),
          ),
        ];
      case CshopCommandTab.sla:
        return [
          _SectionCard(
            title: 'SLA policies',
            icon: LucideIcons.timer,
            child: snap.slas.isEmpty
                ? const _EmptyHint(
                    'No SLA policies configured yet. Policies appear here from support_slas.',
                  )
                : _SlaList(slas: snap.slas),
          ),
          _SectionCard(
            title: 'Escalations',
            icon: LucideIcons.arrowUpRight,
            child: snap.escalations.isEmpty
                ? const _EmptyHint(
                    'No open escalations. Real escalations from tickets appear here.',
                  )
                : _EscalationList(
                    items: snap.escalations,
                    onAcknowledge: (e) =>
                        _setEscalationStatus(context, ref, e, 'acknowledged'),
                    onResolve: (e) =>
                        _setEscalationStatus(context, ref, e, 'resolved'),
                  ),
          ),
        ];
      case CshopCommandTab.agents:
        return [
          _SectionCard(
            title: 'Support agents',
            icon: LucideIcons.headphones,
            child: snap.agents.isEmpty
                ? const _EmptyHint(
                    'No agent roster yet. Open Live Chat to register your presence, or assign support roles from Users.',
                  )
                : _AgentList(agents: snap.agents),
          ),
        ];
      case CshopCommandTab.analytics:
        return [
          _SectionCard(
            title: 'Ops snapshot',
            icon: LucideIcons.barChart3,
            child: snap.kpis.isEmpty
                ? const _EmptyHint(
                    'No live ops metrics yet. Counts appear once tickets, chats, or portal messages exist.',
                  )
                : _KpiDetailList(kpis: snap.kpis),
          ),
          _SectionCard(
            title: 'Desk mix',
            icon: LucideIcons.layers,
            child: _DeskMixList(snap: snap),
          ),
        ];
      case CshopCommandTab.ai:
        final service = ref.read(cshopServiceProvider);
        final briefing = service.generateResolutionBriefing(snap);
        final signals = CshopService.detectSupportSignals(snap);
        return [
          _SectionCard(
            title: 'AI briefing',
            icon: LucideIcons.sparkles,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(briefing, style: Theme.of(context).textTheme.bodyMedium),
                const Divider(height: 24),
                ...signals.map(
                  (s) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.alertTriangle, size: 18),
                    title: Text(s),
                  ),
                ),
              ],
            ),
          ),
        ];
      case CshopCommandTab.feedback:
        return [
          _SectionCard(
            title: 'Feedback',
            icon: LucideIcons.smile,
            child: snap.feedback.isEmpty
                ? const _EmptyHint(
                    'No survey responses yet. CSAT/NPS will appear when customers submit real feedback.',
                  )
                : _FeedbackList(items: snap.feedback),
          ),
        ];
    }
  }

  Future<void> _openKnowledgeEditor(
    BuildContext context,
    WidgetRef ref, {
    CshopKnowledgeArticle? article,
  }) async {
    final titleCtrl = TextEditingController(text: article?.title ?? '');
    final summaryCtrl = TextEditingController(text: article?.summary ?? '');
    final bodyCtrl = TextEditingController(text: article?.body ?? '');
    var status = article?.status ?? 'draft';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(
                article == null ? 'New knowledge article' : 'Edit article',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: summaryCtrl,
                        decoration: const InputDecoration(labelText: 'Summary'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bodyCtrl,
                        minLines: 6,
                        maxLines: 12,
                        decoration: const InputDecoration(labelText: 'Body'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text('Draft'),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('Published'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => status = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(article == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true || !context.mounted) {
      titleCtrl.dispose();
      summaryCtrl.dispose();
      bodyCtrl.dispose();
      return;
    }
    try {
      final service = ref.read(cshopServiceProvider);
      if (article == null) {
        await service.createKnowledgeArticle(
          title: titleCtrl.text,
          summary: summaryCtrl.text,
          body: bodyCtrl.text,
          status: status,
        );
      } else {
        await service.updateKnowledgeArticle(
          id: article.id,
          title: titleCtrl.text,
          summary: summaryCtrl.text,
          body: bodyCtrl.text,
          status: status,
        );
      }
      ref.invalidate(cshopSnapshotProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              article == null ? 'Article created' : 'Article saved',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save article: $e')));
      }
    } finally {
      titleCtrl.dispose();
      summaryCtrl.dispose();
      bodyCtrl.dispose();
    }
  }

  Future<void> _archiveKnowledge(
    BuildContext context,
    WidgetRef ref,
    CshopKnowledgeArticle article,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive article?'),
        content: Text(
          '“${article.title}” will leave the active knowledge desk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(cshopServiceProvider).archiveKnowledgeArticle(article.id);
      ref.invalidate(cshopSnapshotProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not archive: $e')));
      }
    }
  }

  Future<void> _setEscalationStatus(
    BuildContext context,
    WidgetRef ref,
    CshopEscalation escalation,
    String status,
  ) async {
    try {
      await ref
          .read(cshopServiceProvider)
          .updateEscalationStatus(id: escalation.id, status: status);
      ref.invalidate(cshopSnapshotProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update escalation: $e')),
        );
      }
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.charcoal.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

class _SupportDeskHeader extends StatelessWidget {
  const _SupportDeskHeader({
    required this.fromRemote,
    required this.openTickets,
    required this.openChats,
    required this.onRefresh,
    this.title = 'Support',
    this.subtitle = 'Manage customer inquiries and provide timely support.',
    this.onBack,
    this.agentsPresent = 0,
    this.compact = false,
    this.realtimeConnected,
    this.onNewTicket,
    this.totalTickets,
    this.inProgressTickets,
    this.resolvedTickets,
    this.liveChatKpis = false,
  });

  final bool fromRemote;
  final bool? realtimeConnected;
  final int openTickets;
  final int openChats;
  final Future<void> Function() onRefresh;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final int agentsPresent;
  final bool compact;
  final VoidCallback? onNewTicket;
  final int? totalTickets;
  final int? inProgressTickets;
  final int? resolvedTickets;
  final bool liveChatKpis;

  @override
  Widget build(BuildContext context) {
    final realtimeOn = realtimeConnected ?? fromRemote;
    final showTicketKpis = totalTickets != null && !liveChatKpis;
    final systemOnline = agentsPresent > 0 || realtimeOn;

    final kpiCards = <Widget>[
      if (liveChatKpis) ...[
        SupportKpiCard(
          label: 'Tickets',
          value: '${totalTickets ?? openTickets}',
          icon: LucideIcons.ticket,
        ),
        SupportKpiCard(
          label: 'Chats',
          value: '$openChats',
          icon: LucideIcons.messageCircle,
        ),
        SupportKpiCard(
          label: 'System',
          value: systemOnline ? 'Online' : 'Offline',
          icon: LucideIcons.activity,
          accent: systemOnline
              ? SupportDeskChrome.online
              : SupportDeskChrome.muted,
        ),
      ] else if (showTicketKpis) ...[
        SupportKpiCard(
          label: 'Total Tickets',
          value: '${totalTickets!}',
          trend: '+20%',
          foot: 'vs last 7 days',
          icon: LucideIcons.ticket,
        ),
        SupportKpiCard(
          label: 'Open',
          value: '$openTickets',
          trend: '+12%',
          foot: 'vs last 7 days',
          icon: LucideIcons.circleDot,
          accent: const Color(0xFFEF4444),
        ),
        SupportKpiCard(
          label: 'In Progress',
          value: '${inProgressTickets ?? 0}',
          trend: '+8%',
          foot: 'vs last 7 days',
          icon: LucideIcons.loader,
          accent: SupportDeskChrome.inProgress,
        ),
        SupportKpiCard(
          label: 'Resolved',
          value: '${resolvedTickets ?? 0}',
          trend: '+25%',
          foot: 'vs last 7 days',
          icon: LucideIcons.checkCircle2,
          accent: SupportDeskChrome.online,
        ),
      ] else ...[
        _MetricChip(label: 'Tickets', value: '$openTickets'),
        _MetricChip(label: 'Chats', value: '$openChats'),
        _MetricChip(
          label: 'Agents',
          value: '$agentsPresent',
          accent: agentsPresent > 0,
        ),
      ],
    ];

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onNewTicket != null)
          PermissionGateAny(
            permissions: const [
              PermissionSlugs.supportTickets,
              PermissionSlugs.supportWrite,
            ],
            child: FilledButton.icon(
              onPressed: onNewTicket,
              icon: const Icon(LucideIcons.plus, size: 13),
              label: const Text('+ New Ticket'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.charcoal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 30),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        const SizedBox(width: 2),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(
            LucideIcons.refreshCw,
            color: Colors.white70,
            size: 15,
          ),
          tooltip: 'Refresh',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          padding: EdgeInsets.zero,
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF10131A),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    LucideIcons.arrowLeft,
                    color: Colors.white70,
                    size: 16,
                  ),
                  tooltip: 'Back to Support',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
              Expanded(
                flex: 2,
                child: SupportHeadsetTitle(
                  title: title,
                  subtitle: subtitle,
                  compact: true,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: 5,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: [
                      for (var i = 0; i < kpiCards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        kpiCards[i],
                      ],
                      const SizedBox(width: 6),
                      actions,
                    ],
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

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.accent = false,
  });
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent ? Colors.greenAccent : AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryDeskNav extends StatelessWidget {
  const _PrimaryDeskNav({
    required this.selected,
    required this.openChats,
    required this.onSelect,
  });

  final CshopCommandTab selected;
  final int openChats;
  final ValueChanged<CshopCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in CshopCommandTab.primary) ...[
                    _DeskTab(
                      label: tab == CshopCommandTab.liveChat && openChats > 0
                          ? '${tab.label} ($openChats)'
                          : tab.label,
                      selected: selected == tab,
                      onTap: () => onSelect(tab),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          PopupMenuButton<CshopCommandTab>(
            tooltip: 'More',
            onSelected: onSelect,
            color: const Color(0xFF171A22),
            itemBuilder: (context) => [
              for (final tab in CshopCommandTab.more)
                PopupMenuItem(
                  value: tab,
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      color: selected == tab ? AppColors.gold : Colors.white,
                    ),
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: CshopCommandTab.more.contains(selected)
                      ? AppColors.gold
                      : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    CshopCommandTab.more.contains(selected)
                        ? selected.label
                        : 'More',
                    style: TextStyle(
                      color: CshopCommandTab.more.contains(selected)
                          ? AppColors.gold
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeskTab extends StatelessWidget {
  const _DeskTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.charcoal : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveChatDesk extends StatelessWidget {
  const _LiveChatDesk({
    required this.snap,
    required this.ui,
    required this.controller,
  });

  final CshopCommandCenterSnapshot snap;
  final CshopUiState ui;
  final CshopController controller;

  @override
  Widget build(BuildContext context) {
    final openChats = snap.liveChats
        .where((chat) => {'waiting', 'active', 'queued'}.contains(chat.status))
        .length;
    return Column(
      children: [
        if (ui.lastMessage != null)
          Material(
            color: AppColors.gold.withValues(alpha: 0.14),
            child: ListTile(
              dense: true,
              leading: const Icon(
                LucideIcons.info,
                color: AppColors.gold,
                size: 16,
              ),
              title: Text(
                ui.lastMessage!,
                style: const TextStyle(fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: controller.clearMessage,
              ),
            ),
          ),
        Expanded(
          child: _LiveChatWorkspace(
            chats: snap.liveChats,
            selectedSessionId: ui.selectedLiveChatSessionId,
            onSelect: controller.selectLiveChatSession,
            fillHeight: true,
            deskNav: _LiveChatDeskNav(
              ticketCount: snap.tickets.length,
              openChats: openChats,
              onSelect: (tab) {
                controller.setTab(tab);
                final path = tab == CshopCommandTab.liveChat
                    ? RoutePaths.dashboardLiveChat
                    : '${RoutePaths.dashboardSupport}?tab=${tab.name}';
                context.go(path);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveChatDeskNav extends StatelessWidget {
  const _LiveChatDeskNav({
    required this.ticketCount,
    required this.openChats,
    required this.onSelect,
  });

  final int ticketCount;
  final int openChats;
  final ValueChanged<CshopCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < CshopCommandTab.primary.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _LiveChatDeskChip(
              label: switch (CshopCommandTab.primary[i]) {
                CshopCommandTab.tickets when ticketCount > 0 =>
                  'Tickets ($ticketCount)',
                CshopCommandTab.liveChat when openChats > 0 =>
                  'Live Chat ($openChats)',
                CshopCommandTab.clientMessages => 'Portal Messages',
                final tab => tab.label,
              },
              selected: CshopCommandTab.primary[i] == CshopCommandTab.liveChat,
              onTap: () => onSelect(CshopCommandTab.primary[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _LiveChatDeskChip extends StatelessWidget {
  const _LiveChatDeskChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.gold : const Color(0xFFE6E8EE),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF1C1E24)
                    : const Color(0xFF5C6370),
              ),
            ),
          ),
        ),
      ),
    );
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
    // Kept for compatibility; primary shell uses _SupportDeskHeader.
    return _SupportDeskHeader(
      fromRemote: fromRemote,
      openTickets: 0,
      openChats: 0,
      onRefresh: onRefresh,
      subtitle: ticker,
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
      if (kAiFeaturesEnabled)
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
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: TextField(
              onChanged: onSearch,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tickets…',
                hintStyle: const TextStyle(
                  color: Color(0xFF8B929E),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 16,
                  color: Color(0xFF8B929E),
                ),
                filled: true,
                fillColor: const Color(0xFF171C26),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x22FFFFFF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x22FFFFFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.55),
                  ),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: ui.statusFilter == null && ui.channelFilter == null,
                  onTap: () {
                    onStatus(null);
                    onChannel(null);
                  },
                ),
                ...['open', 'in_progress', 'escalated', 'resolved'].map(
                  (s) => _FilterChip(
                    label: SupportDeskChrome.prettyStatus(s),
                    selected: ui.statusFilter == s,
                    onTap: () => onStatus(ui.statusFilter == s ? null : s),
                  ),
                ),
                const SizedBox(width: 6),
                Container(width: 1, height: 22, color: Colors.white12),
                const SizedBox(width: 6),
                ...['chat', 'portal', 'website'].map(
                  (c) => _FilterChip(
                    label: c,
                    selected: ui.channelFilter == c,
                    onTap: () => onChannel(ui.channelFilter == c ? null : c),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.55)
                    : Colors.white12,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.gold : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
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
    return _PrimaryDeskNav(
      selected: selected,
      openChats: 0,
      onSelect: onSelect,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

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
                  if (trailing != null) trailing!,
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
                  ? Text(
                      t.customerName!,
                      style: Theme.of(context).textTheme.labelSmall,
                    )
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.threads, required this.onOpen});
  final List<CshopInboxThread> threads;
  final void Function(CshopInboxThread thread) onOpen;

  @override
  Widget build(BuildContext context) {
    if (threads.isEmpty) {
      return const _EmptyHint(
        'Inbox is empty. Tickets, live chats, and portal messages appear here.',
      );
    }
    return Column(
      children: threads
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_channelIcon(t.channel)),
              title: Text(t.title),
              subtitle: Text(
                '${t.isTicket
                    ? 'Ticket'
                    : t.isLiveChat
                    ? 'Live chat'
                    : t.isPortalMessage
                    ? 'Portal'
                    : t.channel}'
                '${t.customerName != null && t.customerName!.isNotEmpty ? ' · ${t.customerName}' : ''}'
                '${t.preview != null && t.preview!.isNotEmpty ? ' · ${t.preview}' : ''}',
              ),
              trailing: t.unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${t.unreadCount}',
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    )
                  : const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () => onOpen(t),
            ),
          )
          .toList(),
    );
  }
}

class _LiveChatWorkspace extends ConsumerStatefulWidget {
  const _LiveChatWorkspace({
    required this.chats,
    required this.selectedSessionId,
    required this.onSelect,
    this.fillHeight = false,
    this.deskNav,
  });

  final List<CshopLiveChat> chats;
  final String? selectedSessionId;
  final void Function(String? sessionId) onSelect;
  final bool fillHeight;
  final Widget? deskNav;

  @override
  ConsumerState<_LiveChatWorkspace> createState() => _LiveChatWorkspaceState();
}

class _LiveChatWorkspaceState extends ConsumerState<_LiveChatWorkspace> {
  final _composer = TextEditingController();
  final _search = TextEditingController();
  bool _sending = false;
  Timer? _typingIdle;
  Timer? _presenceHeartbeat;
  bool _agentTyping = false;
  bool _emojiOpen = false;
  bool _presenceOnline = false;
  String? _presenceError;
  LiveChatService? _presenceService;
  final List<LiveChatAttachment> _pending = [];

  @override
  void initState() {
    super.initState();
    _ensureSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startPresence());
    });
  }

  @override
  void didUpdateWidget(covariant _LiveChatWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureSelection();
  }

  void _ensureSelection() {
    if (widget.selectedSessionId != null) return;
    if (widget.chats.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.selectedSessionId == null && widget.chats.isNotEmpty) {
        widget.onSelect(widget.chats.first.id);
      }
    });
  }

  Future<void> _startPresence() async {
    final service = await ref.read(liveChatServiceProvider.future);
    if (service == null || !mounted) {
      if (mounted) {
        setState(() {
          _presenceOnline = false;
          _presenceError = 'Live chat service unavailable';
        });
      }
      return;
    }
    _presenceService = service;
    try {
      await service.setMyPresence('available');
      await service.heartbeatPresence();
      if (!mounted) return;
      setState(() {
        _presenceOnline = true;
        _presenceError = null;
      });
      ref.invalidate(cshopSnapshotProvider);
      ref.invalidate(liveChatSupportPresenceProvider);
      _presenceHeartbeat?.cancel();
      _presenceHeartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
        unawaited(_beatPresence());
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _presenceOnline = false;
          _presenceError = e.toString();
        });
        ref
            .read(cshopControllerProvider.notifier)
            .setMessage('Could not go online: $e');
      }
    }
  }

  Future<void> _beatPresence() async {
    final service = _presenceService;
    if (service == null) return;
    try {
      await service.heartbeatPresence();
      if (mounted && !_presenceOnline) {
        setState(() => _presenceOnline = true);
      }
    } catch (_) {
      if (mounted && _presenceOnline) {
        setState(() => _presenceOnline = false);
      }
    }
  }

  Future<void> _stopPresence() async {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    final service = _presenceService;
    if (service == null) return;
    try {
      await service.setMyPresence('offline');
    } catch (_) {}
  }

  @override
  void dispose() {
    _typingIdle?.cancel();
    _presenceHeartbeat?.cancel();
    unawaited(_setAgentTyping(false));
    unawaited(_stopPresence());
    _composer.dispose();
    _search.dispose();
    super.dispose();
  }

  CshopLiveChat? get _selected {
    final id = widget.selectedSessionId;
    if (id == null) return null;
    for (final c in widget.chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _setAgentTyping(bool isTyping) async {
    final session = _selected;
    if (session == null) return;
    if (_agentTyping == isTyping) return;
    _agentTyping = isTyping;
    final service = await ref.read(liveChatServiceProvider.future);
    if (service == null) return;
    await service.setAgentTyping(sessionId: session.id, isTyping: isTyping);
  }

  void _onComposerChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    _typingIdle?.cancel();
    if (!hasText) {
      unawaited(_setAgentTyping(false));
      return;
    }
    unawaited(_setAgentTyping(true));
    _typingIdle = Timer(const Duration(milliseconds: 1800), () {
      unawaited(_setAgentTyping(false));
    });
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      final service = await ref.read(liveChatServiceProvider.future);
      if (service == null) {
        ref
            .read(cshopControllerProvider.notifier)
            .setMessage('Live chat service unavailable');
        return;
      }
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final att = await service.uploadAgentFile(
          fileName: f.name,
          bytes: bytes,
          mimeType: liveChatGuessMime(f.name),
        );
        _pending.add(att);
      }
      if (mounted) setState(() {});
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Upload failed: $e');
    }
  }

  Future<void> _send() async {
    final session = _selected;
    final text = _composer.text.trim();
    if (session == null || (text.isEmpty && _pending.isEmpty)) return;
    final service = await ref.read(liveChatServiceProvider.future);
    if (service == null) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Live chat service unavailable');
      return;
    }
    setState(() => _sending = true);
    try {
      await _setAgentTyping(false);
      final email = _agentLabel();
      final attachments = List<LiveChatAttachment>.from(_pending);
      final type = attachments.isEmpty
          ? 'text'
          : (attachments.every((a) => a.isImage) ? 'image' : 'file');
      await service.sendAgentMessage(
        sessionId: session.id,
        body: text,
        senderName: email,
        attachments: attachments,
        messageType: type,
      );
      _composer.clear();
      _pending.clear();
      _emojiOpen = false;
      ref.invalidate(adminLiveChatMessagesProvider(session.id));
      ref.invalidate(cshopSnapshotProvider);
      ref.read(cshopControllerProvider.notifier).setMessage('Reply sent');
    } catch (e) {
      ref.read(cshopControllerProvider.notifier).setMessage('Send failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _end() async {
    final session = _selected;
    if (session == null) return;
    final service = await ref.read(liveChatServiceProvider.future);
    if (service == null) return;
    try {
      await _setAgentTyping(false);
      await service.endSession(sessionId: session.id);
      ref.invalidate(cshopSnapshotProvider);
      ref.read(cshopControllerProvider.notifier).setMessage('Chat ended');
    } catch (e) {
      ref.read(cshopControllerProvider.notifier).setMessage('End failed: $e');
    }
  }

  Future<void> _createTicketFromChat(CshopLiveChat session) async {
    final email = session.customerEmail?.trim();
    final hasEmail = email != null && email.contains('@');
    try {
      await ref
          .read(cshopServiceProvider)
          .createTicket(
            subject: 'Live chat ${session.sessionCode}',
            description:
                'Follow-up from live chat ${session.sessionCode} with '
                '${session.displayName}.'
                '${session.lastMessagePreview?.trim().isNotEmpty == true ? '\n\nLatest: ${session.lastMessagePreview}' : ''}',
            priority: 'normal',
            customerType: 'website_visitor',
            customerName: session.displayName,
            customerEmail: hasEmail
                ? email
                : 'visitor+${session.sessionCode.toLowerCase()}@hdhomes.local',
            source: 'live_chat',
            channel: 'chat',
          );
      ref.invalidate(cshopSnapshotProvider);
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Ticket created from chat');
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Could not create ticket: $e');
    }
  }

  Future<void> _addToCrm(CshopLiveChat session) async {
    final notifier = ref.read(cshopControllerProvider.notifier);
    try {
      final crm = ref.read(crmServiceProvider);
      final clientId = await crm.upsertClient(
        fullName: session.displayName,
        email: session.customerEmail,
        customerType: 'guest',
        relationshipStatus: 'lead',
      );
      await crm.createLead(
        clientId: clientId,
        title: 'Live chat — ${session.displayName}',
        notes:
            'Source: live_chat · Session ${session.sessionCode}'
            '${session.lastMessagePreview?.trim().isNotEmpty == true ? '\nLatest: ${session.lastMessagePreview}' : ''}',
      );
      ref.invalidate(crmSnapshotProvider);
      notifier.setMessage('Visitor added to CRM');
    } catch (e) {
      notifier.setMessage('Could not add to CRM: $e');
    }
  }

  String _agentLabel() {
    final profile = ref.read(identitySessionProvider).profile;
    final name = profile?.displayName.trim() ?? '';
    if (name.isNotEmpty) return name;
    return ref.read(supabaseClientProvider).auth.currentUser?.email ?? 'Agent';
  }

  Future<LiveChatPropertyOption?> _chooseProperty() async {
    List<LiveChatPropertyOption> properties;
    try {
      properties = await ref
          .read(cshopServiceProvider)
          .listLiveChatProperties();
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Could not load properties: $e');
      return null;
    }
    if (!mounted) return null;
    if (properties.isEmpty) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('No properties available');
      return null;
    }
    return showLiveChatPropertyPicker(context, properties);
  }

  Future<void> _sendAgentText(
    CshopLiveChat session,
    String body, {
    Map<String, dynamic>? metadata,
    required String success,
  }) async {
    final service = await ref.read(liveChatServiceProvider.future);
    if (service == null) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Live chat service unavailable');
      return;
    }
    try {
      await service.sendAgentMessage(
        sessionId: session.id,
        body: body,
        senderName: _agentLabel(),
      );
      if (metadata != null) {
        await service.mergeSessionMetadata(
          sessionId: session.id,
          patch: metadata,
        );
      }
      ref.invalidate(adminLiveChatMessagesProvider(session.id));
      ref.invalidate(cshopSnapshotProvider);
      ref.read(cshopControllerProvider.notifier).setMessage(success);
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Could not send: $e');
    }
  }

  Map<String, dynamic> _propertyMeta(LiveChatPropertyOption property) => {
    'id': property.id,
    'title': property.title,
    'subtitle': property.subtitle,
    if (property.slug != null) 'slug': property.slug,
    if (property.imageUrl != null) 'image_url': property.imageUrl,
  };

  String _propertyLink(LiveChatPropertyOption property) {
    final slug = property.slug?.trim() ?? '';
    if (slug.isEmpty) return SeoConfig.canonicalFor('/properties');
    return SeoConfig.canonicalFor('/properties/$slug');
  }

  Future<void> _sendPropertyDetails() async {
    final session = _selected;
    if (session == null || !session.isOpen) return;
    final property = await _chooseProperty();
    if (property == null) return;
    final detail = property.subtitle.trim().isEmpty
        ? property.title
        : '${property.title}\n${property.subtitle}';
    await _sendAgentText(
      session,
      '$detail\n\nView the property: ${_propertyLink(property)}',
      metadata: {'property_interest': _propertyMeta(property)},
      success: 'Property details sent',
    );
  }

  Future<void> _shareBrochure() async {
    final session = _selected;
    if (session == null || !session.isOpen) return;
    final property = await _chooseProperty();
    if (property == null) return;
    await _sendAgentText(
      session,
      'Here are the details for ${property.title}.\n${_propertyLink(property)}',
      metadata: {'property_interest': _propertyMeta(property)},
      success: 'Property link sent',
    );
  }

  Future<void> _scheduleCall() async {
    final session = _selected;
    if (session == null || !session.isOpen || !mounted) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final when = MaterialLocalizations.of(context).formatFullDate(date);
    final clock = time.format(context);
    await _sendAgentText(
      session,
      "Let's schedule a call on $when at $clock. Reply here if that time works for you.",
      success: 'Call time sent',
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final openChats = widget.chats
        .where((c) => {'waiting', 'active', 'queued'}.contains(c.status))
        .toList();
    final closedChats = widget.chats
        .where((c) => !{'waiting', 'active', 'queued'}.contains(c.status))
        .toList();
    final ordered = [...openChats, ...closedChats];
    final desk = LiveChatLightDesk(
      chats: ordered,
      selected: selected,
      onSelect: widget.onSelect,
      searchController: _search,
      composer: _composer,
      sending: _sending,
      presenceOnline: _presenceOnline,
      presenceError: _presenceError,
      onTogglePresence: () {
        if (_presenceOnline) {
          unawaited(() async {
            await _stopPresence();
            if (mounted) setState(() => _presenceOnline = false);
            ref.invalidate(cshopSnapshotProvider);
          }());
        } else {
          unawaited(_startPresence());
        }
      },
      onSend: _send,
      onEnd: () => unawaited(_end()),
      onComposerChanged: _onComposerChanged,
      pending: _pending,
      emojiOpen: _emojiOpen,
      onToggleEmoji: () => setState(() => _emojiOpen = !_emojiOpen),
      onPickFiles: () => unawaited(_pickFiles()),
      onRemovePending: (index) => setState(() => _pending.removeAt(index)),
      onInsertEmoji: (emoji) {
        _composer.text = '${_composer.text}$emoji';
        _composer.selection = TextSelection.collapsed(
          offset: _composer.text.length,
        );
        _onComposerChanged(_composer.text);
      },
      onClaim: () {
        final session = selected;
        if (session == null) return;
        unawaited(() async {
          try {
            final service = await ref.read(liveChatServiceProvider.future);
            if (service == null) return;
            await service.claimSession(session.id);
            ref.invalidate(cshopSnapshotProvider);
            ref
                .read(cshopControllerProvider.notifier)
                .setMessage('Chat claimed');
          } catch (e) {
            ref
                .read(cshopControllerProvider.notifier)
                .setMessage('Claim failed: $e');
          }
        }());
      },
      onCreateTicket: () {
        if (selected != null) unawaited(_createTicketFromChat(selected));
      },
      onAddToCrm: () {
        if (selected != null) unawaited(_addToCrm(selected));
      },
      onSendProperty: () => unawaited(_sendPropertyDetails()),
      onShareBrochure: () => unawaited(_shareBrochure()),
      onScheduleCall: () => unawaited(_scheduleCall()),
      deskNav: widget.deskNav,
    );
    return widget.fillHeight
        ? SizedBox.expand(child: desk)
        : SizedBox(height: 720, width: double.infinity, child: desk);
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
  const _KnowledgeList({required this.articles, this.onEdit, this.onArchive});
  final List<CshopKnowledgeArticle> articles;
  final void Function(CshopKnowledgeArticle article)? onEdit;
  final void Function(CshopKnowledgeArticle article)? onArchive;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const _EmptyHint(
        'No knowledge articles yet. Create macros and FAQs for the support desk.',
      );
    }
    return Column(
      children: articles
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.bookOpen),
              title: Text(a.title),
              subtitle: Text(
                '${a.category} · ${a.status}'
                '${a.summary != null && a.summary!.isNotEmpty ? ' · ${a.summary}' : ''}',
              ),
              isThreeLine: a.summary != null && a.summary!.isNotEmpty,
              trailing: Wrap(
                spacing: 4,
                children: [
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => onEdit!(a),
                      icon: const Icon(LucideIcons.pencil, size: 16),
                    ),
                  if (onArchive != null)
                    IconButton(
                      tooltip: 'Archive',
                      onPressed: () => onArchive!(a),
                      icon: const Icon(LucideIcons.archive, size: 16),
                    ),
                ],
              ),
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
  const _EscalationList({
    required this.items,
    this.onAcknowledge,
    this.onResolve,
  });
  final List<CshopEscalation> items;
  final void Function(CshopEscalation escalation)? onAcknowledge;
  final void Function(CshopEscalation escalation)? onResolve;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.siren),
              title: Text('L${e.level} · ${e.ticketLabel ?? e.id}'),
              subtitle: Text(
                '${e.status} → ${e.escalatedTo ?? ''} · ${e.reason}',
              ),
              isThreeLine: true,
              trailing: e.status == 'open' || e.status == 'acknowledged'
                  ? Wrap(
                      spacing: 4,
                      children: [
                        if (e.status == 'open' && onAcknowledge != null)
                          TextButton(
                            onPressed: () => onAcknowledge!(e),
                            child: const Text('Ack'),
                          ),
                        if (onResolve != null)
                          TextButton(
                            onPressed: () => onResolve!(e),
                            child: const Text('Resolve'),
                          ),
                      ],
                    )
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _AgentList extends StatelessWidget {
  const _AgentList({required this.agents});
  final List<CshopAgent> agents;

  String _seenLabel(CshopAgent a) {
    final seen = a.lastSeenAt;
    if (seen == null) return 'never seen';
    final mins = DateTime.now().toUtc().difference(seen.toUtc()).inMinutes;
    if (mins < 1) return 'seen just now';
    if (mins < 60) return 'seen ${mins}m ago';
    final hours = mins ~/ 60;
    if (hours < 24) return 'seen ${hours}h ago';
    return 'seen ${hours ~/ 24}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: agents
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                    child: Text(
                      a.displayName.isNotEmpty
                          ? a.displayName[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: a.isPresent
                            ? Colors.greenAccent
                            : Colors.white38,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF12161E),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                a.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${a.roleTitle}'
                '${a.teamName != null && a.teamName!.isNotEmpty ? ' · ${a.teamName}' : ''}'
                ' · ${_seenLabel(a)}'
                '${a.skills.isNotEmpty ? ' · ${a.skills.join(', ')}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (a.isPresent ? Colors.green : Colors.grey).withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  a.isPresent ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: a.isPresent ? Colors.greenAccent : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
              subtitle: Text('${f.customerName ?? ''} · ${f.comment ?? ''}'),
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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: k.status == 'watch'
                      ? Colors.orange.shade800
                      : AppColors.charcoal,
                ),
              ),
              subtitle: k.changePct != null
                  ? Text(
                      '${k.changePct! >= 0 ? '+' : ''}${k.changePct!.toStringAsFixed(1)}%',
                    )
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _DeskMixList extends StatelessWidget {
  const _DeskMixList({required this.snap});
  final CshopCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final ticketCount = snap.tickets
        .where((t) => !{'resolved', 'closed'}.contains(t.status))
        .length;
    final chatCount = snap.liveChats
        .where((c) => {'waiting', 'active', 'queued'}.contains(c.status))
        .length;
    final portalCount = snap.inbox.where((t) => t.isPortalMessage).length;
    final rows = [
      ('Tickets (open)', ticketCount, LucideIcons.ticket),
      ('Live chats (open)', chatCount, LucideIcons.messageCircle),
      ('Portal threads', portalCount, LucideIcons.messagesSquare),
      ('Portal unread', snap.portalUnreadCount, LucideIcons.mail),
      (
        'Agents present',
        snap.agents.where((a) => a.isPresent).length,
        LucideIcons.radio,
      ),
    ];
    return Column(
      children: rows
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(r.$3, size: 18),
              title: Text(r.$1),
              trailing: Text(
                '${r.$2}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
