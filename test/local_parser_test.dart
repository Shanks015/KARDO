import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/services/local_transformer_service.dart';

void main() {
  group('LocalTransformerService Tests', () {
    test('Developer Fallback Mock Data Test', () async {
      // Simulate non-mobile extraction (which returns developer mock data)
      final mockFile = XFile('test_image.png');
      final result = await LocalTransformerService.extractCard(mockFile);

      expect(result, isNotNull);
      expect(result['organization_name'], equals('Google LLC'));
      expect(result['point_person'], equals('Sundar Pichai'));
      expect(result['department'], equals('Chief Executive Officer'));
      expect(result['location'], equals('Mountain View, CA'));
      expect(result['contact_number'], equals('+1 (650) 253-0000'));
      expect(result['contact_email'], equals('sundar@google.com'));
      expect(result['organization_type'], equals('BUSINESS'));
    });
  });
}
