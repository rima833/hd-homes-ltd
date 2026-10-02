import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Smoke checks for deployed Cloudinary Edge Functions.
void main() {
  const projectHost = 'wbonjdqsifwsawhhxygl.supabase.co';

  Future<({int status, String body})> post(
    String functionName, {
    Map<String, dynamic>? body,
    bool withAnonKey = false,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.https(projectHost, '/functions/v1/$functionName'),
      );
      request.headers.set('Content-Type', 'application/json');
      if (withAnonKey) {
        // Publishable/anon key is client-safe; used only to reach the gateway.
        const anon = String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
          defaultValue: '',
        );
        if (anon.isNotEmpty) {
          request.headers.set('apikey', anon);
          request.headers.set('Authorization', 'Bearer $anon');
        }
      }
      request.write(jsonEncode(body ?? {'folder': 'hdhomes/general/website/test'}));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (status: response.statusCode, body: text);
    } finally {
      client.close();
    }
  }

  test('cloudinary-sign requires auth (401)', () async {
    final res = await post('cloudinary-sign');
    expect(res.status, 401);
  });

  test('cloudinary-delete requires auth (401)', () async {
    final res = await post('cloudinary-delete');
    expect(res.status, 401);
  });

  test('cloudinary-replace requires auth (401)', () async {
    final res = await post('cloudinary-replace');
    expect(res.status, 401);
  });

  test('cloudinary-migrate requires auth (401)', () async {
    final res = await post('cloudinary-migrate');
    expect(res.status, 401);
  });

  test('cloudinary-migrate-batch requires auth (401)', () async {
    final res = await post('cloudinary-migrate-batch');
    expect(res.status, 401);
  });

  test('cloudinary-sign-public rejects disallowed folders (403)', () async {
    final res = await post(
      'cloudinary-sign-public',
      body: {'folder': 'evil/path', 'resource_type': 'image'},
      withAnonKey: true,
    );
    // Without anon key the gateway may still return 401; with key expect 403.
    expect(res.status == 403 || res.status == 401, isTrue);
    if (res.status == 403) {
      expect(res.body, contains('not allowed'));
    }
  });

  test('cloudinary-sign-public allows website folder when reachable', () async {
    final res = await post(
      'cloudinary-sign-public',
      body: {
        'folder': 'hdhomes/general/website/test',
        'resource_type': 'image',
      },
      withAnonKey: true,
    );
    // 200 when secrets + gateway allow; 401 if anon key not injected in CI.
    expect(res.status == 200 || res.status == 401, isTrue);
    if (res.status == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      expect(json['signature'], isNotEmpty);
      expect(json['folder'], 'hdhomes/general/website/test');
      expect(json.containsKey('api_secret'), isFalse);
    }
  });
}
