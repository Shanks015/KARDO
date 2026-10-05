import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../theme/tokens.dart';
import '../widgets/ios_components.dart';
import '../widgets/kardo_components.dart';
import 'scanner_screen.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    final state = ref.watch(localCardsProviderForInsights);

    return Scaffold(
      backgroundColor: t.scaffoldBackground,
      appBar: const IOSNavBar(
        title: 'Insights',
        showBackButton: false,
      ),
      body: state.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: t.accent),
        ),
        error: (error, _) => KardoErrorState(
          message: 'Insights could not be loaded.',
          onRetry: () => ref.invalidate(localCardsProviderForInsights),
        ),
        data: (cards) => cards.isEmpty
            ? KardoEmptyState(
                icon: Icons.insights_rounded,
                title: 'No insights yet',
                message:
                    'Scan a few cards and this page will show the patterns across your network.',
                actionLabel: 'Scan Card',
                actionIcon: Icons.camera_alt_rounded,
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                ),
              )
            : _buildContent(context, cards),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Map<String, dynamic>> cards) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    final insights = _computeInsights(cards);

    final children = <Widget>[
      _buildOverview(context, insights),
      const SizedBox(height: KardoSpacing.xl),
      _buildActivity(context, t, insights),
      const SizedBox(height: KardoSpacing.xl),
      _buildPipeline(context, t, insights),
      const SizedBox(height: KardoSpacing.xl),
      _buildAttention(context, t, insights),
    ];

    void addSection(Widget? section) {
      if (section == null) return;
      children
        ..add(const SizedBox(height: KardoSpacing.xl))
        ..add(section);
    }

    addSection(_buildOrgTypeBreakdown(context, t, insights));
    addSection(_buildTopOrganizations(context, t, insights));
    addSection(_buildDepartmentBreakdown(context, t, insights));
    addSection(_buildContactCompleteness(context, t, insights));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        KardoSpacing.screen,
        KardoSpacing.sm,
        KardoSpacing.screen,
        KardoSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ── Overview ───────────────────────────────────────────────────────────────

  Widget _buildOverview(BuildContext context, Map<String, dynamic> insights) {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
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

  // ── Recent activity ────────────────────────────────────────────────────────

  Widget _buildActivity(
      BuildContext context, KardoTokens t, Map<String, dynamic> insights) {
    final DateTime? latest = insights['latestScan'] as DateTime?;
    final List<int> weekly = (insights['weekly'] as List<int>);
    final int thisWeek = insights['addedThisWeek'] as int;
    final maxWeek = weekly.fold<int>(1, (m, v) => v > m ? v : m);

    return KardoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.accentLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.history_rounded, color: t.accent, size: 19),
              ),
              const SizedBox(width: KardoSpacing.md),
              Text(
                'Recent activity',
                style: t.bodyLarge.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: t.accentLight,
                  borderRadius: BorderRadius.circular(t.radiusPill),
                ),
                child: Text(
                  thisWeek > 0 ? '+$thisWeek this week' : 'No scans this week',
                  style: t.labelSmall.copyWith(
                    color: t.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KardoSpacing.md),
          Text(
            latest == null
                ? 'No recent scans'
                : 'Last scan ${_relTime(latest)}',
            style: t.bodySmall.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: KardoSpacing.lg),
          SizedBox(
            height: 76,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final count in weekly)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (count > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '$count',
                                style: t.labelSmall
                                    .copyWith(color: t.textTertiary),
                              ),
                            ),
                          Container(
                            height: count == 0
                                ? 4
                                : 12 + (count / maxWeek) * 48,
                            decoration: BoxDecoration(
                              color: count == 0
                                  ? t.surfaceBackground
                                  : t.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: KardoSpacing.sm),
          Text(
            'Cards added over the last 6 weeks',
            style: t.labelSmall.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }

  // ── Pipeline ───────────────────────────────────────────────────────────────

  Widget _buildPipeline(
      BuildContext context, KardoTokens t, Map<String, dynamic> insights) {
    final byKanban = insights['byKanban'] as Map<String, int>;
    final int total = insights['totalCards'] as int;
    final int pending = insights['pendingFollowUp'] as int;

    const statuses = ['New Lead', 'Contacted', 'Followed Up', 'Closed'];
    final colors = {
      'New Lead': t.kanbanNewLead,
      'Contacted': t.kanbanContacted,
      'Followed Up': t.kanbanFollowedUp,
      'Closed': t.kanbanClosed,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KardoSectionHeader('Pipeline'),
        const SizedBox(height: KardoSpacing.md),
        KardoCard(
          child: Column(
            children: [
              for (int i = 0; i < statuses.length; i++) ...[
                if (i > 0) const SizedBox(height: KardoSpacing.md),
                _pipelineRow(
                  t,
                  label: statuses[i],
                  count: byKanban[statuses[i]] ?? 0,
                  total: total,
                  color: colors[statuses[i]]!,
                ),
              ],
              if (pending > 0) ...[
                const SizedBox(height: KardoSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(KardoSpacing.md),
                  decoration: BoxDecoration(
                    color: t.warning.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(t.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.forum_rounded,
                          color: t.warning, size: 18),
                      const SizedBox(width: KardoSpacing.sm),
                      Expanded(
                        child: Text(
                          '$pending contacts are waiting on a follow-up',
                          style: t.bodySmall.copyWith(
                            color: t.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _pipelineRow(
    KardoTokens t, {
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: KardoSpacing.sm),
            Text(label,
                style: t.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('$count',
                style: t.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: KardoSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : count / total,
            minHeight: 6,
            backgroundColor: t.surfaceBackground,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Needs attention ────────────────────────────────────────────────────────

  Widget _buildAttention(
      BuildContext context, KardoTokens t, Map<String, dynamic> insights) {
    final issues = <_AttentionIssue>[];

    final missingEmail = insights['missingEmail'] as int;
    final missingPhone = insights['missingPhone'] as int;
    final missingLocation = insights['missingLocation'] as int;
    final duplicateOrgs = insights['duplicateOrgs'] as int;
    final duplicateExtra = insights['duplicateExtra'] as int;
    final Map<String, dynamic>? topDuplicate =
        insights['topDuplicate'] as Map<String, dynamic>?;

    if (missingEmail > 0) {
      issues.add(_AttentionIssue(
        Icons.mail_outline_rounded,
        '$missingEmail ${missingEmail == 1 ? 'card has' : 'cards have'} no email address',
      ));
    }
    if (missingPhone > 0) {
      issues.add(_AttentionIssue(
        Icons.phone_outlined,
        '$missingPhone ${missingPhone == 1 ? 'card has' : 'cards have'} no phone number',
      ));
    }
    if (missingLocation > 0) {
      issues.add(_AttentionIssue(
        Icons.location_on_outlined,
        '$missingLocation ${missingLocation == 1 ? 'card is' : 'cards are'} missing a location',
      ));
    }
    if (duplicateOrgs > 0) {
      final detail = topDuplicate != null
          ? ' — ${topDuplicate['name']} alone has ${topDuplicate['count']}'
          : '';
      issues.add(_AttentionIssue(
        Icons.copy_all_rounded,
        '$duplicateExtra extra ${duplicateExtra == 1 ? 'contact' : 'contacts'} across $duplicateOrgs already-known '
        'organizations$detail',
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KardoSectionHeader('Needs Attention'),
        const SizedBox(height: KardoSpacing.md),
        KardoCard(
          child: issues.isEmpty
              ? Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.success.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_rounded,
                          color: t.success, size: 19),
                    ),
                    const SizedBox(width: KardoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your records look complete',
                              style: t.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            'Contact details present, no duplicate organizations.',
                            style: t.bodySmall
                                .copyWith(color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (int i = 0; i < issues.length; i++) ...[
                      if (i > 0)
                        const SizedBox(height: KardoSpacing.md),
                      Row(
                        children: [
                          Icon(issues[i].icon,
                              color: t.warning, size: 18),
                          const SizedBox(width: KardoSpacing.sm),
                          Expanded(
                            child: Text(
                              issues[i].text,
                              style: t.bodySmall
                                  .copyWith(color: t.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  // ── Organization type breakdown ────────────────────────────────────────────

  Widget? _buildOrgTypeBreakdown(
      BuildContext context, KardoTokens t, Map<String, dynamic> insights) {
    final orgTypeMap = insights['cardsByOrgType'] as Map<String, int>;
    if (orgTypeMap.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KardoSectionHeader('Cards by Organization Type'),
        const SizedBox(height: KardoSpacing.md),
        ...orgTypeMap.entries.map((entry) {
          final percentage =
              (entry.value / insights['totalCards'] * 100).toStringAsFixed(1);
          return Padding(
            padding: const EdgeInsets.only(bottom: KardoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key,
                        style:
                            t.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    Text('${entry.value} ($percentage%)',
                        style: t.bodySmall.copyWith(color: t.textTertiary)),
                  ],
                ),
                const SizedBox(height: KardoSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: entry.value / insights['totalCards'],
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
  }

  // ── Top organizations ──────────────────────────────────────────────────────

  Widget? _buildTopOrganizations(
      BuildContext context, KardoTokens t, Map<String, dynamic> insights) {
    final topOrgs =
        (insights['topOrganizations'] as List<Map<String, dynamic>>)
            .take(5)
            .toList();
    if (topOrgs.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KardoSectionHeader('Top Organizations'),
        const SizedBox(height: KardoSpacing.md),
        ...topOrgs.asMap().entries.map((entry) {
          final index = entry.key;
          final org = entry.value;
          final maxCount = topOrgs.first['count'] as int;
          final percentage = (org['count'] as int) / maxCount * 100;

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org['name'] as String,
                        style:
                            t.bodyMedium.copyWith(fontWeight: FontWeight.w600),
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
                Text('${org['count']}',
                    style: t.bodySmall.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideX(begin: -0.2);
        }).toList(),
      ],
    );
  }

  // ── Departments ────────────────────────────────────────────────────────────

  Widget? _buildDepartmentBreakdown(
      BuildContext context, KardoTokens t, Map<String, dynamic> insights) {
    final deptMap = insights['cardsByDepartment'] as Map<String, int>;
    if (deptMap.isEmpty) return null;

    final topDepts = deptMap.entries.toList()
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: t.accentLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.accent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.key,
                      style:
                          t.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: KardoSpacing.sm),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
  }

  // ── Contact completeness ───────────────────────────────────────────────────

  Widget? _buildContactCompleteness(
      BuildContext context, KardoTokens t, Map<String, dynamic> insights) {
    final completeness =
        insights['contactCompleteness'] as Map<String, dynamic>;

    final totalCards = completeness['total'] as int;
    final withEmail = completeness['hasEmail'] as int;
    final withPhone = completeness['hasPhone'] as int;
    final withBoth = completeness['hasBoth'] as int;

    if (totalCards == 0) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KardoSectionHeader('Contact Completeness'),
        const SizedBox(height: KardoSpacing.md),
        GlassmorphismContainer.fromTheme(
          context,
          child: Padding(
            padding: const EdgeInsets.all(KardoSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCircularStat(context, t, withBoth, totalCards,
                    'Email & Phone', t.success),
                _buildCircularStat(
                    context, t, withEmail, totalCards, 'Email Only', t.accent),
                _buildCircularStat(
                    context, t, withPhone, totalCards, 'Phone Only', t.info),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
      ],
    );
  }

  Widget _buildCircularStat(BuildContext context, KardoTokens t, int value,
      int total, String label, Color color) {
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
                  valueColor: AlwaysStoppedAnimation<Color>(color),
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
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: KardoSpacing.sm),
        Text(
          label,
          style: t.bodySmall.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        Text('($value)', style: t.bodySmall.copyWith(color: t.textSecondary)),
      ],
    );
  }

  // ── Computation ────────────────────────────────────────────────────────────

  Map<String, dynamic> _computeInsights(List<Map<String, dynamic>> cards) {
    final total = cards.length;
    final cardsByOrgType = <String, int>{};
    final cardsByOrgName = <String, int>{};
    final cardsByDepartment = <String, int>{};
    final byKanban = <String, int>{};
    int hasEmail = 0;
    int hasPhone = 0;
    int hasBoth = 0;
    int missingEmail = 0;
    int missingPhone = 0;
    int missingLocation = 0;

    DateTime? latestScan;
    final weekly = List<int>.filled(6, 0);
    int addedThisWeek = 0;
    final now = DateTime.now();

    for (var card in cards) {
      // Organization type
      final orgType =
          (card['organization_type'] ?? '').toString().toUpperCase();
      if (orgType.isNotEmpty) {
        cardsByOrgType[orgType] = (cardsByOrgType[orgType] ?? 0) + 1;
      }

      // Organization name
      final orgName = (card['organization_name'] ?? '').toString().trim();
      if (orgName.isNotEmpty) {
        cardsByOrgName[orgName] = (cardsByOrgName[orgName] ?? 0) + 1;
      }

      // Department
      final dept = (card['department'] ?? '').toString().trim();
      if (dept.isNotEmpty) {
        cardsByDepartment[dept] = (cardsByDepartment[dept] ?? 0) + 1;
      }

      // Pipeline stage
      final stage =
          (card['kanban_status'] ?? '').toString().trim().isEmpty
              ? 'New Lead'
              : card['kanban_status'].toString();
      byKanban[stage] = (byKanban[stage] ?? 0) + 1;

      // Contact completeness + gaps
      final email = (card['contact_email'] ?? '').toString().trim();
      final phone = (card['contact_number'] ?? '').toString().trim();
      final location = (card['location'] ?? '').toString().trim().isNotEmpty
          ? card['location'].toString().trim()
          : (card['address'] ?? '').toString().trim();
      final hasEmailVal = email.isNotEmpty && email.toLowerCase() != 'not found';
      final hasPhoneVal = phone.isNotEmpty && phone.toLowerCase() != 'not found';

      if (hasEmailVal) {
        hasEmail++;
      } else {
        missingEmail++;
      }
      if (hasPhoneVal) {
        hasPhone++;
      } else {
        missingPhone++;
      }
      if (hasEmailVal && hasPhoneVal) hasBoth++;
      if (location.isEmpty || location.toLowerCase() == 'not found') {
        missingLocation++;
      }

      // Activity timeline
      final created = DateTime.tryParse(
              (card['created_at'] ?? card['timestamp'] ?? '').toString()) ??
          DateTime.tryParse((card['timestamp'] ?? '').toString());
      if (created != null) {
        if (latestScan == null || created.isAfter(latestScan)) {
          latestScan = created;
        }
        final ageDays = now.difference(created).inDays;
        if (ageDays < 7) addedThisWeek++;
        if (ageDays >= 0) {
          final weeksAgo = ageDays ~/ 7;
          if (weeksAgo < 6) weekly[5 - weeksAgo]++;
        }
      }
    }

    // Top organizations
    final topOrgs = cardsByOrgName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topOrgsList = topOrgs
        .take(5)
        .map((e) => {'name': e.key, 'count': e.value})
        .toList();

    // Duplicates: organizations appearing on more than one card
    final dupEntries =
        cardsByOrgName.entries.where((e) => e.value > 1).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final duplicateExtra =
        dupEntries.fold<int>(0, (sum, e) => sum + (e.value - 1));

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
      'byKanban': byKanban,
      'pendingFollowUp':
          (byKanban['New Lead'] ?? 0) + (byKanban['Contacted'] ?? 0),
      'missingEmail': missingEmail,
      'missingPhone': missingPhone,
      'missingLocation': missingLocation,
      'duplicateOrgs': dupEntries.length,
      'duplicateExtra': duplicateExtra,
      'topDuplicate': dupEntries.isEmpty
          ? null
          : {'name': dupEntries.first.key, 'count': dupEntries.first.value},
      'latestScan': latestScan,
      'weekly': weekly,
      'addedThisWeek': addedThisWeek,
    };
  }

  String _relTime(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    return 'on ${DateFormat('d MMM').format(d)}';
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

class _AttentionIssue {
  final IconData icon;
  final String text;
  const _AttentionIssue(this.icon, this.text);
}

// Create a provider for local cards used by insights
final localCardsProviderForInsights =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = LocalDatabaseService();
  return await db.getCards();
});
