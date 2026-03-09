import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/sync_fields_mixin.dart';

class PurchaseReturnModel with SyncFieldsMixin {
  @override
  final String id;
  @override
  final String localId;
  @override
  final String syncStatus;
  @override
  final String? lastSyncedAt;
  @override
  final String? pbUpdated;
  @override
  final String? created;
  @override
  final String? updated;

  final String supplier; // FK → suppliers.id
  final double totalAmount;
  final String date;

  PurchaseReturnModel({
    required this.id,
    required this.localId,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncedAt,
    this.pbUpdated,
    this.created,
    this.updated,
    required this.supplier,
    this.totalAmount = 0.0,
    required this.date,
  });

  factory PurchaseReturnModel.fromMap(Map<String, dynamic> map) {
    return PurchaseReturnModel(
      id: map[DbConstants.colId] ?? '',
      localId: map[DbConstants.colLocalId] ?? '',
      syncStatus: map[DbConstants.colSyncStatus] ?? SyncStatus.synced,
      lastSyncedAt: map[DbConstants.colLastSyncedAt],
      pbUpdated: map[DbConstants.colPbUpdated],
      created: map[DbConstants.colCreated],
      updated: map[DbConstants.colUpdated],
      supplier: map['supplier'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    ...syncFieldsToMap(),
    'supplier': supplier,
    'totalAmount': totalAmount,
    'date': date,
  };

  Map<String, dynamic> toServerMap() => {
    'supplier': supplier,
    'totalAmount': totalAmount,
    'date': date,
  };

  PurchaseReturnModel copyWith({
    String? id,
    String? localId,
    String? syncStatus,
    String? lastSyncedAt,
    String? pbUpdated,
    String? created,
    String? updated,
    String? supplier,
    double? totalAmount,
    String? date,
  }) {
    return PurchaseReturnModel(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pbUpdated: pbUpdated ?? this.pbUpdated,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      supplier: supplier ?? this.supplier,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
    );
  }
}
