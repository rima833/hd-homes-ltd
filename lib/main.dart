import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hdhomesproject/app.dart';

import 'package:hdhomesproject/core/config/supabase_config.dart';

import 'package:hdhomesproject/core/utils/app_logger.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();



  if (SupabaseConfig.isConfigured) {

    await Supabase.initialize(

      url: SupabaseConfig.url,

      publishableKey: SupabaseConfig.publishableKey,

    );

    AppLogger.info('Supabase initialized');

  } else {

    AppLogger.warning('Supabase not configured — running in offline mode');

  }



  runApp(

    const ProviderScope(

      child: HdHomesApp(),

    ),

  );

}


