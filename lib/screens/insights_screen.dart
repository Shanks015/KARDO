import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/local_db_service.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Insights Dashboard"),
        elevation: 0,
      ),
      body: _buildInsightsView(context),
    );
  }

  Widget _buildInsightsView(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
              ],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsSection(context),
                const SizedBox(height: 32),
                _buildOrganizationTypeBreakdown(context),
                const SizedBox(height: 32),
                _buildTopOrganizations(context),
                const SizedBox(height: 32),
                _buildDepartmentBreakdown(context),
                const SizedBox(height: 32),
                _buildContactCompletenessCard(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Get local cards to compute insights
        final localCardsState =
            ref.watch(localCardsProviderForInsights);

        return localCardsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (cards) {
            final insights = _computeInsights(cards);
            return Column(
              children: [
                Text(
                  'Overview',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        '${insights['totalCards']}',
                        'Total Cards',
                        Icons.business_center,
                        Colors.blueAccent,
                      ).animate().scale(delay: 0.ms, duration: 400.ms),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        '${insights['organizationCount']}',
                        'Organizations',
                        Icons.domain,
                        Colors.greenAccent,
                      ).animate().scale(delay: 100.ms, duration: 400.ms),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        '${insights['departmentCount']}',
                        'Departments',
                        Icons.people,
                        Colors.purpleAccent,
                      ).animate().scale(delay: 200.ms, duration: 400.ms),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationTypeBreakdown(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final localCardsState =
            ref.watch(localCardsProviderForInsights);

        return localCardsState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (cards) {
            final insights = _computeInsights(cards);
            final orgTypeMap =
                insights['cardsByOrgType'] as Map<String, int>;

            if (orgTypeMap.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cards by Organization Type',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...orgTypeMap.entries.map((entry) {
                  final percentage =
                      (entry.value / insights['totalCards'] * 100)
                          .toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${entry.value} ($percentage%)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: entry.value /
                                insights['totalCards'],
                            minHeight: 8,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceVariant,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(
                              _getColorForOrgType(entry.key),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: -0.2);
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTopOrganizations(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final localCardsState =
            ref.watch(localCardsProviderForInsights);

        return localCardsState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (cards) {
            final insights = _computeInsights(cards);
            final topOrgs =
                (insights['topOrganizations'] as List<Map<String, dynamic>>)
                    .take(5)
                    .toList();

            if (topOrgs.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Organizations',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...topOrgs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final org = entry.value;
                  final maxCount = topOrgs.first['count'] as int;
                  final percentage =
                      (org['count'] as int) / maxCount * 100;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _getColorForIndex(index),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                org['name'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(4),
                                child:
                                    LinearProgressIndicator(
                                  value: percentage / 100,
                                  minHeight: 6,
                                  backgroundColor:
                                      Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant,
                                  valueColor:
                                      AlwaysStoppedAnimation<
                                          Color>(
                                    _getColorForIndex(index),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${org['count']}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: -0.2);
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDepartmentBreakdown(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final localCardsState =
            ref.watch(localCardsProviderForInsights);

        return localCardsState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (cards) {
            final insights = _computeInsights(cards);
            final deptMap =
                insights['cardsByDepartment'] as Map<String, int>;

            if (deptMap.isEmpty) {
              return const SizedBox.shrink();
            }

            // Take top 6 departments
            final topDepts = deptMap.entries
                .toList()
                ..sort((a, b) => b.value.compareTo(a.value));
            final displayDepts = topDepts.take(6).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Departments',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: displayDepts.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.value}',
                              style:
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .scale(delay: 100.ms, duration: 400.ms);
                  }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildContactCompletenessCard(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final localCardsState =
            ref.watch(localCardsProviderForInsights);

        return localCardsState.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (cards) {
            final insights = _computeInsights(cards);
            final completeness =
                insights['contactCompleteness'] as Map<String, dynamic>;

            final totalCards = completeness['total'] as int;
            final withEmail = completeness['hasEmail'] as int;
            final withPhone = completeness['hasPhone'] as int;
            final withBoth = completeness['hasBoth'] as int;

            if (totalCards == 0) {
              return const SizedBox.shrink();
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Completeness',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCircularStat(
                        context,
                        withBoth,
                        totalCards,
                        'Email & Phone',
                        Colors.greenAccent,
                      ),
                      _buildCircularStat(
                        context,
                        withEmail,
                        totalCards,
                        'Email Only',
                        Colors.blueAccent,
                      ),
                      _buildCircularStat(
                        context,
                        withPhone,
                        totalCards,
                        'Phone Only',
                        Colors.purpleAccent,
                      ),
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2);
          },
        );
      },
    );
  }

  Widget _buildCircularStat(BuildContext context, int value, int total,
      String label, Color color) {
    final percentage = (value / total * 100).toStringAsFixed(1);
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: value / total,
                  strokeWidth: 8,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surface
                      .withOpacity(0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    percentage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        Text(
          '($value)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Map<String, dynamic> _computeInsights(
      List<Map<String, dynamic>> cards) {
    final total = cards.length;
    final cardsByOrgType = <String, int>{};
    final cardsByOrgName = <String, int>{};
    final cardsByDepartment = <String, int>{};
    int hasEmail = 0;
    int hasPhone = 0;
    int hasBoth = 0;

    for (var card in cards) {
      // Organization type
      final orgType =
          (card['organization_type'] ?? '').toString().toUpperCase();
      if (orgType.isNotEmpty) {
        cardsByOrgType[orgType] = (cardsByOrgType[orgType] ?? 0) + 1;
      }

      // Organization name
      final orgName = (card['organization_name'] ?? '').toString();
      if (orgName.isNotEmpty) {
        cardsByOrgName[orgName] = (cardsByOrgName[orgName] ?? 0) + 1;
      }

      // Department
      final dept = (card['department'] ?? '').toString();
      if (dept.isNotEmpty) {
        cardsByDepartment[dept] = (cardsByDepartment[dept] ?? 0) + 1;
      }

      // Contact completeness
      final email = (card['contact_email'] ?? '').toString().trim();
      final phone = (card['contact_number'] ?? '').toString().trim();
      final hasEmailVal = email.isNotEmpty;
      final hasPhoneVal = phone.isNotEmpty;

      if (hasEmailVal) hasEmail++;
      if (hasPhoneVal) hasPhone++;
      if (hasEmailVal && hasPhoneVal) hasBoth++;
    }

    // Top organizations
    final topOrgs = cardsByOrgName.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    final topOrgsList = topOrgs
        .take(5)
        .map((e) => {'name': e.key, 'count': e.value})
        .toList();

    return {
      'totalCards': total,
      'organizationCount': cardsByOrgName.length,
      'departmentCount': cardsByDepartment.length,
      'cardsByOrgType': cardsByOrgType,
      'topOrganizations': topOrgsList,
      'cardsByDepartment': cardsByDepartment,
      'contactCompleteness': {
        'hasEmail': hasEmail,
        'hasPhone': hasPhone,
        'hasBoth': hasBoth,
        'total': total,
      },
    };
  }

  Color _getColorForOrgType(String type) {
    final colors = {
      'UNIVERSITY': Colors.blueAccent,
      'BUSINESS': Colors.greenAccent,
      'CONSULTANCY': Colors.orangeAccent,
      'NGO': Colors.purpleAccent,
      'STARTUP': Colors.redAccent,
      'GOVERNMENT': Colors.indigoAccent,
    };
    return colors[type] ?? Colors.blueAccent;
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.redAccent,
    ];
    return colors[index % colors.length];
  }
}

// Create a provider for local cards used by insights
final localCardsProviderForInsights = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = LocalDatabaseService();
  return await db.getCards();
});
