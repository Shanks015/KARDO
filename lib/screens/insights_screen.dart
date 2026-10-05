import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/local_db_service.dart';
import '../theme/tokens.dart';
import '../widgets/ios_components.dart';
import '../widgets/kardo_components.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    return Scaffold(
      backgroundColor: t.scaffoldBackground,
      appBar: const IOSNavBar(
        title: 'Insights',
        showBackButton: false,
      ),
      body: _buildInsightsView(context),
    );
  }

  Widget _buildInsightsView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        KardoSpacing.screen,
        KardoSpacing.sm,
        KardoSpacing.screen,
        KardoSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsSection(context),
          const SizedBox(height: KardoSpacing.xl),
          _buildOrganizationTypeBreakdown(context),
          const SizedBox(height: KardoSpacing.xl),
          _buildTopOrganizations(context),
          const SizedBox(height: KardoSpacing.xl),
          _buildDepartmentBreakdown(context),
          const SizedBox(height: KardoSpacing.xl),
          _buildContactCompletenessCard(context),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Get local cards to compute insights
        final localCardsState =
            ref.watch(localCardsProviderForInsights);

        return localCardsState.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: KardoSpacing.xxl),
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context)
                    .extension<KardoTokensExtension>()!
                    .tokens
                    .accent,
              ),
            ),
          ),
          error: (error, _) => KardoErrorState(
            message: 'Insights could not be loaded.',
            onRetry: () => ref.invalidate(localCardsProviderForInsights),
          ),
          data: (cards) {
            final insights = _computeInsights(cards);
            final t =
                Theme.of(context).extension<KardoTokensExtension>()!.tokens;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KardoSectionHeader('Overview'),
                const SizedBox(height: KardoSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        '${insights['totalCards']}',
                        'Total Cards',
                        Icons.business_center_rounded,
                        t.accent,
                      ).animate().scale(delay: 0.ms, duration: 400.ms),
                    ),
                    const SizedBox(width: KardoSpacing.md),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        '${insights['organizationCount']}',
                        'Organizations',
                        Icons.domain_rounded,
                        t.success,
                      ).animate().scale(delay: 100.ms, duration: 400.ms),
                    ),
                    const SizedBox(width: KardoSpacing.md),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        '${insights['departmentCount']}',
                        'Departments',
                        Icons.people_rounded,
                        t.info,
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
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    return GlassmorphismContainer.fromTheme(
      context,
      child: Padding(
        padding: const EdgeInsets.all(KardoSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: KardoSpacing.md),
            Text(
              value,
              style: t.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: KardoSpacing.xs),
            Text(
              label,
              style: t.bodySmall.copyWith(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationTypeBreakdown(BuildContext context) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
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
                const KardoSectionHeader('Cards by Organization Type'),
                const SizedBox(height: KardoSpacing.md),
                ...orgTypeMap.entries.map((entry) {
                  final percentage =
                      (entry.value / insights['totalCards'] * 100)
                          .toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: KardoSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: t.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${entry.value} ($percentage%)',
                              style: t.bodySmall
                                  .copyWith(color: t.textTertiary),
                            ),
                          ],
                        ),
                        const SizedBox(height: KardoSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: entry.value /
                                insights['totalCards'],
                            minHeight: 8,
                            backgroundColor: t.surfaceBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getColorForOrgType(t, entry.key),
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
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
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
                const KardoSectionHeader('Top Organizations'),
                const SizedBox(height: KardoSpacing.md),
                ...topOrgs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final org = entry.value;
                  final maxCount = topOrgs.first['count'] as int;
                  final percentage =
                      (org['count'] as int) / maxCount * 100;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: KardoSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _getColorForIndex(t, index),
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
                        const SizedBox(width: KardoSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                org['name'] as String,
                                style: t.bodyMedium
                                    .copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: KardoSpacing.xs),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  minHeight: 6,
                                  backgroundColor: t.surfaceBackground,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getColorForIndex(t, index),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: KardoSpacing.sm),
                        Text(
                          '${org['count']}',
                          style: t.bodySmall
                              .copyWith(fontWeight: FontWeight.bold),
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
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
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
                const KardoSectionHeader('Top Departments'),
                const SizedBox(height: KardoSpacing.md),
                Wrap(
                  spacing: KardoSpacing.sm,
                  runSpacing: KardoSpacing.sm,
                  children: displayDepts.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: t.accentLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: t.accent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key,
                            style: t.bodySmall
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: KardoSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: const TextStyle(
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
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
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

            return GlassmorphismContainer.fromTheme(
              context,
              child: Padding(
                padding: const EdgeInsets.all(KardoSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Completeness',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: KardoSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCircularStat(
                          context,
                          withBoth,
                          totalCards,
                          'Email & Phone',
                          t.success,
                        ),
                        _buildCircularStat(
                          context,
                          withEmail,
                          totalCards,
                          'Email Only',
                          t.accent,
                        ),
                        _buildCircularStat(
                          context,
                          withPhone,
                          totalCards,
                          'Phone Only',
                          t.info,
                        ),
                      ],
                    ),
                  ],
                ),
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
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
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
                  backgroundColor: t.surfaceBackground,
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

  Color _getColorForOrgType(KardoTokens t, String type) {
    final colors = {
      'UNIVERSITY': t.accent,
      'BUSINESS': t.success,
      'CONSULTANCY': t.warning,
      'NGO': t.kanbanFollowedUp,
      'STARTUP': t.error,
      'GOVERNMENT': t.info,
    };
    return colors[type] ?? t.accent;
  }

  Color _getColorForIndex(KardoTokens t, int index) {
    final colors = [
      t.accent,
      t.success,
      t.warning,
      t.info,
      t.kanbanContacted,
    ];
    return colors[index % colors.length];
  }
}

// Create a provider for local cards used by insights
final localCardsProviderForInsights = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = LocalDatabaseService();
  return await db.getCards();
});
