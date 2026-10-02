import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/home/data/providers/payment_calculator_provider.dart';
import 'package:intl/intl.dart';

/// Applications and staff replies for whoever is using the calculator:
/// public site, client portal, or investor portal.
class CalculatorApplicationsPanel extends ConsumerWidget {
  const CalculatorApplicationsPanel({super.key});

  static const _gold = Color(0xFFD4AF37);
  static const _card = Color(0xFF161616);
  static const _muted = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isAuthenticatedProvider);
    if (!signedIn) {
      return _shell(
        child: Text(
          'Sign in with the same email you apply with to track this plan and read replies from HD Homes. Guests are contacted by phone, email, or WhatsApp.',
          style: GoogleFonts.manrope(color: _muted, fontSize: 13, height: 1.45),
        ),
      );
    }

    final async = ref.watch(myCalculatorApplicationsProvider);
    final money = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    );
    final when = DateFormat('d MMM yyyy, h:mm a');

    return async.when(
      loading: () => _shell(
        child: const LinearProgressIndicator(
          color: _gold,
          backgroundColor: Color(0xFF2A2A2A),
        ),
      ),
      error: (_, _) => _shell(
        child: Text(
          'Your applications could not be loaded.',
          style: GoogleFonts.manrope(color: _muted, fontSize: 13),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _shell(
            child: Text(
              'Applications you send from this calculator show up here, including replies from HD Homes.',
              style: GoogleFonts.manrope(
                color: _muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your plan applications',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Status updates and replies from HD Homes appear here.',
              style: GoogleFonts.manrope(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _ApplicationCard(application: items[i], money: money, when: when),
            ],
          ],
        );
      },
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.money,
    required this.when,
  });

  final CmsCalculatorApplication application;
  final NumberFormat money;
  final DateFormat when;

  @override
  Widget build(BuildContext context) {
    final app = application;
    final created = app.createdAt?.toLocal();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  app.planName.isEmpty ? 'Payment plan' : app.planName,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  app.statusLabel,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFFD4AF37),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (created != null) ...[
            const SizedBox(height: 4),
            Text(
              when.format(created),
              style: GoogleFonts.manrope(
                color: const Color(0xFF8A8A8A),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${money.format(app.monthlyPayment)} / month · '
            'Deposit ${money.format(app.depositAmount)} · '
            '${app.durationMonths} months',
            style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: app.hasReply
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: app.hasReply
                    ? const Color(0xFFD4AF37).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.hasReply ? 'Reply from HD Homes' : 'Waiting for a reply',
                  style: GoogleFonts.manrope(
                    color: app.hasReply
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFF8A8A8A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  app.hasReply
                      ? app.adminReply
                      : 'Your application is with the team. Their reply will appear here.',
                  style: GoogleFonts.manrope(
                    color: app.hasReply
                        ? Colors.white
                        : const Color(0xFF8A8A8A),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
