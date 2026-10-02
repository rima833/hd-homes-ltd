import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Asks a returning visitor to continue the saved chat or start a new one.
class LiveChatResumePrompt extends StatelessWidget {
  const LiveChatResumePrompt({
    super.key,
    required this.state,
    required this.onContinue,
    required this.onStartNew,
    this.compact = false,
  });

  final LiveChatVisitorState state;
  final VoidCallback onContinue;
  final VoidCallback onStartNew;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final saved = state.savedSession;
    final open = saved?.isOpen == true;
    final when = saved?.startedAt?.toLocal();
    final whenLabel = when == null ? null : DateFormat('MMM d, y').format(when);
    final preview = state.savedPreview;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.messageCircle, color: AppColors.gold, size: 28),
            const SizedBox(height: 10),
            Text(
              'Saved conversation',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 15 : 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              open
                  ? 'Continue where you left off, or start a new chat.'
                  : 'Your last chat is saved. View it, or start a new one.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: const Color(0xFF9A9A9A),
                height: 1.4,
                fontSize: compact ? 12.5 : 13.5,
              ),
            ),
            if (preview != null || whenLabel != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x33D4AF37)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (whenLabel != null)
                      Text(
                        whenLabel,
                        style: GoogleFonts.manrope(
                          color: const Color(0xFF9A9A9A),
                          fontSize: 11,
                        ),
                      ),
                    if (preview != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.loading ? null : onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF1C1915),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(open ? 'Continue conversation' : 'View saved chat'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: state.loading ? null : onStartNew,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x33D4AF37)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Start new chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
