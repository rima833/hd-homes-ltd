import 'package:hdhomesproject/features/consultation/domain/entities/customer_consultation_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerConsultationService {
  CustomerConsultationService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<List<CustomerConsultationBooking>> listMyBookings() async {
    final client = _client;
    if (client == null) return const [];

    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];

    final rows = await client
        .from('consultation_bookings')
        .select(
          '*, consultation_departments(name), '
          'consultation_advisors(full_name, phone, whatsapp, email)',
        )
        .eq('user_id', userId)
        .order('scheduled_at', ascending: false);

    return (rows as List)
        .map(
          (e) => CustomerConsultationBooking.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> cancelBooking(String bookingId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    await client.rpc(
      'customer_cancel_consultation',
      params: {'p_booking_id': bookingId},
    );
  }

  Future<void> claimGuestBookings() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc('claim_my_consultation_bookings');
    } catch (_) {
      // Optional helper — ignore if unavailable.
    }
  }
}
