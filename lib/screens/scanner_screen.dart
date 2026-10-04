import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/groq_service.dart';
import '../services/local_transformer_service.dart';
import '../services/image_processor_service.dart';
import '../theme/tokens.dart';
import 'result_screen.dart';
import 'batch_processing_screen.dart';
import 'camera_screen.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String _processingStep = '';
  String? _capturedImagePath;

  bool get _supportsCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _openLiveCamera() async {
    if (!_supportsCamera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live camera is not available on this platform.')),
      );
      return;
    }
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result is XFile) {
      _processImage(result);
    } else if (result is List<XFile> && result.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => BatchProcessingScreen(images: result)),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && !_supportsCamera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera capture is not available on this platform.')),
      );
      return;
    }

    if (source == ImageSource.gallery) {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 90);
      if (images.isNotEmpty) {
        if (images.length == 1) {
          _processImage(images.first);
        } else {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => BatchProcessingScreen(images: images)),
            );
          }
        }
      }
    } else {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 90);
      if (image != null) _processImage(image);
    }
  }

  Future<void> _processImage(XFile xFile) async {
    setState(() {
      _capturedImagePath = xFile.path;
      _isProcessing = true;
      _processingStep = 'Processing image...';
    });

    try {
      // Step 1: Image pre-processing (contrast enhancement + dominant color)
      setState(() => _processingStep = 'Enhancing image quality...');
      final processed = await ImageProcessorService.processCardImage(xFile.path);
      
      // Create an XFile from the processed image
      final processedXFile = XFile(processed.processedImagePath);

      // Step 2: OCR + field extraction (Groq AI -> On-Device ML Kit OCR Fallback)
      setState(() => _processingStep = 'Analyzing with Ultra-Fast Groq AI...');
      
      Map<String, dynamic>? result;

      // Attempt 1: Groq Ultra-Fast AI Vision (< 0.4s)
      try {
        result = await GroqService.extractCard(xFile);
        if (result != null) {
          debugPrint("ScannerScreen: Successfully extracted data via Groq AI Vision");
        }
      } catch (e) {
        debugPrint("ScannerScreen: Groq attempt failed: $e");
      }

      // Attempt 2: Fallback to local offline ML Kit OCR (0.1s on device)
      if (result == null) {
        setState(() => _processingStep = 'Extracting text locally (offline)...');
        result = await LocalTransformerService.extractCard(processedXFile);
        debugPrint("ScannerScreen: Used local transformer OCR fallback");
      }

      final captureTime = DateTime.now().toIso8601String();
      result['timestamp'] = captureTime;
      result['created_at'] = captureTime;

      // Step 3: Save card image permanently
      setState(() => _processingStep = 'Saving card image...');
      final savedImagePath = await ImageProcessorService.saveCardImage(processed.processedImagePath);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) => ResultScreen(
              extractedData: result!,
              xFile: processedXFile, // Use the processed image here as well
              savedImagePath: savedImagePath,
              dominantColor: processed.dominantColor,
              dominantColorSecondary: processed.dominantColorSecondary,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: t.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Scan Business Card'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isProcessing
          ? _buildProcessingView(theme, t)
          : _buildOptionsView(theme, t),
    );
  }

  Widget _buildProcessingView(ThemeData theme, KardoTokens t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: t.accent,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Processing card info...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildOptionsView(ThemeData theme, KardoTokens t) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose input method',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'All processing happens 100% offline on your device',
              style: theme.textTheme.bodyMedium?.copyWith(color: t.textTertiary),
            ),
            const Spacer(),
            if (_supportsCamera) ...[
              _buildOptionCard(
                theme,
                t: t,
                title: 'Live Camera',
                subtitle: 'Auto-detect & snap the card',
                icon: Icons.videocam_rounded,
                gradientColors: [t.accent, t.accentDark],
                onTap: _openLiveCamera,
                delay: 0.ms,
                badge: 'RECOMMENDED',
              ),
              const SizedBox(height: 20),
            ],
            _buildOptionCard(
              theme,
              t: t,
              title: 'From Gallery',
              subtitle: 'Choose one or multiple card images',
              icon: Icons.photo_library_rounded,
              gradientColors: [t.accent, t.accentDark],
              onTap: () => _pickImage(ImageSource.gallery),
              delay: 200.ms,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    ThemeData theme, {
    required KardoTokens t,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    required Duration delay,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: t.textOnAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: t.textOnAccent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: t.textOnAccent,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.warning,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: t.textOnAccent.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textOnAccent.withOpacity(0.7), size: 22),
          ],
        ),
      ).animate().fadeIn(delay: delay, duration: 400.ms).slideX(begin: 0.1, duration: 400.ms),
    );
  }
}
