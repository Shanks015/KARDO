import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
    'BUSINESS', 'STARTUP', 'UNIVERSITY', 'CONSULTANCY', 'NGO', 'GOVERNMENT', 'HEALTHCARE', 'FINANCE', 'TECHNOLOGY', 'TECH', 'OTHER'
  ];

  String _getFormattedCapturedDateTime() {
    final raw = widget.extractedData['timestamp']?.toString() ?? widget.extractedData['created_at']?.toString() ?? '';
    if (raw.isEmpty) {
      return DateFormat('MMM dd, yyyy • h:mm a').format(DateTime.now());
    }
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM dd, yyyy • h:mm a').format(dt.toLocal());
    } catch (_) {
      return raw;
    }
  }

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
    'department': Icons.work_outline_rounded,
    'organization_name': Icons.business_rounded,
    'contact_number': Icons.phone_outlined,
    'contact_email': Icons.email_outlined,
    'url': Icons.language_rounded,
    'location': Icons.location_on_outlined,
    'address': Icons.home_outlined,
    'notes': Icons.notes_rounded,
  };

  @override
  void initState() {
    super.initState();
    var rawTag = widget.extractedData['organization_type']?.toString().toUpperCase().trim() ?? 'BUSINESS';
    if (rawTag == 'TECH') rawTag = 'TECHNOLOGY';
    if (rawTag == 'GOVT') rawTag = 'GOVERNMENT';
    if (rawTag == 'EDU') rawTag = 'UNIVERSITY';
    _selectedTag = _tagOptions.contains(rawTag) ? rawTag : 'BUSINESS';
    _kanbanStatus = 'New Lead';

    for (final key in _fieldLabels.keys) {
      var value = widget.extractedData[key]?.toString() ?? '';
      if (value.toLowerCase() == 'not found') value = '';
      _controllers[key] = TextEditingController(text: value);
    }
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

      final captureIso = widget.extractedData['timestamp'] ?? widget.extractedData['created_at'] ?? DateTime.now().toIso8601String();
      finalData['timestamp'] = captureIso;
      finalData['created_at'] = captureIso;

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
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28),
                const SizedBox(width: 10),
                const Text('Card Saved', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text("Business card for '$person' has been successfully saved to your library as card #$slNo."),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF536DFE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Great!'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context);
        }
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
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 140,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF536DFE)),
          label: const Text('New Contact', style: TextStyle(color: Color(0xFF536DFE), fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                // Top section: Beautiful Card Preview
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: File(widget.savedImagePath).existsSync()
                          ? Image.file(File(widget.savedImagePath), fit: BoxFit.cover)
                          : Image.file(File(widget.xFile.path), fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF536DFE).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF536DFE).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF536DFE)),
                        const SizedBox(width: 6),
                        Text(
                          'Captured On: ${_getFormattedCapturedDateTime()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF536DFE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Inline Warning Banner if fields are missing
                if (_controllers['point_person']?.text.trim().isEmpty == true ||
                    _controllers['organization_name']?.text.trim().isEmpty == true) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50.withOpacity(isDark ? 0.15 : 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade300, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'AI detected some missing details (Name or Company). Please review and fill them in manually.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Personal section
                _buildSectionTitle('Personal'),
                _buildFieldGroup([
                  _buildTextField('point_person', 'Full Name'),
                  _buildTextField('contact_email', 'Email Address'),
                  _buildTextField('contact_number', 'Phone Number'),
                ]),
                const SizedBox(height: 24),

                // Work section
                _buildSectionTitle('Work'),
                _buildFieldGroup([
                  _buildTextField('department', 'Job Title / Role'),
                  _buildTextField('organization_name', 'Company'),
                  _buildTextField('url', 'Website'),
                ]),
                const SizedBox(height: 24),

                // Settings section (mimicking mockup style)
                _buildSectionTitle('Settings'),
                _buildFieldGroup([
                  _buildDropdownField('Category', _selectedTag, _tagOptions, (v) => setState(() => _selectedTag = v!)),
                  _buildDropdownField('Lead Status', _kanbanStatus, _kanbanOptions, (v) => setState(() => _kanbanStatus = v!)),
                  _buildTextField('location', 'Address', maxLines: 2),
                ]),
                const SizedBox(height: 32),

                // Save Button inside ListView
                FilledButton(
                  onPressed: _isSaving ? null : _saveCard,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF536DFE),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save to contacts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 48), // Padding at the bottom
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
      ),
    );
  }

  Widget _buildFieldGroup(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) Divider(height: 1, indent: 48, color: isDark ? Colors.grey.shade800 : const Color(0xFFF0F0F0)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField(String key, String placeholder, {int maxLines = 1}) {
    return TextFormField(
      controller: _controllers[key],
      keyboardType: key == 'contact_number' ? TextInputType.phone : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
        prefixIcon: Icon(_fieldIcons[key], color: Colors.grey.shade400, size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, void Function(String?) onChanged) {
    final effectiveItems = items.contains(value) ? items : [...items, value];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.label_outline_rounded, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: Icon(Icons.expand_more, color: Colors.grey.shade400, size: 20),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87, 
                  fontSize: 15, 
                  fontWeight: FontWeight.w500
                ),
                items: effectiveItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
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
