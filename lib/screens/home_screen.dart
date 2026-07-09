import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/data_provider.dart';
import '../services/image_processor_service.dart';
import 'contact_detail_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';
import 'sheet_data_screen.dart';
import 'insights_screen.dart';
import 'batch_test_screen.dart';
import 'export_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabPulseController;

  final List<Widget> _screens = [
    const _HomeView(),
    const SheetDataScreen(),
    const InsightsScreen(),
    const ExportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fabPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? _buildScanFab(theme)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildScanFab(ThemeData theme) {
    return AnimatedBuilder(
      animation: _fabPulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3 + 0.2 * _fabPulseController.value),
                blurRadius: 20 + 10 * _fabPulseController.value,
                spreadRadius: 2 + 4 * _fabPulseController.value,
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScannerScreen()),
            ),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const CircleBorder(),
            child: const Icon(Icons.document_scanner_rounded, size: 28),
          ),
        );
      },
    ).animate().scale(delay: 600.ms, duration: 500.ms, curve: Curves.elasticOut);
  }

  Widget _buildBottomBar(ThemeData theme) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
          _navItem(Icons.contacts_outlined, Icons.contacts_rounded, 'Cards', 1),
          const SizedBox(width: 48), // FAB space
          _navItem(Icons.insights_outlined, Icons.insights_rounded, 'Insights', 2),
          _navItem(Icons.file_download_outlined, Icons.file_download_rounded, 'Export', 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Home View ──────────────────────────────────────────────────────────────
class _HomeView extends ConsumerWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cardsState = ref.watch(localCardsProvider);

    final cards = cardsState.maybeWhen(data: (d) => d, orElse: () => <Map<String, dynamic>>[]);
    final totalCards = cards.length;
    final recentCards = cards.take(3).toList();

    // Count by type
    final Map<String, int> typeCounts = {};
    for (final c in cards) {
      final t = c['organization_type']?.toString() ?? 'BUSINESS';
      typeCounts[t] = (typeCounts[t] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Premium gradient app bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            actions: [
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BatchTestScreen()),
                ),
                icon: const Icon(Icons.bug_report, color: Colors.white),
                tooltip: 'Run Batch Test',
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'kardo',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                        const SizedBox(height: 4),
                        Text(
                          'Offline Business Card Scanner',
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                        ).animate().fadeIn(delay: 200.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats Row ───────────────────────────────────────────
                  Row(
                    children: [
                      _buildStatCard(
                        theme,
                        icon: Icons.credit_card_rounded,
                        label: 'Total Cards',
                        value: '$totalCards',
                        color: theme.colorScheme.primary,
                        delay: 0.ms,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        theme,
                        icon: Icons.category_rounded,
                        label: 'Categories',
                        value: '${typeCounts.length}',
                        color: const Color(0xFF00897B),
                        delay: 100.ms,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        theme,
                        icon: Icons.today_rounded,
                        label: 'This Month',
                        value: '${_countThisMonth(cards)}',
                        color: const Color(0xFF5E35B1),
                        delay: 200.ms,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Scan Action Card ─────────────────────────────────────
                  _buildScanCard(context, theme).animate().scale(delay: 300.ms, duration: 500.ms),

                  const SizedBox(height: 28),

                  // ── Recent Cards ─────────────────────────────────────────
                  if (recentCards.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Contacts',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to contacts tab (handled by parent)
                          },
                          child: Text('See all', style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...recentCards.asMap().entries.map((e) {
                      final index = e.key;
                      final card = e.value;
                      return _buildRecentCard(context, theme, card, index);
                    }).toList(),
                  ],

                  const SizedBox(height: 28),

                  // ── Tips ─────────────────────────────────────────────────
                  _buildTipsCard(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Duration delay,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
          ],
        ),
      ).animate().fadeIn(delay: delay, duration: 400.ms).scale(delay: delay, duration: 400.ms),
    );
  }

  Widget _buildScanCard(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScannerScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 140,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan a Card',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use live camera or gallery — 100% offline AI extraction',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Scan Now',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCard(BuildContext context, ThemeData theme, Map<String, dynamic> card, int index) {
    final color = ImageProcessorService.hexToColor(card['dominant_color']?.toString() ?? '0xFF1565C0');
    final name = _field(card, 'point_person');
    final role = _field(card, 'department');
    final org = _field(card, 'organization_name');
    final imagePath = card['image_path']?.toString() ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ContactDetailScreen(card: card)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: imagePath.isNotEmpty && File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
                    : Container(
                        color: color.withOpacity(0.15),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Unknown' : name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  if (role.isNotEmpty)
                    Text(role, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                  if (org.isNotEmpty)
                    Text(org, style: TextStyle(fontSize: 12, color: color), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 400 + 80 * index), duration: 300.ms).slideX(begin: 0.05),
    );
  }

  Widget _buildTipsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text('Pro Tips', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber.shade700)),
          ]),
          const SizedBox(height: 10),
          _tip('📷', 'Use good lighting & hold steady for auto-snap in live camera'),
          _tip('🎨', 'Each contact gets themed colors extracted from their card'),
          _tip('🔄', 'Drag contacts between Kanban columns to track your leads'),
          _tip('📡', 'Tap "NFC" on any contact to write it to a reusable NFC tag'),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _tip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  String _field(Map<String, dynamic> card, String key) {
    final v = card[key]?.toString() ?? '';
    return v.toLowerCase() == 'not found' ? '' : v;
  }

  int _countThisMonth(List<Map<String, dynamic>> cards) {
    final now = DateTime.now();
    int count = 0;
    for (final card in cards) {
      try {
        final ts = card['timestamp']?.toString() ?? '';
        if (ts.isNotEmpty) {
          final dt = DateTime.parse(ts);
          if (dt.year == now.year && dt.month == now.month) count++;
        }
      } catch (_) {}
    }
    return count;
  }
}
