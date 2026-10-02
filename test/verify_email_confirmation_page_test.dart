import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/authentication/domain/services/auth_confirmation_link.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/verify_email_page.dart';

Future<void> _pumpVerify(
  WidgetTester tester, {
  bool openedFromConfirmationLink = false,
  String? confirmationError,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark,
        home: VerifyEmailPage(
          email: 'person@example.com',
          openedFromConfirmationLink: openedFromConfirmationLink,
          confirmationError: confirmationError,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    AuthConfirmationLink.launch = null;
    AuthConfirmationLink.clearRawLaunchUri();
  });

  testWidgets('confirm link shows that the email has been confirmed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpVerify(tester, openedFromConfirmationLink: true);

    expect(tester.takeException(), isNull);
    expect(find.text('Your email has been confirmed'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Waiting for confirmation'), findsNothing);
    expect(find.text('Verify your email'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('waiting screen stays waiting until the confirm link opens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpVerify(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Waiting for confirmation'), findsOneWidget);
    expect(find.text('Your email has been confirmed'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('expired confirm link explains the failure', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpVerify(
      tester,
      confirmationError: 'Email link is invalid or has expired',
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('expired or was already used'), findsOneWidget);
    expect(find.text('Your email has been confirmed'), findsNothing);
    expect(find.text('Waiting for confirmation'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
