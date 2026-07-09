import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/nfc_service.dart';
import '../services/image_processor_service.dart';

class QrShareScreen extends StatefulWidget {
  final Map<String, dynamic> card;

  const QrShareScreen({super.key, required this.card});

  @override
  State<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends State<QrShareScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false;
  String? _savedPath;

  late String _vcardData;
  late Color primaryColor;
  late Color secondaryColor;

  @override
  void initState() {
    super.initState();
    _vcardData = NfcService.buildVCard(widget.card);
    final hexPrimary = widget.card['dominant_color']?.toString() ?? '0xFF1565C0';
    final hexSecondary = widget.card['dominant_color_secondary']?.toString() ?? '0xFF0D47A1';
    primaryColor = ImageProcessorService.hexToColor(hexPrimary);
    secondaryColor = ImageProcessorService.hexToColor(hexSecondary);
  }

  String _getField(String key) {
    final v = widget.card[key]?.toString() ?? '';
    return v.toLowerCase() == 'not found' ? '' : v;
  }

  Future<void> _saveQrToFile() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not render QR code');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/snapcard_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      setState(() => _savedPath = path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareQr() async {
    if (_savedPath == null) await _saveQrToFile();
    if (_savedPath == null) return;

    try {
      await Share.shareXFiles(
        [XFile(_savedPath!)],
        text: 'Contact card for ${_getField("point_person")} — scan this QR code to save the contact!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareVcardText() async {
    try {
      await Share.share(_vcardData, subject: 'Contact: ${_getField("point_person")}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _getField('point_person');
    final org = _getField('organization_name');
    final role = _getField('department');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: primaryColor,
            title: const Text('QR Share', style: TextStyle(color: Colors.white)),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Gradient header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, secondaryColor],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (role.isNotEmpty)
                        Text(role, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      if (org.isNotEmpty)
                        Text(org, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                // QR Code
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        'Scan to save contact',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Contains vCard 3.0 — works with any camera app',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // QR with themed border
                      RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.2),
                                blurRadius: 24,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              QrImageView(
                                data: _vcardData,
                                version: QrVersions.auto,
                                size: 220,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: primaryColor,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: secondaryColor,
                                ),
                                errorCorrectionLevel: QrErrorCorrectLevel.H,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'kardo',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 32),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: _isSaving
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                              label: 'Save QR',
                              color: primaryColor,
                              onTap: _isSaving ? null : _saveQrToFile,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                              label: 'Share QR',
                              color: secondaryColor,
                              onTap: _shareQr,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, duration: 400.ms),
                      const SizedBox(height: 12),

                      // Share vCard text
                      OutlinedButton.icon(
                        onPressed: _shareVcardText,
                        icon: Icon(Icons.contact_page_rounded, color: primaryColor),
                        label: Text('Share as vCard text', style: TextStyle(color: primaryColor)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ).animate().fadeIn(delay: 500.ms),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey : color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onTap == null
              ? []
              : [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
