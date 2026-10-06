import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'local_db_service.dart';

class OldVersionImportResult {
  final int imported;
  final int skipped;
  final int photos;

  const OldVersionImportResult({
    required this.imported,
    required this.skipped,
    required this.photos,
  });
}

/// Merges a kardo_migration_export.zip (created by the old
/// com.niknotjonas.visitingcard.mobile_app build) into this app's database.
///
/// The old app lives in a separate Android sandbox, so its data can only
/// cross over as a file the user picks here. The zip carries the SQLCipher
/// database, its encryption key and the cards/ photo directory — the same
/// layout the existing Drive backup uses.
class OldVersionImportService {
  static Future<OldVersionImportResult> importFromZipBytes(
      Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw Exception('This file is not a valid Kardo backup.');
    }

    final dbEntry = archive.findFile('snapcard_secure.db');
    final keyEntry = archive.findFile('encryption_key.txt');
    if (dbEntry == null) {
      throw Exception('Backup is missing its database (snapcard_secure.db).');
    }
    if (keyEntry == null) {
      throw Exception('Backup is missing its decryption key.');
    }

    final tempDir = await getTemporaryDirectory();
    final extractRoot =
        Directory(p.join(tempDir.path, 'old_kardo_import'));
    if (extractRoot.existsSync()) {
      extractRoot.deleteSync(recursive: true);
    }
    extractRoot.createSync(recursive: true);

    final oldDbPath = p.join(extractRoot.path, 'snapcard_secure.db');
    File(oldDbPath).writeAsBytesSync(dbEntry.content as List<int>);
    final password = String.fromCharCodes(keyEntry.content as List<int>);

    Database? oldDb;
    try {
      oldDb = await openDatabase(
        oldDbPath,
        password: password,
        readOnly: true,
      );
      final oldRows = await oldDb.query('cards');
      await oldDb.close();
      oldDb = null;

      final rows =
          oldRows.map((r) => Map<String, dynamic>.from(r)).toList();

      final dbService = LocalDatabaseService();
      final appDir = await getApplicationDocumentsDirectory();
      final cardsDir = Directory(p.join(appDir.path, 'cards'));
      if (!cardsDir.existsSync()) cardsDir.createSync(recursive: true);

      int imported = 0;
      int skipped = 0;
      int photos = 0;

      for (final row in rows) {
        row['image_path'] =
            await _recoverImage(archive, row, cardsDir, isNew: () {
          photos++;
        });

        final duplicate = await dbService.checkDuplicate(row);
        if (duplicate != null) {
          skipped++;
          continue;
        }
        await dbService.saveCard(row);
        imported++;
      }

      return OldVersionImportResult(
        imported: imported,
        skipped: skipped,
        photos: photos,
      );
    } finally {
      await oldDb?.close();
      try {
        extractRoot.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Old rows store absolute paths inside the old package's sandbox
  /// (/data/user/0/com.niknotjonas.../app_flutter/cards/...). Locates the
  /// photo in the zip, copies it into this app's cards directory and
  /// returns the new local path — or '' when the photo is not in the backup.
  static Future<String> _recoverImage(
    Archive archive,
    Map<String, dynamic> row,
    Directory cardsDir, {
    required void Function() isNew,
  }) async {
    final rawPath = (row['image_path'] ?? '').toString();
    if (rawPath.isEmpty) return '';

    final normalized = rawPath.replaceAll('\\', '/');
    if (!normalized.contains('cards/')) return '';
    final base = p.basename(normalized);
    if (base.isEmpty) return '';

    final dest = File(p.join(cardsDir.path, base));
    if (dest.existsSync()) return dest.path;

    final entry = archive.findFile('cards/$base');
    if (entry == null) return '';

    dest.writeAsBytesSync(entry.content as List<int>);
    isNew();
    return dest.path;
  }
}
