import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import '../providers/data_provider.dart';
import '../services/nfc_service.dart';
import '../theme/atelier_theme.dart';
import '../theme/tokens.dart';
import '../widgets/zoomable_image_viewer.dart';
import 'qr_share_screen.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> card;

  const ContactDetailScreen({super.key, required this.card});

  @override
  ConsumerState<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  late Map<String, dynamic> card;

  @override
  void initState() {
    super.initState();
    card = widget.card;
  }

  String _getField(String key) {
    final v = card[key]?.toString() ?? '';
    return v.toLowerCase() == 'not found' ? '' : v;
  }

  String _getFormattedCapturedDateTime() {
    final raw = card['timestamp']?.toString() ?? card['created_at']?.toString() ?? '';
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM dd, yyyy • h:mm a').format(dt.toLocal());
    } catch (_) {
      return raw;
    }
  }

  Future<void> _launchPhone() async {
    final phone = _getField('contact_number');
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _launchEmail() async {
    final email = _getField('contact_email');
    if (email.isEmpty) return;
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _launchUrl() async {
    var url = _getField('url');
    if (url.isEmpty) return;
    if (!url.startsWith('http')) url = 'https://$url';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deleteCard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text("Delete '${_getField('point_person')}' permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      final slNo = int.tryParse(card['sl_no']?.toString() ?? '') ?? 0;
      if (slNo > 0) {
        await ref.read(localCardsProvider.notifier).deleteCard(slNo);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _nfcShare() async {
    final isAvailable = await NfcService.isNfcAvailable();
    if (!mounted) return;
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC is not available on this device')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NfcBottomSheet(card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    final name = _getField('point_person');
    final role = _getField('department');
    final org = _getField('organization_name');
    final phone = _getField('contact_number');
    final email = _getField('contact_email');
    final url = _getField('url');
    final location = _getField('location').isNotEmpty ? _getField('location') : _getField('address');
    final imagePath = card['image_path']?.toString() ?? '';

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: t.scaffoldBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: t.scaffoldBackground,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new, color: t.textPrimary),
            ),
            actions: [
              IconButton(
                onPressed: _addToContacts,
                icon: Icon(Icons.person_add_alt_1_rounded, color: t.textPrimary),
                tooltip: 'Add to Contacts',
              ),
              IconButton(
                onPressed: _deleteCard,
                icon: Icon(Icons.delete_outline_rounded, color: t.textPrimary),
                tooltip: 'Delete',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: t.cardBackground,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(top: 60, bottom: 20),
                child: Transform.rotate(
                  angle: 0.0349, // 2 degrees
                  child: Container(
                    width: 200, // Fixed width to look like a physical card
                    decoration: BoxDecoration(
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                      border: Border.all(color: t.borderDefault, width: 1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        if (imagePath.isNotEmpty && File(imagePath).existsSync()) {
                          showZoomableImageViewer(context, imagePath: imagePath, title: name);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Hero(
                          tag: 'card_${widget.card['sl_no']}',
                          child: imagePath.isNotEmpty && File(imagePath).existsSync()
                              ? Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.file(File(imagePath), fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.zoom_in_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  color: theme.colorScheme.surfaceVariant,
                                  child: Center(
                                    child: Icon(Icons.credit_card, size: 80, color: t.accent),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Unknown' : name, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: t.textPrimary)),
                  if (role.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(role, style: theme.textTheme.headlineMedium?.copyWith(color: t.textSecondary)),
                  ],
                  if (org.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(org, style: theme.textTheme.titleMedium?.copyWith(color: t.accent, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 32),

                  // Actions Row (Square buttons)
                  Row(
                    children: [
                      _buildSquareAction(Icons.phone_outlined, _launchPhone, theme),
                      const SizedBox(width: 16),
                      _buildSquareAction(Icons.email_outlined, _launchEmail, theme),
                      const SizedBox(width: 16),
                      _buildSquareAction(Icons.person_add_alt_1_rounded, _addToContacts, theme),
                      const SizedBox(width: 16),
                      _buildSquareAction(Icons.nfc_rounded, _nfcShare, theme),
                      const SizedBox(width: 16),
                      _buildSquareAction(Icons.qr_code_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrShareScreen(card: card))), theme),
                    ],
                  ),
                  
                  const SizedBox(height: 48),

                  if (phone.isNotEmpty || email.isNotEmpty || url.isNotEmpty || location.isNotEmpty || _getFormattedCapturedDateTime().isNotEmpty) ...[
                    Text('DETAILS', style: theme.textTheme.labelMedium?.copyWith(color: t.textSecondary)),
                    const SizedBox(height: 16),
                    _buildDataField('PHONE NUMBER', phone, _launchPhone, theme),
                    _buildDataField('EMAIL ADDRESS', email, _launchEmail, theme),
                    _buildDataField('WEBSITE', url, _launchUrl, theme),
                    _buildDataField('LOCATION', location, null, theme),
                    _buildDataField('CAPTURED ON', _getFormattedCapturedDateTime(), null, theme),
                    const SizedBox(height: 32),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareAction(IconData icon, VoidCallback onTap, ThemeData theme) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: t.cardBackground,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: t.borderDefault, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: t.textPrimary, size: 20),
      ),
    );
  }

  Widget _buildDataField(String label, String value, VoidCallback? onTap, ThemeData theme) {
    if (value.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.borderDefault, width: 1))),
        padding: const EdgeInsets.only(bottom: 8, top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.labelLarge, overflow: TextOverflow.visible),
          ],
        ),
      ),
    );
  }

  // Removed unused widgets
  Future<void> _addToContacts() async {
    final card = widget.card;
    final personName = card['point_person']?.toString() ?? '';
    final orgName = card['organization_name']?.toString() ?? '';
    final department = card['department']?.toString() ?? '';
    final phone = card['contact_number']?.toString() ?? '';
    final email = card['contact_email']?.toString() ?? '';
    final url = card['url']?.toString() ?? '';
    
    // Format name as Name - Company
    final String displayName = orgName.isNotEmpty && orgName != 'Not Found' 
        ? '${personName.isNotEmpty && personName != 'Not Found' ? personName : 'Unknown'} - $orgName'
        : (personName.isNotEmpty && personName != 'Not Found' ? personName : 'Unknown Contact');

    if (await FlutterContacts.requestPermission()) {
      final newContact = Contact()
        ..name.first = displayName
        ..organizations = [Organization(company: orgName, title: department)]
        ..phones = [Phone(phone)]
        ..emails = [Email(email)]
        ..websites = [Website(url)];

      try {
        await newContact.insert();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved directly to your contacts!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save contact: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to access contacts'), backgroundColor: Colors.orange),
        );
      }
    }
  }
}

// Removed _DetailItem

/// NFC write bottom sheet
class _NfcBottomSheet extends StatefulWidget {
  final Map<String, dynamic> card;
  const _NfcBottomSheet({required this.card});

  @override
  State<_NfcBottomSheet> createState() => _NfcBottomSheetState();
}

class _NfcBottomSheetState extends State<_NfcBottomSheet> {
  String _status = 'Ready to write...';
  bool _done = false;
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _startWrite();
  }

  Future<void> _startWrite() async {
    setState(() { _writing = true; _status = 'Hold your phone to an NFC tag...'; });
    final error = await NfcService.writeVCardToTag(
      widget.card,
      onStatusUpdate: (msg) {
        if (mounted) setState(() => _status = msg);
      },
    );
    if (mounted) {
      setState(() {
        _writing = false;
        _done = error == null;
        _status = error ?? '✅ Contact written to NFC tag!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: t.cardBackground,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _done ? Icons.check_circle_rounded : Icons.nfc_rounded,
            size: 64,
            color: _done ? Colors.green : t.accent,
          ).animate(onPlay: (c) => _writing ? c.repeat() : null)
            .shimmer(duration: 1500.ms, color: Colors.teal),
          const SizedBox(height: 20),
          Text(
            _writing ? 'Waiting for NFC tag...' : (_done ? 'Success!' : 'Failed'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_status, textAlign: TextAlign.center, style: TextStyle(color: t.textTertiary)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await NfcService.stopSession();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    NfcService.stopSession();
    super.dispose();
  }
}
