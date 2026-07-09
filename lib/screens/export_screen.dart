import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/export_service.dart';
import '../services/local_db_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? singleCard; // non-null when called from contact detail

  const ExportScreen({super.key, this.singleCard});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _selectedFilter = 'All';
  bool _isExporting = false;
  String _exportingFormat = '';

  final List<String> _filterOptions = [
    'All', 'UNIVERSITY', 'BUSINESS', 'CONSULTANCY', 'NGO', 'STARTUP', 'GOVERNMENT'
  ];

  bool get _isSingleCard => widget.singleCard != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(_isSingleCard ? 'Export Card' : 'Export All Cards'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.primaryContainer.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    _isSingleCard ? 'Export this contact' : 'Export your collection',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 6),
                  Text(
                    _isSingleCard
                        ? 'Generate a PDF, vCard, or QR code for this contact'
                        : 'Download all saved cards in multiple formats',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ).animate().fadeIn(delay: 100.ms),

                  // Filter (only for bulk export)
                  if (!_isSingleCard) ...[
                    const SizedBox(height: 28),
                    _buildSectionTitle(theme, 'FILTER BY TYPE'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filterOptions.length,
                        itemBuilder: (_, i) {
                          final f = _filterOptions[i];
                          final selected = _selectedFilter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(f, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                              selected: selected,
                              onSelected: (_) => setState(() => _selectedFilter = f),
                              showCheckmark: false,
                              selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                              side: BorderSide(color: selected ? theme.colorScheme.primary : Colors.grey.shade300),
                            ),
                          );
                        },
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ],

                  const SizedBox(height: 28),
                  _buildSectionTitle(theme, 'EXPORT FORMAT'),
                  const SizedBox(height: 14),

                  // ── Cards ────────────────────────────────────────────────
                  _buildExportCard(
                    theme,
                    icon: Icons.picture_as_pdf_rounded,
                    title: _isSingleCard ? 'Export as PDF' : 'Export to PDF',
                    subtitle: _isSingleCard
                        ? 'Card image + all details in a beautiful PDF'
                        : 'Professional report with all contacts',
                    gradient: [const Color(0xFF5C35C8), const Color(0xFF2D1B69)],
                    isLoading: _isExporting && _exportingFormat == 'pdf',
                    onTap: () => _export('pdf'),
                    delay: 0.ms,
                  ),
                  const SizedBox(height: 14),

                  if (_isSingleCard) ...[
                    _buildExportCard(
                      theme,
                      icon: Icons.contact_page_rounded,
                      title: 'Export as vCard (.vcf)',
                      subtitle: 'Standard format — opens directly in any contacts app',
                      gradient: [const Color(0xFF00897B), const Color(0xFF004D40)],
                      isLoading: _isExporting && _exportingFormat == 'vcf',
                      onTap: () => _export('vcf'),
                      delay: 100.ms,
                    ),
                    const SizedBox(height: 14),
                  ],

                  _buildExportCard(
                    theme,
                    icon: Icons.table_chart_rounded,
                    title: 'Export to Excel',
                    subtitle: 'Spreadsheet with headers, styling & Kanban status',
                    gradient: [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
                    isLoading: _isExporting && _exportingFormat == 'excel',
                    onTap: () => _export('excel'),
                    delay: 100.ms,
                    visible: !_isSingleCard,
                  ),
                  if (!_isSingleCard) const SizedBox(height: 14),

                  _buildExportCard(
                    theme,
                    icon: Icons.description_rounded,
                    title: 'Export to CSV',
                    subtitle: 'Lightweight format for any spreadsheet app',
                    gradient: [const Color(0xFFE65100), const Color(0xFFBF360C)],
                    isLoading: _isExporting && _exportingFormat == 'csv',
                    onTap: () => _export('csv'),
                    delay: 200.ms,
                    visible: !_isSingleCard,
                  ),

                  const SizedBox(height: 28),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.offline_bolt_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '100% offline — files are saved to your device and can be shared via Bluetooth, email, or messaging apps.',
                            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ),
            ),
          ),

          // Full-screen loading overlay
          if (_isExporting)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Generating $_exportingFormat...', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildExportCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required bool isLoading,
    required VoidCallback onTap,
    required Duration delay,
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _isExporting ? null : onTap,
      child: AnimatedOpacity(
        opacity: _isExporting && !isLoading ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        maxLines: 2),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    ).animate().scale(delay: delay, duration: 400.ms, curve: Curves.easeOut);
  }

  Future<void> _export(String format) async {
    setState(() {
      _isExporting = true;
      _exportingFormat = format.toUpperCase();
    });

    try {
      final exportService = ExportService();
      String filePath;

      if (_isSingleCard) {
        // Single card export
        final card = widget.singleCard!;
        if (format == 'pdf') {
          filePath = await exportService.exportSingleCardPdf(card);
        } else if (format == 'vcf') {
          filePath = await exportService.exportToVCard(card);
        } else {
          throw Exception('Unknown format for single card: $format');
        }
      } else {
        // Bulk export
        final db = LocalDatabaseService();
        final cards = await db.getCards();

        if (cards.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No cards to export'), backgroundColor: Colors.orange),
            );
          }
          setState(() => _isExporting = false);
          return;
        }

        final filter = _selectedFilter == 'All' ? null : _selectedFilter;

        switch (format) {
          case 'pdf':
            filePath = await exportService.exportToPdf(cards, filterType: filter);
            break;
          case 'excel':
            filePath = await exportService.exportToXls(cards, filterType: filter);
            break;
          case 'csv':
            filePath = await exportService.exportToCsv(cards, filterType: filter);
            break;
          default:
            throw Exception('Unknown format: $format');
        }
      }

      setState(() => _isExporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${format.toUpperCase()} exported successfully!'),
            backgroundColor: Colors.green.shade700,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () => OpenFile.open(filePath),
          ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
