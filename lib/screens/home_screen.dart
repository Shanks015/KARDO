import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_provider.dart';
import '../services/image_processor_service.dart';
import '../theme/tokens.dart';
import '../widgets/ios_components.dart';
import 'contact_detail_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';
import 'sheet_data_screen.dart';
import 'export_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabPulseController;

  final List<Widget> _screens = [
    const _HomeView(),
    const SheetDataScreen(),
    const ExportScreen(),
    const SettingsScreen(),
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
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;

    return Scaffold(
      backgroundColor: t.scaffoldBackground,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      floatingActionButton: IOSFloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        icon: Icons.add,
        tooltip: 'Scan Card',
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: IOSBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Library',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Export',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Home View ──────────────────────────────────────────────────────────────
class _HomeView extends ConsumerStatefulWidget {
  const _HomeView();

  @override
  ConsumerState<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<_HomeView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardsState = ref.watch(localCardsProvider);

    return cardsState.when(
      data: (cards) {
        final filteredCards = cards.where((card) {
          final person = (card['point_person']?.toString() ?? '').toLowerCase();
          final org = (card['organization_name']?.toString() ?? '').toLowerCase();
          final department = (card['department']?.toString() ?? '').toLowerCase();
          final email = (card['contact_email']?.toString() ?? '').toLowerCase();
          final phone = (card['contact_number']?.toString() ?? '').toLowerCase();
          final type = (card['organization_type']?.toString() ?? '').toLowerCase();
          
          return _searchQuery.isEmpty ||
              person.contains(_searchQuery) ||
              org.contains(_searchQuery) ||
              department.contains(_searchQuery) ||
              email.contains(_searchQuery) ||
              phone.contains(_searchQuery) ||
              type.contains(_searchQuery);
        }).toList();

        final recentCards = filteredCards.take(3).toList();

        // Count by type
        final Map<String, int> typeCounts = {};
        for (final card in cards) {
          final type =
              card['organization_type']?.toString() ?? 'BUSINESS';
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }

        return CustomScrollView(
          slivers: [
            // Header with translucent blurred background
            SliverToBoxAdapter(
              child: _buildHeader(context, t),
            ),
            SliverToBoxAdapter(
              child: const SizedBox(height: 24),
            ),
            // Search bar
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: IOSSearchBar(
                  hintText: 'Search by type, CEO or category...',
                  onChanged: (value) {
                    setState(() => _searchQuery = value.trim().toLowerCase());
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: const SizedBox(height: 32),
            ),
            // Action buttons
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: IOSBorderedButton(
                        text: 'Scan Card',
                        icon: Icons.camera_alt,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScannerScreen()),
                        ),
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: IOSBorderedButton(
                        text: 'Export Data',
                        icon: Icons.import_export,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ExportScreen()),
                        ),
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: const SizedBox(height: 32),
            ),
            // Recent scans section
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Recent Scans',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: t.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SheetDataScreen()),
                      ),
                      child: Text(
                        'View All Scans',
                        style: TextStyle(
                          color: t.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: const SizedBox(height: 12),
            ),
            // Recent cards
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: recentCards.isNotEmpty
                  ? SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final card = recentCards[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildRecentCard(
                              context,
                              card,
                              index,
                              isDark,
                              t,
                            ),
                          );
                        },
                        childCount: recentCards.length,
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No scans yet',
                            style: TextStyle(
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: const SizedBox(height: 100), // FAB padding
            ),
          ],
        );
      },
      loading: () => const CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, stack) => CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Error: $error')),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, KardoTokens t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accent.withOpacity(0.12),
            ),
            child: Center(
              child: Icon(
                Icons.contact_page_rounded,
                color: t.accent,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Kardo Scan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCard(
      BuildContext context,
      Map<String, dynamic> card,
      int index,
      bool isDark,
      KardoTokens t) {
    final dominantColor =
        ImageProcessorService.hexToColor(card['dominant_color']?.toString() ??
            '0xFF1565C0');
    final name = _field(card, 'point_person');
    final role = _field(card, 'department');
    final org = _field(card, 'organization_name');
    final imagePath = card['image_path']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContactDetailScreen(card: card)),
        );
      },
      child: GlassmorphismContainer.fromTheme(
        context,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail / Placeholder with squircle clipping
              ClipRRect(
                borderRadius: BorderRadius.circular(16), // Approximate squircle
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: imagePath.isNotEmpty && File(imagePath).existsSync()
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: dominantColor.withOpacity(0.2),
                          child: Center(
                            child: Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: dominantColor,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Unknown' : name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: t.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: t.textTertiary,
                          size: 20,
                        ),
                      ],
                    ),
                    if (role.isNotEmpty || org.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          '${role.isNotEmpty ? role : ''}${role.isNotEmpty && org.isNotEmpty ? ' at ' : ''}${org.isNotEmpty ? org : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Row(
                      children: [
                         Icon(Icons.location_on,
                            size: 12, color: t.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            card['location']?.toString().isNotEmpty == true
                                ? card['location']!
                                : 'Paris, 24 Street Avenue', // Mockup dummy text fallback
                            style: TextStyle(
                              fontSize: 11,
                              color: t.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                         Icon(Icons.phone,
                            size: 12, color: t.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            card['contact_number']?.toString().isNotEmpty == true
                                ? card['contact_number']!
                                : '+971 453 644 14',
                            style: TextStyle(
                              fontSize: 11,
                              color: t.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                         Icon(Icons.email,
                            size: 12, color: t.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            card['contact_email']?.toString().isNotEmpty == true
                                ? card['contact_email']!
                                : 'not.provided@example.com',
                            style: TextStyle(
                              fontSize: 11,
                              color: t.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _field(Map<String, dynamic> card, String key) {
    final v = card[key]?.toString() ?? '';
    return v.toLowerCase() == 'not found' ? '' : v;
  }
}
