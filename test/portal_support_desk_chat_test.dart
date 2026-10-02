import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_support_desk.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  testWidgets('chat bubbles hug their text and the composer stays readable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PortalSupportDeskThread(
            ticket: const PortalSupportDeskTicket(
              id: '1',
              subject: 'my property',
              status: 'open',
            ),
            messages: const [
              PortalSupportDeskMessage(body: 'hi', isMine: false),
              PortalSupportDeskMessage(body: 'ok', isMine: true),
            ],
            loading: false,
            canReply: true,
            replyController: controller,
            onSend: () {},
            sending: false,
            onAttach: () {},
            attachmentLabel: 'lease.pdf',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder bubbleOf(String text, Color color) {
      return find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration && decoration.color == color;
        }),
      );
    }

    final goldText = tester.getSize(find.text('ok'));
    final whiteText = tester.getSize(find.text('hi'));
    final gold = tester.getSize(
      bubbleOf('ok', PortalSupportDeskColors.bubble),
    );
    final white = tester.getSize(
      bubbleOf('hi', PortalSupportDeskColors.supportBubble),
    );

    expect(gold.width, lessThan(goldText.width + 48));
    expect(white.width, lessThan(whiteText.width + 48));
    expect(gold.width, lessThan(160));
    expect(white.width, lessThan(160));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, PortalSupportDeskColors.ink);
    expect(field.decoration?.filled, isTrue);
    expect(field.decoration?.fillColor, const Color(0xFFFBF9F6));
    expect(
      field.decoration?.hintStyle?.color,
      const Color(0xFF6E675F),
    );

    final attachment = tester.widget<Text>(find.text('lease.pdf'));
    expect(attachment.style?.color, PortalSupportDeskColors.ink);

    final clip = tester.element(find.byIcon(LucideIcons.paperclip).first);
    final clipColor = IconTheme.of(clip).color!;
    expect(clipColor.computeLuminance(), lessThan(0.45));
  });
}
