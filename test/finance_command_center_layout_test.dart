import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hdhomesproject/features/fapms/presentation/pages/finance_command_center_page.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/payment_verification_providers.dart';
import 'package:hdhomesproject/features/fapms/presentation/widgets/finance_command_center_shell.dart';

/// Simulates admin shell chrome above finance content.
class _AdminShellHarness extends StatelessWidget {
  const _AdminShellHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          color: AppColors.charcoal,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            'Admin Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Admin > Finance',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

void main() {
  group('FinanceCommandCenterPage layout', () {
    Future<void> pumpFinancePage(
      WidgetTester tester, {
      required Size viewport,
    }) async {
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseConfiguredProvider.overrideWithValue(false),
            fapmsSnapshotProvider.overrideWith(
              (ref) async => FapmsDemo.snapshot(),
            ),
            fapmsRealtimeProvider.overrideWith((ref) {}),
            paymentVerificationRealtimeProvider.overrideWith((ref) {}),
            paymentIntentsProvider.overrideWith((ref) async => []),
            pendingPaymentIntentsProvider.overrideWith((ref) async => []),
            pendingVerificationCountProvider.overrideWith(
              (ref) => const AsyncValue.data(0),
            ),
            receivingAccountsProvider.overrideWith((ref) async => []),
            paymentMethodsConfigProvider.overrideWith((ref) async => []),
            lateFeeRulesProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: viewport),
              child: Scaffold(
                backgroundColor: Colors.black,
                body: SizedBox(
                  width: viewport.width,
                  height: viewport.height,
                  child: _AdminShellHarness(
                    child: const FinanceCommandCenterPage(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders CRM-style finance desk shell', (tester) async {
      await pumpFinancePage(
        tester,
        viewport: const Size(1400, 800),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FinanceDeskSidebar), findsOneWidget);
      expect(find.text('Ops briefing'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('fits tight viewport without overflow', (tester) async {
      await pumpFinancePage(
        tester,
        viewport: const Size(1024, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('live alert'), findsOneWidget);
    });

    testWidgets('sidebar navigation switches sections', (tester) async {
      await pumpFinancePage(
        tester,
        viewport: const Size(1400, 800),
      );

      await tester.tap(find.text('Banking'));
      await tester.pumpAndSettle();
      expect(find.text('Bank accounts'), findsOneWidget);
    });
  });
}
