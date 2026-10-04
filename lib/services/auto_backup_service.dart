import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_drive_service.dart';

/// Opportunistic backup triggered by app lifecycle (pause/resume).
///
/// The Auto Backup dropdown only wrote `backup_frequency` to prefs and
/// nothing ever consumed it — this closes that gap. Runs silently, only
/// when the user picked a frequency, the interval has elapsed, and a
/// Google account is already signed in (a lifecycle hook must never pop
/// a consent dialog at the user).
class AutoBackupService {
  static bool _running = false;

  static Future<void> runIfNeeded() async {
    if (_running) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final interval = _intervalFor(prefs.getString('backup_frequency'));
      if (interval == null) {
        debugPrint('Auto backup: skipped (frequency off)');
        return;
      }

      final last = prefs.getString('last_backup_timestamp');
      if (last != null) {
        final age = DateTime.now().difference(DateTime.parse(last));
        if (age < interval) {
          debugPrint('Auto backup: skipped (not due yet)');
          return;
        }
      }

      if (await GoogleDriveService.getCurrentUser() == null) {
        debugPrint('Auto backup: skipped (not signed in)');
        return;
      }

      final ok = await GoogleDriveService.backupToDrive();
      debugPrint(ok
          ? 'Auto backup succeeded'
          : 'Auto backup failed: ${GoogleDriveService.lastError}');
    } catch (e) {
      debugPrint('Auto backup error: $e');
    } finally {
      _running = false;
    }
  }

  static Duration? _intervalFor(String? frequency) {
    switch (frequency) {
      case 'Daily':
        return const Duration(days: 1);
      case 'Weekly':
        return const Duration(days: 7);
      case 'Monthly':
        return const Duration(days: 30);
      default:
        return null;
    }
  }
}
