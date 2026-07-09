import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cross_file/cross_file.dart';

class CloudAIService {
  /// Extracts business card fields using Gemini 1.5 Flash.
  static Future<Map<String, dynamic>?> extractCard(XFile imageFile) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      debugPrint("CloudAIService: Missing GEMINI_API_KEY in .env");
      return null;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final dataPart = DataPart('image/jpeg', imageBytes);

      final prompt = TextPart('''
Analyze this business card image and extract the following information.
Return ONLY a valid JSON object with the exact keys below. Do not use markdown blocks, just return raw JSON.
If a field is not found, use "Not Found" as the value.

Keys required:
- point_person (The person's full name, properly capitalized)
- department (The person's job title or position)
- organization_name (The company or organization name)
- location (The physical address)
- contact_number (The phone number)
- contact_email (The email address)
- url (The website URL)
''');

      final response = await model.generateContent([
        Content.multi([prompt, dataPart])
      ]);

      var text = response.text;
      if (text == null || text.isEmpty) return null;

      // Clean up potential markdown formatting from Gemini
      text = text.trim();
      if (text.startsWith('```json')) {
        text = text.substring(7);
      } else if (text.startsWith('```')) {
        text = text.substring(3);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      
      return {
        'point_person': parsed['point_person']?.toString() ?? 'Not Found',
        'department': parsed['department']?.toString() ?? 'Not Found',
        'organization_name': parsed['organization_name']?.toString() ?? 'Not Found',
        'location': parsed['location']?.toString() ?? 'Not Found',
        'contact_number': parsed['contact_number']?.toString() ?? 'Not Found',
        'contact_email': parsed['contact_email']?.toString() ?? 'Not Found',
        'url': parsed['url']?.toString() ?? 'Not Found',
      };
    } catch (e) {
      debugPrint("CloudAIService error: $e");
      return null; // Return null so the caller can fallback to local OCR
    }
  }
}
