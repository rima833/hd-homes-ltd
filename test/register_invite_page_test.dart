import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:hdhomesproject/features/authentication/domain/services/organization_service.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/register_page.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';

class _StaffPreviewService extends OrganizationService {
  _StaffPreviewService() : super(audit: AuditService());

  @override
  Future<Map<String, dynamic>?> previewAnyInvitation(String token) async {
    return {
      'valid': true,
      'kind': 'staff',
      'status': 'pending',
      'email': 'invitee@example.com',
      'role_slug': 'admin',
      'first_name': 'Calvin',
      'last_name': 'Ade',
    };
  }
}

void main() {
  testWidgets('staff invite opens the registration form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organizationServiceProvider.overrideWithValue(_StaffPreviewService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const RegisterPage(
            invitationToken: 'invite-token',
            initialEmail: 'invitee@example.com',
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Something went wrong'), findsNothing);
    expect(find.text('How will you use HD Homes?'), findsNothing);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Work email'), findsOneWidget);
    expect(find.text('Create staff access'), findsOneWidget);
    expect(
      find.text('Staff invite: join as admin (invitee@example.com).'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
