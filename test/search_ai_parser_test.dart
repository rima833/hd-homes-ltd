import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/properties/data/models/marketplace_property.dart';
import 'package:hdhomesproject/features/search/data/providers/search_intelligence_provider.dart';

void main() {
  group('parseAiSearchQuery', () {
    test('extracts location, type, bedrooms, and budget', () {
      final result = parseAiSearchQuery(
        'Show me a 4-bedroom duplex in Abuja under ₦180M with a swimming pool.',
      );

      expect(result.extractedCriteria, contains('Location: Abuja'));
      expect(result.extractedCriteria, contains('Type: Duplex'));
      expect(result.extractedCriteria, contains('Bedrooms: 4+'));
      expect(result.extractedCriteria, contains('Budget: under ₦180M'));
      expect(result.extractedCriteria, contains('Amenity: Swimming Pool'));
      expect(result.filters.state, 'FCT');
      expect(result.confidence, greaterThan(70));
    });

    test('detects investment intent', () {
      final result = parseAiSearchQuery('Find investment properties with at least 15% ROI');
      expect(result.extractedCriteria, contains('Goal: Investment'));
      expect(result.filters.purpose, PropertyPurpose.invest);
    });
  });
}
