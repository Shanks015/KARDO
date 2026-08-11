import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../services/nfc_service.dart';

class ExportService {
  String _val(Map<String, dynamic> card, String key) {
    final v = card[key]?.toString() ?? '';
    return v.toLowerCase() == 'not found' ? '' : v;
  }

  Future<Directory> _getExportDirectory() async {
    final dir = await getTemporaryDirectory();
    final exportDir = Directory('${dir.path}/kardo_exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  /// Export a single card as a styled PDF (image at top + structured data below)
  Future<String> exportSingleCardPdf(Map<String, dynamic> card) async {
    try {
      final pdf = pw.Document();
      final imagePath = card['image_path']?.toString() ?? '';
      final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();

      pw.MemoryImage? cardImage;
      if (hasImage) {
        final bytes = await File(imagePath).readAsBytes();
        cardImage = pw.MemoryImage(bytes);
      }

      final name = _val(card, 'point_person');
      final org = _val(card, 'organization_name');
      final role = _val(card, 'department');
      final phone = _val(card, 'contact_number');
      final email = _val(card, 'contact_email');
      final url = _val(card, 'url');
      final location = _val(card, 'location').isNotEmpty ? _val(card, 'location') : _val(card, 'address');
      final tag = _val(card, 'organization_type');
      final notes = _val(card, 'notes').isNotEmpty ? _val(card, 'notes') : _val(card, 'remark');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header bar
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('kardo',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          )),
                      pw.Text(
                        'Generated ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                if (cardImage != null) ...[
                  pw.Center(
                    child: pw.Container(
                      height: 200,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 8,
                        verticalRadius: 8,
                        child: pw.Image(cardImage, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 32),
                ],

                pw.Text(name.isNotEmpty ? name : 'Unnamed Contact',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                if (role.isNotEmpty)
                  pw.Text(role, style: pw.TextStyle(fontSize: 14, color: PdfColors.blueGrey600)),
                if (org.isNotEmpty)
                  pw.Text(org, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                pw.SizedBox(height: 24),

                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 16),

                _buildPdfField('Phone', phone),
                _buildPdfField('Email', email),
                _buildPdfField('Website', url),
                _buildPdfField('Address', location),
                _buildPdfField('Tag', tag),

                if (notes.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 16),
                  pw.Text('Notes', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(notes, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                ],

                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    'Exported by kardo — Business Card Scanner',
                    style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final dir = await _getExportDirectory();
      final safeName = name.isNotEmpty ? name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') : 'Contact';
      final path = '${dir.path}/kardo_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      return path;
    } catch (e) {
      debugPrint('Error generating single PDF: $e');
      rethrow;
    }
  }

  pw.Widget _buildPdfField(String label, String value) {
    if (value.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(label, style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(color: PdfColors.black, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Export a single card as vCard (.vcf)
  Future<String> exportToVCard(Map<String, dynamic> card) async {
    try {
      final vcfString = NfcService.buildVCard(card);
      final dir = await _getExportDirectory();
      final name = _val(card, 'point_person').replaceAll(' ', '_');
      final path = '${dir.path}/kardo_${name}_${DateTime.now().millisecondsSinceEpoch}.vcf';
      final file = File(path);
      await file.writeAsString(vcfString);
      return path;
    } catch (e) {
      debugPrint('Error generating vCard: $e');
      rethrow;
    }
  }

  /// Export list of cards as PDF with a tabular layout
  Future<String> exportToPdf(List<Map<String, dynamic>> cards, {String? filterType}) async {
    try {
      final pdf = pw.Document();

      final filteredCards = filterType == null || filterType == 'All'
          ? cards
          : cards.where((c) => _val(c, 'organization_type').toUpperCase() == filterType.toUpperCase()).toList();

      final headers = ['Name', 'Title', 'Company', 'Phone', 'Email'];
      final data = filteredCards.map((c) {
        return [
          _val(c, 'point_person'),
          _val(c, 'department'),
          _val(c, 'organization_name'),
          _val(c, 'contact_number'),
          _val(c, 'contact_email'),
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 10),
              margin: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('kardo', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  pw.Text('Exported ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              if (filterType != null && filterType != 'All')
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.Text('Filtered by: $filterType', style: pw.TextStyle(fontSize: 14, color: PdfColors.blueGrey600)),
                ),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(2.5),
                },
              ),
            ];
          },
        ),
      );

      final dir = await _getExportDirectory();
      final fileName = 'kardo_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      return path;
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      rethrow;
    }
  }

  /// Export to Excel (.xlsx)
  Future<String> exportToXls(List<Map<String, dynamic>> cards, {String? filterType}) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Contacts'];
      excel.setDefaultSheet('Contacts');

      final filteredCards = filterType == null || filterType == 'All'
          ? cards
          : cards.where((c) => _val(c, 'organization_type').toUpperCase() == filterType.toUpperCase()).toList();

      final headers = [
        'Name',
        'Title',
        'Company',
        'Address',
        'Phone',
        'Email',
        'Website',
        'Tag',
        'Notes',
        'Date Added'
      ];

      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
      }

      for (int i = 0; i < filteredCards.length; i++) {
        final c = filteredCards[i];
        final row = [
          _val(c, 'point_person'),
          _val(c, 'department'),
          _val(c, 'organization_name'),
          _val(c, 'location').isNotEmpty ? _val(c, 'location') : _val(c, 'address'),
          _val(c, 'contact_number'),
          _val(c, 'contact_email'),
          _val(c, 'url'),
          _val(c, 'organization_type'),
          _val(c, 'notes').isNotEmpty ? _val(c, 'notes') : _val(c, 'remark'),
          c['timestamp'] ?? c['created_at'] ?? '',
        ];

        for (var j = 0; j < row.length; j++) {
          var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1));
          cell.value = TextCellValue(row[j].toString());
        }
      }

      final dir = await _getExportDirectory();
      final fileName = 'kardo_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final path = '${dir.path}/$fileName';
      final file = File(path);
      
      final fileBytes = excel.save();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
      }
      return path;
    } catch (e) {
      debugPrint('Error generating Excel: $e');
      rethrow;
    }
  }

  /// Export to CSV format
  Future<String> exportToCsv(List<Map<String, dynamic>> cards, {String? filterType}) async {
    try {
      final filteredCards = filterType == null || filterType == 'All'
          ? cards
          : cards.where((c) => _val(c, 'organization_type').toUpperCase() == filterType.toUpperCase()).toList();

      final buffer = StringBuffer();
      
      // Header
      buffer.writeln('Name,Title,Company,Address,Phone,Email,Website,Tag,Notes,DateAdded');

      for (var c in filteredCards) {
        final row = [
          _escapeCsv(_val(c, 'point_person')),
          _escapeCsv(_val(c, 'department')),
          _escapeCsv(_val(c, 'organization_name')),
          _escapeCsv(_val(c, 'location').isNotEmpty ? _val(c, 'location') : _val(c, 'address')),
          _escapeCsv(_val(c, 'contact_number')),
          _escapeCsv(_val(c, 'contact_email')),
          _escapeCsv(_val(c, 'url')),
          _escapeCsv(_val(c, 'organization_type')),
          _escapeCsv(_val(c, 'notes').isNotEmpty ? _val(c, 'notes') : _val(c, 'remark')),
          _escapeCsv(c['timestamp']?.toString() ?? c['created_at']?.toString() ?? ''),
        ];
        buffer.writeln(row.join(','));
      }

      final dir = await _getExportDirectory();
      final fileName = 'kardo_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsString(buffer.toString());
      return path;
    } catch (e) {
      debugPrint('Error generating CSV: $e');
      rethrow;
    }
  }

  String _escapeCsv(String text) {
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      final safe = text.replaceAll('"', '""');
      return '"$safe"';
    }
    return text;
  }

  /// Trigger the native share sheet for the generated file
  void shareFile(String filePath, {String? text}) {
    Share.shareXFiles(
      [XFile(filePath)],
      text: text ?? 'Exported by kardo',
    );
  }
}

