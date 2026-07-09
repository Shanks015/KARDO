import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/data_provider.dart';
import '../services/local_transformer_service.dart';
import '../services/image_processor_service.dart';

class BatchProcessingScreen extends ConsumerStatefulWidget {
  final List<XFile> images;

  const BatchProcessingScreen({super.key, required this.images});

  @override
  ConsumerState<BatchProcessingScreen> createState() => _BatchProcessingScreenState();
}

class _BatchProcessingScreenState extends ConsumerState<BatchProcessingScreen> {
  int _currentIndex = 0;
  bool _isFinished = false;
  String _currentStep = '';
  final List<_BatchResult> _results = [];

  @override
  void initState() {
    super.initState();
    _processBatch();
  }

  Future<void> _processBatch() async {
    for (int i = 0; i < widget.images.length; i++) {
      if (!mounted) return;
      setState(() {
        _currentIndex = i;
        _currentStep = 'Processing image ${i + 1} of ${widget.images.length}...';
      });

      final xFile = widget.images[i];
      try {
        // 1. Image preprocessing + dominant color
        setState(() => _currentStep = 'Enhancing image quality...');
        final processed = await ImageProcessorService.processCardImage(xFile.path);
        final savedImagePath = await ImageProcessorService.saveCardImage(processed.processedImagePath);

        // 2. OCR + field extraction
        setState(() => _currentStep = 'Extracting text with AI...');
        final processedXFile = XFile(processed.processedImagePath);
        final data = await LocalTransformerService.extractCard(processedXFile);

        final pointPerson = data['point_person']?.toString().trim() ?? '';
        final orgName = data['organization_name']?.toString().trim() ?? '';

        if ((pointPerson.isEmpty || pointPerson.toLowerCase().contains('not found')) &&
            (orgName.isEmpty || orgName.toLowerCase().contains('not found'))) {
          _results.add(_BatchResult(
            fileName: xFile.name,
            status: _ResultStatus.error,
            message: 'Could not extract contact data from this image',
          ));
          continue;
        }

        // 3. Duplicate check
        final duplicate = await ref.read(localDbServiceProvider).checkDuplicate(data);

        if (duplicate != null) {
          _results.add(_BatchResult(
            fileName: xFile.name,
            status: _ResultStatus.skipped,
            message: "Duplicate: '${duplicate['point_person']}' already exists",
          ));
          continue;
        }

        // 4. Save with image + colors
        final cardData = {
          ...data,
          'image_path': savedImagePath,
          'dominant_color': ImageProcessorService.colorToHex(processed.dominantColor),
          'dominant_color_secondary': ImageProcessorService.colorToHex(processed.dominantColorSecondary),
          'kanban_status': 'New Lead',
        };
        final slNo = await ref.read(localCardsProvider.notifier).addCard(cardData);

        _results.add(_BatchResult(
          fileName: xFile.name,
          status: _ResultStatus.success,
          message: 'Saved as contact #$slNo',
          slNo: slNo,
        ));
      } catch (e) {
        _results.add(_BatchResult(
          fileName: xFile.name,
          status: _ResultStatus.error,
          message: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }

    if (mounted) {
      setState(() => _isFinished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(_isFinished ? 'Batch Complete' : 'Processing Cards'),
        automaticallyImplyLeading: _isFinished,
      ),
      body: _isFinished ? _buildSummary(theme) : _buildProgress(theme),
    );
  }

  Widget _buildProgress(ThemeData theme) {
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
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    color: theme.colorScheme.primary,
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms, color: theme.colorScheme.secondary),
            const SizedBox(height: 32),
            Text(
              'Processing ${_currentIndex + 1} of ${widget.images.length}',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _currentStep,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 500.ms).then().fadeOut(duration: 500.ms),
            const SizedBox(height: 24),
            Text(
              '100% offline • No internet required',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final successCount = _results.where((r) => r.status == _ResultStatus.success).length;
    final skipCount = _results.where((r) => r.status == _ResultStatus.skipped).length;
    final errorCount = _results.where((r) => r.status == _ResultStatus.error).length;

    return Column(
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryChip('✅ Saved', successCount, Colors.green),
              _summaryChip('⚠️ Skipped', skipCount, Colors.orange),
              _summaryChip('❌ Failed', errorCount, Colors.red),
            ],
          ),
        ),

        // Result list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final result = _results[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: result.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: result.color, width: 4)),
                ),
                child: Row(
                  children: [
                    Icon(result.icon, color: result.color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          Text(result.message,
                              style: TextStyle(color: result.color, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms).slideX(begin: 0.05);
            },
          ),
        ),

        // Done button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.done_all_rounded),
            label: Text('Done  ($successCount saved)'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ).animate().fadeIn(delay: 300.ms),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
      ],
    );
  }
}

enum _ResultStatus { success, skipped, error }

class _BatchResult {
  final String fileName;
  final _ResultStatus status;
  final String message;
  final int? slNo;

  _BatchResult({
    required this.fileName,
    required this.status,
    required this.message,
    this.slNo,
  });

  Color get color => switch (status) {
        _ResultStatus.success => Colors.green,
        _ResultStatus.skipped => Colors.orange,
        _ResultStatus.error => Colors.red,
      };

  IconData get icon => switch (status) {
        _ResultStatus.success => Icons.check_circle_rounded,
        _ResultStatus.skipped => Icons.warning_rounded,
        _ResultStatus.error => Icons.error_rounded,
      };
}