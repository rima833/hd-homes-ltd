import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether Supabase has been initialized with valid credentials.
final supabaseConfiguredProvider = Provider<bool>((ref) {
  return SupabaseConfig.isConfigured;
});

/// Injected Supabase client. Throws if Supabase is not initialized.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) {
    throw StateError('Supabase is not configured');
  }
  return Supabase.instance.client;
});
