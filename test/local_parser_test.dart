import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/services/local_transformer_service.dart';

void main() {
  group('LocalTransformerService Tests', () {
    test('Parser returns canned mock data under the test environment', () async {
      // FLUTTER_TEST is set by `flutter test`, which routes extractCard
      // through the developer mock instead of ML Kit.
      final mockFile = XFile('test_image.png');
      final result = await LocalTransformerService.extractCard(mockFile);

      expect(result, isNotNull);
      final data = result!;
      expect(data['organization_name'], equals('Aetheria Innovations Inc'));
      expect(data['point_person'], equals('Alex Morgan'));
      expect(data['department'], equals('VP of Business Development'));
      expect(data['location'],
          equals('100 Silicon Way, Suite 400, San Francisco, CA 94107'));
      expect(data['contact_number'], equals('+1 (415) 890-1234'));
      expect(data['contact_email'], equals('alex.morgan@aetheria.io'));
      expect(data['organization_type'], equals('TECHNOLOGY'));
    });
  });
}
