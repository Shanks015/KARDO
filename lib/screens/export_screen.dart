import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/export_service.dart';
import '../services/local_db_service.dart';
import '../theme/tokens.dart';
import '../widgets/ios_components.dart';
import '../widgets/kardo_components.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;

    return Scaffold(
      backgroundColor: t.scaffoldBackground,
      appBar: IOSNavBar(
        title: _isSingleCard ? 'Export Card' : 'Export All Cards',
        showBackButton: true,
      ),
      body: _buildBody(context, theme, isDark),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, bool isDark) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              _isSingleCard ? 'Export this contact' : 'Export your collection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSingleCard
                  ? 'Generate a PDF, vCard, or QR code for this contact'
                  : 'Download all saved cards in multiple formats',
              style: TextStyle(
                fontSize: 16,
                color: t.textSecondary,
              ),
            ),

            // Filter (only for bulk export)
            if (!_isSingleCard) ...[
              const SizedBox(height: 28),
              Text(
                'FILTER BY TYPE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filterOptions.length,
                  itemBuilder: (context, index) {
                    final filter = _filterOptions[index];
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child:                       FilterChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        selectedColor: t.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? t.accent
                                : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'EXPORT FORMAT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
            ]
            else ...[
              const SizedBox(height: 28),
              Text(
                'EXPORT FORMAT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Format selections as iOS-style cells
            _buildExportFormatCell(
              context,
              theme,
              isDark,
              icon: Icons.picture_as_pdf_rounded,
              title: _isSingleCard ? 'Export as PDF' : 'Export to PDF',
              subtitle: _isSingleCard
                  ? 'Card image + all details in a beautiful PDF'
                  : 'Professional report with all contacts',
              isLoading: _isExporting && _exportingFormat == 'pdf',
              isPrimary: true,
              onTap: () => _export('pdf'),
            ),
            const SizedBox(height: 14),

            if (_isSingleCard) ...[
              _buildExportFormatCell(
                context,
                theme,
                isDark,
                icon: Icons.contact_page_rounded,
                title: 'Export as vCard (.vcf)',
                subtitle:
                    'Standard format — opens directly in any contacts app',
                isLoading:
                    _isExporting && _exportingFormat == 'vcf',
                isPrimary: false,
                onTap: () => _export('vcf'),
              ),
              const SizedBox(height: 14),
            ],

            _buildExportFormatCell(
              context,
              theme,
              isDark,
              icon: Icons.table_chart_rounded,
              title: 'Export to Excel',
              subtitle:
                  'Spreadsheet with headers, styling & Kanban status',
              isLoading:
                  _isExporting && _exportingFormat == 'excel',
              isPrimary: false,
              onTap: () => _export('excel'),
              visible: !_isSingleCard,
            ),
            if (!_isSingleCard) const SizedBox(height: 14),

            _buildExportFormatCell(
              context,
              theme,
              isDark,
              icon: Icons.description_rounded,
              title: 'Export to CSV',
              subtitle:
                  'Lightweight format for any spreadsheet app',
              isLoading:
                  _isExporting && _exportingFormat == 'csv',
              isPrimary: false,
              onTap: () => _export('csv'),
              visible: !_isSingleCard,
            ),

            const SizedBox(height: 28),
            // Info box
            _buildInfoBox(context, theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildExportFormatCell(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    {required IconData icon,
    required String title,
    required String subtitle,
    required bool isLoading,
    required bool isPrimary,
    required VoidCallback onTap,
    bool visible = true}) {
    if (!visible) return const SizedBox.shrink();
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? t.accent
                : t.borderDefault,
            width: isPrimary ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isPrimary
                    ? t.accent
                    : (isDark
                        ? Colors.white
                        : t.accent),
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: t.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: t.textSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(
      BuildContext context, ThemeData theme, bool isDark) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.accentLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.borderDefault,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bolt_rounded,
            color: t.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Files are saved to your device and can be shared via Bluetooth, email, or messaging apps.',
              style: TextStyle(
                fontSize: 14,
                color: t.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(String format) async {
    setState(() {
      _isExporting = true;
      _exportingFormat = format;
    });

    try {
      String filePath;
      final service = ExportService();

      if (_isSingleCard) {
        final card = widget.singleCard!;
        if (format == 'pdf') {
          filePath = await service.exportSingleCardPdf(card);
        } else if (format == 'vcf') {
          filePath = await service.exportToVCard(card);
        } else {
          throw Exception('Format not supported for single card');
        }
      } else {
        final db = LocalDatabaseService();
        List<Map<String, dynamic>> cards = await db.getCards();

        if (_selectedFilter != 'All') {
          cards = cards
              .where((c) =>
                  (c['organization_type']?.toString() ?? '').toUpperCase() ==
                  _selectedFilter.toUpperCase())
              .toList();
        }

        if (format == 'pdf') {
          filePath =
              await service.exportToPdf(cards, filterType: _selectedFilter);
        } else if (format == 'excel') {
          filePath =
              await service.exportToXls(cards, filterType: _selectedFilter);
        } else if (format == 'csv') {
          filePath =
              await service.exportToCsv(cards, filterType: _selectedFilter);
        } else {
          throw Exception('Format not supported for multi card');
        }
      }

      if (mounted) {
        final file = File(filePath);
        if (await file.exists()) {
          await Share.shareXFiles(
            [XFile(filePath)],
            text: 'Check out my business card collection from Kardo Scan!',
          );

          // Also offer to open the file
          final bool? openFile =
              await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Export Successful'),
              content: Text(
                  'Your file has been exported successfully. Open it now?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Open'),
                ),
              ],
            ),
          );

          if (openFile == true && mounted) {
            await OpenFile.open(filePath);
          }
        } else {
          if (mounted) {
            showKardoSnack(context, 'Export failed — file not found.',
                kind: KardoSnackKind.error);
          }
        }
      }
    } catch (e) {
      debugPrint('Export failed: $e');
      if (mounted) {
        showKardoSnack(context, 'Export failed. Please try again.',
            kind: KardoSnackKind.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportingFormat = '';
        });
      }
    }
  }
}