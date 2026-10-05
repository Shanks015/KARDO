import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/config_provider.dart';
import '../providers/data_provider.dart';
import '../theme/tokens.dart';
import '../widgets/ios_components.dart';
import '../services/google_drive_service.dart';
import 'export_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const String _appVersion = '2.0.0';
  static const String _repoUrl = 'https://github.com/Shanks015/KARDO';

  GoogleSignInAccount? _currentUser;
  String _backupFrequency = 'Never';
  String _lastBackupTime = 'Never';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  Future<void> _loadBackupSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backupFrequency = prefs.getString('backup_frequency') ?? 'Daily';
    });

    final account = await GoogleDriveService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _currentUser = account;
    });

    if (account != null && mounted) {
      _refreshLastBackupDate();
    }
  }

  Future<void> _refreshLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final localTime = prefs.getString('last_backup_timestamp');
    if (localTime != null) {
      final now = DateTime.now();
      final lastBackup = DateTime.parse(localTime);
      final diff = now.difference(lastBackup);
      String timeAgo;

      if (diff.inDays > 0) {
        timeAgo = '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      } else if (diff.inHours > 0) {
        timeAgo = '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inMinutes > 0) {
        timeAgo = '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
      } else {
        timeAgo = 'Just now';
      }
      setState(() => _lastBackupTime = timeAgo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    final cardCount = ref
        .watch(localCardsProvider)
        .maybeWhen(data: (cards) => cards.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: t.scaffoldBackground,
      appBar: const IOSNavBar(
        title: 'Settings',
        showBackButton: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            // ── Account / Drive sign-in ──
            _buildAccountCard(t),
            const SizedBox(height: 28),

            // ── Appearance ──
            _buildSectionHeader('Appearance', Icons.palette_outlined, t),
            const SizedBox(height: 12),
            GlassmorphismContainer.fromTheme(
              context,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Dark Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    config.isDark
                        ? 'Easy on the eyes at night'
                        : 'Bright and clear for daylight',
                    style: TextStyle(fontSize: 13, color: t.textSecondary),
                  ),
                  secondary: Icon(
                    config.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: t.accent,
                  ),
                  value: config.isDark,
                  activeColor: t.accent,
                  onChanged: (_) =>
                      ref.read(configProvider.notifier).toggleTheme(),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Data ──
            _buildSectionHeader('Data', Icons.folder_outlined, t),
            const SizedBox(height: 12),
            GlassmorphismContainer.fromTheme(
              context,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildStatChip(
                          icon: Icons.badge_outlined,
                          value: '$cardCount',
                          label: cardCount == 1 ? 'Card saved' : 'Cards saved',
                          t: t,
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          icon: Icons.save_alt_rounded,
                          value: 'CSV',
                          label: 'Export format',
                          t: t,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(Icons.import_export_rounded,
                          color: t.accent, size: 22),
                      title: Text(
                        'Export & Share Data',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Save all cards to a file',
                        style: TextStyle(
                            fontSize: 12, color: t.textSecondary),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: t.textTertiary),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExportScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Backup & Restore ──
            if (_currentUser != null) ...[
              _buildSectionHeader(
                  'Backup & Restore', Icons.cloud_sync_outlined, t),
              const SizedBox(height: 12),
              GlassmorphismContainer.fromTheme(
                context,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.schedule_rounded,
                            color: t.accent, size: 22),
                        title: Text(
                          'Auto Backup',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _backupFrequency == 'Never'
                              ? 'Automatic uploads are off'
                              : 'Uploads every ${_backupFrequency.toLowerCase()}',
                          style: TextStyle(
                              fontSize: 12, color: t.textSecondary),
                        ),
                        trailing: DropdownButton<String>(
                          value: _backupFrequency,
                          underline: const SizedBox(),
                          isDense: true,
                          dropdownColor: t.surfaceBackground,
                          items: ['Never', 'Daily', 'Weekly', 'Monthly']
                              .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                      f,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              setState(() => _backupFrequency = val);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString('backup_frequency', val);
                            }
                          },
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isLoading ? null : _handleRestore,
                              icon: const Icon(Icons.settings_backup_restore_rounded,
                                  size: 18),
                              label: const Text('Restore'),
                              style: ButtonStyle(
                                padding: MaterialStateProperty.all(
                                    const EdgeInsets.symmetric(vertical: 14)),
                                side: MaterialStateProperty.all(BorderSide(
                                    color: t.borderDefault, width: 1)),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  _isLoading ? null : _handleBackupNow,
                              icon: _isLoading
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                t.textOnAccent),
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_rounded,
                                      size: 18),
                              label: Text(_isLoading ? 'Working…' : 'Back Up Now'),
                              style: ButtonStyle(
                                padding: MaterialStateProperty.all(
                                    const EdgeInsets.symmetric(vertical: 14)),
                                backgroundColor:
                                    MaterialStateProperty.all(t.accent),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── About ──
            _buildSectionHeader('About', Icons.info_outline_rounded, t),
            const SizedBox(height: 12),
            GlassmorphismContainer.fromTheme(
              context,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(Icons.flutter_dash_rounded,
                          color: t.accent, size: 22),
                      title: Text(
                        'Version',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      trailing: Text(
                        _appVersion,
                        style: TextStyle(
                            fontSize: 14, color: t.textTertiary),
                      ),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(Icons.description_outlined,
                          color: t.accent, size: 22),
                      title: Text(
                        'Open-source Licenses',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: t.textTertiary),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Kardo',
                        applicationVersion: _appVersion,
                        applicationLegalese:
                            'Business card scanner & mini CRM',
                      ),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(Icons.code_rounded,
                          color: t.accent, size: 22),
                      title: Text(
                        'Source Code',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'github.com/Shanks015/KARDO',
                        style: TextStyle(
                            fontSize: 12, color: t.textSecondary),
                      ),
                      trailing: Icon(Icons.open_in_new_rounded,
                          color: t.textTertiary, size: 18),
                      onTap: () => launchUrl(
                        Uri.parse(_repoUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Kardo — scanned, sorted, saved.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: t.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(KardoTokens t) {
    if (_currentUser == null) {
      return GlassmorphismContainer.fromTheme(
        context,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.cloud_upload_rounded, color: t.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Drive Backup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to keep your cards safe across devices',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: IOSBorderedButton(
                  text: 'Sign In with Google',
                  icon: Icons.login_rounded,
                  isLoading: _isLoading,
                  onPressed: _handleSignIn,
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final photo = _currentUser!.photoUrl;
    final name = _currentUser!.displayName;
    final backedUp = _lastBackupTime != 'Never';

    return GlassmorphismContainer.fromTheme(
      context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: t.accent.withOpacity(0.15),
                  backgroundImage:
                      photo != null ? NetworkImage(photo) : null,
                  child: photo == null
                      ? Text(
                          (name?.isNotEmpty ?? false)
                              ? name![0].toUpperCase()
                              : _currentUser!.email[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: t.accent,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name?.isNotEmpty == true
                            ? name!
                            : _currentUser!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: backedUp ? t.success : t.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            backedUp
                                ? 'Backed up $_lastBackupTime'
                                : 'Not backed up yet',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _isLoading ? null : _handleSignOut,
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8)),
                    side: MaterialStateProperty.all(
                        BorderSide(color: t.borderDefault, width: 1)),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                        fontSize: 13, color: t.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required KardoTokens t,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.surfaceBackground.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: t.accent),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await GoogleDriveService.signIn();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    await _loadBackupSettings();
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    await GoogleDriveService.signOut();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      setState(() {
        _currentUser = null;
        _isLoading = false;
        _lastBackupTime = 'Never';
      });
    }
  }

  Future<void> _handleRestore() async {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    if (_currentUser == null) {
      await _handleSignIn();
      if (_currentUser == null || !mounted) return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
            'This will replace all your current cards with the data from Google Drive. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(t.error),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    final success = await GoogleDriveService.restoreFromDrive();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Restore successful! Your cards are now loaded.'
              : GoogleDriveService.lastError ??
                  'Restore failed or no backup found.'),
          backgroundColor: success ? t.success : t.error,
        ),
      );
    }
    if (success) {
      ref.read(localCardsProvider.notifier).loadCards();
    }
  }

  Future<void> _handleBackupNow() async {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;

    if (_currentUser == null) {
      await _handleSignIn();
      if (_currentUser == null) return;
    }

    setState(() => _isLoading = true);
    final success = await GoogleDriveService.backupToDrive();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Backup successful!'
              : GoogleDriveService.lastError ??
                  'Backup failed. Please try again.'),
          backgroundColor: success ? t.success : t.error,
        ),
      );
    }
    if (success) _refreshLastBackupDate();
  }

  Widget _buildSectionHeader(
      String title, IconData icon, KardoTokens t) {
    return Row(
      children: [
        Icon(icon, size: 15, color: t.textTertiary),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: t.textTertiary,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
