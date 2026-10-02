import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';

void main() {
  group('Client portal routes', () {
    test('all 12 client modules have route paths', () {
      expect(RoutePaths.client, '/client');
      expect(RoutePaths.clientProperties, '/client/properties');
      expect(RoutePaths.clientSaved, '/client/saved');
      expect(RoutePaths.clientPayments, '/client/payments');
      expect(RoutePaths.clientDocuments, '/client/documents');
      expect(RoutePaths.clientConstruction, '/client/construction');
      expect(RoutePaths.clientInspections, '/client/inspections');
      expect(RoutePaths.clientMessages, '/client/messages');
      expect(RoutePaths.clientNotifications, '/client/notifications');
      expect(RoutePaths.clientSupport, '/client/support');
      expect(RoutePaths.clientReferrals, '/client/referrals');
      expect(RoutePaths.clientSettings, '/client/settings');
      expect(RoutePaths.clientMore, '/client/more');
      expect(RoutePaths.clientTools, '/client/tools');
      expect(RoutePaths.clientApplications, '/client/applications');
    });

    test('More hub is distinct from Settings', () {
      expect(RoutePaths.clientMore, isNot(RoutePaths.clientSettings));
    });

    test('property detail route is nested under properties', () {
      expect(
        RoutePaths.clientPropertyDetail('abc-123'),
        '/client/properties/abc-123',
      );
    });
  });

  group('ClientProperty model', () {
    test('parses nested property join', () {
      final property = ClientProperty.fromJson({
        'id': 'cp-1',
        'client_id': 'client-1',
        'property_id': 'prop-1',
        'purchase_price': 45000000,
        'payment_progress_pct': 65,
        'construction_progress_pct': 42,
        'properties': {
          'title': 'Lagos Premium Estate',
          'slug': 'lagos-premium',
          'property_locations': [
            {'city': 'Lagos', 'state': 'LA'},
          ],
          'property_images': [
            {'url': 'https://example.com/img.jpg', 'is_cover': true},
          ],
          'property_pricing': [
            {'price': 45000000, 'currency': 'NGN'},
          ],
        },
      });
      expect(property.title, 'Lagos Premium Estate');
      expect(property.location, 'Lagos, LA');
      expect(property.imageUrl, 'https://example.com/img.jpg');
      expect(property.paymentProgressPct, 65);
      expect(property.constructionProgressPct, 42);
      expect(property.formattedPrice, contains('45'));
    });

    test('parses nested property join when relations are objects', () {
      final property = ClientProperty.fromJson({
        'id': 'cp-2',
        'client_id': 'client-1',
        'property_id': 'prop-2',
        'properties': {
          'title': 'Victoria Crest',
          'slug': 'victoria-crest',
          'property_locations': {'city': 'Abuja', 'state': 'FCT'},
          'property_images': {'url': 'https://example.com/cover.jpg', 'is_cover': true},
          'property_pricing': {'price': 25000000, 'currency': 'NGN'},
        },
      });
      expect(property.title, 'Victoria Crest');
      expect(property.location, 'Abuja, FCT');
      expect(property.imageUrl, 'https://example.com/cover.jpg');
      expect(property.purchasePrice, 25000000);
    });
  });

  group('ClientInstallment', () {
    test('parses installment with nested property title as object', () {
      final installment = ClientInstallment.fromJson({
        'id': 'inst-1',
        'amount': 2500000,
        'due_date': '2026-08-21T00:00:00.000Z',
        'status': 'pending',
        'properties': {'title': 'Victoria Crest — Building 12 Unit 4'},
      });
      expect(installment.amount, 2500000);
      expect(installment.propertyTitle, 'Victoria Crest — Building 12 Unit 4');
      expect(installment.formattedAmount, contains('2'));
    });
  });

  group('ClientConstructionUpdate', () {
    test('parses nested project and photos as objects', () {
      final update = ClientConstructionUpdate.fromJson({
        'id': 'cu-1',
        'title': 'Foundation complete',
        'completion_percent': 35,
        'update_date': '2026-07-01T00:00:00.000Z',
        'projects': {'name': 'Victoria Crest'},
        'construction_photos': {'url': 'https://example.com/photo.jpg'},
      });
      expect(update.projectName, 'Victoria Crest');
      expect(update.photos, ['https://example.com/photo.jpg']);
      expect(update.completionPercent, 35);
    });
  });

  group('ClientDashboardSnapshot', () {
    test('formats currency totals', () {
      const snap = ClientDashboardSnapshot(
        client: ClientRecord(id: 'c1'),
        outstandingBalance: 2500000,
        totalPaid: 10000000,
      );
      expect(snap.formattedOutstanding, contains('2'));
      expect(snap.formattedTotalPaid, contains('10'));
    });
  });

  group('ClientReferralSummary', () {
    test('defaults to empty state', () {
      const summary = ClientReferralSummary();
      expect(summary.referralCode, '');
      expect(summary.pendingEarnings, 0);
      expect(summary.commissions, isEmpty);
    });
  });
}
