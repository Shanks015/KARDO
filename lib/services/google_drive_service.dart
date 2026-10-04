import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'local_db_service.dart';

/// An HTTP Client that injects headers for Google Drive API.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  static const String _backupFileName = 'kardo_backup.zip';

  /// Last failure reason, surfaced to the UI so "it didn't work" tells us why.
  static String? lastError;

  // Auth-only GoogleSignIn (no restricted scopes)
  static final GoogleSignIn _googleSignInAuth = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '754250458332-olj550qt0kfgf97tg6bufptet7ll8233.apps.googleusercontent.com',
    forceCodeForRefreshToken: false,
  );

  // Drive-scoped GoogleSignIn (for backup/restore only)
  static final GoogleSignIn _googleSignInDrive = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
    serverClientId: '754250458332-olj550qt0kfgf97tg6bufptet7ll8233.apps.googleusercontent.com',
  );

  /// Authenticate with Google (shows consent if not signed in)
  static Future<GoogleSignInAccount?> signIn() async {
    lastError = null;
    try {
      final account = await _googleSignInAuth.signIn();
      if (account == null) lastError = 'Sign-in was cancelled.';
      return account;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      lastError = e.toString();
      return null;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    await _googleSignInAuth.signOut();
    await _googleSignInDrive.signOut();
  }

  /// Check if user is currently signed in
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    if (await _googleSignInAuth.isSignedIn()) {
      return _googleSignInAuth.signInSilently();
    }
    return null;
  }

  /// Returns an authenticated DriveApi instance
  static Future<drive.DriveApi?> _getDriveApi() async {
    // Need drive-scoped account for Drive API access
    final account = await _googleSignInDrive.signInSilently();
    if (account == null) {
      // Try silent sign-in with drive scope
      try {
        final newAccount = await _googleSignInDrive.signIn();
        if (newAccount == null) {
          lastError ??= 'Google Drive permission was declined.';
          return null;
        }
        final headers = await newAccount.authHeaders;
        final client = GoogleAuthClient(headers);
        return drive.DriveApi(client);
      } catch (e) {
        debugPrint('Drive sign-in error: $e');
        lastError = e.toString();
        return null;
      }
    }
    final headers = await account.authHeaders;
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  /// Zips the SQLite database and the images directory
  static Future<File> _createBackupZip() async {
    final encoder = ZipFileEncoder();
    final tempDir = await getTemporaryDirectory();
    final zipPath = p.join(tempDir.path, _backupFileName);
    
    // Create new zip
    encoder.create(zipPath);

    // Add SQLite database
    final dbPath = p.join(await getDatabasesPath(), 'snapcard_secure.db');
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      encoder.addFile(dbFile);
    }

    // Add cards directory (images)
    final appDir = await getApplicationDocumentsDirectory();
    final cardsDir = Directory(p.join(appDir.path, 'cards'));
    if (cardsDir.existsSync()) {
      encoder.addDirectory(cardsDir);
    }

    encoder.close();
    return File(zipPath);
  }

  /// Uploads the zip backup to Google Drive App Data folder
  static Future<bool> backupToDrive() async {
    lastError = null;
    try {
      final api = await _getDriveApi();
      if (api == null) {
        lastError ??= 'Not authenticated with Google Drive.';
        throw Exception('Not authenticated');
      }

      final zipFile = await _createBackupZip();
      if (!zipFile.existsSync()) throw Exception('Backup zip creation failed');

      // Check if backup already exists in appDataFolder
      final query = "name = '$_backupFileName' and 'appDataFolder' in parents";
      final fileList = await api.files.list(q: query, spaces: 'appDataFolder');
      
      final media = drive.Media(zipFile.openRead(), zipFile.lengthSync());
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Update existing backup
        final existingFileId = fileList.files!.first.id!;
        await api.files.update(drive.File(), existingFileId, uploadMedia: media);
      } else {
        // Create new backup
        final newFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];
        await api.files.create(newFile, uploadMedia: media);
      }

      // Record successful backup time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_timestamp', DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      debugPrint('Backup Error: $e');
      lastError ??= e.toString();
      return false;
    }
  }

  /// Downloads the backup from Google Drive and restores DB + images
  static Future<bool> restoreFromDrive() async {
    lastError = null;
    try {
      final api = await _getDriveApi();
      if (api == null) {
        lastError ??= 'Not authenticated with Google Drive.';
        throw Exception('Not authenticated');
      }

      final query = "name = '$_backupFileName' and 'appDataFolder' in parents";
      final fileList = await api.files.list(q: query, spaces: 'appDataFolder');

      if (fileList.files == null || fileList.files!.isEmpty) {
        throw Exception('No backup found on Google Drive');
      }

      final fileId = fileList.files!.first.id!;
      
      // Download the media stream
      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, 'downloaded_backup.zip');
      final fileStream = File(zipPath).openWrite();
      await response.stream.pipe(fileStream);
      await fileStream.close();

      final zipFile = File(zipPath);
      if (!zipFile.existsSync()) throw Exception('Download failed');

      // Close all DB connections before overwriting
      await LocalDatabaseService.closeDatabase();

      // Extract zip directly to temp
      final extractDir = Directory(p.join(tempDir.path, 'extracted_backup'));
      if (extractDir.existsSync()) extractDir.deleteSync(recursive: true);
      extractDir.createSync();
      
      final bytes = zipFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final dbDir = await getDatabasesPath();
      final appDir = await getApplicationDocumentsDirectory();
      final cardsDir = Directory(p.join(appDir.path, 'cards'));

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          if (filename == 'encryption_key.txt') {
            // Restore encryption key
            final keyStr = String.fromCharCodes(data);
            const storage = FlutterSecureStorage();
            await storage.write(key: 'db_encryption_key', value: keyStr);
          } else if (filename == 'snapcard_secure.db') {
            // Restore database
            File(p.join(dbDir, filename))
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else if (filename.startsWith('cards/')) {
            // Restore image
            final destPath = p.join(appDir.path, filename);
            File(destPath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          }
        }
      }

      // Cleanup
      zipFile.deleteSync();
      if (extractDir.existsSync()) extractDir.deleteSync(recursive: true);

      return true;
    } catch (e) {
      debugPrint('Restore Error: $e');
      lastError ??= e.toString();
      return false;
    }
  }

  /// Get details of the last backup from Drive (returns null if none)
  static Future<DateTime?> getLastBackupDateFromDrive() async {
    try {
      final api = await _getDriveApi();
      if (api == null) return null;

      final query = "name = '$_backupFileName' and 'appDataFolder' in parents";
      final fileList = await api.files.list(q: query, spaces: 'appDataFolder', $fields: 'files(modifiedTime)');

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.modifiedTime;
      }
    } catch (e) {
      debugPrint('Fetch Backup Info Error: $e');
    }
    return null;
  }
}
