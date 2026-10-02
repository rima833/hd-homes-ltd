import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hdhomesproject/app.dart';
import 'package:hdhomesproject/core/config/supabase_config.dart';
import 'package:hdhomesproject/core/errors/global_error_handlers.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:hdhomesproject/features/authentication/domain/services/auth_confirmation_link.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await runGuardedApp(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Path URLs so /contact deep-links on web.
    if (kIsWeb) {
      usePathUrlStrategy();
      // Snapshot the confirm-email redirect before Auth strips ?code= / #tokens.
      AuthConfirmationLink.captureLaunchUrl(Uri.base);
    }
    installGlobalErrorHandlers();
    await _loadIconFonts();

    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      AppLogger.info('Supabase initialized');
    } else {
      AppLogger.warning('Supabase not configured — running in offline mode');
    }

    runApp(const ProviderScope(child: HdHomesApp()));
  });
}

/// Registers the icon fonts under the family names [Icon] widgets request.
/// On web those families otherwise fall through to the text font and paint
/// as empty squares.
Future<void> _loadIconFonts() async {
  await Future.wait([
    _loadFontFamily('MaterialIcons', 'assets/fonts/MaterialIcons-Regular.otf'),
    _loadFontFamily(
      'packages/lucide_icons/Lucide',
      'assets/fonts/lucide.ttf',
    ),
  ]);
}

Future<void> _loadFontFamily(String family, String asset) async {
  try {
    final data = await rootBundle.load(asset);
    final loader = FontLoader(family)..addFont(Future.value(data));
    await loader.load();
  } catch (error, stack) {
    AppLogger.warning('Icon font $family did not load: $error\n$stack');
  }
}
