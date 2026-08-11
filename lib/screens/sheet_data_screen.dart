import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/data_provider.dart';
import '../services/image_processor_service.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/ios_components.dart';
import '../widgets/zoomable_image_viewer.dart';
import 'contact_detail_screen.dart';

class SheetDataScreen extends ConsumerStatefulWidget {
  const SheetDataScreen({super.key});

  @override
  ConsumerState<SheetDataScreen> createState() => _SheetDataScreenState();
}

class _SheetDataScreenState extends ConsumerState<SheetDataScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  int _viewMode = 0; // 0=List, 1=Gallery, 2=Kanban

  final List<String> _kanbanColumns = [
    'New Lead', 'Contacted', 'Followed Up', 'Closed'
  ];
  final List<String> _filters = [
    'All', 'UNIVERSITY', 'BUSINESS', 'CONSULTANCY', 'NGO', 'STARTUP', 'GOVERNMENT'
  ];

  // For carousel/gallery view
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _carouselIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getField(Map<String, dynamic> card, String key) {
    final v = card[key]?.toString() ?? '';
    return v.toLowerCase() == 'not found' ? '' : v;
  }

  Color _cardColor(Map<String, dynamic> card) {
    final hex = card['dominant_color']?.toString() ?? '0xFF1565C0';
    return ImageProcessorService.hexToColor(hex);
  }

  List<Map<String, dynamic>> _filterCards(List<Map<String, dynamic>> cards) {
    return cards.where((card) {
      final person = _getField(card, 'point_person').toLowerCase();
      final org = _getField(card, 'organization_name').toLowerCase();
      final department = _getField(card, 'department').toLowerCase();
      final email = _getField(card, 'contact_email').toLowerCase();
      final phone = _getField(card, 'contact_number').toLowerCase();
      final type = (card['organization_type'] ?? '').toString().toUpperCase();

      final matchesSearch = _searchQuery.isEmpty ||
          person.contains(_searchQuery.toLowerCase()) ||
          org.contains(_searchQuery.toLowerCase()) ||
          department.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase()) ||
          phone.contains(_searchQuery.toLowerCase()) ||
          type.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedFilter == 'All' || type == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dataState = ref.watch(sheetDataProvider);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : LiquidGlassTheme.iceBlue,
      appBar: IOSNavBar(
        title: 'My Contacts',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(localCardsProvider.notifier).loadCards();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar (identical to home screen)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: IOSSearchBar(
                hintText: 'Search name, company, email...',
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 48,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                itemBuilder: (_, i) {
                  final filter = _filters[i];
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
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
                      selectedColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // View mode segmented control (Responsive List | Gallery | Kanban)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IOSegmentedControl(
                segments: const ['List', 'Gallery', 'Kanban'],
                icons: const [
                  Icons.view_list_rounded,
                  Icons.grid_view_rounded,
                  Icons.view_kanban_outlined,
                ],
                selectedIndex: _viewMode,
                onValueChanged: (index) =>
                    setState(() => _viewMode = index),
              ),
            ),
            const SizedBox(height: 12),

            // Content area
            Expanded(
              child: dataState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', textAlign: TextAlign.center)),
                data: (rawData) {
                  final cards = rawData
                      .whereType<Map<String, dynamic>>()
                      .cast<Map<String, dynamic>>()
                      .toList();
                  final filtered = _filterCards(cards);

                  if (filtered.isEmpty) {
                    return _buildEmpty(context);
                  }

                  if (_viewMode == 0) {
                    return _buildListView(filtered, isDark);
                  } else if (_viewMode == 1) {
                    return _buildCarouselView(filtered);
                  } else {
                    return _buildKanbanView(filtered, isDark);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── List View ─────────────────────────────────────────────────────────────
  Widget _buildListView(List<Map<String, dynamic>> cards, bool isDark) {
    return RefreshIndicator(
      onRefresh: () => ref.read(localCardsProvider.notifier).loadCards(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          final color = _cardColor(card);
          final name = _getField(card, 'point_person');
          final role = _getField(card, 'department');
          final org = _getField(card, 'organization_name');
          final phone = _getField(card, 'contact_number');
          final email = _getField(card, 'contact_email');
          final slNo = card['sl_no']?.toString() ?? '';
          final imagePath = card['image_path']?.toString() ?? '';

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ContactDetailScreen(card: card)),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: GlassmorphismContainer.fromTheme(
                context,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: color, width: 4)),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail (Tap to zoom in/out)
                      GestureDetector(
                        onTap: () {
                          if (imagePath.isNotEmpty && File(imagePath).existsSync()) {
                            showZoomableImageViewer(context, imagePath: imagePath, title: name);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 88,
                            child: imagePath.isNotEmpty && File(imagePath).existsSync()
                                ? Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.file(File(imagePath), fit: BoxFit.cover),
                                      ),
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.zoom_in_rounded,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    color: color.withOpacity(0.15),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name.isEmpty ? 'Unknown' : name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text('#$slNo', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              if (role.isNotEmpty)
                                Text(role, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              if (org.isNotEmpty)
                                Row(children: [
                                  Icon(Icons.business, size: 12, color: color),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(org, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                ]),
                              const SizedBox(height: 4),
                              if (phone.isNotEmpty)
                                Row(children: [
                                  const Icon(Icons.phone, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(phone, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                                ]),
                              if (email.isNotEmpty)
                                Row(children: [
                                  const Icon(Icons.email, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                                ]),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.chevron_right, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: 40 * index), duration: 300.ms).slideX(begin: 0.05),
            ),
          );
        },
      ),
    );
  }

  // ── Carousel / Gallery View ──────────────────────────────────────────────
  Widget _buildCarouselView(List<Map<String, dynamic>> cards) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            itemBuilder: (context, index) {
              final card = cards[index];
              final color = _cardColor(card);
              final secHex = card['dominant_color_secondary']?.toString() ?? '0xFF0D47A1';
              final secColor = ImageProcessorService.hexToColor(secHex);
              final imagePath = card['image_path']?.toString() ?? '';
              final name = _getField(card, 'point_person');
              final org = _getField(card, 'organization_name');
              final role = _getField(card, 'department');

              final scale = index == _carouselIndex ? 1.0 : 0.9;

              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ContactDetailScreen(card: card)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, secColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Card photo
                          if (imagePath.isNotEmpty && File(imagePath).existsSync())
                            Image.file(File(imagePath), fit: BoxFit.cover)
                          else
                            Container(
                              alignment: Alignment.center,
                              child: Icon(Icons.credit_card, color: Colors.white.withOpacity(0.3), size: 80),
                            ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                                stops: const [0.4, 1.0],
                              ),
                            ),
                          ),
                          // Top-right Zoom Button & Tap gesture
                          Positioned(
                            top: 16,
                            right: 16,
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                              ),
                              onPressed: () {
                                if (imagePath.isNotEmpty && File(imagePath).existsSync()) {
                                  showZoomableImageViewer(context, imagePath: imagePath, title: name);
                                }
                              },
                              tooltip: 'Zoom Image',
                            ),
                          ),
                          // Text overlay (Tap to open details)
                          Positioned(
                            bottom: 24,
                            left: 24,
                            right: 24,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name.isEmpty ? 'Unknown' : name,
                                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                      if (role.isNotEmpty)
                                        Text(role, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14)),
                                      if (org.isNotEmpty)
                                        Text(org, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ContactDetailScreen(card: card)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cards.length.clamp(0, 10), (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _carouselIndex ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _carouselIndex
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Kanban Board View ─────────────────────────────────────────────────────
  Widget _buildKanbanView(List<Map<String, dynamic>> allCards, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _kanbanColumns.map((column) {
          final columnCards = allCards
              .where((c) => (c['kanban_status'] ?? 'New Lead') == column)
              .toList();

          return _buildKanbanColumn(column, columnCards, isDark);
        }).toList(),
      ),
    );
  }

  Widget _buildKanbanColumn(String title, List<Map<String, dynamic>> cards, bool isDark) {
    final theme = Theme.of(context);
    final columnColors = {
      'New Lead': const Color(0xFF5E35B1),
      'Contacted': const Color(0xFF1565C0),
      'Followed Up': const Color(0xFF00897B),
      'Closed': const Color(0xFF2E7D32),
    };
    final color = columnColors[title] ?? theme.colorScheme.primary;

    return Container(
      width: 230,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${cards.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Cards as drag targets
          DragTarget<Map<String, dynamic>>(
            onAcceptWithDetails: (details) {
              final card = details.data;
              final slNo = int.tryParse(card['sl_no']?.toString() ?? '') ?? 0;
              if (slNo > 0) {
                ref.read(localCardsProvider.notifier).updateKanbanStatus(slNo, title);
              }
            },
            builder: (context, candidates, rejected) {
              return Container(
                constraints: BoxConstraints(minHeight: 80, maxHeight: MediaQuery.of(context).size.height * 0.65),
                decoration: BoxDecoration(
                  color: candidates.isNotEmpty
                      ? color.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: candidates.isNotEmpty ? color.withOpacity(0.3) : Colors.transparent,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ...cards.map((card) => _buildKanbanCard(card, color, isDark)),
                      if (cards.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          child: Text(
                            'Drop cards here',
                            style: TextStyle(color: color.withOpacity(0.4), fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(Map<String, dynamic> card, Color columnColor, bool isDark) {
    final color = _cardColor(card);
    final name = _getField(card, 'point_person');
    final org = _getField(card, 'organization_name');
    final phone = _getField(card, 'contact_number');

    return LongPressDraggable<Map<String, dynamic>>(
      data: card,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: Container(
            width: 210,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Text(name.isEmpty ? 'Card' : name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildKanbanCardContent(card, color, name, org, phone, isDark),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContactDetailScreen(card: card)),
        ),
        child: _buildKanbanCardContent(card, color, name, org, phone, isDark),
      ),
    );
  }

  Widget _buildKanbanCardContent(Map<String, dynamic> card, Color color, String name, String org, String phone, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.isEmpty ? 'Unknown' : name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
          if (org.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(org, style: TextStyle(fontSize: 11, color: color), overflow: TextOverflow.ellipsis),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.phone, size: 10, color: Colors.grey),
              const SizedBox(width: 3),
              Text(phone, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No matching contacts' : 'No contacts yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text('Scan a business card to get started', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}