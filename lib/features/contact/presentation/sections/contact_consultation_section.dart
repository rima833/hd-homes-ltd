import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/consultation_booking_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _panel = Color(0xFF15171D);
const _card = Color(0xFF1C1F28);
const _gold = Color(0xFFD4AF37);
const _muted = Color(0xFF9CA3AF);
const _border = Color(0x33D4AF37);

/// Premium consultation CTA — routes to the full `/book-consultation` flow.
class ContactConsultationSection extends ConsumerWidget {
  const ContactConsultationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(consultationDepartmentsProvider);
    final deptCount = departmentsAsync.valueOrNull?.length ?? 8;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final wide = maxW.isFinite && maxW >= 900;
        return Container(
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          clipBehavior: Clip.antiAlias,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildContent(context, deptCount)),
                    Expanded(flex: 2, child: _buildPreview(context)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildContent(context, deptCount),
                    _buildPreview(context),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, int deptCount) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRIVATE CONSULTATION',
            style: GoogleFonts.inter(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: _gold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Book Your Private Consultation',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Meet with specialists in sales, investment, legal, architecture, '
            'construction, mortgages, or partnerships — with live availability.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _FeaturePill(icon: LucideIcons.calendar, label: 'Live slots'),
              _FeaturePill(icon: LucideIcons.userCheck, label: 'Expert advisors'),
              _FeaturePill(
                icon: LucideIcons.video,
                label: 'Phone, video, or office',
              ),
              _FeaturePill(
                icon: LucideIcons.shieldCheck,
                label: 'Instant confirmation',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => context.go(RoutePaths.bookConsultation),
                icon: const Icon(LucideIcons.calendarPlus, size: 18),
                label: const Text('Start booking'),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Text(
                '$deptCount departments available',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Container(
      color: _card,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const _StepRow(
            number: '1',
            title: 'Personal details',
            subtitle: 'Name, phone, email',
          ),
          const _StepRow(
            number: '2',
            title: 'Choose department',
            subtitle: 'Sales, legal, investment…',
          ),
          const _StepRow(
            number: '3',
            title: 'Pick a time',
            subtitle: 'Real-time calendar slots',
          ),
          const _StepRow(
            number: '4',
            title: 'Confirm',
            subtitle: 'Review & book instantly',
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.clock,
                  size: 16,
                  color: _gold.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Typical response: under 15 minutes',
                    style: GoogleFonts.inter(fontSize: 12, color: _muted),
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

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold),
            ),
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _gold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
