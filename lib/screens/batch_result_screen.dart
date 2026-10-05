import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_provider.dart';
import '../theme/tokens.dart';
import '../widgets/kardo_components.dart';

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
    showKardoSnack(context, message, kind: KardoSnackKind.warning);
  }

  Future<bool> _saveCurrentCard() async {
    final controllers = _pageControllers[_currentIndex];
    final person = controllers['point_person']?.text.trim() ?? '';
    final org = controllers['organization_name']?.text.trim() ?? '';
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;

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
                style: FilledButton.styleFrom(backgroundColor: t.warning),
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
      debugPrint('Batch card save failed: $e');
      if (mounted) {
        showKardoSnack(context, 'Could not save one of the cards.',
            kind: KardoSnackKind.error);
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
        showKardoSnack(
            context, 'All ${widget.extractedDataList.length} cards saved!',
            kind: KardoSnackKind.success);
        Navigator.pop(context);
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
    final t = theme.extension<KardoTokensExtension>()!.tokens;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close_rounded, size: 20, color: t.grey),
          label: Text('Cancel Batch', style: TextStyle(color: t.grey, fontSize: 13)),
        ),
        title: Text(
          'Review ${_currentIndex + 1} of ${widget.extractedDataList.length}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: t.text),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.extractedDataList.length,
        itemBuilder: (context, index) {
          return _buildPage(index, theme, isDark, t);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: t.card,
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
                    side: BorderSide(color: t.grey),
                    foregroundColor: t.grey,
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
                    backgroundColor: t.accent,
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

  Widget _buildPage(int index, ThemeData theme, bool isDark, KardoTokens t) {
    final controllers = _pageControllers[index];
    final data = widget.extractedDataList[index];
    final imagePath = data['image_path']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
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
                      : Container(color: t.surfaceAlt, child: const Icon(Icons.image_not_supported)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        _buildSectionTitle('Personal', t),
        _buildFieldGroup([
          _buildTextField('point_person', 'Full Name', controllers),
          _buildTextField('contact_email', 'Email Address', controllers),
          _buildTextField('contact_number', 'Phone Number', controllers),
        ], t),
        const SizedBox(height: 24),

        _buildSectionTitle('Work', t),
        _buildFieldGroup([
          _buildTextField('organization_name', 'Company / Organization', controllers),
          _buildTextField('department', 'Job Title / Role', controllers),
          _buildTextField('url', 'Website URL', controllers),
        ], t),
        const SizedBox(height: 24),

        _buildSectionTitle('Organization Type', t),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: _tagOptions.map((tag) {
            final isSelected = _selectedTags[index] == tag;
            return ChoiceChip(
              label: Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : t.grey)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedTags[index] = tag);
              },
              selectedColor: t.accent,
              backgroundColor: t.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              side: BorderSide(color: isSelected ? Colors.transparent : t.grey.withOpacity(0.3)),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        _buildSectionTitle('Additional Details', t),
        _buildFieldGroup([
          _buildTextField('location', 'Location / Address', controllers),
          _buildTextField('notes', 'Notes', controllers, maxLines: 3),
        ], t),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(String title, KardoTokens t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
          style: t.labelMedium.copyWith(fontWeight: FontWeight.bold, color: t.grey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildFieldGroup(List<Widget> children, KardoTokens t) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: t.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTextField(String key, String label, Map<String, TextEditingController> controllers, {int maxLines = 1}) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: controllers[key],
        maxLines: maxLines,
          style: t.bodySmall,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: t.grey, fontSize: 13),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}
