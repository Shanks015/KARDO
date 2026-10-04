import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/config_provider.dart';
import '../providers/data_provider.dart';
import '../theme/liquid_glass_theme.dart';
import '../theme/tokens.dart';
import '../widgets/ios_components.dart';
import '../services/google_drive_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  GoogleSignInAccount? _currentUser;
  String _backupFrequency = 'Never';
  String _lastBackupTime = 'Unknown';
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
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;

    return Scaffold(
      backgroundColor: t.scaffoldBackground,
      appBar: const IOSNavBar(
        title: 'Settings',
        showBackButton: false,
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            // Appearance Section
            _buildSectionHeader('Appearance', t),
            const SizedBox(height: 12),
            GlassmorphismContainer.fromTheme(
              context,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: t.textPrimary,
                  ),
                ),
                subtitle: Text(
                  config.isDark ? 'Dark theme enabled' : 'Light theme enabled',
                  style: TextStyle(
                    fontSize: 14,
                    color: t.textSecondary,
                  ),
                ),
                secondary: Icon(
                  config.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: t.accent,
                ),
                value: config.isDark,
                activeColor: t.accent,
                onChanged: (_) => ref.read(configProvider.notifier).toggleTheme(),
              ),
            ),
            const SizedBox(height: 24),

            // Backup & Restore Section
            _currentUser == null
                ? GlassmorphismContainer.fromTheme(
                    context,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.cloud_upload_rounded,
                        color: t.accent,
                      ),
                      title: Text(
                        'Google Drive Backup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: t.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Sign in to securely backup your cards',
                        style: TextStyle(
                          fontSize: 14,
                          color: t.textSecondary,
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: _isLoading ? null : _handleSignIn,
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 14,
                            color: t.textOnAccent,
                          ),
                        ),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(
                            t.accent,
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // User Info
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: _currentUser?.photoUrl !=
                                  null
                              ? NetworkImage(
                                  _currentUser!.photoUrl!)
                              : null,
                          child: _currentUser?.photoUrl ==
                                  null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          _currentUser!.email,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: t.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Last backup: $_lastBackupTime',
                          style: TextStyle(
                            fontSize: 14,
                            color: t.textSecondary,
                          ),
                        ),
                        trailing: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : _handleSignOut,
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 14,
                              color: t.textPrimary,
                            ),
                          ),
                          style: ButtonStyle(
                            side: MaterialStateProperty.all(
                              BorderSide(
                                color: t.borderDefault,
                                width: 1,
                              ),
                            ),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),

                      // Auto Backup
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Auto Backup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: t.textPrimary,
                          ),
                        ),
                        trailing: DropdownButton<String>(
                          value: _backupFrequency,
                          underline: const SizedBox(),
                          isDense: true,
                          items: ['Never', 'Daily', 'Weekly', 'Monthly']
                              .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                      f,
                                      style: TextStyle(
                                        fontSize: 14,
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
                              await prefs.setString(
                                  'backup_frequency', val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Backup/Restore Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : _handleRestore,
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Restore'),
                              style: ButtonStyle(
                                side: MaterialStateProperty.all(
                                  BorderSide(
                                    color: t.borderDefault,
                                    width: 1,
                                  ),
                                ),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : _handleBackupNow,
                              icon: const Icon(Icons.cloud_upload_rounded),
                              label: const Text('Back Up'),
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(
                                  t.accent,
                                ),
                                shape: MaterialStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
            const SizedBox(height: 24),



            // About Section
            Center(
              child:               Text(
                'kardo Standalone v3.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: t.textTertiary,
                ),
              ),
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
      });
    }
  }

  Future<void> _handleRestore() async {
    final t = Theme.of(context).extension<KardoTokensExtension>()!.tokens;
    if (_currentUser == null) {
      await _handleSignIn();
      if (_currentUser == null) return;
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
              backgroundColor: MaterialStateProperty.all(
                t.error,
              ),
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ?? false;

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
          backgroundColor:
              success ? t.success : t.error,
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
          backgroundColor:
              success ? t.success : t.error,
        ),
      );
    }
    if (success) _refreshLastBackupDate();
  }

  Widget _buildSectionHeader(String title, KardoTokens t) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: t.textTertiary,
        letterSpacing: 0.5,
      ),
    );
  }
}