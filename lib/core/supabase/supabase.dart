/// Legacy export — prefer [supabaseClientProvider] from core/network.
library;

export 'package:hdhomesproject/core/network/supabase_provider.dart'
    show supabaseClientProvider;
export 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase => Supabase.instance.client;
