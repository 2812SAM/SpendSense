import '../models/transaction.dart';
import '../services/sheets_service.dart';
import '../services/local_storage_service.dart';
import '../core/constants.dart';

class SyncService {
  final SheetsService _sheets;
  final LocalStorageService _local;

  SyncService({
    SheetsService? sheets,
    LocalStorageService? local,
  })  : _sheets = sheets ?? SheetsService.instance,
        _local = local ?? LocalStorageService.instance;

  static final SyncService instance = SyncService();

  Future<bool> syncTransaction(MyTransaction transaction) async {
    final success = await _sheets.logMyTransaction(transaction);
    if (success) {
      await _local.markSynced(transaction.id);
      return true;
    }

    await _local.markSyncFailed(
      transaction.id,
      'Could not reach Google Sheets. Will retry later.',
    );
    return false;
  }

  Future<void> retryUnsyncedTransactions() async {
    final retryable = await _local.getConfirmedPendingSync();
    if (retryable.isEmpty) return;

    for (final transaction in retryable) {
      final success = await _sheets.logMyTransaction(transaction);
      if (success) {
        await _local.markSynced(transaction.id);
      } else {
        await _local.markSyncFailed(
          transaction.id,
          'Retry failed. Will try again later.',
        );
      }
    }
  }
}
