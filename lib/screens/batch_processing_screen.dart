import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/groq_service.dart';
import '../services/local_transformer_service.dart';
import '../services/image_processor_service.dart';
import '../theme/tokens.dart';
import 'batch_result_screen.dart';

class BatchProcessingScreen extends ConsumerStatefulWidget {
  final List<XFile> images;

  const BatchProcessingScreen({super.key, required this.images});

  @override
  ConsumerState<BatchProcessingScreen> createState() => _BatchProcessingScreenState();
}

class _BatchProcessingScreenState extends ConsumerState<BatchProcessingScreen> {
  int _currentIndex = 0;
  String _currentStep = '';

  @override
  void initState() {
    super.initState();
    _processBatch();
  }

  Future<void> _processBatch() async {
    final List<Map<String, dynamic>> extractedList = [];

    for (int i = 0; i < widget.images.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentIndex = i;
        _currentStep = 'Processing image ${i + 1} of ${widget.images.length}...';
      });

      final xFile = widget.images[i];
      try {
        setState(() => _currentStep = 'Enhancing image quality...');
        final processed = await ImageProcessorService.processCardImage(xFile.path);
        final savedImagePath = await ImageProcessorService.saveCardImage(processed.processedImagePath);

        setState(() => _currentStep = 'Extracting text with Groq AI...');
        final processedXFile = XFile(processed.processedImagePath);
        var data = await GroqService.extractCard(xFile);
        data ??= await LocalTransformerService.extractCard(processedXFile);

        final cardData = {
          ...data,
          'image_path': savedImagePath,
          'dominant_color': ImageProcessorService.colorToHex(processed.dominantColor),
          'dominant_color_secondary': ImageProcessorService.colorToHex(processed.dominantColorSecondary),
          'kanban_status': 'New Lead',
        };
        extractedList.add(cardData);
      } catch (e) {
        // Just add empty data with the image if it failed to process entirely
        extractedList.add({
          'image_path': xFile.path,
          'dominant_color': '0xFF1565C0',
          'dominant_color_secondary': '0xFF1565C0',
          'kanban_status': 'New Lead',
        });
      }
    }

    if (mounted) {
      if (extractedList.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BatchResultScreen(extractedDataList: extractedList),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.extension<KardoTokensExtension>()!.tokens;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Processing Batch'),
        automaticallyImplyLeading: false,
      ),
      body: _buildProgress(theme, t),
    );
  }

  Widget _buildProgress(ThemeData theme, KardoTokens t) {
    final progress = (_currentIndex + 1) / widget.images.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: t.surfaceAlt,
                    color: t.accent,
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms, color: t.secondary),
            const SizedBox(height: 32),
            Text(
              'Processing ${_currentIndex + 1} of ${widget.images.length}',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _currentStep,
              style: theme.textTheme.bodyMedium?.copyWith(color: t.grey),
              textAlign: TextAlign.center,
            ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 500.ms).then().fadeOut(duration: 500.ms),
            const SizedBox(height: 24),
            Text(
              'No internet required',
              style: TextStyle(fontSize: 12, color: t.accent),
            ),
          ],
        ),
      ),
    );
  }
}