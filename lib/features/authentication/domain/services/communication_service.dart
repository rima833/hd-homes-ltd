import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hdhomesproject/core/auth/models/security_event.dart';
import 'package:hdhomesproject/core/auth/services/security_service.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/notification_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Communication Engine — all modules should dispatch through this service.
class CommunicationService {
  CommunicationService({
    required SecurityService security,
    SupabaseClient? client,
  })  : _security = security,
        _client = client;

  final SecurityService _security;
  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  /// Smart Communication Orchestrator™ entry point.
  Future<AppNotification?> dispatch(CommunicationDispatchRequest request) async {
    final client = _client;
    if (client == null) {
      throw const AuthenticationException('Communication service unavailable.');
    }

    final template = NotificationTemplateCatalog.bySlug(request.templateSlug);
    if (template == null) {
      throw ValidationException('Unknown notification template: ${request.templateSlug}');
    }

    final prefs = await loadPrefs(request.userId);
    final requested = request.channels ?? template.defaultChannels;
    final plan = SmartCommunicationOrchestrator.plan(
      requested: requested,
      prefs: prefs,
      priority: request.priority,
      type: template.type,
    );

    final title = template.title(request.variables);
    final body = template.body(request.variables);

    // Phase 1: persist in-app notification; email/SMS queued as delivery rows.
    AppNotification? created;
    if (plan.channels.contains(NotificationChannel.inApp)) {
      created = await _insertInApp(
        userId: request.userId,
        title: title,
        body: body,
        template: template,
        priority: request.priority,
        actionUrl: request.actionUrl,
        metadata: {
          ...request.metadata,
          'orchestration': plan.reason,
          if (plan.deferUntil != null)
            'deferred_until': plan.deferUntil!.toIso8601String(),
        },
        deliverNow: plan.sendImmediately,
      );
    }

    for (final channel in plan.channels) {
      if (channel == NotificationChannel.inApp) continue;
      await _queueDelivery(
        userId: request.userId,
        channel: channel,
        title: title,
        body: body,
        notificationId: created?.id,
        status: plan.sendImmediately
            ? DeliveryStatus.queued
            : DeliveryStatus.queued,
      );
    }

    await _log(request.userId, 'notification_dispatched', {
      'template': request.templateSlug,
      'channels': plan.channels.map((c) => c.slug).toList(),
      'reason': plan.reason,
    });

    return created;
  }

  Future<NotificationCenterSnapshot> loadCenter(String userId) async {
    final items = await listNotifications(userId);
    final prefs = await loadPrefs(userId);
    final unread = items.where((n) => !n.isRead && !n.isArchived).length;
    return NotificationCenterSnapshot(
      items: items,
      unreadCount: unread,
      prefs: prefs,
    );
  }

  Future<List<AppNotification>> listNotifications(
    String userId, {
    bool includeArchived = false,
  }) async {
    final client = _client;
    if (client == null) return const [];
    try {
      var query = client
          .from('notifications')
          .select()
          .eq('user_id', userId);
      if (!includeArchived) {
        query = query.eq('is_archived', false);
      }
      final rows = await query
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List)
          .map((r) => AppNotification.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<int> unreadCount(String userId) async {
    final client = _client;
    if (client == null) return 0;
    try {
      final rows = await client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('is_archived', false);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markRead(String notificationId) async {
    final client = _client;
    if (client == null) return;
    await client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', notificationId);
  }

  Future<void> markAllRead(String userId) async {
    final client = _client;
    if (client == null) return;
    await client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId).eq('is_read', false);
  }

  Future<void> archive(String notificationId) async {
    final client = _client;
    if (client == null) return;
    await client.from('notifications').update({
      'is_archived': true,
    }).eq('id', notificationId);
  }

  Future<void> togglePin(String notificationId, bool pinned) async {
    final client = _client;
    if (client == null) return;
    await client.from('notifications').update({
      'is_pinned': pinned,
    }).eq('id', notificationId);
  }

  Future<void> deleteNotification(String notificationId) async {
    final client = _client;
    if (client == null) return;
    await client.from('notifications').delete().eq('id', notificationId);
  }

  Future<CommunicationChannelPrefs> loadPrefs(String userId) async {
    final client = _client;
    if (client == null) return const CommunicationChannelPrefs();
    try {
      final row = await client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return CommunicationChannelPrefs.fromNotificationPrefsJson(
        row == null ? null : Map<String, dynamic>.from(row),
      );
    } catch (_) {
      return const CommunicationChannelPrefs();
    }
  }

  Future<void> savePrefs(String userId, CommunicationChannelPrefs prefs) async {
    final client = _client;
    if (client == null) return;
    await client.from('notification_preferences').upsert(prefs.toUpsertMap(userId));
    await _log(userId, 'prefs_updated', {});
  }

  Future<AnnouncementPost> publishAnnouncement({
    required String title,
    required String body,
    required String actorId,
    String targetAudience = 'everyone',
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthenticationException('Communication service unavailable.');
    }
    final row = await client.from('announcement_posts').insert({
      'title': title,
      'body': body,
      'target_audience': targetAudience,
      'published': true,
      'published_at': DateTime.now().toUtc().toIso8601String(),
      'created_by': actorId,
    }).select().single();

    await _log(actorId, 'announcement_published', {
      'title': title,
      'audience': targetAudience,
    });

    // Fan-out simplified: create system notification for actor demo;
    // full fan-out uses Edge Function / queue in production.
    await dispatch(
      CommunicationDispatchRequest(
        userId: actorId,
        templateSlug: 'announcement',
        variables: {'title': title, 'body': body},
        priority: NotificationPriority.high,
      ),
    );

    return AnnouncementPost.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<AnnouncementPost>> listAnnouncements() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('announcement_posts')
          .select()
          .eq('published', true)
          .order('published_at', ascending: false)
          .limit(50);
      return (rows as List)
          .map((r) => AnnouncementPost.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Subscribe to realtime inserts for the current user.
  RealtimeChannel? subscribe(
    String userId,
    void Function(AppNotification notification) onInsert,
  ) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('notifications:$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            try {
              final n = AppNotification.fromJson(
                Map<String, dynamic>.from(payload.newRecord),
              );
              onInsert(n);
            } catch (_) {}
          },
        )
        .subscribe();
    return channel;
  }

  Future<AppNotification> _insertInApp({
    required String userId,
    required String title,
    required String body,
    required NotificationTemplate template,
    required NotificationPriority priority,
    String? actionUrl,
    Map<String, dynamic> metadata = const {},
    bool deliverNow = true,
  }) async {
    final client = _client!;
    final row = await client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'category': template.category.slug,
      'type': template.type.slug,
      'priority': priority.slug,
      'template_slug': template.slug,
      'action_url': actionUrl,
      'metadata': metadata,
      'is_read': false,
      'delivery_status':
          deliverNow ? DeliveryStatus.delivered.slug : DeliveryStatus.queued.slug,
    }).select().single();
    return AppNotification.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> _queueDelivery({
    required String userId,
    required NotificationChannel channel,
    required String title,
    required String body,
    String? notificationId,
    required DeliveryStatus status,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('notification_delivery').insert({
        'user_id': userId,
        'notification_id': notificationId,
        'channel': channel.slug,
        'title': title,
        'body': body,
        'status': status.slug,
      });
    } catch (_) {}
  }

  Future<void> _log(
    String actorId,
    String action,
    Map<String, dynamic> metadata,
  ) async {
    _security.record(
      SecurityEvent(
        type: SecurityEventType.profileUpdated,
        timestamp: DateTime.now(),
        userId: actorId,
        userAgent: kIsWeb ? 'web' : defaultTargetPlatform.name,
        metadata: {'module': 'communication', 'action': action, ...metadata},
      ),
    );
    final client = _client;
    if (client == null) return;
    // ignore: unawaited_futures
    client.from('communication_logs').insert({
      'actor_id': actorId,
      'event_type': action,
      'metadata': metadata,
    }).then((_) {}, onError: (_) {});
  }
}
