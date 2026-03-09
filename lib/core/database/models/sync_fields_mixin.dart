import 'package:al_sakr/core/database/database_constants.dart';

/// Mixin that provides common sync-related fields and serialization helpers
/// for all local database model classes.
mixin SyncFieldsMixin {
  String get id;
  String get localId;
  String get syncStatus;
  String? get lastSyncedAt;
  String? get pbUpdated;
  String? get created;
  String? get updated;

  /// Returns a map of only the sync-related columns.
  Map<String, dynamic> syncFieldsToMap() => {
    DbConstants.colId: id,
    DbConstants.colLocalId: localId,
    DbConstants.colSyncStatus: syncStatus,
    DbConstants.colLastSyncedAt: lastSyncedAt,
    DbConstants.colPbUpdated: pbUpdated,
    DbConstants.colCreated: created,
    DbConstants.colUpdated: updated,
  };

  /// Reads the common sync fields from a SQLite row map.
  static Map<String, dynamic> extractSyncFields(Map<String, dynamic> map) => {
    'id': map[DbConstants.colId] ?? '',
    'localId': map[DbConstants.colLocalId] ?? '',
    'syncStatus': map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
    'lastSyncedAt': map[DbConstants.colLastSyncedAt],
    'pbUpdated': map[DbConstants.colPbUpdated],
    'created': map[DbConstants.colCreated],
    'updated': map[DbConstants.colUpdated],
  };
}
