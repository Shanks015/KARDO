import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageProcessorService {
  /// Full processing pipeline: returns processed image path + dominant colors
  static Future<ProcessedImageResult> processCardImage(String inputPath) async {
    try {
      // 1. Load image
      final file = File(inputPath);
      final bytes = await file.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) throw Exception('Failed to decode image');

      // 2. Auto-orient based on EXIF
      final oriented = img.bakeOrientation(original);

      // 3. Enhance contrast for better OCR
      final enhanced = _enhanceContrast(oriented);

      // 4. Save processed image
      final processedPath = await _saveTempImage(enhanced, 'processed');

      // 5. Extract dominant colors using palette_generator
      final dominantColors = await _extractDominantColors(inputPath);

      return ProcessedImageResult(
        processedImagePath: processedPath,
        originalImagePath: inputPath,
        dominantColor: dominantColors[0],
        dominantColorSecondary: dominantColors[1],
      );
    } catch (e) {
      debugPrint('Image processing error: $e');
      // Return original path on failure - OCR will still work
      final fallbackColors = await _extractDominantColors(inputPath);
      return ProcessedImageResult(
        processedImagePath: inputPath,
        originalImagePath: inputPath,
        dominantColor: fallbackColors[0],
        dominantColorSecondary: fallbackColors[1],
      );
    }
  }

  /// Applies adaptive contrast enhancement suitable for business card OCR
  static img.Image _enhanceContrast(img.Image source) {
    // Normalize: stretch histogram to use full 0-255 range
    img.Image result = img.copyResize(source,
      width: source.width > 1600 ? 1600 : source.width,
      interpolation: img.Interpolation.cubic,
    );

    // Convert to grayscale copy for histogram analysis, keep color for display
    // Apply auto levels: find 1st and 99th percentile and remap
    final List<int> brightness = [];
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        brightness.add((0.299 * r + 0.587 * g + 0.114 * b).round());
      }
    }
    brightness.sort();
    final int low = brightness[(brightness.length * 0.01).floor()].clamp(0, 255);
    final int high = brightness[(brightness.length * 0.99).floor()].clamp(0, 255);
    final double range = (high - low).toDouble();

    if (range < 10) return result; // Already well-contrasted

    // Apply level stretch
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final newR = ((pixel.r.toInt() - low) / range * 255).round().clamp(0, 255);
        final newG = ((pixel.g.toInt() - low) / range * 255).round().clamp(0, 255);
        final newB = ((pixel.b.toInt() - low) / range * 255).round().clamp(0, 255);
        result.setPixelRgb(x, y, newR, newG, newB);
      }
    }

    return result;
  }

  /// Extracts 2 dominant colors from the image using palette_generator
  static Future<List<Color>> _extractDominantColors(String imagePath) async {
    try {
      final imageProvider = FileImage(File(imagePath));
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 16,
      );

      Color primary = paletteGenerator.dominantColor?.color ??
          paletteGenerator.vibrantColor?.color ??
          const Color(0xFF1565C0);

      Color secondary = paletteGenerator.darkVibrantColor?.color ??
          paletteGenerator.darkMutedColor?.color ??
          Color.lerp(primary, Colors.black, 0.3)!;

      // Ensure both colors are not too close to white (poor contrast)
      if (_luminance(primary) > 0.85) {
        primary = const Color(0xFF1565C0);
      }
      if (_luminance(secondary) > 0.85) {
        secondary = Color.lerp(primary, Colors.black, 0.4)!;
      }

      return [primary, secondary];
    } catch (e) {
      debugPrint('Color extraction error: $e');
      return [const Color(0xFF1565C0), const Color(0xFF0D47A1)];
    }
  }

  /// Relative luminance for contrast check (WCAG formula)
  static double _luminance(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Save processed image to app documents directory
  static Future<String> _saveTempImage(img.Image image, String suffix) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = p.join(dir.path, 'snapcard_${suffix}_$timestamp.jpg');
    final file = File(path);
    await file.writeAsBytes(img.encodeJpg(image, quality: 88));
    return path;
  }

  /// Save a card image permanently (for storage alongside contact data)
  static Future<String> saveCardImage(String tempPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cardsDir = Directory(p.join(dir.path, 'cards'));
      if (!await cardsDir.exists()) await cardsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = p.join(cardsDir.path, 'card_$timestamp.jpg');
      await File(tempPath).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Error saving card image: $e');
      return tempPath;
    }
  }

  /// Save a heavily compressed, low-quality version of the card image
  static Future<String> saveLowQualityCardImage(String tempPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cardsDir = Directory(p.join(dir.path, 'cards'));
      if (!await cardsDir.exists()) await cardsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = p.join(cardsDir.path, 'card_lq_$timestamp.jpg');
      
      final bytes = await File(tempPath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original != null) {
        // Resize to a max width of 400 for extreme space saving
        final resized = img.copyResize(original, width: 400);
        // Encode with very low quality (20)
        final compressedBytes = img.encodeJpg(resized, quality: 20);
        await File(destPath).writeAsBytes(compressedBytes);
        return destPath;
      }
      
      return tempPath;
    } catch (e) {
      debugPrint('Error saving low quality card image: $e');
      return tempPath;
    }
  }

  /// Convert Color to hex string for storage
  static String colorToHex(Color color) {
    return '0x${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// Parse hex string to Color
  static Color hexToColor(String hex) {
    try {
      final value = int.parse(hex.replaceAll('0x', ''), radix: 16);
      return Color(value);
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }
}

class ProcessedImageResult {
  final String processedImagePath;
  final String originalImagePath;
  final Color dominantColor;
  final Color dominantColorSecondary;

  const ProcessedImageResult({
    required this.processedImagePath,
    required this.originalImagePath,
    required this.dominantColor,
    required this.dominantColorSecondary,
  });
}
