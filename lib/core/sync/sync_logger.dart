import 'package:flutter/foundation.dart';

/// Simple logger for sync operations.
/// Prints to console in debug mode only.
class SyncLogger {
  static void info(String message) {
    if (kDebugMode) {
      print('🔄 [Sync] $message');
    }
  }

  static void success(String message) {
    if (kDebugMode) {
      print('✅ [Sync] $message');
    }
  }

  static void error(String message, [Object? error]) {
    if (kDebugMode) {
      print('❌ [Sync] $message${error != null ? ': $error' : ''}');
    }
  }

  static void warn(String message) {
    if (kDebugMode) {
      print('⚠️ [Sync] $message');
    }
  }

  /// Logs a summary of a sync cycle.
  static void summary({
    required Duration duration,
    required int upsynced,
    required int downsynced,
    required int failures,
  }) {
    if (kDebugMode) {
      print(
        '📊 [Sync] Completed in ${duration.inMilliseconds}ms '
        '| ⬆$upsynced ⬇$downsynced ❌$failures',
      );
    }
  }
}
