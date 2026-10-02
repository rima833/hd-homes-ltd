import 'dart:convert';
import 'dart:typed_data';

import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_service.dart';
import 'package:hdhomesproject/features/live_chat/domain/entities/live_chat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Visitor + agent live chat against Supabase RPCs / tables.
class LiveChatService {
  LiveChatService({
    required SupabaseClient client,
    required SharedPreferences prefs,
    MediaService? mediaService,
  }) : _client = client,
       _prefs = prefs,
       _media = mediaService;

  final SupabaseClient _client;
  final SharedPreferences _prefs;
  final MediaService? _media;

  static const _sessionPrefKey = 'hd_live_chat_session_id_v1';
  static const _previewPrefKey = 'hd_live_chat_last_preview_v1';
  static const _bucket = 'live-chat';

  String? get storedSessionId {
    final id = _prefs.getString(_sessionPrefKey);
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> persistSessionId(String? id) async {
    if (id == null || id.isEmpty) {
      await _prefs.remove(_sessionPrefKey);
    } else {
      await _prefs.setString(_sessionPrefKey, id);
    }
  }

  Future<void> clearStoredSession() async {
    await persistSessionId(null);
    await _prefs.remove(_previewPrefKey);
  }

  String? get storedPreview {
    final text = _prefs.getString(_previewPrefKey);
    if (text == null || text.trim().isEmpty) return null;
    return text.trim();
  }

  Future<void> persistPreview(String? text) async {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _prefs.remove(_previewPrefKey);
    } else {
      await _prefs.setString(
        _previewPrefKey,
        trimmed.length > 160 ? '${trimmed.substring(0, 157)}...' : trimmed,
      );
    }
  }

  Map<String, dynamic>? _coerceMap(dynamic row) {
    if (row == null) return null;
    if (row is Map<String, dynamic>) return row;
    if (row is Map) return Map<String, dynamic>.from(row);
    if (row is List && row.isNotEmpty) return _coerceMap(row.first);
    if (row is String) {
      try {
        return _coerceMap(jsonDecode(row));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<LiveChatSession> startSession({
    required String visitorKey,
    String? customerName,
    String? customerEmail,
  }) async {
    final row = await _client.rpc(
      'live_chat_start',
      params: {
        'p_visitor_key': visitorKey,
        'p_customer_name': customerName,
        'p_customer_email': customerEmail,
      },
    );
    final map = _coerceMap(row);
    if (map == null || map['id'] == null) {
      throw StateError('Could not start live chat session');
    }
    final session = LiveChatSession.fromJson(map);
    await persistSessionId(session.id);
    return session;
  }

  Future<LiveChatSession?> resumeStoredSession({
    required String visitorKey,
  }) async {
    final id = storedSessionId;
    if (id == null) return null;
    try {
      final row = await _client.rpc(
        'live_chat_get_session',
        params: {'p_session_id': id, 'p_visitor_key': visitorKey},
      );
      final map = _coerceMap(row);
      if (map == null) {
        await clearStoredSession();
        return null;
      }
      return LiveChatSession.fromJson(map);
    } catch (_) {
      await clearStoredSession();
      return null;
    }
  }

  Future<LiveChatSession?> getVisitorSession({
    required String sessionId,
    required String visitorKey,
  }) async {
    try {
      final row = await _client.rpc(
        'live_chat_get_session',
        params: {'p_session_id': sessionId, 'p_visitor_key': visitorKey},
      );
      final map = _coerceMap(row);
      if (map == null) return null;
      return LiveChatSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<LiveChatMessage> sendVisitorMessage({
    required String sessionId,
    required String visitorKey,
    required String body,
    String? senderName,
    List<LiveChatAttachment> attachments = const [],
    String messageType = 'text',
  }) async {
    final row = await _client.rpc(
      'live_chat_send_visitor',
      params: {
        'p_session_id': sessionId,
        'p_visitor_key': visitorKey,
        'p_body': body,
        'p_sender_name': senderName,
        'p_attachments': attachments.map((a) => a.toJson()).toList(),
        'p_message_type': messageType,
      },
    );
    final map = _coerceMap(row);
    if (map == null) throw StateError('Could not send message');
    return LiveChatMessage.fromJson(map);
  }

  Future<LiveChatAttachment> uploadVisitorFile({
    required String visitorKey,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final mime = mimeType ?? 'application/octet-stream';
    final media = _media;
    if ((mime.startsWith('image/') || mime.startsWith('video/')) &&
        media != null &&
        media.isCloudinaryEnabled) {
      final url = await media.uploadPublicWebsiteMedia(
        bytes: bytes,
        contentType: mime,
        originalFilename: fileName,
        folder: 'hdhomes/general/website/live-chat',
      );
      return LiveChatAttachment(
        name: fileName,
        url: url,
        mimeType: mime,
        sizeBytes: bytes.length,
      );
    }

    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path =
        'visitor/${visitorKey.trim()}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mime),
        );
    final url = _client.storage.from(_bucket).getPublicUrl(path);
    return LiveChatAttachment(
      name: fileName,
      url: url,
      mimeType: mime,
      sizeBytes: bytes.length,
    );
  }

  Future<LiveChatSession?> setTyping({
    required String sessionId,
    required String visitorKey,
    required bool isTyping,
    String actor = 'visitor',
  }) async {
    try {
      final row = await _client.rpc(
        'live_chat_set_typing',
        params: {
          'p_session_id': sessionId,
          'p_visitor_key': visitorKey,
          'p_is_typing': isTyping,
          'p_actor': actor,
        },
      );
      final map = _coerceMap(row);
      if (map == null) return null;
      return LiveChatSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Staff typing indicator (authenticated). `visitor_key` is ignored by RPC.
  Future<LiveChatSession?> setAgentTyping({
    required String sessionId,
    required bool isTyping,
  }) {
    return setTyping(
      sessionId: sessionId,
      visitorKey: '',
      isTyping: isTyping,
      actor: 'agent',
    );
  }

  Future<List<LiveChatMessage>> listVisitorMessages({
    required String sessionId,
    required String visitorKey,
  }) async {
    final rows = await _client.rpc(
      'live_chat_list_messages',
      params: {'p_session_id': sessionId, 'p_visitor_key': visitorKey},
    );
    if (rows is! List) return const [];
    return rows
        .map(
          (e) => LiveChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<LiveChatMessage>> listSessionMessages(String sessionId) async {
    final rows = await _client
        .from('live_chat_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map(
          (e) => LiveChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<LiveChatAttachment> uploadAgentFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final mime = mimeType ?? 'application/octet-stream';
    final media = _media;
    if ((mime.startsWith('image/') || mime.startsWith('video/')) &&
        media != null &&
        media.isCloudinaryEnabled) {
      final asset = await media.upload(
        UploadMediaRequest(
          bytes: bytes,
          contentType: mime,
          originalFilename: fileName,
          entityType: MediaEntityType.library,
          role: 'website',
          folderName: 'live-chat',
        ),
      );
      return LiveChatAttachment(
        name: fileName,
        url: asset.deliveryUrl,
        mimeType: mime,
        sizeBytes: bytes.length,
      );
    }

    final uid = _client.auth.currentUser?.id ?? 'staff';
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path =
        'agent/$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mime),
        );
    final url = _client.storage.from(_bucket).getPublicUrl(path);
    return LiveChatAttachment(
      name: fileName,
      url: url,
      mimeType: mime,
      sizeBytes: bytes.length,
    );
  }

  Future<LiveChatSession> claimSession(String sessionId) async {
    final row = await _client.rpc(
      'live_chat_claim_session',
      params: {'p_session_id': sessionId},
    );
    final map = _coerceMap(row);
    if (map == null) throw StateError('Could not claim session');
    return LiveChatSession.fromJson(map);
  }

  Future<void> setMyPresence(String status) async {
    await _client.rpc(
      'set_my_support_agent_presence',
      params: {'p_status': status},
    );
  }

  Future<void> heartbeatPresence() async {
    await _client.rpc('heartbeat_my_support_agent');
  }

  /// Public: whether any agent heartbeated as available/busy within ~2 minutes.
  Future<LiveChatSupportPresence> fetchSupportPresence() async {
    try {
      final row = await _client.rpc('live_chat_agents_online');
      final map = _coerceMap(row);
      if (map != null) {
        return LiveChatSupportPresence(
          online: map['online'] == true,
          agentsPresent: (map['agents_present'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return const LiveChatSupportPresence(online: false, agentsPresent: 0);
  }

  Future<LiveChatSession> assignSession({
    required String sessionId,
    required String agentId,
  }) async {
    final row = await _client.rpc(
      'live_chat_assign_session',
      params: {'p_session_id': sessionId, 'p_agent_id': agentId},
    );
    final map = _coerceMap(row);
    if (map == null) throw StateError('Could not assign session');
    return LiveChatSession.fromJson(map);
  }

  Future<void> mergeSessionMetadata({
    required String sessionId,
    required Map<String, dynamic> patch,
  }) async {
    final row = await _client
        .from('live_chat_sessions')
        .select('metadata')
        .eq('id', sessionId)
        .maybeSingle();
    final current = row?['metadata'];
    final meta = current is Map
        ? Map<String, dynamic>.from(current)
        : <String, dynamic>{};
    meta.addAll(patch);
    await _client
        .from('live_chat_sessions')
        .update({'metadata': meta})
        .eq('id', sessionId);
  }

  Future<LiveChatMessage> sendAgentMessage({
    required String sessionId,
    required String body,
    String? senderName,
    List<LiveChatAttachment> attachments = const [],
    String messageType = 'text',
  }) async {
    final row = await _client.rpc(
      'live_chat_send_agent',
      params: {
        'p_session_id': sessionId,
        'p_body': body,
        'p_sender_name': senderName,
        'p_attachments': attachments.map((a) => a.toJson()).toList(),
        'p_message_type': messageType,
      },
    );
    final map = _coerceMap(row);
    if (map == null) throw StateError('Could not send agent message');
    return LiveChatMessage.fromJson(map);
  }

  Future<LiveChatSession> endSession({
    required String sessionId,
    String? visitorKey,
  }) async {
    final row = await _client.rpc(
      'live_chat_end_session',
      params: {'p_session_id': sessionId, 'p_visitor_key': visitorKey},
    );
    final map = _coerceMap(row);
    if (map == null) throw StateError('Could not end session');
    final session = LiveChatSession.fromJson(map);
    if (visitorKey != null) await persistSessionId(session.id);
    return session;
  }
}
