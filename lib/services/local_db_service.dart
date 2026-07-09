import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class LocalDatabaseService {
  static Database? _db;
  static const String _legacyKey = 'saved_cards';

  /// Get or initialize the SQLite database
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'snapcard.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sl_no INTEGER,
            organization_type TEXT DEFAULT 'BUSINESS',
            organization_name TEXT DEFAULT '',
            location TEXT DEFAULT '',
            point_person TEXT DEFAULT '',
            department TEXT DEFAULT '',
            contact_number TEXT DEFAULT '',
            contact_email TEXT DEFAULT '',
            address TEXT DEFAULT '',
            url TEXT DEFAULT '',
            remark TEXT DEFAULT '',
            image_path TEXT DEFAULT '',
            dominant_color TEXT DEFAULT '0xFF1565C0',
            dominant_color_secondary TEXT DEFAULT '0xFF0D47A1',
            kanban_status TEXT DEFAULT 'New Lead',
            tags TEXT DEFAULT '',
            notes TEXT DEFAULT '',
            timestamp TEXT DEFAULT ''
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add new columns for v2
          try { await db.execute('ALTER TABLE cards ADD COLUMN image_path TEXT DEFAULT ""'); } catch (_) {}
          try { await db.execute('ALTER TABLE cards ADD COLUMN dominant_color TEXT DEFAULT "0xFF1565C0"'); } catch (_) {}
          try { await db.execute('ALTER TABLE cards ADD COLUMN dominant_color_secondary TEXT DEFAULT "0xFF0D47A1"'); } catch (_) {}
          try { await db.execute('ALTER TABLE cards ADD COLUMN kanban_status TEXT DEFAULT "New Lead"'); } catch (_) {}
          try { await db.execute('ALTER TABLE cards ADD COLUMN tags TEXT DEFAULT ""'); } catch (_) {}
          try { await db.execute('ALTER TABLE cards ADD COLUMN notes TEXT DEFAULT ""'); } catch (_) {}
        }
      },
    );
  }

  /// Migrate data from SharedPreferences (legacy) to SQLite on first run
  Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> legacyCards = jsonDecode(raw);
      if (legacyCards.isEmpty) return;

      final db = await database;
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cards'));
      if ((count ?? 0) > 0) return; // Already migrated

      for (final card in legacyCards) {
        if (card is Map) {
          await db.insert('cards', _sanitize(Map<String, dynamic>.from(card)));
        }
      }

      // Remove legacy data after successful migration
      await prefs.remove(_legacyKey);
      debugPrint('Migration: moved ${legacyCards.length} cards from SharedPreferences to SQLite');
    } catch (e) {
      debugPrint('Migration failed (non-critical): $e');
    }
  }

  /// Get all saved cards
  Future<List<Map<String, dynamic>>> getCards() async {
    try {
      final db = await database;
      final results = await db.query('cards', orderBy: 'sl_no DESC');
      return results.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      debugPrint('Error loading cards: $e');
      return [];
    }
  }

  /// Save a new card and return its assigned sl_no
  Future<int> saveCard(Map<String, dynamic> cardData) async {
    try {
      final db = await database;

      final maxResult = Sqflite.firstIntValue(
        await db.rawQuery('SELECT MAX(sl_no) FROM cards'),
      );
      final nextSlNo = (maxResult ?? 0) + 1;

      final newCard = _sanitize({
        ...cardData,
        'sl_no': nextSlNo,
        'SL No': nextSlNo,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await db.insert('cards', newCard, conflictAlgorithm: ConflictAlgorithm.replace);
      return nextSlNo;
    } catch (e) {
      throw Exception('Failed to save card: $e');
    }
  }

  /// Update an existing card by sl_no
  Future<void> updateCard(int slNo, Map<String, dynamic> cardData) async {
    try {
      final db = await database;
      final updates = _sanitize(cardData);
      await db.update('cards', updates, where: 'sl_no = ?', whereArgs: [slNo]);
    } catch (e) {
      throw Exception('Failed to update card: $e');
    }
  }

  /// Update kanban status of a card
  Future<void> updateKanbanStatus(int slNo, String status) async {
    final db = await database;
    await db.update(
      'cards',
      {'kanban_status': status},
      where: 'sl_no = ?',
      whereArgs: [slNo],
    );
  }

  /// Delete a card by sl_no
  Future<void> deleteCard(int slNo) async {
    try {
      final db = await database;
      await db.delete('cards', where: 'sl_no = ?', whereArgs: [slNo]);
    } catch (e) {
      throw Exception('Failed to delete card: $e');
    }
  }

  /// Check for duplicate cards
  Future<Map<String, dynamic>?> checkDuplicate(Map<String, dynamic> cardData) async {
    try {
      final db = await database;

      final String personName = (cardData['point_person'] ?? '').toString().trim().toLowerCase();
      final String contactNumber = (cardData['contact_number'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      final String contactEmail = (cardData['contact_email'] ?? '').toString().trim().toLowerCase();

      if (personName.isEmpty && contactNumber.isEmpty && contactEmail.isEmpty) return null;

      final results = await db.query('cards');
      for (final card in results) {
        final String existingName = (card['point_person'] ?? '').toString().trim().toLowerCase();
        final String existingPhone = (card['contact_number'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final String existingEmail = (card['contact_email'] ?? '').toString().trim().toLowerCase();

        if (personName.isNotEmpty && existingName.isNotEmpty && personName == existingName) {
          return Map<String, dynamic>.from(card);
        }
        if (contactNumber.isNotEmpty && existingPhone.isNotEmpty && contactNumber == existingPhone) {
          return Map<String, dynamic>.from(card);
        }
        if (contactEmail.isNotEmpty && existingEmail.isNotEmpty && contactEmail == existingEmail) {
          return Map<String, dynamic>.from(card);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking duplicate: $e');
      return null;
    }
  }

  /// Sanitize map keys to match SQLite column names
  Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    const validColumns = {
      'sl_no', 'organization_type', 'organization_name', 'location',
      'point_person', 'department', 'contact_number', 'contact_email',
      'address', 'url', 'remark', 'image_path', 'dominant_color',
      'dominant_color_secondary', 'kanban_status', 'tags', 'notes', 'timestamp',
    };

    final result = <String, dynamic>{};
    data.forEach((key, value) {
      final normalizedKey = key.toLowerCase().replaceAll(' ', '_');
      if (validColumns.contains(normalizedKey)) {
        result[normalizedKey] = value?.toString() ?? '';
      }
    });
    return result;
  }
}
