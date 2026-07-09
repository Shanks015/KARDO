import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_transformer_service.dart';
import '../services/cloud_ai_service.dart';
import '../services/image_processor_service.dart';
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
    final result = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result != null) {
      _processImage(result);
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
      _isProcessing = true;
      _processingStep = 'Processing image...';
    });

    try {
      // Step 1: Image pre-processing (contrast enhancement + dominant color)
      setState(() => _processingStep = 'Enhancing image quality...');
      final processed = await ImageProcessorService.processCardImage(xFile.path);
      
      // Create an XFile from the processed image
      final processedXFile = XFile(processed.processedImagePath);

      // Step 2: OCR + field extraction (Hybrid)
      setState(() => _processingStep = 'Analyzing with AI...');
      
      Map<String, dynamic>? result;
      try {
        final connectivityResult = await (Connectivity().checkConnectivity());
        final isOnline = connectivityResult != ConnectivityResult.none;

        if (isOnline) {
          setState(() => _processingStep = 'Extracting data via Cloud AI...');
          result = await CloudAIService.extractCard(processedXFile);
        }
      } catch (e) {
        debugPrint("Connectivity check failed: $e");
      }

      // Fallback to local OCR if offline or Cloud AI failed
      if (result == null) {
        setState(() => _processingStep = 'Extracting text locally...');
        result = await LocalTransformerService.extractCard(processedXFile);
      }

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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Scan Business Card'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isProcessing
          ? _buildProcessingView(theme)
          : _buildOptionsView(theme),
    );
  }

  Widget _buildProcessingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.colorScheme.primary,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1500.ms, color: theme.colorScheme.secondary),
          const SizedBox(height: 32),
          Text(
            _processingStep,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 500.ms).then().fadeOut(duration: 500.ms),
          const SizedBox(height: 12),
          Text(
            'Running on-device AI — no internet needed',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsView(ThemeData theme) {
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
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (_supportsCamera) ...[
              _buildOptionCard(
                theme,
                title: 'Live Camera',
                subtitle: 'Auto-detect & snap the card',
                icon: Icons.videocam_rounded,
                gradientColors: [const Color(0xFF6A1B9A), const Color(0xFF283593)],
                onTap: _openLiveCamera,
                delay: 0.ms,
                badge: 'RECOMMENDED',
              ),
              const SizedBox(height: 16),
              _buildOptionCard(
                theme,
                title: 'Quick Photo',
                subtitle: 'Take a photo of the card now',
                icon: Icons.camera_alt_rounded,
                gradientColors: [const Color(0xFF00695C), const Color(0xFF004D40)],
                onTap: () => _pickImage(ImageSource.camera),
                delay: 100.ms,
              ),
              const SizedBox(height: 16),
            ],
            _buildOptionCard(
              theme,
              title: 'From Gallery',
              subtitle: 'Choose one or multiple card images',
              icon: Icons.photo_library_rounded,
              gradientColors: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
              onTap: () => _pickImage(ImageSource.gallery),
              delay: 200.ms,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    ThemeData theme, {
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
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
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
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
          ],
        ),
      ).animate().fadeIn(delay: delay, duration: 400.ms).slideX(begin: 0.1, duration: 400.ms),
    );
  }
}
