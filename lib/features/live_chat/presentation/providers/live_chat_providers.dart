import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/live_chat/domain/entities/live_chat_models.dart';
import 'package:hdhomesproject/features/live_chat/domain/services/live_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final liveChatPanelOpenProvider = StateProvider<bool>((ref) => false);

/// When true, portal Messages should open on the Live chat tab (e.g. from public Concierge).
final portalMessagesOpenLiveChatProvider = StateProvider<bool>((ref) => false);

final liveChatServiceProvider = FutureProvider<LiveChatService?>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  final prefs = await SharedPreferences.getInstance();
  return LiveChatService(
    client: ref.watch(supabaseClientProvider),
    prefs: prefs,
    mediaService: ref.watch(mediaServiceProvider),
  );
});

/// Public Online/Offline for Concierge — polls agent heartbeat presence.
final liveChatSupportPresenceProvider =
    StreamProvider.autoDispose<LiveChatSupportPresence>((ref) async* {
      const offline = LiveChatSupportPresence(online: false, agentsPresent: 0);
      final service = await ref.watch(liveChatServiceProvider.future);
      if (service == null) {
        yield offline;
        return;
      }

      Future<LiveChatSupportPresence> read() async {
        try {
          return await service.fetchSupportPresence();
        } catch (_) {
          return offline;
        }
      }

      yield await read();
      yield* Stream.periodic(
        const Duration(seconds: 12),
      ).asyncMap((_) => read());
    });

/// Stable visitor id for live chat — independent of device fingerprint (web-safe).
final liveChatVisitorKeyProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  const key = 'hd_live_chat_visitor_key_v1';
  final existing = prefs.getString(key);
  if (existing != null && existing.length >= 12) return existing;

  final rng = Random();
  final hex = List.generate(8, (_) => rng.nextInt(16).toRadixString(16)).join();
  final value = 'web-$hex-${DateTime.now().millisecondsSinceEpoch}';
  await prefs.setString(key, value);
  return value;
});

class LiveChatVisitorState {
  const LiveChatVisitorState({
    this.session,
    this.savedSession,
    this.savedPreview,
    this.offerResume = false,
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.uploading = false,
    this.error,
    this.displayName = '',
    this.customerEmail = '',
    this.pendingAttachments = const [],
  });

  final LiveChatSession? session;

  /// Last stored conversation, offered before the visitor continues or starts new.
  final LiveChatSession? savedSession;
  final String? savedPreview;
  final bool offerResume;
  final List<LiveChatMessage> messages;
  final bool loading;
  final bool sending;
  final bool uploading;
  final String? error;
  final String displayName;
  final String customerEmail;
  final List<LiveChatAttachment> pendingAttachments;

  bool get peerIsTyping => session?.agentIsTyping == true;

  /// Visitor has a saved chat and has not chosen continue or new yet.
  bool get awaitingChoice => offerResume && session == null && savedSession != null;

  LiveChatVisitorState copyWith({
    LiveChatSession? session,
    bool clearSession = false,
    LiveChatSession? savedSession,
    bool clearSaved = false,
    String? savedPreview,
    bool clearPreview = false,
    bool? offerResume,
    List<LiveChatMessage>? messages,
    bool? loading,
    bool? sending,
    bool? uploading,
    String? error,
    bool clearError = false,
    String? displayName,
    String? customerEmail,
    List<LiveChatAttachment>? pendingAttachments,
  }) {
    return LiveChatVisitorState(
      session: clearSession ? null : (session ?? this.session),
      savedSession: clearSaved ? null : (savedSession ?? this.savedSession),
      savedPreview: clearPreview
          ? null
          : (clearSaved ? null : (savedPreview ?? this.savedPreview)),
      offerResume: clearSaved ? false : (offerResume ?? this.offerResume),
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      uploading: uploading ?? this.uploading,
      error: clearError ? null : (error ?? this.error),
      displayName: displayName ?? this.displayName,
      customerEmail: customerEmail ?? this.customerEmail,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    );
  }
}

class LiveChatVisitorController extends Notifier<LiveChatVisitorState> {
  Timer? _poll;
  Timer? _typingIdle;
  String? _visitorKey;
  bool _localTyping = false;
  RealtimeChannel? _broadcast;
  bool _broadcastConnected = false;
  bool _postgresConnected = false;
  bool _started = false;
  Future<void>? _startFuture;

  @override
  LiveChatVisitorState build() {
    ref.onDispose(() {
      _poll?.cancel();
      _typingIdle?.cancel();
      _started = false;
      _startFuture = null;
      unawaited(_detachBroadcast());
      unawaited(_clearTyping());
    });
    // Bootstrap only when a live-chat UI mounts (ensureStarted) — not on
    // first accidental watch / Contact Hub first paint.
    return const LiveChatVisitorState(loading: false);
  }

  /// Starts session resume + realtime/poll. Idempotent; safe to call from UI.
  Future<void> ensureStarted() {
    if (_started) return _startFuture ?? Future.value();
    _started = true;
    state = state.copyWith(loading: true);
    return _startFuture = _bootstrap();
  }

  Future<LiveChatService?> _service() =>
      ref.read(liveChatServiceProvider.future);

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  bool get _realtimeConnected =>
      _postgresConnected || _broadcastConnected;

  void _armPoll() {
    _poll?.cancel();
    // Slow fallback only — prefer postgres realtime, then broadcast.
    final interval = _realtimeConnected
        ? const Duration(seconds: 20)
        : const Duration(seconds: 3);
    _poll = Timer.periodic(interval, (_) {
      unawaited(_refreshMessages());
      unawaited(_reloadSession());
    });
  }

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _detachBroadcast() async {
    final channel = _broadcast;
    _broadcast = null;
    _broadcastConnected = false;
    _postgresConnected = false;
    if (channel == null) return;
    if (!ref.watch(supabaseConfiguredProvider)) return;
    try {
      await ref.read(supabaseClientProvider).removeChannel(channel);
    } catch (_) {}
  }

  Future<void> _attachBroadcast(String sessionId) async {
    if (!ref.read(supabaseConfiguredProvider)) return;
    await _detachBroadcast();
    final client = ref.read(supabaseClientProvider);
    try {
      final channel = client.channel('live-chat:$sessionId');
      // Secondary: Realtime Broadcast (DB triggers + anon-safe).
      channel
        ..onBroadcast(
          event: 'message',
          callback: (_) {
            unawaited(_refreshMessages());
          },
        )
        ..onBroadcast(
          event: 'session',
          callback: (_) {
            unawaited(_reloadSession());
            unawaited(_refreshMessages());
          },
        );

      // Primary when RLS allows: postgres changes on messages + session.
      // If registration fails, broadcast + poll remain.
      try {
        channel
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'session_id',
              value: sessionId,
            ),
            callback: (_) {
              _postgresConnected = true;
              if (state.session != null) _armPoll();
              unawaited(_refreshMessages());
            },
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_chat_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: sessionId,
            ),
            callback: (_) {
              _postgresConnected = true;
              if (state.session != null) _armPoll();
              unawaited(_reloadSession());
              unawaited(_refreshMessages());
            },
          );
      } catch (_) {
        // Keep broadcast; anon visitors often cannot SELECT via RLS.
      }

      channel.subscribe((status, [error]) {
        _broadcastConnected = status == RealtimeSubscribeStatus.subscribed;
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut ||
            status == RealtimeSubscribeStatus.closed) {
          _postgresConnected = false;
        }
        if (state.session != null) _armPoll();
      });
      _broadcast = channel;
    } catch (_) {
      _broadcast = null;
      _broadcastConnected = false;
      _postgresConnected = false;
    }
  }

  Future<void> _bootstrap() async {
    try {
      final service = await _service();
      if (service == null) {
        state = state.copyWith(
          loading: false,
          error: 'Live chat is unavailable right now.',
        );
        return;
      }
      _visitorKey = await ref.read(liveChatVisitorKeyProvider.future);
      final resumed = await service.resumeStoredSession(
        visitorKey: _visitorKey!,
      );
      if (resumed != null) {
        final preview = await _previewFor(service, resumed.id, _visitorKey!);
        state = state.copyWith(
          clearSession: true,
          savedSession: resumed,
          savedPreview: preview,
          offerResume: true,
          messages: const [],
          displayName: resumed.customerName ?? state.displayName,
          loading: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          loading: false,
          offerResume: false,
          clearSaved: true,
          clearError: true,
        );
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: userFacingError(e));
    }
  }

  void setDisplayName(String name) {
    state = state.copyWith(displayName: name);
  }

  /// Prefill name/email from a signed-in client profile.
  void bindIdentity({String? name, String? email}) {
    final nextName = name?.trim() ?? '';
    final nextEmail = email?.trim() ?? '';
    if (nextName.isEmpty && nextEmail.isEmpty) return;
    state = state.copyWith(
      displayName: nextName.isNotEmpty ? nextName : state.displayName,
      customerEmail: nextEmail.isNotEmpty ? nextEmail : state.customerEmail,
    );
  }

  Future<String?> _previewFor(
    LiveChatService service,
    String sessionId,
    String visitorKey,
  ) async {
    try {
      final messages = await service.listVisitorMessages(
        sessionId: sessionId,
        visitorKey: visitorKey,
      );
      for (final message in messages.reversed) {
        final body = message.body.trim();
        if (body.isEmpty) continue;
        await service.persistPreview(body);
        return service.storedPreview;
      }
    } catch (_) {}
    return service.storedPreview;
  }

  /// Open the saved conversation instead of starting a new one.
  Future<void> continueSavedChat() async {
    final saved = state.savedSession;
    final key = _visitorKey;
    final service = await _service();
    if (saved == null || key == null || service == null) return;
    state = state.copyWith(
      session: saved,
      offerResume: false,
      loading: true,
      clearError: true,
      displayName: saved.customerName ?? state.displayName,
    );
    await _refreshMessages();
    if (saved.isOpen) {
      await _attachBroadcast(saved.id);
      _armPoll();
    } else {
      await _detachBroadcast();
      _stopPoll();
    }
    state = state.copyWith(loading: false);
  }

  /// Close any open saved chat and start a fresh conversation.
  Future<void> startNewChat() async {
    final service = await _service();
    final String key =
        _visitorKey ?? await ref.read(liveChatVisitorKeyProvider.future);
    _visitorKey = key;
    if (service == null) {
      state = state.copyWith(error: 'Live chat is unavailable right now.');
      return;
    }
    final previous = state.session ?? state.savedSession;
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _clearTyping();
      if (previous != null && previous.isOpen) {
        await service.endSession(sessionId: previous.id, visitorKey: key);
      }
      await service.clearStoredSession();
      await _detachBroadcast();
      _stopPoll();
      state = state.copyWith(
        clearSession: true,
        clearSaved: true,
        messages: const [],
        pendingAttachments: const [],
        offerResume: false,
      );
      final session = await service.startSession(
        visitorKey: key,
        customerName: state.displayName.trim().isEmpty
            ? null
            : state.displayName.trim(),
        customerEmail: state.customerEmail.trim().isEmpty
            ? null
            : state.customerEmail.trim(),
      );
      state = state.copyWith(session: session, loading: false);
      await _refreshMessages();
      await _attachBroadcast(session.id);
      _armPoll();
    } catch (e) {
      state = state.copyWith(loading: false, error: userFacingError(e));
    }
  }

  Future<void> startOrResume() async {
    final service = await _service();
    final String key =
        _visitorKey ?? await ref.read(liveChatVisitorKeyProvider.future);
    _visitorKey = key;
    if (service == null) {
      state = state.copyWith(error: 'Live chat is unavailable right now.');
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await service.startSession(
        visitorKey: key,
        customerName: state.displayName.trim().isEmpty
            ? null
            : state.displayName.trim(),
        customerEmail: state.customerEmail.trim().isEmpty
            ? null
            : state.customerEmail.trim(),
      );
      state = state.copyWith(session: session, loading: false);
      await _refreshMessages();
      await _attachBroadcast(session.id);
      _armPoll();
    } catch (e) {
      state = state.copyWith(loading: false, error: userFacingError(e));
    }
  }

  Future<void> _refreshMessages() async {
    final session = state.session;
    final key = _visitorKey;
    final service = await _service();
    if (session == null || key == null || service == null) return;
    try {
      final messages = await service.listVisitorMessages(
        sessionId: session.id,
        visitorKey: key,
      );
      for (final message in messages.reversed) {
        final body = message.body.trim();
        if (body.isEmpty) continue;
        await service.persistPreview(body);
        break;
      }
      state = state.copyWith(messages: messages, clearError: true);
    } catch (e) {
      state = state.copyWith(error: userFacingError(e));
    }
  }

  Future<void> _reloadSession() async {
    final session = state.session;
    final key = _visitorKey;
    final service = await _service();
    if (session == null || key == null || service == null) return;
    final next = await service.getVisitorSession(
      sessionId: session.id,
      visitorKey: key,
    );
    if (next == null) return;
    state = state.copyWith(session: next);
    if (!next.isOpen) {
      await service.clearStoredSession();
      await _detachBroadcast();
      _stopPoll();
    }
  }

  /// Called from the message field `onChanged` to show agent-side typing.
  void onComposerChanged(String text) {
    final hasText = text.trim().isNotEmpty;
    _typingIdle?.cancel();
    if (!hasText) {
      unawaited(_setTyping(false));
      return;
    }
    if (!_localTyping) {
      unawaited(_setTyping(true));
    }
    _typingIdle = Timer(const Duration(milliseconds: 1800), () {
      unawaited(_setTyping(false));
    });
  }

  Future<void> _setTyping(bool isTyping) async {
    if (_localTyping == isTyping) return;
    _localTyping = isTyping;
    final session = state.session;
    final key = _visitorKey;
    final service = await _service();
    if (session == null || key == null || service == null || !session.isOpen) {
      return;
    }
    final next = await service.setTyping(
      sessionId: session.id,
      visitorKey: key,
      isTyping: isTyping,
    );
    // Do not replace the session on each keystroke — that rebuilds the
    // transcript and looks like the chat reloaded.
    if (next != null && next.id != session.id) {
      state = state.copyWith(session: next);
    }
  }

  Future<void> _clearTyping() async {
    _typingIdle?.cancel();
    if (!_localTyping) return;
    await _setTyping(false);
  }

  void removePendingAttachment(LiveChatAttachment attachment) {
    final next = state.pendingAttachments
        .where((a) => a.url != attachment.url)
        .toList();
    state = state.copyWith(pendingAttachments: next);
  }

  Future<void> pickAndQueueFiles({
    required List<({String name, Uint8List bytes, String? mimeType})> files,
  }) async {
    if (files.isEmpty) return;
    if (state.awaitingChoice) return;
    var session = state.session;
    if (session == null) {
      await startOrResume();
      session = state.session;
    }
    if (session == null || !session.isOpen) return;
    final service = await _service();
    final key = _visitorKey;
    if (service == null || key == null) return;

    state = state.copyWith(uploading: true, clearError: true);
    try {
      final uploaded = <LiveChatAttachment>[];
      for (final file in files) {
        if (file.bytes.isEmpty) continue;
        uploaded.add(
          await service.uploadVisitorFile(
            visitorKey: key,
            fileName: file.name,
            bytes: file.bytes,
            mimeType: file.mimeType,
          ),
        );
      }
      if (uploaded.isEmpty) {
        state = state.copyWith(
          uploading: false,
          error: 'Could not read selected files.',
        );
        return;
      }
      state = state.copyWith(
        uploading: false,
        pendingAttachments: [...state.pendingAttachments, ...uploaded],
      );
    } catch (e) {
      state = state.copyWith(uploading: false, error: userFacingError(e));
    }
  }

  Future<void> send(String body) async {
    final text = body.trim();
    final attachments = List<LiveChatAttachment>.from(state.pendingAttachments);
    if (text.isEmpty && attachments.isEmpty) return;

    await ensureStarted();
    if (state.awaitingChoice) return;

    var session = state.session;
    if (session == null) {
      await startOrResume();
      session = state.session;
      if (session == null) return;
    }
    if (!session.isOpen) return;
    final service = await _service();
    final key = _visitorKey;
    if (service == null || key == null) return;

    await _clearTyping();
    state = state.copyWith(
      sending: true,
      clearError: true,
      pendingAttachments: const [],
    );
    try {
      final type = attachments.isEmpty
          ? 'text'
          : (attachments.every((a) => a.isImage) ? 'image' : 'file');
      await service.sendVisitorMessage(
        sessionId: session.id,
        visitorKey: key,
        body: text,
        senderName: state.displayName.trim().isEmpty
            ? null
            : state.displayName.trim(),
        attachments: attachments,
        messageType: type,
      );
      await _refreshMessages();
      state = state.copyWith(sending: false);
    } catch (e) {
      state = state.copyWith(
        sending: false,
        pendingAttachments: attachments,
        error: userFacingError(e),
      );
    }
  }

  Future<void> endChat() async {
    final session = state.session;
    final key = _visitorKey;
    final service = await _service();
    if (session == null || key == null || service == null) return;
    try {
      await _clearTyping();
      final ended = await service.endSession(
        sessionId: session.id,
        visitorKey: key,
      );
      await _detachBroadcast();
      _stopPoll();
      String? preview;
      for (final message in state.messages.reversed) {
        final body = message.body.trim();
        if (body.isNotEmpty) {
          preview = body;
          break;
        }
      }
      preview ??= state.savedPreview;
      if (preview != null) await service.persistPreview(preview);
      state = state.copyWith(
        clearSession: true,
        savedSession: ended,
        savedPreview: preview ?? service.storedPreview,
        offerResume: true,
        messages: const [],
        pendingAttachments: const [],
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: userFacingError(e));
    }
  }
}

final liveChatVisitorControllerProvider =
    NotifierProvider<LiveChatVisitorController, LiveChatVisitorState>(
      LiveChatVisitorController.new,
    );

final adminLiveChatRealtimeConnectedProvider = StateProvider<bool>(
  (ref) => false,
);

/// Admin: messages for the selected Support live-chat session (realtime).
final adminLiveChatMessagesProvider = FutureProvider.autoDispose
    .family<List<LiveChatMessage>, String>((ref, sessionId) async {
      final service = await ref.watch(liveChatServiceProvider.future);
      if (service == null) return const [];
      if (!ref.watch(supabaseConfiguredProvider)) return const [];

      final client = ref.watch(supabaseClientProvider);
      final channel = client.channel('admin-live-chat-$sessionId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (_) => ref.invalidateSelf(),
        )
        ..subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            deferProviderMutation(
              () =>
                  ref
                          .read(adminLiveChatRealtimeConnectedProvider.notifier)
                          .state =
                      true,
            );
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            deferProviderMutation(
              () =>
                  ref
                          .read(adminLiveChatRealtimeConnectedProvider.notifier)
                          .state =
                      false,
            );
          }
        });
      ref.onDispose(() {
        unawaited(client.removeChannel(channel));
        deferProviderMutation(
          () =>
              ref.read(adminLiveChatRealtimeConnectedProvider.notifier).state =
                  false,
        );
      });
      return service.listSessionMessages(sessionId);
    });
