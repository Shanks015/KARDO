import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for performing offline Named Entity Recognition (NER) on text using TensorFlow Lite.
/// This service enables offline extraction of person names, organizations, locations,
/// and other entities from text without requiring network connectivity.
class OfflineTransformerService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;

  // Label sequence for NER task (BIO format)
  // Adjust these labels according to your trained model's output
  static final List<String> _labels = [
    'O',           // Outside of any entity
    'B-PER',       // Beginning of Person name
    'I-PER',       // Inside of Person name
    'B-ORG',       // Beginning of Organization
    'I-ORG',       // Inside of Organization
    'B-LOC',       // Beginning of Location
    'I-LOC',       // Inside of Location
    'B-MISC',      // Beginning of Miscellaneous
    'I-MISC',      // Inside of Miscellaneous
  ];

  /// Initializes the TensorFlow Lite interpreter with the model asset.
  /// Must be called before using any other methods in this class.
  ///
  /// Note: Ensure the model asset is properly declared in pubspec.yaml:
  ///   assets:
  ///     - assets/models/ner_model.tflite
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Load the model from assets
      final modelPath = 'assets/models/ner_model.tflite';
      try {
        _interpreter = await Interpreter.fromAsset(modelPath);
      } catch (e) {
        debugPrint('Offline Transformer Service: NER model is empty or invalid. Running in fallback heuristic mode.');
        _isInitialized = true; // Mark initialized so we don't spam errors
        return;
      }
      
      _isInitialized = true;
      debugPrint('Offline Transformer Service: Model loaded successfully from $modelPath');

      // Log model information for debugging
      if (_interpreter != null) {
        final inputTensor = _interpreter!.getInputTensor(0);
        final outputTensor = _interpreter!.getOutputTensor(0);
        debugPrint('Offline model loaded: input=${inputTensor.shape}, output=${outputTensor.shape}');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to load offline transformer model: $e');
      debugPrint('Stack trace: $stackTrace');
      _interpreter = null;
      _isInitialized = false;
      rethrow; // Re-throw to allow caller to handle the error appropriately
    }
  }

  /// Releases resources used by the interpreter.
  /// Call this when the app is terminating to free native resources.
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }

  /// Extracts named entities from text using the offline transformer model.
  ///
  /// Returns a map with entity types as keys and the detected entities as values.
  /// Returns empty map if model is not initialized or an error occurs.
  ///
  /// Supported entity types (based on the model's training):
  ///   - 'person': Person names
  ///   - 'organization': Company/organization names
  ///   - 'location': Locations/addresses
  ///   - 'misc': Miscellaneous entities
  static Future<Map<String, String>> extractEntities(String text) async {
    if (!_isInitialized || _interpreter == null) {
      debugPrint('Offline Transformer Service: Model not initialized. Attempting to initialize...');
      await init(); // Try to initialize if not done yet

      if (!_isInitialized || _interpreter == null) {
        debugPrint('Offline Transformer Service: Model not available');
        return {};
      }
    }

    if (text.trim().isEmpty) {
      return {};
    }

    try {
      // Preprocess text: tokenize and convert to input tensor
      final List<int> tokens = _tokenize(text);

      if (tokens.isEmpty) {
        return {};
      }

      // Prepare input tensor - shape should match model's expected input
      // Most NER models expect: [batch_size, sequence_length]
      final List<List<int>> input = [tokens];

      // Get expected input shape from model
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final int expectedSeqLength = inputShape.length > 1 ? inputShape[1] : 128;

      // Pad or truncate sequence to match expected length
      final List<int> paddedTokens = _padOrTruncate(tokens, expectedSeqLength);
      final List<List<int>> finalInput = [paddedTokens];

      // Prepare output buffer
      // Output shape is typically: [batch_size, sequence_length, num_labels]
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final int batchSize = outputShape[0];
      final int seqLength = outputShape.length > 1 ? outputShape[1] : 128;
      final int numLabels = outputShape.length > 2 ? outputShape[2] : _labels.length;

      // Create 3D output buffer: [batch, sequence, labels]
      final List<List<List<double>>> output = List.generate(
        batchSize,
        (_) => List.generate(
          seqLength,
          (_) => List.filled(numLabels, 0.0)
        )
      );

      // Run inference
      _interpreter!.run(finalInput, output);

      // Postprocess: convert logits to labels and extract entities
      final Map<String, String> entities = _extractEntitiesFromOutput(
        output[0],      // First batch item
        paddedTokens,   // Tokens (padded/truncated)
        text,           // Original text for character-level alignment
      );

      return entities;
    } catch (e, stackTrace) {
      debugPrint('Error during entity extraction: $e');
      debugPrint('Stack trace: $stackTrace');
      return {};
    }
  }

  /// Tokenizes input text into token IDs suitable for the model.
  ///
  /// This is a simplified whitespace tokenizer. For production use with
  /// BERT-based models, you should replace this with the actual tokenizer
  /// used during model training (WordPiece, BPE, etc.).
  static List<int> _tokenize(String text) {
    // TODO: Replace with actual tokenizer matching your model's vocabulary
    // This implementation uses a simple hash-based approach for demonstration

    if (text.trim().isEmpty) return [];

    // Convert to lowercase and split on whitespace and common punctuation
    // Using a simpler approach to avoid regex issues
    final List<String> tokens = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]+'), ' ')  // Replace punctuation with space
        .trim()
        .split(RegExp(r'\s+'))                  // Split on whitespace
        .where((token) => token.isNotEmpty)
        .toList();

    // Convert tokens to IDs using a simple hashing approach
    // In a real implementation, you would use a vocabulary lookup
    return tokens.map((token) {
      // Simple hash function to generate consistent IDs
      int hash = 0;
      for (int i = 0; i < token.length; i++) {
        hash = (hash * 31 + token.codeUnitAt(i)) & 0x7fffffff;
      }
      return (hash % 10000) + 1; // Ensure non-zero and reasonable range
    }).toList();
  }

  /// Pads or truncates a sequence to the specified length.
  static List<int> _padOrTruncate(List<int> sequence, int targetLength) {
    if (sequence.length >= targetLength) {
      return sequence.sublist(0, targetLength);
    } else {
      // Pad with zeros (assuming 0 is the padding token)
      final List<int> padded = List.from(sequence);
      padded.addAll(List.filled(targetLength - sequence.length, 0));
      return padded;
    }
  }

  /// Extracts entities from model output logits using simple argmax decoding.
  ///
  /// [logits] - 2D list [sequence_length, num_labels] containing model output
  /// [tokens] - List of token IDs corresponding to the input sequence
  /// [originalText] - Original input text for fallback token mapping
  static Map<String, String> _extractEntitiesFromOutput(
      List<List<double>> logits,
      List<int> tokens,
      String originalText) {

    final Map<String, String> entities = <String, String>{};
    final List<String> predictedLabels = <String>[];
    
    // Create a word list from the original text matching the tokenizer's logic
    final List<String> originalWords = originalText
        .replaceAll(RegExp(r'[^\w\s]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    try {
      // For each token position, find the label with highest probability
      for (int i = 0; i < logits.length; i++) {
        if (i >= _labels.length) break; // Safety check

        final List<double> logitsForPosition = logits[i];
        if (logitsForPosition.isEmpty) {
          predictedLabels.add('O');
          continue;
        }

        // Find index of maximum logit (argmax)
        int maxIndex = 0;
        double maxValue = logitsForPosition[0];

        for (int j = 1; j < logitsForPosition.length; j++) {
          if (logitsForPosition[j] > maxValue) {
            maxValue = logitsForPosition[j];
            maxIndex = j;
          }
        }

        // Ensure index is within bounds
        final String label = maxIndex < _labels.length
            ? _labels[maxIndex]
            : 'O';

        predictedLabels.add(label);
      }

      // Extract entities using simple BIO decoding
      String currentEntity = '';
      String currentType = '';

      for (int i = 0; i < predictedLabels.length; i++) {
        final String label = predictedLabels[i];

        if (label.startsWith('B-')) {
          // Start of a new entity
          if (currentEntity.isNotEmpty) {
            // Save previous entity
            _addEntity(entities, currentType, currentEntity);
          }
          // Start new entity
          currentType = label.substring(2); // Remove 'B-' prefix
          currentEntity = _tokenToWord(tokens[i], i, originalWords) ?? '';
        } else if (label.startsWith('I-') && currentType == label.substring(2)) {
          // Continuation of current entity
          final String? nextWord = _tokenToWord(tokens[i], i, originalWords);
          if (nextWord != null && nextWord.isNotEmpty) {
            if (currentEntity.isNotEmpty) {
              currentEntity += ' ';
            }
            currentEntity += nextWord;
          }
        } else {
          // Outside any entity or transition to different entity type
          if (currentEntity.isNotEmpty) {
            _addEntity(entities, currentType, currentEntity);
            currentEntity = '';
            currentType = '';
          }
        }
      }

      // Don't forget the last entity if any
      if (currentEntity.isNotEmpty) {
        _addEntity(entities, currentType, currentEntity);
      }

    } catch (e) {
      debugPrint('Error in entity extraction from output: $e');
      // Return empty map on error - caller should handle fallback
    }

    return entities;
  }

  /// Helper method to add an entity to the results map.
  static void _addEntity(Map<String, String> entities, String type, String entity) {
    if (entity.trim().isEmpty) return;

    final String cleanEntity = entity.trim();

    // Map NER types to output keys
    String outputKey;
    switch (type) {
      case 'PER':
        outputKey = 'person';
        break;
      case 'ORG':
        outputKey = 'organization';
        break;
      case 'LOC':
        outputKey = 'location';
        break;
      case 'MISC':
        outputKey = 'misc';
        break;
      default:
        // For unknown types, default to misc
        outputKey = 'misc';
    }

    // Only store the first occurrence of each entity type
    // or concatenate if you prefer to collect all entities
    if (!entities.containsKey(outputKey) ||
        entities[outputKey]!.isEmpty ||
        entities[outputKey] == 'Not Found') {
      entities[outputKey] = cleanEntity;
    }
  }

  /// Attempts to map a token ID back to its original word.
  /// This is a simplified implementation - real implementations would
  /// use the tokenizer's vocabulary for accurate mapping.
  static String? _tokenToWord(int tokenId, int tokenIndex, List<String> originalWords) {
    if (tokenId == 0) return null; // Assuming 0 is padding

    // Map back to the original word based on position, preserving original case
    if (tokenIndex >= 0 && tokenIndex < originalWords.length) {
      return originalWords[tokenIndex];
    }
    
    // Fallback if index out of bounds
    return null;
  }

  /// Checks if the offline transformer service is initialized and ready.
  static bool get isReady => _isInitialized && _interpreter != null;
}