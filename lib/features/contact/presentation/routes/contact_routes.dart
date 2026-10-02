import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/consultation/presentation/pages/book_consultation_page.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/presentation/pages/contact_page.dart';
import 'package:hdhomesproject/features/inspection/presentation/pages/book_inspection_page.dart';

ContactScrollTarget? _targetFromQuery(String? section) {
  return switch (section?.toLowerCase()) {
    'options' || 'channels' => ContactScrollTarget.options,
    'offices' => ContactScrollTarget.offices,
    'inspection' || 'book-inspection' => ContactScrollTarget.inspection,
    'consultation' || 'book-consultation' => ContactScrollTarget.consultation,
    'callback' => ContactScrollTarget.callback,
    'chat' || 'live-chat' => ContactScrollTarget.liveChat,
    'whatsapp' => ContactScrollTarget.whatsapp,
    'support' => ContactScrollTarget.support,
    'careers' || 'career' => ContactScrollTarget.careers,
    'partnerships' || 'partnership' => ContactScrollTarget.partnerships,
    'newsletter' => ContactScrollTarget.newsletter,
    _ => null,
  };
}

List<RouteBase> get contactRoutes => [
      GoRoute(
        path: RoutePaths.contact,
        name: 'contact',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return ContactPage(
            initialTarget: _targetFromQuery(q['section']),
            fromBookInspection: q['from'] == 'book-inspection',
            initialInspectionPropertyId: q['property'],
            initialInspectionEstateId: q['estate'],
          );
        },
      ),
      // Full dedicated Book Inspection experience (not a Contact Hub stub).
      GoRoute(
        path: RoutePaths.bookInspection,
        name: 'book-inspection',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return BookInspectionPage(
            initialPropertyId: q['property'],
            initialEstateId: q['estate'],
          );
        },
      ),
      GoRoute(
        path: RoutePaths.bookConsultation,
        name: 'book-consultation',
        builder: (context, state) => const BookConsultationPage(),
      ),
    ];
