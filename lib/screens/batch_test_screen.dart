import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../services/local_transformer_service.dart';
import '../services/image_processor_service.dart';
import '../services/groq_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_provider.dart';
class BatchTestScreen extends ConsumerStatefulWidget {
  const BatchTestScreen({super.key});

  @override
  ConsumerState<BatchTestScreen> createState() => _BatchTestScreenState();
}

class _BatchTestScreenState extends ConsumerState<BatchTestScreen> {
  bool _isProcessing = true;
  String _statusText = 'Initializing...';
  List<String> _assetPaths = [];
  int _currentIndex = 0;
  final List<Map<String, dynamic>> _results = [];
  final List<String> _processedImagePaths = [];
  bool _hasExportedCsv = false;

  @override
  void initState() {
    super.initState();
    _runBatchTest();
  }

  Future<void> _runBatchTest() async {
    try {
      // 1. Find all test images
      setState(() => _statusText = 'Finding test images...');
      
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _assetPaths = assetManifest.listAssets()
          .where((String key) => key.startsWith('assets/batch_test_cards/') && (key.endsWith('.jpeg') || key.endsWith('.jpg')))
          .toList();
      _assetPaths.sort((a, b) {
        final numA = int.tryParse(a.split('_').last.split('.').first) ?? 0;
        final numB = int.tryParse(b.split('_').last.split('.').first) ?? 0;
        return numA.compareTo(numB);
      });

      if (_assetPaths.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusText = 'No images found in assets/test_cards/';
        });
        return;
      }

      final tempDir = await getTemporaryDirectory();

      // 2. Process each image sequentially
      for (int i = 0; i < _assetPaths.length; i++) {
        final path = _assetPaths[i];
        setState(() => _statusText = 'Processing image ${i + 1}/${_assetPaths.length}...');
        
        final byteData = await rootBundle.load(path);
        final file = File('${tempDir.path}/test_card_$i.jpg');
        await file.writeAsBytes(byteData.buffer.asUint8List());

        final xFile = XFile(file.path);
        // Use our pipeline
        final processed = await ImageProcessorService.processCardImage(xFile.path);
        final processedXFile = XFile(processed.processedImagePath);

        Map<String, dynamic>? result;
        try {
          final bool forceOffline = false; // Hybrid: Use cloud if online
          
          if (!forceOffline) {
            final connectivityResult = await (Connectivity().checkConnectivity());
            final isOnline = !connectivityResult.contains(ConnectivityResult.none);

            if (isOnline) {
              result = await GroqService.extractCard(processedXFile);
              if (result != null) result['engine'] = 'cloud_vlm';
            }
          }
        } catch (e) {
          debugPrint("Connectivity check failed: $e");
        }

        if (result == null) {
          result = await LocalTransformerService.extractCard(processedXFile);
          result['engine'] = 'local_ocr';
        }
        _results.add(result!);
        _processedImagePaths.add(processed.processedImagePath);
        
        // Auto-save each card immediately
        try {
          final lowQualityImagePath = await ImageProcessorService.saveLowQualityCardImage(processed.processedImagePath);
          final mappedData = {
            'point_person': result['name'] ?? 'Not Found',
            'department': result['job_title'] ?? 'Not Found',
            'organization_name': result['company'] ?? 'Not Found',
            'contact_number': result['phone'] ?? 'Not Found',
            'contact_email': result['email'] ?? 'Not Found',
            'url': result['website'] ?? 'Not Found',
            'address': result['address'] ?? 'Not Found',
            'notes': 'Batch Processed via ${result['engine'] ?? 'AI'}',
            'category': 'BUSINESS',
            'kanban_status': 'New Lead',
            'image_path': lowQualityImagePath,
          };
          await ref.read(localCardsProvider.notifier).addCard(mappedData);
        } catch (e) {
          debugPrint('Failed to save card ${i + 1}: $e');
        }
      }

      setState(() {
        _isProcessing = false;
        _statusText = 'Finished processing and saving ${_assetPaths.length} cards.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Error: $e';
      });
    }
  }

  Future<void> _exportCsv() async {
    if (_results.isEmpty) return;
    try {
      final header = "Image,Engine,Name,NameScore,Title,TitleScore,Company,CompanyScore,Address,Phone,Email,URL\n";
      final buffer = StringBuffer(header);
      
      final htmlBuffer = StringBuffer();
      htmlBuffer.writeln('<html><head><title>Batch Test Results</title>');
      htmlBuffer.writeln('<style>body { font-family: sans-serif; } table { border-collapse: collapse; width: 100%; } th, td { border: 1px solid #ddd; padding: 12px; vertical-align: top; } img { max-width: 300px; height: auto; border-radius: 8px; }</style>');
      htmlBuffer.writeln('</head><body><h2>Batch Test Results (${_results.length} cards)</h2><table>');
      htmlBuffer.writeln('<tr><th>Image</th><th>Extracted Details</th></tr>');
      
      for (int i = 0; i < _results.length; i++) {
        final r = _results[i];
        final img = _assetPaths[i].split('/').last;
        final engine = r['engine'] ?? 'unknown';
        final name = _escapeCsv(r['name'] ?? '');
        final title = _escapeCsv(r['job_title'] ?? '');
        final company = _escapeCsv(r['company'] ?? '');
        final address = _escapeCsv(r['address'] ?? '');
        final phone = _escapeCsv(r['phone'] ?? '');
        final email = _escapeCsv(r['email'] ?? '');
        final url = _escapeCsv(r['website'] ?? '');
        
        final scores = r['_debug_scores'] as Map<String, dynamic>? ?? {};
        final nameScore = (scores['name_score'] as double?)?.toStringAsFixed(1) ?? 'N/A';
        final titleScore = (scores['title_score'] as double?)?.toStringAsFixed(1) ?? 'N/A';
        final companyScore = (scores['company_score'] as double?)?.toStringAsFixed(1) ?? 'N/A';
        
        buffer.writeln("$img,$engine,$name,$nameScore,$title,$titleScore,$company,$companyScore,$address,$phone,$email,$url");
        
        // Base64 image for HTML
        final path = _assetPaths[i];
        final byteData = await rootBundle.load(path);
        final base64String = base64Encode(byteData.buffer.asUint8List());
        
        htmlBuffer.writeln('<tr>');
        htmlBuffer.writeln('<td style="width: 320px;"><img src="data:image/jpeg;base64,$base64String"/><br><br><b>$img</b><br><small>Engine: $engine</small></td>');
        htmlBuffer.writeln('<td>');
        htmlBuffer.writeln('<b>Name:</b> ${r['name'] ?? 'Not Found'} <small>($nameScore)</small><br><br>');
        htmlBuffer.writeln('<b>Title:</b> ${r['job_title'] ?? 'Not Found'} <small>($titleScore)</small><br><br>');
        htmlBuffer.writeln('<b>Company:</b> ${r['company'] ?? 'Not Found'} <small>($companyScore)</small><br><br>');
        htmlBuffer.writeln('<b>Email:</b> ${r['email'] ?? 'Not Found'}<br><br>');
        htmlBuffer.writeln('<b>Phone:</b> ${r['phone'] ?? 'Not Found'}<br><br>');
        htmlBuffer.writeln('<b>Address:</b> ${r['address'] ?? 'Not Found'}<br><br>');
        htmlBuffer.writeln('<b>Website:</b> ${r['website'] ?? 'Not Found'}');
        htmlBuffer.writeln('</td>');
        htmlBuffer.writeln('</tr>');
      }
      
      htmlBuffer.writeln('</table></body></html>');
      
      final tempDir = await getTemporaryDirectory();
      final csvFile = File('${tempDir.path}/Hybrid_AI_Results_${DateTime.now().millisecondsSinceEpoch}.csv');
      await csvFile.writeAsString(buffer.toString());
      
      final htmlFile = File('${tempDir.path}/Hybrid_AI_Report_${DateTime.now().millisecondsSinceEpoch}.html');
      await htmlFile.writeAsString(htmlBuffer.toString());
      
      setState(() => _hasExportedCsv = true);
      
      await Share.shareXFiles([XFile(csvFile.path), XFile(htmlFile.path)], text: 'Batch Test Results (CSV + HTML)');
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _saveAllToDb() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      for (int i = 0; i < _results.length; i++) {
        final result = _results[i];
        final imagePath = _processedImagePaths[i];
        
        final mappedData = {
          'point_person': result['name'] ?? 'Not Found',
          'department': result['job_title'] ?? 'Not Found',
          'organization_name': result['company'] ?? 'Not Found',
          'contact_number': result['phone'] ?? 'Not Found',
          'contact_email': result['email'] ?? 'Not Found',
          'url': result['website'] ?? 'Not Found',
          'address': result['address'] ?? 'Not Found',
          'notes': 'Batch Processed via ${result['engine'] ?? 'AI'}',
          'category': 'BUSINESS',
          'kanban_status': 'New Lead',
          'card_image_path': imagePath,
        };
        
        await ref.read(localCardsProvider.notifier).addCard(mappedData);
      }
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully saved ${_results.length} cards to database!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _escapeCsv(String text) {
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch AI Testing'),
        actions: [
          if (!_isProcessing)
            IconButton(
              icon: Icon(_hasExportedCsv ? Icons.check_circle : Icons.download),
              onPressed: _exportCsv,
              tooltip: 'Export CSV',
            ),
          if (!_isProcessing)
            IconButton(
              icon: const Icon(Icons.save_alt),
              onPressed: _saveAllToDb,
              tooltip: 'Save All to Database',
            ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_statusText, style: theme.textTheme.titleMedium),
                ],
              ),
            )
          : _buildResultsView(theme),
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    if (_results.isEmpty) {
      return Center(child: Text(_statusText));
    }
    
    final currentResult = _results[_currentIndex];
    final currentImage = _processedImagePaths[_currentIndex];
    final currentName = _assetPaths[_currentIndex].split('/').last;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Card ${_currentIndex + 1} of ${_results.length} ($currentName)', 
             style: theme.textTheme.titleMedium),
        ),
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12)
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(currentImage), fit: BoxFit.contain),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildField('Name', currentResult['name']),
              _buildField('Title', currentResult['job_title']),
              _buildField('Company', currentResult['company']),
              _buildField('Email', currentResult['email']),
              _buildField('Phone', currentResult['phone']),
              _buildField('Address', currentResult['address']),
              _buildField('URL', currentResult['website']),
            ],
          ),
        ),
        SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Prev'),
                onPressed: _currentIndex > 0 
                    ? () => setState(() => _currentIndex--) 
                    : null,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
                onPressed: _currentIndex < _results.length - 1 
                    ? () => setState(() => _currentIndex++) 
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value?.toString() ?? 'Not Found', 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
