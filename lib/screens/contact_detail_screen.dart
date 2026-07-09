import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../providers/data_provider.dart';
import '../services/image_processor_service.dart';
import '../services/nfc_service.dart';
import 'qr_share_screen.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> card;

  const ContactDetailScreen({super.key, required this.card});

  @override
  ConsumerState<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showingFront = true;

  late Map<String, dynamic> card;
  late Color primaryColor;
  late Color secondaryColor;

  @override
  void initState() {
    super.initState();
    card = widget.card;
    _initColors();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    _flipAnimation.addListener(() {
      setState(() {
        _showingFront = _flipAnimation.value < math.pi / 2;
      });
    });
  }

  void _initColors() {
    final hexPrimary = card['dominant_color']?.toString() ?? '0xFF1565C0';
    final hexSecondary = card['dominant_color_secondary']?.toString() ?? '0xFF0D47A1';
    primaryColor = ImageProcessorService.hexToColor(hexPrimary);
    secondaryColor = ImageProcessorService.hexToColor(hexSecondary);
  }

  void _flipCard() {
    HapticFeedback.lightImpact();
    if (_flipController.isAnimating) return;
    if (_flipController.value == 0) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  String _getField(String key) {
    final v = card[key]?.toString() ?? '';
    return v.toLowerCase() == 'not found' ? '' : v;
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
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _getField('point_person');
    final role = _getField('department');
    final org = _getField('organization_name');
    final phone = _getField('contact_number');
    final email = _getField('contact_email');
    final url = _getField('url');
    final location = _getField('location').isNotEmpty ? _getField('location') : _getField('address');
    final imagePath = card['image_path']?.toString() ?? '';
    final kanban = card['kanban_status']?.toString() ?? 'New Lead';
    final tag = card['organization_type']?.toString() ?? 'BUSINESS';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Premium hero header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: primaryColor,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
            actions: [
              IconButton(
                onPressed: _deleteCard,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                tooltip: 'Delete',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, secondaryColor],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      // Avatar / initials
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white38, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty
                                ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ).animate().scale(duration: 400.ms),
                      const SizedBox(height: 12),
                      Text(
                        name.isEmpty ? 'Unknown' : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      if (role.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          role,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                        ).animate().fadeIn(delay: 300.ms),
                      ],
                      if (org.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          org,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTag(tag, Colors.white.withOpacity(0.2)),
                          const SizedBox(width: 8),
                          _buildTag(kanban, primaryColor.withOpacity(0.5)),
                        ],
                      ).animate().fadeIn(delay: 500.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 3D Card Flip ────────────────────────────────────────
                  _build3DCardFlip(imagePath, name, org, phone, email, url, theme),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _flipCard,
                      icon: Icon(Icons.flip_rounded, color: primaryColor, size: 18),
                      label: Text(
                        _showingFront ? 'Tap to see details →' : 'Tap to see card →',
                        style: TextStyle(color: primaryColor, fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Quick Actions ────────────────────────────────────────
                  Text('Quick Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildQuickActions(phone, email, url, theme),

                  const SizedBox(height: 24),

                  // ── Contact Details ────────────────────────────────────────
                  Text('Contact Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildDetailCard(theme, [
                    if (phone.isNotEmpty) _DetailItem(Icons.phone_rounded, 'Phone', phone, primaryColor, onTap: _launchPhone),
                    if (email.isNotEmpty) _DetailItem(Icons.email_rounded, 'Email', email, primaryColor, onTap: _launchEmail),
                    if (url.isNotEmpty) _DetailItem(Icons.language_rounded, 'Website', url, primaryColor, onTap: _launchUrl),
                    if (location.isNotEmpty) _DetailItem(Icons.location_on_rounded, 'Location', location, primaryColor),
                  ]),

                  const SizedBox(height: 24),

                  // ── Share Options ────────────────────────────────────────
                  Text('Share', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildShareButton(
                          theme,
                          icon: Icons.qr_code_rounded,
                          label: 'QR Code',
                          color: const Color(0xFF5E35B1),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => QrShareScreen(card: card)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildShareButton(
                          theme,
                          icon: Icons.nfc_rounded,
                          label: 'NFC Tap',
                          color: const Color(0xFF00897B),
                          onTap: _nfcShare,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DCardFlip(String imagePath, String name, String org, String phone, String email, String url, ThemeData theme) {
    return GestureDetector(
      onTap: _flipCard,
      child: SizedBox(
        height: 200,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = _flipAnimation.value;
            final isShowingFront = angle < math.pi / 2;
            final displayAngle = isShowingFront ? angle : angle - math.pi;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(displayAngle),
              child: isShowingFront
                  ? _buildCardFront(imagePath, theme)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _buildCardBack(name, org, phone, email, url, theme),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardFront(String imagePath, ThemeData theme) {
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(imagePath), fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.credit_card, color: Colors.white60, size: 48),
                    const SizedBox(height: 8),
                    Text('Card Photo', style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCardBack(String name, String org, String phone, String email, String url, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceVariant,
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
          if (org.isNotEmpty) Text(org, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          if (phone.isNotEmpty) _backDetail(Icons.phone_rounded, phone, theme),
          if (email.isNotEmpty) _backDetail(Icons.email_rounded, email, theme),
          if (url.isNotEmpty) _backDetail(Icons.language_rounded, url, theme),
        ],
      ),
    );
  }

  Widget _backDetail(IconData icon, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildQuickActions(String phone, String email, String url, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _actionChip(Icons.person_add_rounded, 'Save to Contacts', _addToContacts, theme.colorScheme.primary),
          if (phone.isNotEmpty)
            _actionChip(Icons.call_rounded, 'Call', _launchPhone, const Color(0xFF2E7D32)),
          if (email.isNotEmpty)
            _actionChip(Icons.email_rounded, 'Email', _launchEmail, const Color(0xFF1565C0)),
          if (url.isNotEmpty)
            _actionChip(Icons.open_in_browser_rounded, 'Website', _launchUrl, const Color(0xFF6A1B9A)),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(ThemeData theme, List<_DetailItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final index = e.key;
          final item = e.value;
          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 18),
                ),
                title: Text(item.label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                subtitle: Text(item.value, style: const TextStyle(fontWeight: FontWeight.w500)),
                onTap: item.onTap,
                dense: true,
              ),
              if (index < items.length - 1) const Divider(height: 1, indent: 56),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildShareButton(ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
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

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _DetailItem(this.icon, this.label, this.value, this.color, {this.onTap});
}

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
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _done ? Icons.check_circle_rounded : Icons.nfc_rounded,
            size: 64,
            color: _done ? Colors.green : const Color(0xFF00897B),
          ).animate(onPlay: (c) => _writing ? c.repeat() : null)
            .shimmer(duration: 1500.ms, color: Colors.teal),
          const SizedBox(height: 20),
          Text(
            _writing ? 'Waiting for NFC tag...' : (_done ? 'Success!' : 'Failed'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
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
