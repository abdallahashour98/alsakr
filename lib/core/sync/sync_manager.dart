import 'dart:async';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:al_sakr/core/sync/connectivity_service.dart';
import 'package:al_sakr/core/sync/downsync_service.dart';
import 'package:al_sakr/core/sync/id_mapping_service.dart';
import 'package:al_sakr/core/sync/sync_constants.dart';
import 'package:al_sakr/core/sync/sync_logger.dart';
import 'package:al_sakr/core/sync/upsync_service.dart';
import 'package:al_sakr/features/store/controllers/store_controller.dart';
import 'package:al_sakr/features/clients/controllers/client_controller.dart';
import 'package:al_sakr/features/sales/controllers/sales_controller.dart';
import 'package:al_sakr/features/suppliers/controllers/supplier_controller.dart';
import 'package:al_sakr/features/purchases/controllers/purchases_controller.dart';
import 'package:al_sakr/features/expenses/controllers/expenses_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'sync_manager.g.dart';

/// State exposed by SyncManager to the UI layer.
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? lastError;
  final int pendingCount;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastError,
    this.pendingCount = 0,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? lastError,
    int? pendingCount,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: lastError,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

/// The main Sync Manager that orchestrates bidirectional sync
/// between the local SQLite database and PocketBase.
///
/// It listens to [ConnectivityStatus] and triggers a sync cycle
/// (Upsync → Downsync) whenever connectivity is restored.
///
/// Usage from UI:
/// ```dart
/// // Watch sync state
/// final syncState = ref.watch(syncManagerProvider);
///
/// // Manually trigger sync
/// ref.read(syncManagerProvider.notifier).triggerSync();
/// ```
@Riverpod(keepAlive: true)
class SyncManager extends _$SyncManager {
  Timer? _debounceTimer;
  bool _isRunning = false;

  @override
  SyncState build() {
    // Listen to connectivity changes and trigger sync when online.
    ref.listen<AsyncValue<bool>>(connectivityStatusProvider, (previous, next) {
      final wasOffline = previous?.value != true;
      final isOnline = next.value == true;

      if (wasOffline && isOnline) {
        SyncLogger.info('Connectivity restored — scheduling sync...');
        _scheduleSyncWithDebounce();
      }
    });

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    // ── Trigger an initial sync on startup ──────────────────────────
    // If the app starts already online, the listener above won't fire
    // because there's no offline→online transition. So we schedule an
    // initial sync after a short delay to let providers initialise.
    Future.microtask(() async {
      try {
        final connectivity = await ref.read(connectivityStatusProvider.future);
        if (connectivity) {
          SyncLogger.info('App started online — triggering initial sync...');
          _scheduleSyncWithDebounce();
        }
      } catch (e) {
        SyncLogger.warn('Initial connectivity check failed: $e');
      }
    });

    return const SyncState();
  }

  /// Debounce sync trigger to avoid rapid re-triggers.
  void _scheduleSyncWithDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(syncDebounce, () {
      triggerSync();
    });
  }

  /// Manually trigger a full sync cycle.
  /// Can be called from the UI (e.g., a "Sync Now" button).
  Future<void> triggerSync() async {
    if (_isRunning) {
      SyncLogger.warn('Sync already in progress — skipping.');
      return;
    }

    _isRunning = true;
    state = state.copyWith(isSyncing: true, lastError: null);
    final stopwatch = Stopwatch()..start();

    try {
      final db = await ref.read(localDatabaseProvider.future);
      final pb = await ref.read(pbHelperProvider.future);

      final idMapper = IdMappingService(db);

      // ── Step 1: Upsync (local → server) ────────────────────────────
      SyncLogger.info('═══ Starting UPSYNC ═══');
      final upsync = UpsyncService(db: db, pb: pb, idMapper: idMapper);
      await upsync.upsyncAll();

      // ── Step 2: Downsync (server → local) ──────────────────────────
      SyncLogger.info('═══ Starting DOWNSYNC ═══');
      final downsync = DownsyncService(db: db, pb: pb);
      await downsync.downsyncAll();

      stopwatch.stop();

      SyncLogger.summary(
        duration: stopwatch.elapsed,
        upsynced: upsync.successCount,
        downsynced: downsync.successCount,
        failures: upsync.failureCount,
      );

      // ── Step 3: Global State Invalidation ───────────────────────
      // Invalidate core providers so that UI screens automatically rebuild
      // with the latest data fetched from the local DB.
      ref.invalidate(storeControllerProvider);
      ref.invalidate(clientControllerProvider);
      ref.invalidate(salesControllerProvider);
      ref.invalidate(supplierControllerProvider);
      ref.invalidate(purchasesControllerProvider);
      ref.invalidate(expensesControllerProvider);

      // Update pending count
      final pending = await _countPendingRecords(db);

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        lastError: null,
        pendingCount: pending,
      );
    } catch (e) {
      stopwatch.stop();
      SyncLogger.error('Sync cycle failed', e);

      state = state.copyWith(isSyncing: false, lastError: e.toString());
    } finally {
      _isRunning = false;
    }
  }

  /// Count total pending (unsynced) records across all tables.
  Future<int> _countPendingRecords(dynamic db) async {
    int total = 0;
    for (final table in syncTableOrder) {
      try {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM $table '
          'WHERE sync_status != ?',
          ['synced'],
        );
        total += (result.first['cnt'] as int? ?? 0);
      } catch (_) {}
    }
    return total;
  }

  /// Get the current count of pending records (useful for badge UI).
  Future<int> getPendingCount() async {
    final db = await ref.read(localDatabaseProvider.future);
    return _countPendingRecords(db);
  }
}
