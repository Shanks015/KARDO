import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/config_provider.dart';
import '../providers/data_provider.dart';
import '../theme/liquid_glass_theme.dart';
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
      _backupFrequency = prefs.getString('backup_frequency') ?? 'Never';
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

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A) // Near black for dark mode
          : LiquidGlassTheme.iceBlue,
      appBar: const IOSNavBar(
        title: 'Settings',
        showBackButton: false,
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            // Backup & Restore Section
            _currentUser == null
                ? GlassmorphismContainer.fromTheme(
                    context,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.blue,
                      ),
                      title: Text(
                        'Google Drive Backup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        'Sign in to securely backup your cards',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      trailing: FilledButton(
                        onPressed: _isLoading ? null : _handleSignIn,
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(
                            theme.colorScheme.primary,
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
                            color: isDark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          'Last backup: $_lastBackupTime',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
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
                              color: isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          style: ButtonStyle(
                            side: MaterialStateProperty.all(
                              BorderSide(
                                color: isDark
                                    ? Colors.white
                                    : Colors.black,
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
                            color: isDark
                                ? Colors.white
                                : Colors.black,
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
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
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
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black,
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
                                  theme.colorScheme.primary,
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
              child: Text(
                'kardo Standalone v3.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
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
      await GoogleSignIn().signIn();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    await _loadBackupSettings();
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    setState(() => _isLoading = false);
  }

  Future<void> _handleRestore() async {
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
                Colors.red,
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
              : 'Restore failed or no backup found.'),
          backgroundColor:
              success ? Colors.green : Colors.red,
        ),
      );
    }
    if (success) {
      ref.read(localCardsProvider.notifier).loadCards();
    }
  }

  Future<void> _handleBackupNow() async {
    setState(() => _isLoading = true);
    final success = await GoogleDriveService.backupToDrive();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Backup successful!'
              : 'Backup failed. Please try again.'),
          backgroundColor:
              success ? Colors.green : Colors.red,
        ),
      );
    }
    if (success) _refreshLastBackupDate();
  }
}