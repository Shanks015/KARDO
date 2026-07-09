import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_db_service.dart';

final localDbServiceProvider = Provider((ref) => LocalDatabaseService());

class LocalCardsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final LocalDatabaseService _db;

  LocalCardsNotifier(this._db) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    // Migrate from SharedPreferences on first run
    await _db.migrateFromSharedPreferences();
    await loadCards();
  }

  Future<void> loadCards() async {
    try {
      final cards = await _db.getCards();
      state = AsyncValue.data(cards);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<int> addCard(Map<String, dynamic> card) async {
    final slNo = await _db.saveCard(card);
    await loadCards();
    return slNo;
  }

  Future<void> updateCard(int slNo, Map<String, dynamic> card) async {
    await _db.updateCard(slNo, card);
    await loadCards();
  }

  Future<void> updateKanbanStatus(int slNo, String status) async {
    await _db.updateKanbanStatus(slNo, status);
    await loadCards();
  }

  Future<void> deleteCard(int slNo) async {
    await _db.deleteCard(slNo);
    await loadCards();
  }
}

/// Primary state notifier provider for local cards
final localCardsProvider =
    StateNotifierProvider<LocalCardsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final db = ref.watch(localDbServiceProvider);
  return LocalCardsNotifier(db);
});

/// Backwards compatibility provider for screens that watch sheetDataProvider
final sheetDataProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final localState = ref.watch(localCardsProvider);
  return localState.maybeWhen(
    data: (list) => list,
    orElse: () => <dynamic>[],
  );
});
