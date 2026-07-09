import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_transformer_service.dart';
import '../services/image_processor_service.dart';
import '../services/cloud_ai_service.dart';

class BatchTestScreen extends StatefulWidget {
  const BatchTestScreen({super.key});

  @override
  State<BatchTestScreen> createState() => _BatchTestScreenState();
}

class _BatchTestScreenState extends State<BatchTestScreen> {
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
      
      _assetPaths = List.generate(18, (index) => 'assets/test_cards/card_${index + 1}.jpeg');

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
          final connectivityResult = await (Connectivity().checkConnectivity());
          final isOnline = connectivityResult != ConnectivityResult.none;

          if (isOnline) {
            result = await CloudAIService.extractCard(processedXFile);
          }
        } catch (e) {
          debugPrint("Connectivity check failed: $e");
        }

        if (result == null) {
          result = await LocalTransformerService.extractCard(processedXFile);
        }
        _results.add(result!);
        _processedImagePaths.add(processed.processedImagePath);
      }

      setState(() {
        _isProcessing = false;
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
      final header = "Image,Name,Title,Company,Address,Phone,Email,URL\n";
      final buffer = StringBuffer(header);
      
      for (int i = 0; i < _results.length; i++) {
        final r = _results[i];
        final img = _assetPaths[i].split('/').last;
        final name = _escapeCsv(r['point_person'] ?? '');
        final title = _escapeCsv(r['department'] ?? '');
        final company = _escapeCsv(r['organization_name'] ?? '');
        final address = _escapeCsv(r['location'] ?? '');
        final phone = _escapeCsv(r['contact_number'] ?? '');
        final email = _escapeCsv(r['contact_email'] ?? '');
        final url = _escapeCsv(r['url'] ?? '');
        
        buffer.writeln("$img,$name,$title,$company,$address,$phone,$email,$url");
      }
      
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/Offline_AI_Results_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());
      
      setState(() => _hasExportedCsv = true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to Downloads!'),
          backgroundColor: Colors.green.shade700,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () => OpenFile.open(file.path),
          ),
        ),
      );
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
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
            )
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
              _buildField('Name', currentResult['point_person']),
              _buildField('Title', currentResult['department']),
              _buildField('Company', currentResult['organization_name']),
              _buildField('Email', currentResult['contact_email']),
              _buildField('Phone', currentResult['contact_number']),
              _buildField('Address', currentResult['location']),
              _buildField('URL', currentResult['url']),
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
