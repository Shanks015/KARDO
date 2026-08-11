import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/data_provider.dart';

class BatchResultScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> extractedDataList;

  const BatchResultScreen({super.key, required this.extractedDataList});

  @override
  ConsumerState<BatchResultScreen> createState() => _BatchResultScreenState();
}

class _BatchResultScreenState extends ConsumerState<BatchResultScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isSaving = false;

  late List<Map<String, TextEditingController>> _pageControllers;
  late List<String> _kanbanStatuses;
  late List<String> _selectedTags;

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

  static const List<String> _tagOptions = [
    'BUSINESS', 'STARTUP', 'UNIVERSITY', 'CONSULTANCY', 'NGO', 'GOVERNMENT', 'HEALTHCARE', 'FINANCE', 'TECHNOLOGY'
  ];

  @override
  void initState() {
    super.initState();
    _pageControllers = List.generate(widget.extractedDataList.length, (index) {
      final map = <String, TextEditingController>{};
      final data = widget.extractedDataList[index];
      for (final key in _fieldLabels.keys) {
        var value = data[key]?.toString() ?? '';
        if (value.toLowerCase() == 'not found') value = '';
        map[key] = TextEditingController(text: value);
      }
      return map;
    });

    _kanbanStatuses = List.generate(
        widget.extractedDataList.length,
        (index) => widget.extractedDataList[index]['kanban_status']?.toString() ?? 'New Lead');
    
    _selectedTags = List.generate(
        widget.extractedDataList.length,
        (index) => widget.extractedDataList[index]['organization_type']?.toString() ?? 'BUSINESS');
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var map in _pageControllers) {
      for (var ctrl in map.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
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

  Future<bool> _saveCurrentCard() async {
    final controllers = _pageControllers[_currentIndex];
    final person = controllers['point_person']?.text.trim() ?? '';
    final org = controllers['organization_name']?.text.trim() ?? '';

    if (person.isEmpty) {
      _showWarning('⚠️ Person name is required for card ${_currentIndex + 1}');
      return false;
    }
    if (org.isEmpty) {
      _showWarning('⚠️ Organization name is required for card ${_currentIndex + 1}');
      return false;
    }

    setState(() => _isSaving = true);

    try {
      final originalData = widget.extractedDataList[_currentIndex];
      final Map<String, dynamic> finalData = {...originalData};
      
      controllers.forEach((key, ctrl) {
        finalData[key] = ctrl.text.trim();
      });

      finalData['organization_type'] = _selectedTags[_currentIndex];
      finalData['kanban_status'] = _kanbanStatuses[_currentIndex];
      final captureTime = DateTime.now().toIso8601String();
      finalData['timestamp'] ??= captureTime;
      finalData['created_at'] ??= captureTime;

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
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
          return false;
        }
      }

      await ref.read(localCardsProvider.notifier).addCard(finalData);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onNext() async {
    final saved = await _saveCurrentCard();
    if (!saved) return;

    if (_currentIndex < widget.extractedDataList.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ All ${widget.extractedDataList.length} cards saved!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context); // Pop back to Home
      }
    }
  }

  void _onSkip() {
     if (_currentIndex < widget.extractedDataList.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (mounted) Navigator.pop(context);
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
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
          label: const Text('Cancel Batch', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        title: Text(
          'Review ${_currentIndex + 1} of ${widget.extractedDataList.length}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe to force using buttons
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.extractedDataList.length,
        itemBuilder: (context, index) {
          return _buildPage(index, theme, isDark);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _onSkip,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade400),
                    foregroundColor: Colors.grey.shade700,
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isSaving ? null : _onNext,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF536DFE),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _currentIndex == widget.extractedDataList.length - 1 ? 'Save & Finish' : 'Save & Next',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int index, ThemeData theme, bool isDark) {
    final controllers = _pageControllers[index];
    final data = widget.extractedDataList[index];
    final imagePath = data['image_path']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        // Top section: Preview
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SizedBox(
                  height: 120,
                  child: File(imagePath).existsSync()
                      ? Image.file(File(imagePath), fit: BoxFit.cover, alignment: Alignment.topCenter)
                      : Container(color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        _buildSectionTitle('Personal'),
        _buildFieldGroup([
          _buildTextField('point_person', 'Full Name', controllers),
          _buildTextField('contact_email', 'Email Address', controllers),
          _buildTextField('contact_number', 'Phone Number', controllers),
        ], theme, isDark),
        const SizedBox(height: 24),

        _buildSectionTitle('Work'),
        _buildFieldGroup([
          _buildTextField('organization_name', 'Company / Organization', controllers),
          _buildTextField('department', 'Job Title / Role', controllers),
          _buildTextField('url', 'Website URL', controllers),
        ], theme, isDark),
        const SizedBox(height: 24),

        _buildSectionTitle('Organization Type'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: _tagOptions.map((tag) {
            final isSelected = _selectedTags[index] == tag;
            return ChoiceChip(
              label: Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedTags[index] = tag);
              },
              selectedColor: const Color(0xFF536DFE),
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        _buildSectionTitle('Additional Details'),
        _buildFieldGroup([
          _buildTextField('location', 'Location / Address', controllers),
          _buildTextField('notes', 'Notes', controllers, maxLines: 3),
        ], theme, isDark),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildFieldGroup(List<Widget> children, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTextField(String key, String label, Map<String, TextEditingController> controllers, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: controllers[key],
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}
