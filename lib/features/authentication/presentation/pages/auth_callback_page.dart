import 'dart:async';



import 'package:flutter/material.dart';

import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:go_router/go_router.dart';

import 'package:hdhomesproject/core/constants/route_paths.dart';

import 'package:hdhomesproject/core/network/supabase_provider.dart';

import 'package:hdhomesproject/core/theme/app_theme.dart';

import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



/// Handoff for Supabase Auth deep links that land on `/auth/callback`.

///

/// Keeps the page mounted long enough for `detectSessionInUri` to consume

/// hash/query tokens, then routes to verify-email or reset-password.

/// Do not use a GoRouter `redirect` here — that can drop URL fragments.

class AuthCallbackPage extends HookConsumerWidget {

  const AuthCallbackPage({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    useEffect(() {

      if (!ref.read(supabaseConfiguredProvider)) {

        WidgetsBinding.instance.addPostFrameCallback((_) {

          if (context.mounted) context.go(RoutePaths.login);

        });

        return null;

      }



      final client = ref.read(supabaseClientProvider);

      // Capture before detectSessionInUrl clears the hash.

      final landing = Uri.base;

      final landingFragment = landing.fragment.toLowerCase();

      final landingType =

          (landing.queryParameters['type'] ?? '').toLowerCase();

      final code = landing.queryParameters['code'];

      var navigated = false;

      var sawRecoveryEvent = false;



      bool isRecovery(AuthChangeEvent? event) {

        return sawRecoveryEvent ||

            event == AuthChangeEvent.passwordRecovery ||

            landingType == 'recovery' ||

            landingFragment.contains('type=recovery');

      }



      void goNext(AuthChangeEvent? event) {

        if (navigated || !context.mounted) return;

        navigated = true;

        if (isRecovery(event)) {
          context.go(RoutePaths.resetPassword);
          return;
        }
        final email = client.auth.currentUser?.email ?? '';
        context.go(
          Uri(
            path: RoutePaths.verifyEmail,
            queryParameters: {
              'confirmed': '1',
              if (email.isNotEmpty) 'email': email,
            },
          ).toString(),
        );

      }



      Future<void> consumeCode() async {

        if (code == null || code.isEmpty) return;

        try {

          await client.auth.exchangeCodeForSession(code);

        } catch (_) {}

      }



      final sub = client.auth.onAuthStateChange.listen((data) {

        if (data.event == AuthChangeEvent.passwordRecovery) {

          sawRecoveryEvent = true;

        }

        if (data.session != null ||

            data.event == AuthChangeEvent.passwordRecovery) {

          goNext(data.event);

        }

      });



      unawaited(consumeCode().then((_) {

        if (client.auth.currentSession != null && !navigated) {

          WidgetsBinding.instance.addPostFrameCallback((_) => goNext(null));

        }

      }));



      if (client.auth.currentSession != null) {

        WidgetsBinding.instance.addPostFrameCallback((_) => goNext(null));

      }



      final timeout = Timer(const Duration(seconds: 4), () {

        if (!navigated && context.mounted) {

          goNext(null);

        }

      });



      return () {

        sub.cancel();

        timeout.cancel();

      };

    }, const []);



    return Scaffold(

      body: SafeArea(

        child: Center(

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              Image.asset(AppTheme.logoAsset, height: 48),

              const SizedBox(height: AppSpacing.xl),

              const CircularProgressIndicator(color: AppColors.gold),

              const SizedBox(height: AppSpacing.lg),

              Text(

                'Confirming your HD Homes session…',

                style: Theme.of(context).textTheme.titleMedium,

                textAlign: TextAlign.center,

              ),

            ],

          ),

        ),

      ),

    );

  }

}


