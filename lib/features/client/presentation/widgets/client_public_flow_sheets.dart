import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/consultation/presentation/pages/book_consultation_page.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/consultation_booking_controller.dart';
import 'package:hdhomesproject/features/inspection/presentation/pages/book_inspection_page.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_booking_controller.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_luxury_kit.dart';
import 'package:hdhomesproject/features/consultation/presentation/widgets/consultation_luxury_kit.dart';

/// Opens the same public Book Inspection wizard inside the client portal shell.
Future<void> showClientInspectionBookingSheet(
  BuildContext context,
  WidgetRef ref, {
  String? initialPropertyId,
  String? initialEstateId,
}) async {
  ref.read(inspectionBookingControllerProvider.notifier).reset();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: InspectionLux.bg,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return SizedBox(
        height: height * 0.96,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book inspection',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A3140)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: BookInspectionPage(
                  embedded: true,
                  initialPropertyId: initialPropertyId,
                  initialEstateId: initialEstateId,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Opens the same public Book Consultation wizard inside the client portal shell.
Future<void> showClientConsultationBookingSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  ref.read(consultationBookingControllerProvider.notifier).reset();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ConsultationLux.bg,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return SizedBox(
        height: height * 0.96,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book consultation',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2A3140)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: const BookConsultationPage(embedded: true),
              ),
            ),
          ],
        ),
      );
    },
  );
}
