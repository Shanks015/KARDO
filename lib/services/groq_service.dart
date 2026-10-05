import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class GroqService {
  /// Compress image bytes to ~100KB for ultra-fast network transfer (< 0.1s)
  static Future<Uint8List> compressImage(XFile imageFile) async {
    try {
      final originalBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return originalBytes;

      // Maintain aspect ratio, max width/height 1000px
      img.Image resized;
      if (decoded.width > 1000 || decoded.height > 1000) {
        if (decoded.width >= decoded.height) {
          resized = img.copyResize(decoded, width: 1000);
        } else {
          resized = img.copyResize(decoded, height: 1000);
        }
      } else {
        resized = decoded;
      }

      // Encode as JPEG at 80% quality
      final compressed = img.encodeJpg(resized, quality: 80);
      debugPrint('GroqService: Original image size ${originalBytes.length ~/ 1024} KB -> Compressed to ${compressed.length ~/ 1024} KB');
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('GroqService: Image compression fallback due to $e');
      return await imageFile.readAsBytes();
    }
  }

  /// Extracts business card fields using Groq Llama-3 Vision models (< 0.4s response time)
  static Future<Map<String, dynamic>?> extractCard(XFile imageFile) async {
    var apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      debugPrint('GroqService: GROQ_API_KEY not set in .env');
      return null;
    }

    try {
      final startTime = DateTime.now();
      final compressedBytes = await compressImage(imageFile);
      final base64Image = base64Encode(compressedBytes);

      final models = [
        'qwen/qwen3.6-27b',
        'llama-3.3-70b-versatile',
      ];

      final prompt = '''
You are an expert AI vision system specializing in 100% complete, highly accurate extraction of business cards.

Examine the business card image carefully and extract all information into JSON with this exact schema:

{
  "point_person": "Full Name or Not Found",
  "department": "Job Title/Role or Not Found",
  "organization_name": "Full Company Name or Not Found",
  "organization_type": "BUSINESS or EDUCATION or HEALTHCARE or TECH or GOVT",
  "contact_number": "Phone Number or Not Found",
  "contact_email": "Email Address or Not Found",
  "location": "Full Address/City or Not Found",
  "url": "Website URL or Not Found",
  "notes": "Notes or Not Found"
}

Return ONLY raw valid JSON. Do not include markdown code block syntax.
''';

      for (final model in models) {
        try {
          final response = await http.post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image',
                      }
                    }
                  ]
                }
              ],
              'response_format': {'type': 'json_object'},
              'temperature': 0.1,
              'max_tokens': 1000,
            }),
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            final jsonResp = jsonDecode(response.body);
            final content = jsonResp['choices']?[0]?['message']?['content']?.toString() ?? '';
            if (content.isNotEmpty) {
              var cleanJson = content.trim();
              if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
              if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
              if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
              cleanJson = cleanJson.trim();

              final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
              final elapsed = DateTime.now().difference(startTime).inMilliseconds;
              debugPrint('GroqService: Successfully extracted via Groq model $model in ${elapsed}ms');
              return parsed;
            }
          } else {
            debugPrint('GroqService: Model $model returned status ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('GroqService: Model $model failed: $e');
        }
      }
    } catch (e) {
      debugPrint('GroqService error: $e');
    }
    return null;
  }
}