import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/data_provider.dart';
import '../services/image_processor_service.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> extractedData;
  final XFile xFile;
  final String savedImagePath;
  final Color dominantColor;
  final Color dominantColorSecondary;

  const ResultScreen({
    super.key,
    required this.extractedData,
    required this.xFile,
    required this.savedImagePath,
    required this.dominantColor,
    required this.dominantColorSecondary,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  String _kanbanStatus = 'New Lead';
  String _selectedTag = 'BUSINESS';

  static const List<String> _kanbanOptions = ['New Lead', 'Contacted', 'Followed Up', 'Closed'];
  static const List<String> _tagOptions = [
    'BUSINESS', 'STARTUP', 'UNIVERSITY', 'CONSULTANCY', 'NGO', 'GOVERNMENT', 'HEALTHCARE', 'FINANCE', 'TECHNOLOGY'
  ];

  static const Map<String, String> _fieldLabels = {
    'point_person': 'Full Name',
    'department': 'Job Title / Role',
    'organization_name': 'Company / Organization',
    'contact_number': 'Phone Number',
    'contact_email': 'Email Address',
    'url': 'Website URL',
    'location': 'Full Address',
    'address': 'Full Address',
    'notes': 'Notes',
  };

  static const Map<String, IconData> _fieldIcons = {
    'point_person': Icons.person_rounded,
    'department': Icons.work_rounded,
    'organization_name': Icons.business_rounded,
    'contact_number': Icons.phone_rounded,
    'contact_email': Icons.email_rounded,
    'url': Icons.language_rounded,
    'location': Icons.location_on_rounded,
    'address': Icons.home_rounded,
    'notes': Icons.notes_rounded,
  };

  @override
  void initState() {
    super.initState();
    _selectedTag = widget.extractedData['organization_type']?.toString() ?? 'BUSINESS';
    _kanbanStatus = 'New Lead';

    for (final key in _fieldLabels.keys) {
      var value = widget.extractedData[key]?.toString() ?? '';
      if (value.toLowerCase() == 'not found') value = '';
      _controllers[key] = TextEditingController(text: value);
    }

    // Show warning after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMissingFields());
  }

  void _checkMissingFields() {
    final person = _controllers['point_person']?.text.trim() ?? '';
    final org = _controllers['organization_name']?.text.trim() ?? '';
    if (person.isEmpty && mounted) {
      _showWarning('👤 Name not detected — please fill it in manually');
    } else if (org.isEmpty && mounted) {
      _showWarning('🏢 Organization not detected — please fill it in manually');
    }
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    final person = _controllers['point_person']?.text.trim() ?? '';
    final org = _controllers['organization_name']?.text.trim() ?? '';

    if (person.isEmpty) {
      _showWarning('⚠️ Person name is required');
      return;
    }
    if (org.isEmpty) {
      _showWarning('⚠️ Organization name is required');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build final card data
      final Map<String, dynamic> finalData = {};
      _controllers.forEach((key, ctrl) {
        finalData[key] = ctrl.text.trim();
      });

      finalData['organization_type'] = _selectedTag;
      finalData['kanban_status'] = _kanbanStatus;
      finalData['image_path'] = widget.savedImagePath;
      finalData['dominant_color'] = ImageProcessorService.colorToHex(widget.dominantColor);
      finalData['dominant_color_secondary'] = ImageProcessorService.colorToHex(widget.dominantColorSecondary);

      // Duplicate check
      final duplicate = await ref.read(localDbServiceProvider).checkDuplicate(finalData);
      if (duplicate != null && mounted) {
        final saveAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate Detected'),
            content: Text(
              "A card for '${duplicate['point_person']}' from '${duplicate['organization_name']}' already exists. Save anyway?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        ) ?? false;
        if (!saveAnyway) {
          setState(() => _isSaving = false);
          return;
        }
      }

      final slNo = await ref.read(localCardsProvider.notifier).addCard(finalData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Saved as card #$slNo'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topColor = widget.dominantColor;
    final botColor = widget.dominantColorSecondary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // ── TOP HALF: Card Image Preview ──────────────────────────────────
          Expanded(
            flex: 40,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [topColor, botColor],
                    ),
                  ),
                ),
                // Card image
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      MediaQuery.of(context).padding.top + 52,
                      24,
                      16,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: File(widget.savedImagePath).existsSync()
                          ? Image.file(
                              File(widget.savedImagePath),
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              File(widget.xFile.path),
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
                // Safe area top bar
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        ),
                        Text(
                          'Verify & Save',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _isSaving
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              )
                            : TextButton.icon(
                                onPressed: _saveCard,
                                icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── BOTTOM HALF: Editable Fields ──────────────────────────────────
          Expanded(
            flex: 60,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  // Category tag + Kanban row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Category',
                          value: _selectedTag,
                          items: _tagOptions,
                          onChanged: (v) => setState(() => _selectedTag = v!),
                          icon: Icons.label_rounded,
                          color: topColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Lead Status',
                          value: _kanbanStatus,
                          items: _kanbanOptions,
                          onChanged: (v) => setState(() => _kanbanStatus = v!),
                          icon: Icons.view_kanban_rounded,
                          color: topColor,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),

                  // Editable fields
                  ..._fieldLabels.entries.mapIndexed((index, entry) {
                    final key = entry.key;
                    final label = entry.value;
                    final icon = _fieldIcons[key] ?? Icons.text_fields;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _controllers[key],
                        keyboardType: key == 'contact_number'
                            ? TextInputType.phone
                            : key == 'contact_email'
                                ? TextInputType.emailAddress
                                : key == 'url'
                                    ? TextInputType.url
                                    : TextInputType.multiline,
                        maxLines: key == 'address' || key == 'notes' ? 2 : 1,
                        decoration: InputDecoration(
                          labelText: label,
                          prefixIcon: Icon(icon, color: topColor, size: 20),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: topColor, width: 1.5),
                          ),
                          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ).animate()
                      .fadeIn(delay: Duration(milliseconds: 60 * index), duration: 300.ms)
                      .slideY(begin: 0.1, duration: 300.ms);
                  }).toList(),

                  const SizedBox(height: 8),

                  // Save button
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveCard,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Contact'),
                    style: FilledButton.styleFrom(
                      backgroundColor: topColor,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: color, size: 18),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
          hint: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          selectedItemBuilder: (ctx) => items.map((e) => Align(
            alignment: Alignment.centerLeft,
            child: Text(e, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          )).toList(),
        ),
      ),
    );
  }
}

extension _IndexedMap<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T element) f) sync* {
    int i = 0;
    for (final element in this) {
      yield f(i++, element);
    }
  }
}
